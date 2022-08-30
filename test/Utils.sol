// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract Utils is DSTest {
    using stdStorage for StdStorage;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    StdStorage internal stdstore;

    uint256 constant INITIAL_BALANCE = 100 ether;

    bytes32 internal nextUser = keccak256(abi.encodePacked("user address"));

    /// @notice Modifies the storage of a token to mint new tokens to an address.
    function writeTokenBalance(
        address who,
        address token,
        uint256 amount
    ) external {
        stdstore
            .target(token)
            .sig(IERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amount);
    }

    function getNextUserAddress() external returns (address payable) {
        // Convert bytes32 to address
        address payable user = payable(address(uint160(uint256(nextUser))));
        nextUser = keccak256(abi.encodePacked(nextUser));
        return user;
    }

    /// @notice Create users with initial balance.
    function createUsers(uint256 count)
        external
        returns (address payable[] memory)
    {
        address payable[] memory users = new address payable[](count);
        for (uint256 i = 0; i < count; i++) {
            address payable user = this.getNextUserAddress();
            vm.deal(user, INITIAL_BALANCE);
            users[i] = user;
        }
        return users;
    }

    /// @notice Move block.number forward by a given number of blocks.
    function mineBlocks(uint256 count) external {
        uint256 target = block.number + count;
        vm.roll(target);
    }
}
