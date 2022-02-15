// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract Math {
  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }
}
