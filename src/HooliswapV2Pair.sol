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
    using FixedPointMathLib for uint256;

    uint256 constant MINIMUM_LIQUIDITY = 1000;

    // UniswapV2 now supports arbitrary ERC20 token pairs
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

        // calculate newly deposited amounts that
        // haven’t yet been counted (saved in reserves)
        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;

        uint256 liquidity;

        // Calculate the amount of LP-tokens that must
        // be issued as a reward for provided liquidity
        if (totalSupply == 0) {
            // Initially deposited liquidity (this is a new exchange):
            // How many LP tokens do we need to issue when
            // there’s no liquidity in the pool?

            // Uniswap v2 initially mints shares equal to the
            // geometric mean of the amounts deposited.
            // This formula ensures that the value of a liquidity pool share at
            // any time is essentially independent of the ratio at
            // which liquidity was initially deposited.
            //
            // For example:
            // 1 ABC = 100 XYZ
            // mean(2ABC, 200XYZ) = sqrt(2 * 200) = 20 LP
            // mean(2ABC, 800XYZ) = sqrt(2 * 800) = 40 LP
            uint256 mean = (amount0 * amount1).sqrt();

            // This protect against one liquidity pool token share (1e-18) becoming
            // too expensive, which would turn away small liquidity providers.
            // Simply subtracting 1000 from initial liquidity makes the
            // price of one liquidity share 1000 times cheaper.
            liquidity = mean - MINIMUM_LIQUIDITY;

            // By minting to the 0-address instead of the minter we
            // burn the initial 1000 LP shares.
            // This also means that the pool will never be emptied completely
            // (this saves us from division by zero in some places)
            _mint(address(0), MINIMUM_LIQUIDITY);

            // For example, in order to raise the value of
            // a liquidity pool share to $100, the attacker would need to
            // donate $100,000 to the pool, which would be permanently locked up as liquidity
        } else {
            // proportional to the deposited amount
            // proportional to the total issued amount of LP-tokens
            liquidity = min(
                (amount0 * totalSupply) / r0,
                (amount1 * totalSupply) / r1
            );
        }

        if (liquidity <= 0) revert InsufficientLiquidityMinted();

        _mint(msg.sender, liquidity);
        _update(balance0, balance1);

        emit Mint(msg.sender, amount0, amount1);
    }

    function getReserves()
        public
        view
        returns (
            uint112,
            uint112,
            uint32
        )
    {
        return (reserve0, reserve1, 0);
    }

    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);

        emit Sync(reserve0, reserve1);
    }
}
