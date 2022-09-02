// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

interface IHooliswapV2Pair {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function initialize(address, address) external;

    function getReserves()
        external
        view
        returns (
            uint112,
            uint112,
            uint32
        );

    function mint(address) external returns (uint256 liquidity);

    function burn(address _to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 _amount0Out,
        uint256 _amount1Out,
        address _to
    ) external;
}
