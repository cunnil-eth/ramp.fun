// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BondingCurve.sol";

contract RampToken is ERC20 {
    BondingCurve public bondingCurve;

    error UnauthorizedAccess();

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) payable {
        BondingCurve _bondingCurve = new BondingCurve(msg.sender, this);
        bondingCurve = _bondingCurve;

        if (msg.value > 0) {
            bondingCurve.buy{value: msg.value}();
        }
    }

    modifier onlyCurve() {
        if (msg.sender != address(bondingCurve)) {
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
}