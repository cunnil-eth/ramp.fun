// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
//import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
//import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
//import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
//import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import "./RampToken.sol";
import "./interfaces/IWrappedNativeToken.sol";

contract BondingCurve is ReentrancyGuard {
    bool public tokenMigrated;
    address feeTaker;
    RampToken public token;
    address public constant UNISWAP_NFT_POS_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public constant WETH9 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    /// @dev Constants for exponential curve formula: y = 0.000001 * e^(0.00000001x)
    uint256 public constant BASE_FACTOR = 4e10;       //@note initial price
    uint256 public constant EXP_FACTOR = 1e10;        // 0.00000001 * 1e18
    uint256 public constant MAX_SUPPLY = 1e9;         
    uint256 public constant LIQUIDITY_RESERVE = 2e8;  
    uint256 public constant MAX_PURCHASABLE = 8e8; 
    uint256 public constant PRECISION = 1e18;
    uint256 public constant e = 2718281828459045235;  // e * 1e18

    event TokenBuy(address _token, address _buyer, uint256 _value);
    event TokenSell(address _token, address _seller, uint256 _value);
    event AwaitingForMigration(address _token, uint256 _timestamp);
    event MigrationToDEX(address _token, uint256 _timestamp);

    error NotEnoughFunds();

    constructor(address _feeTaker, RampToken _token) {
        feeTaker = _feeTaker;
        token = _token;
    }

    modifier notMigrated() {
        require(!tokenMigrated, "The token has migrated");
        _;
    }
    /*
    function buy(uint256 amount) external payable nonReentrant notMigrated {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 fee = msg.value / 100;
        uint256 netValue = msg.value - fee;

        (bool success0, ) = feeTaker.call{value: fee}("");
        require(success0, "Buy failed");

        uint256 availableToBuy = MAX_PURCHASABLE - token.totalSupply();
        uint256 finalAmount = amount > availableToBuy ? availableToBuy : amount;

        uint256 cost = _calculatePrice(token.totalSupply(), finalAmount);
        if (netValue < cost) {
            revert NotEnoughFunds();
        }

        token.mint(msg.sender, finalAmount);

        if (netValue > cost) {
            (bool success, ) = msg.sender.call{value: netValue - cost}("");
            require(success, "ETH return failed");
        }

        if (token.totalSupply() == MAX_PURCHASABLE) {
            _setMigrationOn();
        }

        emit TokenBuy(address(token), msg.sender, finalAmount);
    }
    */
    function buy() external payable nonReentrant notMigrated {
        uint256 fee = msg.value / 100;
        uint256 netValue = msg.value - fee;

        uint256 availableToBuy = MAX_PURCHASABLE - token.totalSupply();
        uint256 pricePerToken = _getCurrentPrice();
        uint256 maxTokensBuyable = netValue / pricePerToken;
        uint256 finalAmount = maxTokensBuyable > availableToBuy ? availableToBuy : maxTokensBuyable;

        if (finalAmount == 0) {
            revert NotEnoughFunds();
        }

        uint256 cost = _calculatePrice(token.totalSupply(), finalAmount);

        if (maxTokensBuyable > availableToBuy) {
            fee = cost / 100;
            netValue = msg.value - fee;
        }

        (bool success0, ) = feeTaker.call{value: fee}("");
        require(success0, "Buy failed");

        //@note implementation of initial deployer's buy
        if (msg.sender == feeTaker) {
            token.mint(token.deployer(), finalAmount);

            if (netValue > cost) {
                (bool success, ) = token.deployer().call{value: netValue - cost}("");
                require(success, "ETH return failed");
            }

            emit TokenBuy(address(token), token.deployer(), finalAmount);
        } else {
            token.mint(msg.sender, finalAmount);

            if (netValue > cost) {
                (bool success, ) = msg.sender.call{value: netValue - cost}("");
                require(success, "ETH return failed");
            }

            emit TokenBuy(address(token), msg.sender, finalAmount);
        } 
        if (token.totalSupply() == MAX_PURCHASABLE) {
            _setMigrationOn();
        }
    }

    function sell(uint256 amount) external nonReentrant notMigrated {
        require(amount > 0, "Amount must be greater than 0");
        if (token.balanceOf(msg.sender) < amount) {
            revert NotEnoughFunds();
        }

        uint256 returnAmount = _calculatePrice(token.totalSupply() - amount, amount);
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

    /* function migrateToDex() external {
        //creating and initializing pool
        uint24 poolFee = 5000;
        uint160 sqrtPriceX96 =  (MAX_PURCHASABLE / address(this).balance) ** 0.5;
        address pool = IUniswapV3Factory(UNISWAP_FACTORY).createPool(address(token), WETH9, poolFee);
        IUniswapV3Pool(pool).initialize(sqrtPriceX96);

        //mint a position
        uint256 amount0ToMint = LIQUIDITY_RESERVE;
        uint256 amount1ToMint = address(this).balance / (MAX_PURCHASABLE / LIQUIDITY_RESERVE);

        IWrappedNativeToken(WETH9).deposit{value: amount1ToMint}();
        token.mint(address(this), amount0ToMint);

        TransferHelper.safeApprove(address(token), UNISWAP_NFT_POS_MANAGER, amount0ToMint);
        TransferHelper.safeApprove(WETH9, UNISWAP_NFT_POS_MANAGER, amount1ToMint);
            
        (tokenId, , , ) = INonfungiblePositionManager(UNISWAP_NFT_POS_MANAGER).mint(
            INonfungiblePositionManager(UNISWAP_NFT_POS_MANAGER).MintParams({
                token0: token,
                token1: WETH9,
                fee: poolFee,
                tickLower: -887272,
                tickUpper: 887272,
                amount0Desired: amount0ToMint,
                amount1Desired: amount1ToMint,
                amount0Min: 0,
                amount1Min: 0,
                recipient: feeTaker,
                deadline: block.timestamp
            }));

        payable(feeTaker).transfer(address(this).balance);

        emit MigrationToDEX(address(token), tokenId, block.timestamp);
    }
    */
   //@audit correct calculating price
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
        uint256 expValue = _exp((EXP_FACTOR * supply) / PRECISION);
        return (BASE_FACTOR * expValue) / PRECISION;
    }

    function _calculatePrice(uint256 supply, uint256 amount) internal pure returns (uint256) {
        require(supply + amount <= MAX_SUPPLY, "Exceeds max supply");

        uint256 totalCost = 0;
        uint256 step = amount / 10;

        if (step == 0) step = 1;

        for (uint256 i = 0; i < amount; i += step) {
            uint256 currentAmount = i + step > amount ? amount - i : step;
            totalCost += _getPriceAtSupply(supply + i) * currentAmount;
        }

        return totalCost;
    }

    function _getCurrentPrice() internal view returns (uint256) {
        return _getPriceAtSupply(token.totalSupply());
    }
}