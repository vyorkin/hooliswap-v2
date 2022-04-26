// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "ds-test/test.sol";
import "../HooliswapV2Pair.sol";
import "../mocks/ERC20Mintable.sol";
import "../mocks/ERC20Thief.sol";

contract HooliswapV2PairTest is DSTest {
    ERC20Mintable tokenA;
    ERC20Mintable tokenB;
    ERC20Thief tokenC;

    HooliswapV2Pair pairAB;
    HooliswapV2Pair pairAC;
    TestUser testUser;

    function setUp() public {
        tokenA = new ERC20Mintable("Token A", "TKNA");
        tokenB = new ERC20Mintable("Token B", "TKNB");
        tokenC = new ERC20Thief("Token C", "TKNC", 18);

        pairAB = new HooliswapV2Pair(address(tokenA), address(tokenB));
        pairAC = new HooliswapV2Pair(address(tokenA), address(tokenC));
        testUser = new TestUser();

        tokenA.mint(address(this), 10 ether);
        tokenB.mint(address(this), 10 ether);
        tokenC.mint(address(this), 10 ether);

        tokenA.mint(address(testUser), 10 ether);
        tokenB.mint(address(testUser), 10 ether);
        tokenC.mint(address(testUser), 10 ether);
    }

    function assertReserves(
        HooliswapV2Pair pair,
        uint112 expected0,
        uint112 expected1
    ) internal {
        (uint112 actual0, uint112 actual1, ) = pair.getReserves();
        assertEq(actual0, expected0, "unexpected reserve0");
        assertEq(actual1, expected1, "unexpected reserve1");
    }

    function testMintBootstrap() public {
        // "Emulate" adding of (1 TKNA, 1 TKNB) liquidity
        tokenA.transfer(address(pairAB), 1 ether);
        tokenB.transfer(address(pairAB), 1 ether);

        pairAB.mint();

        // Expected amount of LP tokens
        assertEq(pairAB.balanceOf(address(this)), 1 ether - 1000);

        assertReserves(pairAB, 1 ether, 1 ether);
        assertEq(pairAB.totalSupply(), 1 ether);
    }

    function testMintBalanced() public {
        tokenA.transfer(address(pairAB), 1 ether);
        tokenB.transfer(address(pairAB), 1 ether);

        pairAB.mint(); // + 1 LP

        tokenA.transfer(address(pairAB), 2 ether);
        tokenB.transfer(address(pairAB), 2 ether);

        pairAB.mint(); // + 2 LP

        assertEq(pairAB.balanceOf(address(this)), 3 ether - 1000);
        assertEq(pairAB.totalSupply(), 3 ether);
        assertReserves(pairAB, 3 ether, 3 ether);
    }

    function testMintUnbalanced() public {
        tokenA.transfer(address(pairAB), 1 ether);
        tokenB.transfer(address(pairAB), 1 ether);

        pairAB.mint(); // + 1 LP
        assertEq(pairAB.balanceOf(address(this)), 1 ether - 1000);
        assertReserves(pairAB, 1 ether, 1 ether);

        tokenA.transfer(address(pairAB), 1 ether);
        tokenB.transfer(address(pairAB), 2 ether);

        pairAB.mint(); // + 1 LP
        assertEq(pairAB.balanceOf(address(this)), 2 ether - 1000);
        assertReserves(pairAB, 2 ether, 3 ether);
    }

    function testBurn() public {
        tokenA.transfer(address(pairAB), 1 ether);
        tokenB.transfer(address(pairAB), 1 ether);

        pairAB.mint();
        pairAB.burn();

        // No LP tokens
        assertEq(pairAB.balanceOf(address(this)), 0);
        // Pool returns to its uninitialized state, except the
        // minimum liquidity that was sent to the 0-address (it cannot be claimed)
        assertReserves(pairAB, 1000, 1000);

        assertEq(pairAB.totalSupply(), 1000);
        assertEq(tokenA.balanceOf(address(this)), 10 ether - 1000);
        assertEq(tokenB.balanceOf(address(this)), 10 ether - 1000);
    }

    function testBurnUnbalanced() public {
        tokenA.transfer(address(pairAB), 1 ether);
        tokenB.transfer(address(pairAB), 1 ether);

        pairAB.mint(); // + 1 LP

        tokenA.transfer(address(pairAB), 2 ether);
        tokenB.transfer(address(pairAB), 1 ether);

        pairAB.mint(); // + 1 LP
        pairAB.burn();

        assertEq(pairAB.balanceOf(address(this)), 0);
        assertReserves(pairAB, 1500, 1000);
        assertEq(pairAB.totalSupply(), 1000);
        // We lost 500 tokenA.
        // This is the punishment for price manipulation
        assertEq(tokenA.balanceOf(address(this)), 10 ether - 1000 - 500);
        assertEq(tokenB.balanceOf(address(this)), 10 ether - 1000);
    }

    function testBurnUnbalancedDifferentUsers() public {
        testUser.provideLiquidity(
            address(pairAB),
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether
        ); // + LP for TestUser

        // TestUser provides liquidity,
        // so the HooliswapV2PairTest contract didn't get any LP tokens
        assertEq(pairAB.balanceOf(address(this)), 0);

        assertEq(pairAB.balanceOf(address(testUser)), 1 ether - 1000);
        assertEq(pairAB.totalSupply(), 1 ether);

        tokenA.transfer(address(pairAB), 2 ether);
        tokenB.transfer(address(pairAB), 1 ether);

        pairAB.mint(); // + 1 LP for HooliswapV2PairTest

        assertEq(pairAB.balanceOf(address(this)), 1 ether);
        assertReserves(pairAB, 3 ether, 2 ether);

        pairAB.burn();

        assertEq(pairAB.balanceOf(address(this)), 0);
        assertReserves(pairAB, 1.5 ether, 1 ether);
        assertEq(pairAB.totalSupply(), 1 ether);
        // Minimum liquidity (1000) subtracted only from an initial liquidity provider.
        // We've lost 0.5 ethers (units) due to unbalanced liqudity
        assertEq(tokenA.balanceOf(address(this)), 10 ether - 0.5 ether);
        assertEq(tokenB.balanceOf(address(this)), 10 ether);
    }

    function testSwap() public {
        tokenA.transfer(address(pairAB), 1 ether);
        tokenB.transfer(address(pairAB), 2 ether);
        pairAB.mint();

        tokenA.transfer(address(pairAB), 0.1 ether);
        pairAB.swap(0, 0.18 ether, address(this));

        assertEq(
            tokenA.balanceOf(address(this)),
            10 ether - 1 ether - 0.1 ether,
            "unexpected tokenA balance"
        );
        assertEq(
            tokenB.balanceOf(address(this)),
            10 ether - 2 ether + 0.18 ether,
            "unexpected tokenB balance"
        );
        assertReserves(pairAB, 1 ether + 0.1 ether, 2 ether - 0.18 ether);
    }

    function testSwapTrick() public {
        tokenA.transfer(address(pairAC), 1 ether);
        tokenC.transfer(address(pairAC), 2 ether);
        pairAC.mint();

        tokenC.toggleTrick();
        pairAC.swap(0.9 ether, 1.9 ether, address(this));
        tokenC.toggleTrick();
    }

    function testSwapReverseDirection() public {
        tokenA.transfer(address(pairAB), 1 ether);
        tokenB.transfer(address(pairAB), 2 ether);
        pairAB.mint();

        tokenB.transfer(address(pairAB), 0.2 ether);
        pairAB.swap(0.08 ether, 0, address(this));

        assertEq(
            tokenA.balanceOf(address(this)),
            10 ether - 1 ether + 0.08 ether,
            "unexpected tokenA balance"
        );
        assertEq(
            tokenB.balanceOf(address(this)),
            10 ether - 2 ether - 0.2 ether,
            "unexpected tokenA balance"
        );
        assertReserves(pairAB, 1 ether - 0.08 ether, 2 ether + 0.2 ether);
    }
}

contract TestUser {
    function provideLiquidity(
        address _pair,
        address _token0,
        address _token1,
        uint256 _amount0,
        uint256 _amount1
    ) public {
        ERC20(_token0).transfer(_pair, _amount0);
        ERC20(_token1).transfer(_pair, _amount1);

        HooliswapV2Pair(_pair).mint();
    }

    function withdrawLiquidity(address _pair) public {
        HooliswapV2Pair(_pair).burn();
    }
}
