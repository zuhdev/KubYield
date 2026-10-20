// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ISmartChefV2 {
    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function harvest() external;

    function stakedToken() external view returns (address);

    function rewardToken() external view returns (address);

    function userInfo(address account)
        external
        view
        returns (
            uint256 amount,
            uint256 nftPower,
            uint256 nftPowerBeforeMultiply,
            uint256 rewardDebt,
            uint256 quotaUsed
        );

    function pendingReward(address account) external view returns (uint256);

    function paused() external view returns (bool);
}
