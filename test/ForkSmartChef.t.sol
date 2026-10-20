// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KubYieldVault} from "../src/KubYieldVault.sol";
import {KubYieldShares} from "../src/KubYieldShares.sol";
import {IKubYieldShares} from "../src/interfaces/IKubYieldShares.sol";
import {ISmartChefV2} from "../src/interfaces/ISmartChefV2.sol";
import {IDiamonRouter} from "../src/interfaces/IDiamonRouter.sol";
import {SmartChefLpStrategy} from "../src/SmartChefLpStrategy.sol";

contract ForkSmartChefTest is Test {
    address constant ROUTER = 0xAb30a29168D792c5e6a54E4bcF1Aec926a3b20FA;
    address constant LP = 0x7Bf51541208A70b784006eF7Bd6F774F4012Cd38;
    address constant FARM = 0xd6693F73C0eC5EA56A6C25CE37Ad58820485794a;
    address constant TOMATO = 0x9Ea7E0435B5E50e1DCBB8Eacd63F0dbD3003BdAA;
    address constant KUSDT = 0x7d984C24d2499D840eB3b7016077164e15E5faA6;
    address constant LUMI = 0x95013Dcb6A561e6C003AED9C43Fb8B64008aA361;

    function test_live_harvest() public {
        if (vm.envOr("RUN_KUB_FORK", uint256(0)) == 0) {
            vm.skip(true);
            return;
        }

        vm.createSelectFork(vm.envOr("KUB_RPC_URL", string("https://rpc.kubchain.io")));

        KubYieldShares shares = new KubYieldShares(address(0), address(0), address(0), address(0), 18);
        KubYieldVault vault = new KubYieldVault(IERC20(LP), IKubYieldShares(address(shares)));
        shares.setVault(address(vault));

        address[] memory path0 = new address[](2);
        path0[0] = TOMATO;
        path0[1] = KUSDT;
        address[] memory path1 = new address[](2);
        path1[0] = TOMATO;
        path1[1] = LUMI;

        SmartChefLpStrategy strategy = new SmartChefLpStrategy(
            IERC20(LP), address(vault), ISmartChefV2(FARM), IDiamonRouter(ROUTER), IERC20(TOMATO), path0, path1, 300
        );
        vault.setStrategy(address(strategy));

        deal(LP, address(this), 1_000 ether);
        IERC20(LP).approve(address(vault), 1_000 ether);
        vault.deposit(1_000 ether);
        vault.invest(1_000 ether);

        vm.roll(block.number + 1_000);

        uint256 before = vault.totalAssets();
        vault.harvest();

        assertGt(vault.totalAssets(), before);
        assertEq(IERC20(LP).balanceOf(address(strategy)), 0);
    }
}
