// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./RampToken.sol";

contract BondingCurve is ReentrancyGuard {
    bool public liquidityPoolCreated;
    address public liquidityPool;
    address feeTaker;
    RampToken public token;

    /// @dev Constants for exponential curve formula: y = 0.000001 * e^(0.00000001x)
    uint256 public constant BASE_FACTOR = 1e12;       // 0.000001 * 1e18
    uint256 public constant EXP_FACTOR = 1e10;        // 0.00000001 * 1e18
    uint256 public constant MAX_SUPPLY = 1e9;         
    uint256 public constant LIQUIDITY_RESERVE = 2e8;  
    uint256 public constant MAX_PURCHASABLE = 8e8; 
    uint256 public constant PRECISION = 1e18;
    uint256 public constant e = 2718281828459045235;  // e * 1e18

    event TokenBuy(address _token, address _buyer, uint256 _value);
    event TokenSell(address _token, address _seller, uint256 _value);

    constructor(address _feeTaker, address _token) {
        feeTaker = _feeTaker;
        token = RampToken(_token);
    }

    receive() external payable {
        buy{value: msg.value}();
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
        uint256 expValue = exp((EXP_FACTOR * supply) / PRECISION);
        return (BASE_FACTOR * expValue) / PRECISION;
    }

    function _calculatePrice(uint256 supply, uint256 amount) internal pure returns (uint256) {
        require(supply + amount <= MAX_SUPPLY, "Exceeds max supply");

        uint256 totalCost = 0;
        uint256 step = amount / 10;

        if (step == 0) step = 1;

        for (uint256 i = 0; i < amount; i += step) {
            uint256 currentAmount = i + step > amount ? amount - i : step;
            totalCost += getPriceAtSupply(supply + i) * currentAmount;
        }

        return totalCost;
    }

    function buy(uint256 amount) external payable nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        uint256 availableToBuy = MAX_PURCHASABLE - totalSupply();
        uint256 finalAmount = amount > availableToBuy ? availableToBuy : amount;

        uint256 cost = calculatePrice(totalSupply(), finalAmount);
        require(msg.value >= cost, "Insufficient payment");

        _mint(msg.sender, finalAmount);

        if (msg.value > cost) {
            (bool success, ) = msg.sender.call{value: msg.value - cost}("");
            require(success, "ETH return failed");
        }

        if (totalSupply() >= MAX_PURCHASABLE && !liquidityPoolCreated) {
            createLiquidityPool(owner());
        }
    }

    function buy() external payable nonReentrant {
        uint256 availableToBuy = MAX_PURCHASABLE - totalSupply();
        uint256 pricePerToken = getCurrentPrice();
        uint256 maxTokensBuyable = msg.value / pricePerToken;
        uint256 finalAmount = maxTokensBuyable > availableToBuy ? availableToBuy : maxTokensBuyable;

        require(finalAmount > 0, "Not enough ETH to buy tokens");

        uint256 cost = calculatePrice(totalSupply(), finalAmount);
        _mint(msg.sender, finalAmount);

        if (msg.value > cost) {
            (bool success, ) = msg.sender.call{value: msg.value - cost}("");
            require(success, "ETH return failed");
        }

        if (totalSupply() >= MAX_PURCHASABLE && !liquidityPoolCreated) {
            createLiquidityPool(owner());
        }
    }

    function sell(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(!liquidityPoolCreated || msg.sender != liquidityPool, "LP tokens can't be sold via curve");

        uint256 returnAmount = calculatePrice(totalSupply() - amount, amount);

        _burn(msg.sender, amount);

        (bool success, ) = msg.sender.call{value: returnAmount}("");
        require(success, "ETH transfer failed");
    }

    function createLiquidityPool(address poolAddress) public onlyOwner {
        require(!liquidityPoolCreated, "Liquidity pool already created");
        require(totalSupply() >= MAX_PURCHASABLE, "Not enough tokens sold yet");
        require(poolAddress != address(0), "Invalid pool address");

        liquidityPoolCreated = true;
        liquidityPool = poolAddress;

        _mint(poolAddress, LIQUIDITY_RESERVE);
    }

    function getCurrentPrice() public view returns (uint256) {
        return getPriceAtSupply(totalSupply());
    }

    function isReadyForLiquidityPool() public view returns (bool) {
        return totalSupply() >= MAX_PURCHASABLE && !liquidityPoolCreated;
    }

    function buy() external payable nonReentrant {
        payable(feeTaker).transfer(msg.value / 100);

        emit TokenBuy(address(token), msg.sender, )
    }

    function sell() external nonReentrant {
        
        emit TokenSell(address(token), msg.sender, )
    }

    function calculatePrice() internal view returns (uint256) {

    }
}