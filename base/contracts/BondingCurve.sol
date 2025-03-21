// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/Aerodrome/IRouter.sol";
import "./interfaces/Aerodrome/IPoolFactory.sol";
import "./libraries/TransferHelper.sol";
import "./Rampfun.sol";
import "./RampToken.sol";

contract BondingCurve is ReentrancyGuard {
    address public constant WETH9 = 0x4200000000000000000000000000000000000006;
    address public constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant AERODROME_POOL_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    /// @dev Constants for _exponential curve formula: y = a * e^(bx)
    uint256 public constant BASE_FACTOR = 1e10;       //@note initial price
    uint256 public constant EXP_FACTOR = 3e9;        
    uint256 public constant MAX_SUPPLY = 1e9;         
    uint256 public constant LIQUIDITY_RESERVE = 2e8;  
    uint256 public constant MAX_PURCHASABLE = 8e8; 
    uint256 public constant PRECISION = 1e18;
    //uint256 public constant e = 2718281828459045235;  // e * 1e18
    uint256 public constant VALUE = 8e18;

    address public factory;
    address[] public awaitingForMigration;
    enum TokenStatus{ NotExisting, Created, Migrated }
    mapping(address => TokenStatus) public tokens;

    event TokenBuy(address _token, address _buyer, uint256 _value);
    event TokenSell(address _token, address _seller, uint256 _value);
    event AwaitingForMigration(address _token, uint256 _timestamp);
    event MigrationToDEX(address _token, address pool, uint256 _timestamp);

    error NotEnoughFunds();
    error UnauthorizedAccess();

    constructor(address _factory) {
        factory = _factory;
    }

    modifier notMigrated(RampToken _token) {
        bool tokenMigrated = _token.tokenMigrated();
        require(!tokenMigrated, "The token has migrated");
        _;
    }

    modifier onlyToken() {
        require(tokens[msg.sender] == TokenStatus.Created, UnauthorizedAccess());
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, UnauthorizedAccess());
        _;
    }
    
    function buy(RampToken _token) external payable nonReentrant notMigrated(_token) {
        uint256 fee = msg.value / 100;
        uint256 netValue = msg.value - fee;

        (uint256 cost, uint256 amount) = _calculateCostAndAmount(netValue, _token);

        if (amount == 0) {
            revert NotEnoughFunds();
        }

        //@note implementation of initial deployer's buy
        if (msg.sender == factory) {
            _token.mint(_token.deployer(), amount);

            if (netValue > cost) {
                fee = cost / 99;
                netValue = msg.value - fee;
                (bool success, ) = _token.deployer().call{value: netValue - cost}("");
                require(success, "ETH return failed");
            }

            emit TokenBuy(address(_token), _token.deployer(), amount);
        } else {
            _token.mint(msg.sender, amount);

            if (netValue > cost) {
                fee = cost / 99;
                netValue = msg.value - fee;
                (bool success, ) = msg.sender.call{value: netValue - cost}("");
                require(success, "ETH return failed");
            }

            emit TokenBuy(address(_token), msg.sender, amount);
        }

        (bool success0, ) = factory.call{value: fee}("");
        require(success0, "Buy failed");

        if (_token.totalSupply() == MAX_PURCHASABLE) {
            _token.setMigrationOn();
        }
    }

    function sell(uint256 amount, RampToken _token) external nonReentrant notMigrated(_token) {
        require(amount > 0, "Amount must be greater than 0");

        if (_token.balanceOf(msg.sender) < amount) {
            revert NotEnoughFunds();
        }

        uint256 returnAmount = _calculateCost(amount, _token);
        uint256 fee = returnAmount / 100;

        (bool success0, ) = factory.call{value: fee}("");
        require(success0, "Sell failed");
        (bool success, ) = msg.sender.call{value: returnAmount - fee}("");
        require(success, "ETH transfer failed");

        _token.burn(msg.sender, amount);

        emit TokenSell(address(_token), msg.sender, amount);
    }

    function addToQueueForMigration() external onlyToken {
        awaitingForMigration.push(msg.sender);
        tokens[msg.sender] = TokenStatus.Migrated;

        emit AwaitingForMigration(msg.sender, block.timestamp);
    }

    function migrateToDex(address _token) public {
        //creating and initializing pool
        bool stablePool = false;
        address pool = IPoolFactory(AERODROME_POOL_FACTORY).createPool(_token, WETH9, 0);

        //mint the token to this contract
        RampToken(_token).mint(address(this), LIQUIDITY_RESERVE);

        //approve the token to router
        TransferHelper.safeApprove(_token, AERODROME_ROUTER, LIQUIDITY_RESERVE);

        //add liquidity position
        IRouter(AERODROME_ROUTER).addLiquidityETH{value: VALUE}(
            _token,
            stablePool,
            LIQUIDITY_RESERVE,
            0,
            0,
            factory,
            block.timestamp
        );

        emit MigrationToDEX(_token, pool, block.timestamp);
    }
    
    function migrateToDexBatch() external {
        for (uint i = 0; i < awaitingForMigration.length; i++) {
            migrateToDex(awaitingForMigration[i]);
            delete awaitingForMigration[i];
        }
    }

    function addToken(address _token) external onlyFactory {
        tokens[_token] = TokenStatus.Created;
    }
    
    /// @dev calculating e^x with Taylor series
    /// @param x any uint
    /// @return y = e^x
    function _exp(uint256 x) internal pure returns (uint256) {
        uint256 result = 1 * PRECISION;
        uint256 xi = 1 * PRECISION;
        uint256 fact = 1;
        
        for (uint256 i = 1; i <= 5; i++) {
            fact *= i;
            xi = xi * x;
            result += xi / fact;
        }
        
        return result;
    }

    function _getPriceAtSupply(uint256 supply) internal pure returns (uint256) {
        uint256 x = supply - (supply % 1e7);
        uint256 _expValue = _exp((EXP_FACTOR * x) / PRECISION);
        return (BASE_FACTOR * _expValue) / PRECISION;
    }

    function _calculateCostAndAmount(uint256 _value, RampToken _token) internal view returns (uint256, uint256) {
        uint256 totalCost = 0;
        uint256 remainingValue = _value;
        uint256 tokensToPurchase = 0;
        uint256 supply = _token.totalSupply();

        while (remainingValue > 0 && supply < MAX_PURCHASABLE) {
            uint256 price = _getPriceAtSupply(supply);

            if (remainingValue < price) {
                break;
            }

            uint256 maxTokensAtThisPrice = 1e7 - (supply % 1e7);
            uint256 purchasableAtThisPrice = remainingValue / price;

            if (purchasableAtThisPrice > maxTokensAtThisPrice) {
                purchasableAtThisPrice = maxTokensAtThisPrice;
            }
            
            uint256 currentCost = purchasableAtThisPrice * price;

            totalCost += currentCost;
            tokensToPurchase += purchasableAtThisPrice;
            remainingValue -= currentCost;
            supply += purchasableAtThisPrice;
        }

        return (totalCost, tokensToPurchase);
    }

    function _calculateCost(uint256 _amount, RampToken _token) internal view returns (uint256) {
        uint256 totalReceived = 0;
        uint256 remainingTokens = _amount;
        uint256 supply = _token.totalSupply();

        while (remainingTokens > 0) {
            uint256 price = _getPriceAtSupply(supply);
            uint256 tokensAtThisPrice = supply % 1e7;

            if (tokensAtThisPrice == 0) {
                tokensAtThisPrice = 1e7;
            }

            if (remainingTokens <= tokensAtThisPrice) {
                totalReceived += remainingTokens * price;
                break;
            } else {
                totalReceived += tokensAtThisPrice * price;
                remainingTokens -= tokensAtThisPrice;
                supply -= tokensAtThisPrice;
            }
        }

        return totalReceived;
    }
}