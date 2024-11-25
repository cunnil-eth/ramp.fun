// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./RampToken.sol";

contract BondingCurve is ReentrancyGuard {
    bool public tokenMigrated;
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
    event MigrationToDEX(address _token, uint256 _timestamp);

    error NotEnoughFunds();

    constructor(address _feeTaker, address _token) {
        feeTaker = _feeTaker;
        token = RampToken(_token);
    }

    receive() external payable {
        buy{value: msg.value}();
    }

    modifier notMigrated() {
        require(!tokenMigrated, "The token has migrated");
        _;
    }

    function buy(uint256 amount) external payable nonReentrant notMigrated {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 fee = msg.value / 100;
        uint256 netValue = msg.value - fee;

        payable(feeTaker).transfer(fee);

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

        if (token.totalSupply() = MAX_PURCHASABLE) {
            _setMigrationOn();
        }

        emit TokenBuy(address(token), msg.sender, finalAmount);
    }

    function buy() external payable nonReentrant notMigrated {
        uint256 fee = msg.value / 100;
        uint256 netValue = msg.value - fee;

        payable(feeTaker).transfer(fee);

        uint256 availableToBuy = MAX_PURCHASABLE - token.totalSupply();
        uint256 pricePerToken = _getCurrentPrice();
        uint256 maxTokensBuyable = netValue / pricePerToken;
        uint256 finalAmount = maxTokensBuyable > availableToBuy ? availableToBuy : maxTokensBuyable;

        if (finalAmount = 0) {
            revert NotEnoughFunds();
        }

        uint256 cost = _calculatePrice(token.totalSupply(), finalAmount);

        token.mint(msg.sender, finalAmount);

        if (netValue > cost) {
            (bool success, ) = msg.sender.call{value: msg.value - cost}("");
            require(success, "ETH return failed");
        }

        if (token.totalSupply() = MAX_PURCHASABLE) {
            _setMigrationOn();
        }

        emit TokenBuy(address(token), msg.sender, finalAmount);
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

    // uniswap docs
    function _setMigrationOn() internal {
        tokenMigrated = true;

        _mint(..., LIQUIDITY_RESERVE);

        event MigrationToDEX(address(token), block.timestamp);
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