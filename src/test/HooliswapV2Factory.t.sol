// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "../HooliswapV2Factory.sol";
import "../HooliswapV2Pair.sol";
import "../interfaces/IHooliswapV2Factory.sol";
import "../interfaces/IHooliswapV2Pair.sol";
import "../mocks/ERC20Mintable.sol";

contract HooliswapV2FactoryTest is DSTest {
    Vm private vm = Vm(HEVM_ADDRESS);

    HooliswapV2Factory factory;

    ERC20Mintable token0;
    ERC20Mintable token1;
    ERC20Mintable token2;
    ERC20Mintable token3;

    function setUp() public {
        factory = new HooliswapV2Factory();

        token0 = new ERC20Mintable("Token A", "TKNA");
        token1 = new ERC20Mintable("Token B", "TKNB");
        token2 = new ERC20Mintable("Token C", "TKNC");
        token3 = new ERC20Mintable("Token D", "TKND");
    }

    function testCreatePair() public {
        address addr = factory.createPair(address(token1), address(token0));

        HooliswapV2Pair pair = HooliswapV2Pair(addr);

        assertEq(pair.token0(), address(token0));
        assertEq(pair.token1(), address(token1));
    }

    function testCreatePairZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        factory.createPair(address(0), address(token0));

        vm.expectRevert(ZeroAddress.selector);
        factory.createPair(address(token1), address(0));
    }

    function testCreatePairWhenExists() public {
        factory.createPair(address(token1), address(token0));
        vm.expectRevert(PairExists.selector);
        factory.createPair(address(token1), address(token0));
    }

    function testCreatePairIdenticalTokens() public {
        vm.expectRevert(IdenticalAddresses.selector);
        factory.createPair(address(token0), address(token0));
    }
}
