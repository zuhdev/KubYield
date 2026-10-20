// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockSmartChefV2 {
    using SafeERC20 for IERC20;

    IERC20 public immutable stakedToken;
    IERC20 public immutable rewardToken;
    bool public paused;

    mapping(address => uint256) private _staked;
    mapping(address => uint256) private _pending;

    error Paused();
    error InsufficientStake();

    constructor(IERC20 stakedToken_, IERC20 rewardToken_) {
        stakedToken = stakedToken_;
        rewardToken = rewardToken_;
    }

    function setPending(address account, uint256 amount) external {
        _pending[account] += amount;
    }

    function setPaused(bool paused_) external {
        paused = paused_;
    }

    function deposit(uint256 amount) external {
        if (paused) revert Paused();
        stakedToken.safeTransferFrom(msg.sender, address(this), amount);
        _staked[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        if (paused) revert Paused();
        if (amount > _staked[msg.sender]) revert InsufficientStake();
        _staked[msg.sender] -= amount;
        stakedToken.safeTransfer(msg.sender, amount);
        _claim(msg.sender);
    }

    function harvest() external {
        if (paused) revert Paused();
        _claim(msg.sender);
    }

    function userInfo(address account)
        external
        view
        returns (
            uint256 amount,
            uint256 nftPower,
            uint256 nftPowerBeforeMultiply,
            uint256 rewardDebt,
            uint256 quotaUsed
        )
    {
        return (_staked[account], 0, 0, 0, 0);
    }

    function pendingReward(address account) external view returns (uint256) {
        return _pending[account];
    }

    function _claim(address account) private {
        uint256 amount = _pending[account];
        if (amount == 0) return;
        _pending[account] = 0;
        MockERC20(address(rewardToken)).mint(account, amount);
    }
}
