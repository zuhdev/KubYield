// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KubYieldVault} from "../src/KubYieldVault.sol";
import {KubYieldShares} from "../src/KubYieldShares.sol";
import {IKubYieldShares} from "../src/interfaces/IKubYieldShares.sol";

/// @notice Production deployment against real Kub Chain infrastructure.
/// @dev The SmartChef LP strategy is deployed separately with
///      `DeploySmartChefLpStrategy`, then attached with `vault.setStrategy(...)`.
contract DeployKubYield is Script {
    uint8 public constant SHARES_DECIMALS = 18;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address kycRegistry = vm.envAddress("KYC_REGISTRY");
        address adminProjectRouter = vm.envAddress("ADMIN_PROJECT_ROUTER");
        address committee = vm.envAddress("COMMITTEE");
        address transferRouter = vm.envAddress("TRANSFER_ROUTER");
        address diamonLp = vm.envAddress("DIAMON_LP");

        vm.startBroadcast(deployerPrivateKey);

        KubYieldShares shares =
            new KubYieldShares(kycRegistry, adminProjectRouter, committee, transferRouter, SHARES_DECIMALS);
        KubYieldVault vault = new KubYieldVault(IERC20(diamonLp), IKubYieldShares(address(shares)));
        shares.setVault(address(vault));

        vm.stopBroadcast();

        console.log("KubYieldShares", address(shares));
        console.log("KubYieldVault", address(vault));
    }
}
