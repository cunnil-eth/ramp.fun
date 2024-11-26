// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import "./RampToken.sol";

contract Rampfun is Ownable, IERC721Receiver {
    address constant public UNISWAP_NFT_POS_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    event TokenDeployed(address _deployer, address _token, string _name, string _ticker);

    constructor() Ownable(msg.sender) {}

    receive() external payable {}

    function deployToken(string calldata _name, string calldata _ticker) public payable {
        RampToken token = new RampToken{value: msg.value}(_name, _ticker);

        emit TokenDeployed(msg.sender, address(token), _name, _ticker);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function collectAllFees(uint256 tokenId) external onlyOwner {
        INonfungiblePositionManager(UNISWAP_NFT_POS_MANAGER).CollectParams memory params =
            INonfungiblePositionManager(UNISWAP_NFT_POS_MANAGER).CollectParams({
                tokenId: tokenId,
                recipient: owner(),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = nonfungiblePositionManager.collect(params);
    }

    function onERC721Received(address operator, address, uint256 tokenId, bytes calldata) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

}