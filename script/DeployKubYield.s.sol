// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KubYieldVault} from "../src/KubYieldVault.sol";
import {KubYieldShares} from "../src/KubYieldShares.sol";
import {IKubYieldShares} from "../src/interfaces/IKubYieldShares.sol";

/// @notice Production deployment against real Kub Chain infrastructure.
/// @dev The Diamond Finance strategy is deployed separately once its staking ABI
///      is confirmed, then attached with `vault.setStrategy(...)`.
contract DeployKubYield is Script {
    // Confirmed KUB testnet KAP-20 tokens.
    address public constant KKUB = 0x1de8A5c87d421f53eE4ae398cc766e62E88e9518;
    address public constant USDT = 0x4de09F9E7282C1E66ED13ed930942E7fAb9915E9;

    // Resolve from https://testnet.kubscan.com before deploying.
    address public constant KYC_REGISTRY = address(0);
    address public constant ADMIN_PROJECT_ROUTER = address(0);
    address public constant COMMITTEE = address(0);
    address public constant TRANSFER_ROUTER = address(0);
    address public constant DIAMOND_LP_KKUB_USDT = address(0);

    uint8 public constant SHARES_DECIMALS = 18;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        KubYieldShares shares =
            new KubYieldShares(KYC_REGISTRY, ADMIN_PROJECT_ROUTER, COMMITTEE, TRANSFER_ROUTER, SHARES_DECIMALS);
        KubYieldVault vault = new KubYieldVault(IERC20(DIAMOND_LP_KKUB_USDT), IKubYieldShares(address(shares)));
        shares.setVault(address(vault));

        vm.stopBroadcast();

        console.log("KubYieldShares", address(shares));
        console.log("KubYieldVault", address(vault));
    }
}
