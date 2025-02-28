// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RampToken is ERC20 {
    address public bondingCurveAddress;
    address public deployer;
    bool public tokenMigrated;

    error UnauthorizedAccess();

    constructor(string memory name_, string memory symbol_, address _deployer, address _bondingCurveAddress) ERC20(name_, symbol_) {
        bondingCurveAddress = _bondingCurveAddress;
        deployer = _deployer;
    }

    modifier onlyCurve() {
        if (msg.sender != bondingCurveAddress) {
            revert UnauthorizedAccess();
        }
        _;
    }

    function mint(address _to, uint256 _value) external onlyCurve {
        _mint(_to, _value);
    }

    function burn(address _from, uint256 _value) external onlyCurve {
        _burn(_from, _value);
    }

    function setMigrationOn() external onlyCurve {
        tokenMigrated = true;

        (bool success, ) = bondingCurveAddress.call(abi.encodeWithSignature("addToQueueForMigration()"));
        require(success, "Migration failed");
    }
}