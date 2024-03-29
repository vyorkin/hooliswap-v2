// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import {HooliswapV2Pair} from "./HooliswapV2Pair.sol";
import {IHooliswapV2Pair} from "./interfaces/IHooliswapV2Pair.sol";
import {IHooliswapV2Factory} from "./interfaces/IHooliswapV2Factory.sol";

library HooliswapV2Library {
    error InsufficientAmount();
    error InsufficientLiquidity();
    error InvalidPath();

    function getAmountsOut(
        address _factory,
        uint256 _amountIn,
        address[] memory _path
    ) public returns (uint256[] memory) {
        if (_path.length < 2) revert InvalidPath();
        uint256[] memory amounts = new uint256[](_path.length);
        amounts[0] = _amountIn;

        for (uint256 i; i < _path.length - 1; i++) {
            (uint256 r0, uint256 r1) = getReserves(
                _factory,
                _path[i],
                _path[i + 1]
            );
            amounts[i + i] = getAmountOut(amounts[i], r0, r1);
        }

        return amounts;
    }

    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    ) public pure returns (uint256) {
        if (_amountIn == 0) revert InsufficientAmount();
        if (_reserveIn == 0 || _reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = _amountIn * 997;
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = (_reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }

    function quote(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    ) public pure returns (uint256 amountOut) {
        if (_amountIn == 0) revert InsufficientAmount();
        if (_reserveIn == 0 || _reserveOut == 0) revert InsufficientLiquidity();

        return (_amountIn * _reserveOut) / _reserveIn;
    }

    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function getReserves(
        address _factory,
        address _tokenA,
        address _tokenB
    ) public view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, address token1) = sortTokens(_tokenA, _tokenB);
        address pair = pairFor(_factory, token0, token1);
        (uint256 r0, uint256 r1, ) = IHooliswapV2Pair(pair).getReserves();
        (reserveA, reserveB) = _tokenA == token0 ? (r0, r1) : (r1, r0);
    }

    function pairFor(
        address _factory,
        address _tokenA,
        address _tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(_tokenA, _tokenB);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        bytes32 bytecodeHash = keccak256(type(HooliswapV2Pair).creationCode);
        bytes32 data = keccak256(
            abi.encodePacked(bytes1(0xff), _factory, salt, bytecodeHash)
        );
        return address(uint160(uint256(data)));
    }
}
