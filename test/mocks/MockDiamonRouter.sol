// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDiamonRouter} from "../../src/interfaces/IDiamonRouter.sol";
import {MockDiamonPair} from "./MockDiamonPair.sol";

contract MockDiamonRouter is IDiamonRouter {
    using SafeERC20 for IERC20;

    MockDiamonPair public immutable pair;
    address public immutable rewardToken;
    uint256 public immutable rewardRate;

    error Expired();
    error InvalidPath();
    error InsufficientOutput();
    error InsufficientLiquidity();

    struct AddLiquidityParams {
        address tokenA;
        address tokenB;
        uint256 amountADesired;
        uint256 amountBDesired;
        uint256 amountAMin;
        uint256 amountBMin;
        address to;
    }

    constructor(MockDiamonPair pair_, address rewardToken_, uint256 rewardRate_) {
        pair = pair_;
        rewardToken = rewardToken_;
        rewardRate = rewardRate_;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256, uint256, uint256) {
        if (block.timestamp > deadline) revert Expired();

        AddLiquidityParams memory params =
            AddLiquidityParams(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to);
        return _addLiquidity(params);
    }

    function _addLiquidity(AddLiquidityParams memory params)
        private
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        if (!_isPair(params.tokenA, params.tokenB)) revert InvalidPath();

        (uint112 reserveA, uint112 reserveB) = _reserves(params.tokenA);
        (amountA, amountB) = _optimalLiquidity(params.amountADesired, params.amountBDesired, reserveA, reserveB);
        if (amountA < params.amountAMin || amountB < params.amountBMin || amountA == 0 || amountB == 0) {
            revert InsufficientLiquidity();
        }

        IERC20(params.tokenA).safeTransferFrom(msg.sender, address(pair), amountA);
        IERC20(params.tokenB).safeTransferFrom(msg.sender, address(pair), amountB);
        liquidity = pair.mint(params.to);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        if (block.timestamp > deadline) revert Expired();
        if (path.length != 2) revert InvalidPath();

        amounts = new uint256[](2);
        amounts[0] = amountIn;

        if (path[0] == rewardToken) {
            if (!_isPairToken(path[1])) revert InvalidPath();
            amounts[1] = amountIn * rewardRate / 1e18;
            if (amounts[1] < amountOutMin) revert InsufficientOutput();
            IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), amountIn);
            IERC20(path[1]).safeTransfer(to, amounts[1]);
            return amounts;
        }

        if (!_isPair(path[0], path[1])) revert InvalidPath();
        amounts[1] = pair.getAmountOut(path[0], amountIn);
        if (amounts[1] < amountOutMin) revert InsufficientOutput();

        IERC20(path[0]).safeTransferFrom(msg.sender, address(pair), amountIn);
        pair.swap(path[0], amountIn, to);
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts) {
        if (path.length != 2) revert InvalidPath();

        amounts = new uint256[](2);
        amounts[0] = amountIn;

        if (path[0] == rewardToken) {
            if (!_isPairToken(path[1])) revert InvalidPath();
            amounts[1] = amountIn * rewardRate / 1e18;
            return amounts;
        }

        if (!_isPair(path[0], path[1])) revert InvalidPath();
        amounts[1] = pair.getAmountOut(path[0], amountIn);
    }

    function _isPair(address tokenA, address tokenB) private view returns (bool) {
        return
            (tokenA == pair.token0() && tokenB == pair.token1()) || (tokenA == pair.token1() && tokenB == pair.token0());
    }

    function _isPairToken(address token) private view returns (bool) {
        return token == pair.token0() || token == pair.token1();
    }

    function _reserves(address tokenA) private view returns (uint112 reserveA, uint112 reserveB) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        return tokenA == pair.token0() ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function _optimalLiquidity(uint256 amountADesired, uint256 amountBDesired, uint256 reserveA, uint256 reserveB)
        private
        pure
        returns (uint256 amountA, uint256 amountB)
    {
        if (reserveA == 0 && reserveB == 0) return (amountADesired, amountBDesired);

        uint256 amountBOptimal = amountADesired * reserveB / reserveA;
        if (amountBOptimal <= amountBDesired) return (amountADesired, amountBOptimal);

        uint256 amountAOptimal = amountBDesired * reserveA / reserveB;
        if (amountAOptimal > amountADesired) revert InsufficientLiquidity();
        return (amountAOptimal, amountBDesired);
    }
}
