// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "solmate/tokens/ERC20.sol";

contract ERC20Mintable is ERC20 {
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol, 18)
    {}

    function mint(uint256 amount, address to) public {
        _mint(to, amount);
    }
}
