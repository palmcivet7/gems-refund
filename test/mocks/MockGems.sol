// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockGems is ERC20 {
    uint256 internal constant GEMS_SUPPLY = 20_000_000 * 1e6;

    constructor() ERC20("Mock Gems", "MGEMS") {}

    function mint(address account, uint256 amount) external {
        if (totalSupply() + amount > GEMS_SUPPLY) revert("Gems supply exceeded");
        _mint(account, amount);
    }
}
