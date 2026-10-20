// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract MockDiamonPair is ERC20 {
    using SafeERC20 for IERC20;

    address public immutable token0;
    address public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    error InvalidToken();
    error InsufficientLiquidity();
    error InsufficientOutput();
    error Overflow();

    constructor(address token0_, address token1_) ERC20("Mock Diamon LP", "MDMLP") {
        token0 = token0_;
        token1 = token1_;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function getAmountOut(address tokenIn, uint256 amountIn) external view returns (uint256) {
        (uint112 reserveIn, uint112 reserveOut) = _reservesFor(tokenIn);
        uint256 amountInWithFee = amountIn * 997;
        return amountInWithFee * reserveOut / (uint256(reserveIn) * 1000 + amountInWithFee);
    }

    function mint(address to) external returns (uint256 liquidity) {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;
        uint256 supply = totalSupply();

        if (supply == 0) {
            liquidity = Math.sqrt(amount0 * amount1);
        } else {
            liquidity = Math.min(amount0 * supply / reserve0, amount1 * supply / reserve1);
        }

        if (liquidity == 0) revert InsufficientLiquidity();
        _mint(to, liquidity);
        _update(balance0, balance1);
    }

    function swap(address tokenIn, uint256 amountIn, address to) external returns (uint256 amountOut) {
        (uint112 reserveIn, uint112 reserveOut) = _reservesFor(tokenIn);
        uint256 amountInWithFee = amountIn * 997;
        amountOut = amountInWithFee * reserveOut / (uint256(reserveIn) * 1000 + amountInWithFee);
        if (amountOut == 0 || amountOut >= reserveOut) revert InsufficientOutput();

        IERC20(tokenIn == token0 ? token1 : token0).safeTransfer(to, amountOut);
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }

    function sync() external {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }

    function _reservesFor(address tokenIn) private view returns (uint112 reserveIn, uint112 reserveOut) {
        if (tokenIn == token0) return (reserve0, reserve1);
        if (tokenIn == token1) return (reserve1, reserve0);
        revert InvalidToken();
    }

    function _update(uint256 balance0, uint256 balance1) private {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert Overflow();
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp);
    }
}
