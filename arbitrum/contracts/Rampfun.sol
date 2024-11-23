// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RampToken.sol";

contract Rampfun is Ownable {
    constructor() Ownable(msg.sender) {}

    function deployToken(string calldata _name, string calldata _ticker) public payable {
        RampToken token = new RampToken(_name, _ticker);
    }

}