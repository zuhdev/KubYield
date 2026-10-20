// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KubYieldVault} from "../src/KubYieldVault.sol";
import {KubYieldShares} from "../src/KubYieldShares.sol";
import {IKubYieldShares} from "../src/interfaces/IKubYieldShares.sol";

/// @notice Testnet-only stand-in for a DEX LP token.
contract DemoLP is ERC20 {
    constructor() ERC20("KubYield Demo LP", "kyLP-DEMO") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Local/testnet demo deployment. Diamond Finance is not deployed on KUB
///         testnet, so this deploys a demo LP token and mints 1,000 LP to the deployer.
contract DeployKubYieldDemo is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        DemoLP lp = new DemoLP();
        KubYieldShares shares = new KubYieldShares(address(0), address(0), address(0), address(0), 18);
        KubYieldVault vault = new KubYieldVault(IERC20(address(lp)), IKubYieldShares(address(shares)));
        shares.setVault(address(vault));

        lp.mint(deployer, 1_000 ether);

        vm.stopBroadcast();

        console.log("DemoLP", address(lp));
        console.log("KubYieldShares", address(shares));
        console.log("KubYieldVault", address(vault));
    }
}
