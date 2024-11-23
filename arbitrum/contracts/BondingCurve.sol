// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./RampToken.sol";

contract BondingCurve is ReentrancyGuard {
    address feeTaker;
    RampToken public token;

    uint256 public constant PRICE_FACTOR = 10 ** 18;
    uint256 public constant START_PRICE = 1;

    event TokenBuy(address _token, address _buyer, uint256 _value);
    event TokenSell(address _token, address _seller, uint256 _value);

    constructor(address _feeTaker, address _token) {
        feeTaker = _feeTaker;
        token = RampToken(_token);
    }

    receive() external payable {
        buy{value: msg.value}();
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