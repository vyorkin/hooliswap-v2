// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import {HooliswapV2Pair} from "./HooliswapV2Pair.sol";
import {IHooliswapV2Pair} from "./interfaces/IHooliswapV2Pair.sol";

error IdenticalAddresses();
error PairExists();
error ZeroAddress();

contract HooliswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    event PairCreating(address pair);

    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

    function createPair(address tokenA, address tokenB)
        public
        returns (address addr)
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

        // Salt is a sequence of bytes that’s used to generate new
        // contract’s address deterministically
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        // Creation bytecode is actual smart contract bytecode:
        // 1. Constructor logic.
        // This part is responsible for smart contract initialization and deployment.
        // It’s not stored on the blockchain.
        // 2. Runtime bytecode.
        // The actual business logic of contract.
        // It’s this bytecode that’s stored on the Ethereum blockchain.

        // init code = creation code + args
        // runtime bytecode = EVM(init code)

        bytes memory bytecode = type(HooliswapV2Pair).creationCode;

        // The constructor of HooliswapV2Pair has arguments, so
        // we want encode them and append after the creationCode

        bytes memory args = abi.encode(token0, token1);
        bytes memory initCode = abi.encodePacked(bytecode, args);

        assembly {
            addr := create2(0, add(initCode, 32), mload(initCode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        emit PairCreating(addr);

        pairs[token0][token1] = addr;
        pairs[token1][token0] = addr;
        allPairs.push(addr);

        emit PairCreated(token0, token1, addr, allPairs.length);
    }
}
