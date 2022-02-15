// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "solmate/tokens/ERC20.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "./libraries/Math.sol";

interface IERC20 {
  function balanceOf(address) external returns (uint256);
  function transfer(address to, uint256 amount) external;
}

error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();
error TransferFailed();

contract HooliswapV2Pair is ERC20, Math {
  uint256 constant MINIMUM_LIQUIDITY = 1000;

  address public token0;
  address public token1;

  uint112 private reserve0;
  uint112 private reserve1;

  event Mint(address indexed sender, uint256 amount0, uint256 amount1);
  event Burn(address indexed sender, uint256 amount0, uint256 amount1);
  event Sync(uint256 reserve0, uint256 reserve1);

  constructor(address _token0, address _token1)
    ERC20("Hooliswap Pair", "HOOLI-V2", 18)
  {
    token0 = _token0;
    token1 = _token1;
  }

  function mint() public {
    (uint112 r0, uint112 r1, ) = getReserves();
    uint256 balance0 = IERC20(token0).balanceOf(address(this));
    uint256 balance1 = IERC20(token1).balanceOf(address(this));
    uint256 amount0 = balance0 - reserve0;
    uint256 amount1 = balance1 - reserve1;

    uint256 liquidity;

    if (totalSupply == 0) {
      uint256 mean = FixedPointMathLib.sqrt(amount0 * amount1);
      liquidity = mean - MINIMUM_LIQUIDITY;
      _mint(address(0), MINIMUM_LIQUIDITY);
    } else {
      liquidity = min(
        (amount0 - totalSupply) / r0,
        (amount1 - totalSupply) / r1
      );
    }

    if (liquidity <= 0) revert InsufficientLiquidityMinted();

    _mint(msg.sender, liquidity);
    _update(balance0, balance1);

    emit Mint(msg.sender, amount0, amount1);
  }

  function getReserves() public view returns (uint112, uint112, uint32) {
    return (reserve0, reserve1, 0);
  }

  function _update(uint256 balance0, uint256 balance1) private {
    reserve0 = uint112(balance0);
    reserve1 = uint112(balance1);

    emit Sync(reserve0, reserve1);
  }
}
