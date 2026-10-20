// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {IDiamonPair} from "./interfaces/IDiamonPair.sol";
import {IDiamonRouter} from "./interfaces/IDiamonRouter.sol";
import {ISmartChefV2} from "./interfaces/ISmartChefV2.sol";

contract SmartChefLpStrategy is IStrategy, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_SLIPPAGE_BPS = 2_000;
    uint256 private constant REBALANCE_ITERATIONS = 3;

    IERC20 public immutable asset;
    address public immutable vault;
    ISmartChefV2 public immutable farm;
    IDiamonRouter public immutable router;
    IDiamonPair public immutable pair;
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    IERC20 public immutable rewardToken;
    uint256 public immutable maxSlippageBps;

    address[] private _rewardToToken0Path;
    address[] private _rewardToToken1Path;

    event Invested(uint256 amount);
    event Divested(uint256 amount);
    event Harvested(uint256 rewardAmount, uint256 lpMinted);

    error ZeroAddress();
    error ZeroAmount();
    error OnlyVault();
    error InvalidSlippage();
    error InvalidPath();
    error InvalidFarm();
    error InvalidPair();
    error InvalidRewardToken();
    error InsufficientAssets();
    error NoRewards();
    error SwapFailed();

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    constructor(
        IERC20 asset_,
        address vault_,
        ISmartChefV2 farm_,
        IDiamonRouter router_,
        IERC20 rewardToken_,
        address[] memory rewardToToken0Path_,
        address[] memory rewardToToken1Path_,
        uint256 maxSlippageBps_
    ) {
        if (
            address(asset_) == address(0) || vault_ == address(0) || address(farm_) == address(0)
                || address(router_) == address(0) || address(rewardToken_) == address(0)
        ) revert ZeroAddress();
        if (maxSlippageBps_ > MAX_SLIPPAGE_BPS) revert InvalidSlippage();

        asset = asset_;
        vault = vault_;
        farm = farm_;
        router = router_;
        pair = IDiamonPair(address(asset_));
        token0 = IERC20(pair.token0());
        token1 = IERC20(pair.token1());
        rewardToken = rewardToken_;
        maxSlippageBps = maxSlippageBps_;

        if (pair.totalSupply() == 0) revert InvalidPair();
        if (farm_.stakedToken() != address(asset_) || farm_.rewardToken() != address(rewardToken_)) {
            revert InvalidFarm();
        }
        if (address(rewardToken_) == address(token0) || address(rewardToken_) == address(token1)) {
            revert InvalidRewardToken();
        }

        _validatePath(rewardToToken0Path_, address(token0));
        _validatePath(rewardToToken1Path_, address(token1));
        _rewardToToken0Path = rewardToToken0Path_;
        _rewardToToken1Path = rewardToToken1Path_;
    }

    function rewardToToken0Path() external view returns (address[] memory) {
        return _rewardToToken0Path;
    }

    function rewardToToken1Path() external view returns (address[] memory) {
        return _rewardToToken1Path;
    }

    function totalAssets() public view returns (uint256) {
        (uint256 staked,,,,) = farm.userInfo(address(this));
        return asset.balanceOf(address(this)) + staked;
    }

    function pendingRewards() external view returns (uint256) {
        return farm.pendingReward(address(this));
    }

    function invest(uint256 amount) external nonReentrant onlyVault {
        if (amount == 0) revert ZeroAmount();
        asset.safeTransferFrom(msg.sender, address(this), amount);
        _stake(amount);
        emit Invested(amount);
    }

    function divest(uint256 amount) external nonReentrant onlyVault {
        if (amount == 0) revert ZeroAmount();

        uint256 idle = asset.balanceOf(address(this));
        if (idle < amount) {
            uint256 toWithdraw = amount - idle;
            (uint256 staked,,,,) = farm.userInfo(address(this));
            if (toWithdraw > staked) revert InsufficientAssets();
            farm.withdraw(toWithdraw);
        }

        asset.safeTransfer(msg.sender, amount);
        emit Divested(amount);
    }

    function harvest() external nonReentrant onlyVault {
        uint256 assetsBefore = totalAssets();

        farm.harvest();
        uint256 rewards = rewardToken.balanceOf(address(this));
        if (rewards == 0) revert NoRewards();

        _compound(rewards);

        uint256 assetsAfter = totalAssets();
        if (assetsAfter <= assetsBefore) revert NoRewards();

        emit Harvested(rewards, assetsAfter - assetsBefore);
    }

    function _compound(uint256 rewardAmount) private {
        uint256 amountToToken0 = _rewardSplit(rewardAmount);
        uint256 amountToToken1 = rewardAmount - amountToToken0;

        if (amountToToken0 > 0) _swapReward(amountToToken0, _rewardToToken0Path);
        if (amountToToken1 > 0) _swapReward(amountToToken1, _rewardToToken1Path);

        for (uint256 i; i < REBALANCE_ITERATIONS; ++i) {
            uint256 balance0 = token0.balanceOf(address(this));
            uint256 balance1 = token1.balanceOf(address(this));

            if (balance0 == 0 && balance1 == 0) break;

            if (balance0 == 0 || balance1 == 0) {
                if (balance0 > 0) {
                    _swapToken(token0, token1, balance0 / 2);
                } else {
                    _swapToken(token1, token0, balance1 / 2);
                }
                balance0 = token0.balanceOf(address(this));
                balance1 = token1.balanceOf(address(this));
            }

            if (balance0 == 0 || balance1 == 0) break;
            _addLiquidity(balance0, balance1);
        }

        uint256 lpBalance = asset.balanceOf(address(this));
        if (lpBalance > 0) _stake(lpBalance);
    }

    function _rewardSplit(uint256 rewardAmount) private view returns (uint256 amountToToken0) {
        uint256 probe = rewardAmount / 2;
        if (probe == 0) return 0;

        uint256 probe1 = rewardAmount - probe;
        uint256 out0 = _quote(probe, _rewardToToken0Path);
        uint256 out1 = _quote(probe1, _rewardToToken1Path);
        if (out0 == 0 || out1 == 0) revert SwapFailed();

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        if (reserve0 == 0 || reserve1 == 0) revert InvalidPair();

        uint256 weighted0 = out0 * uint256(reserve1) * probe1;
        uint256 weighted1 = out1 * uint256(reserve0) * probe;
        amountToToken0 = Math.mulDiv(rewardAmount, weighted1, weighted0 + weighted1);
        if (amountToToken0 > rewardAmount) amountToToken0 = rewardAmount;
    }

    function _swapReward(uint256 amountIn, address[] storage path) private {
        uint256 amountOut = _quote(amountIn, path);
        uint256 minAmountOut = amountOut.mulDiv(BPS_DENOMINATOR - maxSlippageBps, BPS_DENOMINATOR);

        IERC20(path[0]).forceApprove(address(router), amountIn);
        router.swapExactTokensForTokens(amountIn, minAmountOut, path, address(this), block.timestamp);
        IERC20(path[0]).forceApprove(address(router), 0);
    }

    function _swapToken(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn) private {
        if (amountIn == 0) return;

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        uint256 amountOut = _quoteMemory(amountIn, path);
        uint256 minAmountOut = amountOut.mulDiv(BPS_DENOMINATOR - maxSlippageBps, BPS_DENOMINATOR);

        tokenIn.forceApprove(address(router), amountIn);
        router.swapExactTokensForTokens(amountIn, minAmountOut, path, address(this), block.timestamp);
        tokenIn.forceApprove(address(router), 0);
    }

    function _addLiquidity(uint256 balance0, uint256 balance1) private {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        if (reserve0 == 0 || reserve1 == 0) revert InvalidPair();

        uint256 equivalent1 = balance0.mulDiv(reserve1, reserve0);
        uint256 used0;
        uint256 used1;

        if (equivalent1 <= balance1) {
            used0 = balance0;
            used1 = equivalent1;
        } else {
            used1 = balance1;
            used0 = balance1.mulDiv(reserve0, reserve1);
        }

        if (used0 == 0 || used1 == 0) return;

        uint256 minAmount0 = used0.mulDiv(BPS_DENOMINATOR - maxSlippageBps, BPS_DENOMINATOR);
        uint256 minAmount1 = used1.mulDiv(BPS_DENOMINATOR - maxSlippageBps, BPS_DENOMINATOR);

        token0.forceApprove(address(router), used0);
        token1.forceApprove(address(router), used1);
        router.addLiquidity(
            address(token0), address(token1), used0, used1, minAmount0, minAmount1, address(this), block.timestamp
        );
        token0.forceApprove(address(router), 0);
        token1.forceApprove(address(router), 0);
    }

    function _stake(uint256 amount) private {
        asset.forceApprove(address(farm), amount);
        farm.deposit(amount);
        asset.forceApprove(address(farm), 0);
    }

    function _quote(uint256 amountIn, address[] storage path) private view returns (uint256) {
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);
        if (amounts.length != path.length || amounts[amounts.length - 1] == 0) revert SwapFailed();
        return amounts[amounts.length - 1];
    }

    function _quoteMemory(uint256 amountIn, address[] memory path) private view returns (uint256) {
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);
        if (amounts.length != path.length || amounts[amounts.length - 1] == 0) revert SwapFailed();
        return amounts[amounts.length - 1];
    }

    function _validatePath(address[] memory path, address expectedToken) private view {
        if (path.length < 2) revert InvalidPath();
        if (path[0] != address(rewardToken) || path[path.length - 1] != expectedToken) {
            revert InvalidPath();
        }
        for (uint256 i; i < path.length; ++i) {
            if (path[i] == address(0)) revert ZeroAddress();
        }
    }
}
