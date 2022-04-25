// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "ds-test/test.sol";
import "../HooliswapV2Pair.sol";
import "../mocks/ERC20Mintable.sol";

contract HooliswapV2PairTest is DSTest {
    ERC20Mintable tokenA;
    ERC20Mintable tokenB;
    HooliswapV2Pair pair;
    TestUser testUser;

    function setUp() public {
        tokenA = new ERC20Mintable("Token A", "TKNA");
        tokenB = new ERC20Mintable("Token B", "TKNB");
        pair = new HooliswapV2Pair(address(tokenA), address(tokenB));
        testUser = new TestUser();

        tokenA.mint(10 ether, address(this));
        tokenB.mint(10 ether, address(this));

        tokenA.mint(10 ether, address(testUser));
        tokenB.mint(10 ether, address(testUser));
    }

    function assertReserves(uint112 expected0, uint112 expected1) internal {
        (uint112 actual0, uint112 actual1, ) = pair.getReserves();
        assertEq(actual0, expected0, "unexpected reserve0");
        assertEq(actual1, expected1, "unexpected reserve1");
    }

    function testMintBootstrap() public {
        // "Emulate" adding of (1 TKNA, 1 TKNB) liquidity
        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 1 ether);

        pair.mint();

        // Expected amount of LP tokens
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);

        assertReserves(1 ether, 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testMintBalanced() public {
        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP

        tokenA.transfer(address(pair), 2 ether);
        tokenB.transfer(address(pair), 2 ether);

        pair.mint(); // + 2 LP

        assertEq(pair.balanceOf(address(this)), 3 ether - 1000);
        assertEq(pair.totalSupply(), 3 ether);
        assertReserves(3 ether, 3 ether);
    }

    function testMintUnbalanced() public {
        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertReserves(1 ether, 1 ether);

        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 2 ether);

        pair.mint(); // + 1 LP
        assertEq(pair.balanceOf(address(this)), 2 ether - 1000);
        assertReserves(2 ether, 3 ether);
    }

    function testBurn() public {
        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 1 ether);

        pair.mint();
        pair.burn();

        // No LP tokens
        assertEq(pair.balanceOf(address(this)), 0);
        // Pool returns to its uninitialized state, except the
        // minimum liquidity that was sent to the 0-address (it cannot be claimed)
        assertReserves(1000, 1000);

        assertEq(pair.totalSupply(), 1000);
        assertEq(tokenA.balanceOf(address(this)), 10 ether - 1000);
        assertEq(tokenB.balanceOf(address(this)), 10 ether - 1000);
    }

    function testBurnUnbalanced() public {
        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP

        tokenA.transfer(address(pair), 2 ether);
        tokenB.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP
        pair.burn();

        assertEq(pair.balanceOf(address(this)), 0);
        assertReserves(1500, 1000);
        assertEq(pair.totalSupply(), 1000);
        // We lost 500 tokenA.
        // This is the punishment for price manipulation
        assertEq(tokenA.balanceOf(address(this)), 10 ether - 1000 - 500);
        assertEq(tokenB.balanceOf(address(this)), 10 ether - 1000);
    }

    function testBurnUnbalancedDifferentUsers() public {
        testUser.provideLiquidity(
            address(pair),
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether
        ); // + LP for TestUser

        // TestUser provides liquidity,
        // so the HooliswapV2PairTest contract didn't get any LP tokens
        assertEq(pair.balanceOf(address(this)), 0);

        assertEq(pair.balanceOf(address(testUser)), 1 ether - 1000);
        assertEq(pair.totalSupply(), 1 ether);

        tokenA.transfer(address(pair), 2 ether);
        tokenB.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP for HooliswapV2PairTest

        assertEq(pair.balanceOf(address(this)), 1 ether);
        assertReserves(3 ether, 2 ether);

        pair.burn();

        assertEq(pair.balanceOf(address(this)), 0);
        assertReserves(1.5 ether, 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
        // Minimum liquidity (1000) subtracted only from an initial liquidity provider.
        // We've lost 0.5 ethers (units) due to unbalanced liqudity
        assertEq(tokenA.balanceOf(address(this)), 10 ether - 0.5 ether);
        assertEq(tokenB.balanceOf(address(this)), 10 ether);
    }
}

contract TestUser {
    function provideLiquidity(
        address _pair,
        address _tokenA,
        address _tokenB,
        uint256 _amountA,
        uint256 _amountB
    ) public {
        ERC20(_tokenA).transfer(_pair, _amountA);
        ERC20(_tokenB).transfer(_pair, _amountB);

        HooliswapV2Pair(_pair).mint();
    }

    function withdrawLiquidity(address _pair) public {
        HooliswapV2Pair(_pair).burn();
    }
}
