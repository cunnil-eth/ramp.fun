// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/Aerodrome/IPool.sol";
import "./RampToken.sol";
import "./BondingCurve.sol";

contract Rampfun is Ownable, IERC721Receiver {
    BondingCurve public bondingCurve;

    event TokenDeployed(address _deployer, address _token, string _name, string _ticker);
    event BondingCurveDeployed(address _bondingCurve);

    constructor() Ownable(msg.sender) {}

    receive() external payable {}

    function deployBondingCurve() public onlyOwner {
        BondingCurve _bondingCurve = new BondingCurve(address(this));
        bondingCurve = _bondingCurve;
        emit BondingCurveDeployed(address(bondingCurve));
    }

    function deployToken(string calldata _name, string calldata _ticker) public payable {
        RampToken token = new RampToken(_name, _ticker, msg.sender, address(bondingCurve));

        bondingCurve.addToken(address(token));

        if (msg.value > 0) {
            bondingCurve.buy{value: msg.value}(token);
            //(bool success, ) = bondingCurveAddress.call{value: msg.value}(abi.encodeWithSignature("buy(address)"));
            //require(success, "Deploy and initial buy failed");
        }

        emit TokenDeployed(msg.sender, address(token), _name, _ticker);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function collectAllFees(address _addressPool) external onlyOwner {
        IPool(_addressPool).claimFees();
    }
    
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}