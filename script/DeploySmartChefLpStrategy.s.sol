// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SmartChefLpStrategy} from "../src/SmartChefLpStrategy.sol";
import {IDiamonRouter} from "../src/interfaces/IDiamonRouter.sol";
import {ISmartChefV2} from "../src/interfaces/ISmartChefV2.sol";

contract DeploySmartChefLpStrategy is Script {
    address public constant DIAMON_ROUTER = 0xAb30a29168D792c5e6a54E4bcF1Aec926a3b20FA;
    address public constant KUSDT_LUMI_LP = 0x7Bf51541208A70b784006eF7Bd6F774F4012Cd38;
    address public constant SMART_CHEF = 0xd6693F73C0eC5EA56A6C25CE37Ad58820485794a;
    address public constant TOMATO = 0x9Ea7E0435B5E50e1DCBB8Eacd63F0dbD3003BdAA;
    address public constant KUSDT = 0x7d984C24d2499D840eB3b7016077164e15E5faA6;
    address public constant LUMI = 0x95013Dcb6A561e6C003AED9C43Fb8B64008aA361;

    uint256 public constant MAX_SLIPPAGE_BPS = 300;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vault = vm.envAddress("VAULT_ADDRESS");

        address[] memory rewardToToken0Path = new address[](2);
        rewardToToken0Path[0] = TOMATO;
        rewardToToken0Path[1] = KUSDT;

        address[] memory rewardToToken1Path = new address[](2);
        rewardToToken1Path[0] = TOMATO;
        rewardToToken1Path[1] = LUMI;

        vm.startBroadcast(deployerPrivateKey);

        SmartChefLpStrategy strategy = new SmartChefLpStrategy(
            IERC20(KUSDT_LUMI_LP),
            vault,
            ISmartChefV2(SMART_CHEF),
            IDiamonRouter(DIAMON_ROUTER),
            IERC20(TOMATO),
            rewardToToken0Path,
            rewardToToken1Path,
            MAX_SLIPPAGE_BPS
        );

        vm.stopBroadcast();

        console.log("SmartChefLpStrategy", address(strategy));
        console.log("Vault", vault);
        console.log("LP", KUSDT_LUMI_LP);
    }
}
