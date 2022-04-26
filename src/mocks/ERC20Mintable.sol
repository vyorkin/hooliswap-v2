// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "solmate/tokens/ERC20.sol";

contract ERC20Mintable is ERC20 {
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol, 18)
    {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
