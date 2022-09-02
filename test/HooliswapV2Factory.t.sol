// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {HooliswapV2Factory, PairExists, IdenticalAddresses, ZeroAddress} from "../src/HooliswapV2Factory.sol";
import {HooliswapV2Pair} from "../src/HooliswapV2Pair.sol";
import {IHooliswapV2Factory} from "../src/interfaces/IHooliswapV2Factory.sol";
import {IHooliswapV2Pair} from "../src/interfaces/IHooliswapV2Pair.sol";
import {Utils} from "./Utils.sol";

contract HooliswapV2FactoryTest is DSTest {
    Vm private vm = Vm(HEVM_ADDRESS);

    HooliswapV2Factory private factory;

    MockERC20 private token0;
    MockERC20 private token1;
    MockERC20 private token2;
    MockERC20 private token3;

    function setUp() public {
        factory = new HooliswapV2Factory();

        vm.label(address(factory), "factory");

        token0 = new MockERC20("Token A", "TKNA", 18);
        token1 = new MockERC20("Token B", "TKNB", 18);
        token2 = new MockERC20("Token C", "TKNC", 18);
        token3 = new MockERC20("Token D", "TKND", 18);

        vm.label(address(token0), "TKNA");
        vm.label(address(token1), "TKNB");
        vm.label(address(token2), "TKNC");
        vm.label(address(token3), "TKND");
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
