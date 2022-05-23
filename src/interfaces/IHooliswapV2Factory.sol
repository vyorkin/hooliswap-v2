// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

interface IHooliswapV2Factory {
    function pairs(address, address) external pure returns (address);

    function createPair(address tokenA, address tokenB)
        external
        returns (address);
}
