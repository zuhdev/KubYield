// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IStrategy
/// @notice Interface between a KubYield vault and an external yield strategy.
/// @dev A strategy custodies vault assets and reports their value. The vault
///      treats any growth in `totalAssets` above its accounted balance as yield.
interface IStrategy {
    /// @notice Total assets currently controlled by the strategy, in underlying units.
    function totalAssets() external view returns (uint256);

    /// @notice Pulls `amount` of underlying from the vault and deploys it.
    function invest(uint256 amount) external;

    /// @notice Returns `amount` of underlying to the vault.
    function divest(uint256 amount) external;

    /// @notice Realizes and restakes rewards. Called by the vault before accounting.
    function harvest() external;
}
