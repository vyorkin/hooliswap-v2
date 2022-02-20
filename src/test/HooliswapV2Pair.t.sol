// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "ds-test/test.sol";
import "../HooliswapV2Pair.sol";
import "../mocks/ERC20Mintable.sol";

contract HooliswapV2PairTest is DSTest {
    ERC20Mintable tokenA;
    ERC20Mintable tokenB;
    HooliswapV2Pair pair;

    function setUp() public {
        tokenA = new ERC20Mintable("Token A", "TKNA");
        tokenB = new ERC20Mintable("Token B", "TKNB");
        pair = new HooliswapV2Pair(address(tokenA), address(tokenB));

        tokenA.mint(10 ether, address(this));
        tokenB.mint(10 ether, address(this));
    }

    function assertReserves(uint112 expected0, uint112 expected1) internal {
        (uint112 actual0, uint112 actual1, ) = pair.getReserves();
        assertEq(actual0, expected0, "unexpected reserve0");
        assertEq(actual1, expected1, "unexpected reserve1");
    }

    function testMintBootstrap() public {
        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 1 ether);

        pair.mint();

        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertReserves(1 ether, 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }
}
