// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/Aerodrome/IRouter.sol";
import "./interfaces/Aerodrome/IPoolFactory.sol";
import "./libraries/TransferHelper.sol";
import "./RampToken.sol";

contract BondingCurve is ReentrancyGuard {
    bool public tokenMigrated;
    address feeTaker;
    RampToken public token;
    address public constant WETH9 = 0x4200000000000000000000000000000000000006;
    address public constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant AERODROME_POOL_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    /// @dev Constants for exponential curve formula: y = a * e^(bx)
    uint256 public constant BASE_FACTOR = 1e10;       //@note initial price
    uint256 public constant EXP_FACTOR = 2023568874961606700;        
    uint256 public constant MAX_SUPPLY = 1e9;         
    uint256 public constant LIQUIDITY_RESERVE = 2e8;  
    uint256 public constant MAX_PURCHASABLE = 8e8; 
    uint256 public constant PRECISION = 1e18;
    uint256 public constant e = 2718281828459045235;  // e * 1e18

    event TokenBuy(address _token, address _buyer, uint256 _value);
    event TokenSell(address _token, address _seller, uint256 _value);
    event AwaitingForMigration(address _token, uint256 _timestamp);
    event MigrationToDEX(address _token, address _pool, uint256 _timestamp);

    error NotEnoughFunds();

    constructor(address _feeTaker, RampToken _token) {
        feeTaker = _feeTaker;
        token = _token;
    }

    modifier notMigrated() {
        require(!tokenMigrated, "The token has migrated");
        _;
    }
    
    function buy() external payable nonReentrant notMigrated {
        uint256 fee = msg.value / 100;
        uint256 netValue = msg.value - fee;

        (uint256 cost, uint256 amount) = _calculateCostAndAmount(netValue);

        if (amount == 0) {
            revert NotEnoughFunds();
        }

        //@note implementation of initial deployer's buy
        if (msg.sender == feeTaker) {
            token.mint(token.deployer(), amount);

            if (netValue > cost) {
                fee = cost / 99;
                netValue = msg.value - fee;
                (bool success, ) = token.deployer().call{value: netValue - cost}("");
                require(success, "ETH return failed");
            }

            emit TokenBuy(address(token), token.deployer(), amount);
        } else {
            token.mint(msg.sender, amount);

            if (netValue > cost) {
                fee = cost / 99;
                netValue = msg.value - fee;
                (bool success, ) = msg.sender.call{value: netValue - cost}("");
                require(success, "ETH return failed");
            }

            emit TokenBuy(address(token), msg.sender, amount);
        }

        (bool success0, ) = feeTaker.call{value: fee}("");
        require(success0, "Buy failed");

        if (token.totalSupply() == MAX_PURCHASABLE) {
            _setMigrationOn();
        }
    }

    function sell(uint256 amount) external nonReentrant notMigrated {
        require(amount > 0, "Amount must be greater than 0");

        if (token.balanceOf(msg.sender) < amount) {
            revert NotEnoughFunds();
        }

        uint256 returnAmount = _calculateCost(amount);
        uint256 fee = returnAmount / 100;

        payable(feeTaker).transfer(fee);
        (bool success, ) = msg.sender.call{value: returnAmount - fee}("");
        require(success, "ETH transfer failed");

        token.burn(msg.sender, amount);

        emit TokenSell(address(token), msg.sender, amount);
    }

    function _setMigrationOn() internal {
        tokenMigrated = true;

        (bool success, ) = feeTaker.call(abi.encodeWithSignature("addToQueueForMigration()"));
        require(success, "Migration failed");

        emit AwaitingForMigration(address(token), block.timestamp);
    }
    
    function migrateToDex() external {
        //creating and initializing pool
        bool stablePool = false;
        address pool = IPoolFactory(AERODROME_POOL_FACTORY).createPool(address(token), WETH9, 0);

        //mint the token to this contract
        token.mint(address(this), LIQUIDITY_RESERVE);

        //approve the token to router
        TransferHelper.safeApprove(address(token), AERODROME_ROUTER, LIQUIDITY_RESERVE);

        //add liquidity position
        IRouter(AERODROME_ROUTER).addLiquidityETH{value: address(this).balance / 4}(
            address(token),
            stablePool,
            LIQUIDITY_RESERVE,
            0,
            0,
            feeTaker,
            block.timestamp
        );

        payable(feeTaker).transfer(address(this).balance);

        emit MigrationToDEX(address(token), pool, block.timestamp);
    }
    
    /// @dev calculating e^x with Taylor series
    /// @param x any uint
    /// @return y = e^x
    function _exp(uint256 x) internal pure returns (uint256) {
        uint256 result = PRECISION;
        uint256 xi = PRECISION;
        uint256 fact = 1;
        
        for (uint256 i = 1; i <= 5; i++) {
            fact *= i;
            xi = (xi * x) / PRECISION;
            result += xi / fact;
        }
        
        return result;
    }

    function _getPriceAtSupply(uint256 supply) internal pure returns (uint256) {
        uint256 x = supply - (supply % 1e7);
        uint256 expValue = _exp((EXP_FACTOR * x) / PRECISION);
        return (BASE_FACTOR * expValue) / PRECISION;
    }

    function _calculateCostAndAmount(uint256 _value) internal view returns (uint256, uint256) {
        uint256 totalCost = 0;
        uint256 remainingValue = _value;
        uint256 tokensToPurchase = 0;
        uint256 supply = token.totalSupply();

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

    function _calculateCost(uint256 _amount) internal view returns (uint256) {
        uint256 totalReceived = 0;
        uint256 remainingTokens = _amount;
        uint256 supply = token.totalSupply();

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