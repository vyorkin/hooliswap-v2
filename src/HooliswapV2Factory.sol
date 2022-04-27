// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "./HooliswapV2Pair.sol";

contract HooliswapV2Factory {
    error IdenticalAddresses();
    error PairExists();
    error ZeroAddress();

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

    function createPair(address tokenA, address tokenB)
        public
        returns (address pair)
    {
        if (tokenA == tokenB) revert IdenticalAddresses();

        // Sort token addresses, this is important to avoid duplicates
        // (the pair contract allows swaps in both directions).
        // Also, pair token addresses are used to generate pair address.
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        if (token0 == address(0)) revert ZeroAddress();
        if (pairs[token0][token1] != address(0)) revert PairExists();

        bytes memory bytecode = type(HooliswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
    }
}
