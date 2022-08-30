// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import {IHooliswapV2Factory} from "./interfaces/IHooliswapV2Factory.sol";
import {IHooliswapV2Pair} from "./interfaces/IHooliswapV2Pair.sol";
import {HooliswapV2Library} from "./HooliswapV2Library.sol";

contract HooliswapV2Router {
    error InsufficientAAmount();
    error InsufficientBAmount();
    error SafeTransferFailed();

    IHooliswapV2Factory private immutable factory;

    constructor(address _factory) {
        factory = IHooliswapV2Factory(_factory);
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
