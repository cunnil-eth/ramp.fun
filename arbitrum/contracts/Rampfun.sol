// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RampToken.sol";

contract Rampfun is Ownable {
    event TokenDeployed(address _deployer, address _token, string _name, string _ticker);

    constructor() Ownable(msg.sender) {}

    receive() external payable {}

    function deployToken(string calldata _name, string calldata _ticker) public payable {
        RampToken token = new RampToken{value: msg.value}(_name, _ticker);

        emit TokenDeployed(msg.sender, address(token), _name, _ticker);
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

}