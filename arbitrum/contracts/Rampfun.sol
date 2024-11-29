// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
//import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import "./RampToken.sol";

contract Rampfun is Ownable, IERC721Receiver {
    address constant public UNISWAP_NFT_POS_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    enum CurveStatus{ NotExisting, Created, Migrated }
    mapping(address => CurveStatus) bondingCurves;
    address[] public awaitingForMigration;

    event TokenDeployed(address _deployer, address _token, string _name, string _ticker);

    constructor() Ownable(msg.sender) {}

    receive() external payable {}

    modifier onlyCurve() {
        require(bondingCurves[msg.sender] == CurveStatus.Created);
        _;
    }

    function deployToken(string calldata _name, string calldata _ticker) public payable {
        RampToken token = new RampToken{value: msg.value}(_name, _ticker);

        bondingCurves[token.bondingCurve.address] = CurveStatus.Created;

        emit TokenDeployed(msg.sender, address(token), _name, _ticker);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function addToQueueForMigration() external onlyCurve {
        awaitingForMigration.push(msg.sender);
        bondingCurves[msg.sender] = CurveStatus.Migrated;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /*function collectAllFees(uint256 tokenId) external onlyOwner {
        (amount0, amount1) = INonfungiblePositionManager.collect(
            INonfungiblePositionManager(UNISWAP_NFT_POS_MANAGER).CollectParams({
                tokenId: tokenId,
                recipient: owner(),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            }));
    }
    
    function migrateToDexBatch() external {
        for (uint i = 0; i < awaitingForMigration.length; i++) {
            (bool success, ) = awaitingForMigration[i].call(abi.encodeWithSignature("migrateToDex()"));
            if (success) {
                delete awaitingForMigration[i];
            }
        }
    }
    */
}