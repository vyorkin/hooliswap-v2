// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "solmate/tokens/ERC20.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "./libraries/Math.sol";

interface IERC20 {
    function balanceOf(address) external returns (uint256);

    function transfer(address to, uint256 amount) external;
}

error InsufficientLiquidity();
error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();
error TransferFailed();
error InsufficientOutputAmount();
error InvalidK();

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
    event Swap(
        address indexed sender,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

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

        // Calculate newly deposited amounts that
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
            // Minted LP shares should be:
            // - Proportional to the deposited amount
            // - Proportional to the total issued amount of LP-tokens

            // With every subsequent deposit we already know the exchange rate
            // between the two assets, and we expect liquidity providers to
            // provide equal value in both. If they don't, we give them
            // liquidity tokens based on the lesser value they provided as a punishment

            // example-1:
            //
            // r0   r1
            // 1001 1001
            // mean = sqrt(1001 * 1001) = 10001
            // initial_liquidity = mean - MINIMUM_LIQUDITY = 1001 - 1000 = 1
            // total_supply = 1000
            //
            // lets say the ration of deposited amounts is diffent,
            // LP amounts will also be different, and one of them will be bigger than the other
            //
            // lp_shares_max(1, 2)
            //           = max(1 * 1/1000, 2 * 1/1000)
            //           = max(1/1000, 2/1000)
            //           = 2/1000 = 0.002
            //
            // lp_shares_min(1, 2) = 1/1000 = 0.001

            // lp_shares_min(2, 2) = 2/1000 = 0.001

            // If we choose the smaller one, we’ll punish for depositing of
            // unbalanced liquidity (liquidity providers would get fewer LP-tokens)

            // so:
            // lp_shares_min(1, 2) = 1/1000 = 0.001
            // lp_shares_min(1, 1) = 1/1000 = 0.001
            //
            // ^^^ amount of LP shares we get for
            // depositing (1, 2) is the same as for depositing (1, 1)

            // example-2:
            //
            // r0   r1
            // 343 16807
            // mean = sqrt(343 * 16807) = 2401
            // initial_liquidity = mean - MINIMUM_LIQUDITY = 2401 - 1000 = 1401
            // total_supply = 2401
            //
            // lets say the ration of deposited amounts is diffent,
            // LP amounts will also be different, and one of them will be bigger than the other
            //
            // lp_shares_max(100, 100) = max(100 * 2401/343, 100 * 2401/16807)
            //           = max(700, 14.2857142857)
            //           = 700
            //
            // lp_shares_min(100, 100) = 14.2857142857
            // lp_shares_min(100, 500) = max(100 * 2401/343, 500 * 2401/16807)
            //                         = max(700, 71.4285714286)
            //                         = 71.4285714286

            // The closer we get to the pool proportion
            // the more LP shares we get

            liquidity = min(
                (amount0 * totalSupply) / r0,
                (amount1 * totalSupply) / r1
            );
        }

        if (liquidity <= 0) revert InsufficientLiquidityMinted();

        _mint(msg.sender, liquidity);
        _update(balance0, balance1, r0, r1);

        emit Mint(msg.sender, amount0, amount1);
    }

    function swap(
        uint256 _amount0Out,
        uint256 _amount1Out,
        address _to
    ) public {
        if (_amount0Out == 0 && _amount1Out == 0) {
            revert InsufficientOutputAmount();
        }

        (uint112 r0, uint112 r1, ) = getReserves();
        // Ensure that there are enough of reserves to send to user
        if (_amount0Out > r0 || _amount1Out > r1) {
            revert InsufficientLiquidity();
        }

        // Calculate token balances of this contract minus the
        // amounts we’re expected to send to the caller.
        //
        // At this point, it’s expected that the caller has
        // sent tokens they want to trade in to this contract

        uint256 balance0 = IERC20(token0).balanceOf(address(this)) -
            _amount0Out;
        uint256 balance1 = IERC20(token1).balanceOf(address(this)) -
            _amount1Out;

        // We need to ensure that product of new reserves is
        // equal or greater than the product of current reserves

        if (balance0 * balance1 < uint256(r0) * uint256(r1)) {
            revert InvalidK();
        }

        // If this requirement is met then:
        // - The caller has calculated the exchange rate correctly (including slippage).
        // - The output amount is correct.
        // - The amount transferred to the contract is also correct.

        // Transfer tokens to the caller and to update the reserves

        _update(balance0, balance1, r0, r1);

        if (_amount0Out > 0) _safeTransfer(token0, _to, _amount0Out);
        if (_amount1Out > 0) _safeTransfer(token1, _to, _amount1Out);

        emit Swap(msg.sender, _amount0Out, _amount1Out, _to);
    }

    function burn() public {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[msg.sender];

        uint256 amount0 = (liquidity * balance0) / totalSupply;
        uint256 amount1 = (liquidity * balance1) / totalSupply;

        if (amount0 <= 0 || amount1 <= 0) revert InsufficientLiquidityBurned();

        _burn(msg.sender, liquidity);

        _safeTransfer(token0, msg.sender, amount0);
        _safeTransfer(token1, msg.sender, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        (uint112 r0, uint112 r1, ) = getReserves();
        _update(balance0, balance1, r0, r1);

        emit Burn(msg.sender, amount0, amount1);
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

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _update(
        uint256 _balance0,
        uint256 _balance1,
        uint256 _reserve0,
        uint256 _reserve1
    ) private {
        reserve0 = uint112(_balance0);
        reserve1 = uint112(_balance1);

        emit Sync(reserve0, reserve1);
    }
}
