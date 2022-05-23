// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

interface IHooliswapV2Pair {
    function initialize(address, address) external;

    function getReserves()
        external
        view
        returns (
            uint112,
            uint112,
            uint32
        );
}
