// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategy} from "../../src/interfaces/IStrategy.sol";

/// @notice Idle strategy used in tests: holds underlying and reports its balance.
contract MockStrategy is IStrategy {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    address public immutable vault;

    constructor(IERC20 asset_, address vault_) {
        asset = asset_;
        vault = vault_;
    }

    function totalAssets() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function invest(uint256 amount) external {
        asset.safeTransferFrom(msg.sender, address(this), amount);
    }

    function divest(uint256 amount) external {
        asset.safeTransfer(vault, amount);
    }

    function harvest() external pure {
        // Tests mint yield directly to the strategy to simulate rewards.
    }
}
