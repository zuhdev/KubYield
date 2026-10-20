// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@kub-chain/contracts/contracts/access/Ownable.sol";
import {Pausable} from "@kub-chain/contracts/contracts/utils/Pausable.sol";
import {IKubYieldShares} from "./interfaces/IKubYieldShares.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";

/// @title KubYieldVault
/// @notice ERC-4626-style vault that accepts a DEX LP token and issues KAP-20 shares.
/// @dev Yield is any growth of `totalAssets()` above `accountedAssets`. Anyone may
///      harvest and receives a fee, which keeps compounding permissionless.
///      Withdrawals remain enabled while the vault is paused.
contract KubYieldVault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant HARVEST_FEE_BPS = 500;

    // Virtual offset that makes the first-depositor inflation attack unprofitable.
    uint256 private constant VIRTUAL_SHARES = 1;
    uint256 private constant VIRTUAL_ASSETS = 1;

    IERC20 public immutable underlying;
    IKubYieldShares public immutable sharesToken;
    IStrategy public strategy;

    /// @notice Assets accounted for at the last deposit, withdrawal, or harvest.
    uint256 public accountedAssets;

    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Harvest(address indexed caller, uint256 rewards, uint256 fee);
    event Invested(uint256 assets);
    event StrategySet(address indexed previousStrategy, address indexed newStrategy);

    error ZeroAddress();
    error ZeroAmount();
    error ZeroShares();
    error ZeroAssets();
    error InsufficientShares();
    error InsufficientLiquidity();
    error NoStrategy();
    error NoRewards();
    error StrategyNotEmpty();

    constructor(IERC20 underlying_, IKubYieldShares sharesToken_) {
        if (address(underlying_) == address(0) || address(sharesToken_) == address(0)) revert ZeroAddress();
        underlying = underlying_;
        sharesToken = sharesToken_;
    }

    // ---------------------------------------------------------------------
    // User actions
    // ---------------------------------------------------------------------

    /// @notice Deposits `assets` of underlying and mints shares to the caller.
    function deposit(uint256 assets) external nonReentrant whenNotPaused returns (uint256 sharesMinted) {
        if (assets == 0) revert ZeroAmount();

        sharesMinted = previewDeposit(assets);
        if (sharesMinted == 0) revert ZeroShares();

        accountedAssets += assets;
        underlying.safeTransferFrom(msg.sender, address(this), assets);
        sharesToken.mint(msg.sender, sharesMinted);

        emit Deposit(msg.sender, msg.sender, assets, sharesMinted);
    }

    /// @notice Burns `shares` from the caller and returns the corresponding assets.
    /// @dev Not gated by `whenNotPaused` so users can always exit.
    function withdraw(uint256 shares) external nonReentrant returns (uint256 assetsRedeemed) {
        if (shares == 0) revert ZeroAmount();
        if (sharesToken.balanceOf(msg.sender) < shares) revert InsufficientShares();

        assetsRedeemed = previewRedeem(shares);
        if (assetsRedeemed == 0) revert ZeroAssets();

        uint256 accounted = accountedAssets;
        accountedAssets = assetsRedeemed >= accounted ? 0 : accounted - assetsRedeemed;

        sharesToken.burn(msg.sender, shares);
        _ensureLiquidity(assetsRedeemed);
        underlying.safeTransfer(msg.sender, assetsRedeemed);

        emit Withdraw(msg.sender, msg.sender, assetsRedeemed, shares);
    }

    /// @notice Realizes strategy yield and pays the caller a fee in underlying.
    /// @return fee Amount of underlying paid to the caller.
    function harvest() external nonReentrant whenNotPaused returns (uint256 fee) {
        IStrategy currentStrategy = strategy;
        if (address(currentStrategy) != address(0)) currentStrategy.harvest();

        uint256 current = totalAssets();
        uint256 accounted = accountedAssets;
        if (current <= accounted) revert NoRewards();

        uint256 rewards = current - accounted;
        fee = rewards.mulDiv(HARVEST_FEE_BPS, BPS_DENOMINATOR);
        accountedAssets = current - fee;

        if (fee > 0) {
            _ensureLiquidity(fee);
            underlying.safeTransfer(msg.sender, fee);
        }

        emit Harvest(msg.sender, rewards, fee);
    }

    // ---------------------------------------------------------------------
    // Owner actions
    // ---------------------------------------------------------------------

    /// @notice Moves idle underlying into the configured strategy.
    function invest(uint256 assets) external nonReentrant onlyOwner {
        if (assets == 0) revert ZeroAmount();
        IStrategy currentStrategy = strategy;
        if (address(currentStrategy) == address(0)) revert NoStrategy();
        if (underlying.balanceOf(address(this)) < assets) revert InsufficientLiquidity();

        underlying.forceApprove(address(currentStrategy), assets);
        currentStrategy.invest(assets);
        underlying.forceApprove(address(currentStrategy), 0);

        emit Invested(assets);
    }

    /// @notice Sets a new strategy. The current strategy must hold no assets.
    function setStrategy(address newStrategy) external onlyOwner {
        if (newStrategy == address(0)) revert ZeroAddress();

        IStrategy currentStrategy = strategy;
        if (address(currentStrategy) != address(0) && currentStrategy.totalAssets() != 0) {
            revert StrategyNotEmpty();
        }

        strategy = IStrategy(newStrategy);
        emit StrategySet(address(currentStrategy), newStrategy);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ---------------------------------------------------------------------
    // Accounting
    // ---------------------------------------------------------------------

    /// @notice Total underlying controlled by the vault, including strategy assets.
    function totalAssets() public view returns (uint256) {
        uint256 idle = underlying.balanceOf(address(this));
        IStrategy currentStrategy = strategy;
        return address(currentStrategy) == address(0) ? idle : idle + currentStrategy.totalAssets();
    }

    /// @notice Assets required to mint `shares`, rounded up.
    function convertToAssets(uint256 shares) public view returns (uint256) {
        return shares.mulDiv(totalAssets() + VIRTUAL_ASSETS, sharesToken.totalSupply() + VIRTUAL_SHARES);
    }

    /// @notice Shares minted for `assets`, rounded down.
    function convertToShares(uint256 assets) public view returns (uint256) {
        return assets.mulDiv(sharesToken.totalSupply() + VIRTUAL_SHARES, totalAssets() + VIRTUAL_ASSETS);
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    function maxDeposit(address) public view returns (uint256) {
        return paused ? 0 : type(uint256).max;
    }

    function maxWithdraw(address account) public view returns (uint256) {
        return previewRedeem(sharesToken.balanceOf(account));
    }

    // ---------------------------------------------------------------------
    // Internals
    // ---------------------------------------------------------------------

    /// @dev Divests from the strategy when idle liquidity cannot cover a transfer.
    function _ensureLiquidity(uint256 assets) private {
        uint256 idle = underlying.balanceOf(address(this));
        if (idle >= assets) return;

        IStrategy currentStrategy = strategy;
        if (address(currentStrategy) == address(0)) revert InsufficientLiquidity();
        currentStrategy.divest(assets - idle);
    }
}
