// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {KAP20} from "@kub-chain/contracts/contracts/token/KAP-20/KAP20.sol";

/// @title KubYieldShares
/// @notice KAP-20 receipt token minted and burned exclusively by the KubYield vault.
/// @dev The vault address can be bound once by the owner, then never changed.
contract KubYieldShares is KAP20 {
    address public vault;

    event VaultSet(address indexed vault);

    error ZeroAddress();
    error VaultAlreadySet();
    error OnlyVault();

    constructor(address kyc_, address adminProjectRouter_, address committee_, address transferRouter_, uint8 decimals_)
        KAP20(
            "KubYield LP Shares",
            "kyLP",
            "kubyield",
            decimals_,
            kyc_,
            adminProjectRouter_,
            committee_,
            transferRouter_,
            4
        )
    {}

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    /// @notice Binds the vault that is allowed to mint and burn shares.
    function setVault(address vault_) external onlyOwner {
        if (vault_ == address(0)) revert ZeroAddress();
        if (vault != address(0)) revert VaultAlreadySet();

        vault = vault_;
        emit VaultSet(vault_);
    }

    function mint(address to, uint256 amount) external onlyVault {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyVault {
        _burn(from, amount);
    }
}
