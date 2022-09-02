// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import {IHooliswapV2Factory} from "./interfaces/IHooliswapV2Factory.sol";
import {IHooliswapV2Pair} from "./interfaces/IHooliswapV2Pair.sol";
import {HooliswapV2Library} from "./HooliswapV2Library.sol";

contract HooliswapV2Router {
    error InsufficientAAmount();
    error InsufficientBAmount();
    error InsufficientOutputAmount();
    error SafeTransferFailed();

    IHooliswapV2Factory private immutable factory;

    constructor(address _factory) {
        factory = IHooliswapV2Factory(_factory);
    }

    function swapExactTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _to
    ) public returns (uint256[] memory amounts) {
        amounts = HooliswapV2Library.getAmountsOut(
            address(factory),
            _amountIn,
            _path
        );
        // Check the final amount
        if (amounts[amounts.length - 1] < _amountOutMin) {
            revert InsufficientOutputAmount();
        }
        address pair0 = HooliswapV2Library.pairFor(
            address(factory),
            _path[0],
            _path[1]
        );
        // If the final amount is good then send input tokens to the first pair
        _safeTransferFrom(_path[0], msg.sender, pair0, amounts[0]);
        // And perform chained swaps
        _swap(amounts, _path, _to);
    }

    function _swap(
        uint256[] memory _amounts,
        address[] memory _path,
        address _to
    ) internal {
        for (uint256 i; i < _path.length - 1; i++) {
            // In pair contracts, token addresses are stored in ascending order,
            // but, in the path, they’re sorted logically:
            // input token goes first, then there’s 0 or
            // multiple intermediate output tokens, then there’s final output token
            (address input, address output) = (_path[i], _path[i + 1]);
            (address token0, ) = HooliswapV2Library.sortTokens(input, output);
            // Next, we’re sorting amounts so they match the order of tokens in pairs.
            // When doing a swap, we want to correctly choose output token.
            uint256 amountOut = _amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            // Find swap destination address:
            // 1. If current pair is not final in the path, we want to
            // send tokens to next pair directly. This allows to save gas.
            // 2. If current pair is final, we want to send tokens to address to_, which
            // is the address that initiated the swap.
            address to = i < _path.length - 2
                ? HooliswapV2Library.pairFor(
                    address(factory),
                    output,
                    _path[i + 2]
                )
                : _to;
            address pair = HooliswapV2Library.pairFor(
                address(factory),
                input,
                output
            );
            IHooliswapV2Pair(pair).swap(amount0Out, amount1Out, to);
        }
    }

    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to
    )
        public
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        if (factory.pairs(_tokenA, _tokenB) == address(0)) {
            factory.createPair(_tokenA, _tokenB);
        }
        (amountA, amountB) = _calculateLiquidity(
            _tokenA,
            _tokenB,
            _amountADesired,
            _amountBDesired,
            _amountAMin,
            _amountBMin
        );
        address pair = HooliswapV2Library.pairFor(
            address(factory),
            _tokenA,
            _tokenB
        );
        _safeTransferFrom(_tokenA, msg.sender, pair, amountA);
        _safeTransferFrom(_tokenB, msg.sender, pair, amountB);
        liquidity = IHooliswapV2Pair(pair).mint(_to);
    }

    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to
    ) public returns (uint256 amountA, uint256 amountB) {
        address pair = HooliswapV2Library.pairFor(
            address(factory),
            _tokenA,
            _tokenB
        );
        IHooliswapV2Pair(pair).transferFrom(msg.sender, pair, _liquidity);
        (amountA, amountB) = IHooliswapV2Pair(pair).burn(_to);
        if (amountA < _amountAMin) revert InsufficientAAmount();
        if (amountB < _amountBMin) revert InsufficientBAmount();
    }

    function _calculateLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        (uint256 reserveA, uint256 reserveB) = HooliswapV2Library.getReserves(
            address(factory),
            _tokenA,
            _tokenB
        );

        if (reserveA == 0 && reserveB == 0) {
            // If reserves are empty then this is a new pair,
            // which means our liquidity will define the reserves ratio,
            // which means we won’t get punished by providing unbalanced liquidity.
            // Thus, we’re allowed to deposit full desired amounts.
            (amountA, amountB) = (_amountADesired, _amountBDesired);
        } else {
            // Otherwise, we need to find optimal amounts,
            // and we begin with finding optimal tokenB amount.
            uint256 amountBOptimal = HooliswapV2Library.quote(
                _amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= _amountBDesired) {
                // If it is less or equal to our desired amount and
                // if it’s higher than our minimal amount, then it’s used.
                if (amountBOptimal <= _amountBMin) {
                    revert InsufficientBAmount();
                }
                (amountA, amountB) = (_amountADesired, amountBOptimal);
            } else {
                // if it is greater than our desired amount, it cannot be used and
                // we need to find a different, optimal, amount A
                uint256 amountAOptimal = HooliswapV2Library.quote(
                    _amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= _amountADesired);
                if (amountAOptimal <= _amountAMin) {
                    revert InsufficientBAmount();
                }
                (amountA, amountB) = (amountAOptimal, _amountBDesired);
            }
        }
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                to,
                value
            )
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool))))
            revert SafeTransferFailed();
    }
}
