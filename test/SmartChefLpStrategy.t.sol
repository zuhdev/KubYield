// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KubYieldVault} from "../src/KubYieldVault.sol";
import {KubYieldShares} from "../src/KubYieldShares.sol";
import {IKubYieldShares} from "../src/interfaces/IKubYieldShares.sol";
import {ISmartChefV2} from "../src/interfaces/ISmartChefV2.sol";
import {SmartChefLpStrategy} from "../src/SmartChefLpStrategy.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockDiamonPair} from "./mocks/MockDiamonPair.sol";
import {MockDiamonRouter} from "./mocks/MockDiamonRouter.sol";
import {MockSmartChefV2} from "./mocks/MockSmartChefV2.sol";

contract SmartChefLpStrategyTest is Test {
    uint256 private constant INITIAL_LP = 10_000 ether;
    uint256 private constant DEPOSIT = 1_000 ether;
    uint256 private constant MAX_SLIPPAGE_BPS = 300;

    MockERC20 private token0;
    MockERC20 private token1;
    MockERC20 private reward;
    MockDiamonPair private pair;
    MockDiamonRouter private router;
    MockSmartChefV2 private farm;
    KubYieldShares private shares;
    KubYieldVault private vault;
    SmartChefLpStrategy private strategy;

    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");

    function setUp() public {
        token0 = new MockERC20("KUSDT", "KUSDT");
        token1 = new MockERC20("LUMI", "LUMI");
        reward = new MockERC20("TOMATO", "TOMATO");
        pair = new MockDiamonPair(address(token0), address(token1));
        router = new MockDiamonRouter(pair, address(reward), 1e18);
        farm = new MockSmartChefV2(IERC20(address(pair)), IERC20(address(reward)));

        token0.mint(address(pair), INITIAL_LP);
        token0.mint(address(router), 1_000_000 ether);
        token1.mint(address(router), 1_000_000 ether);
        token1.mint(address(pair), INITIAL_LP);
        pair.mint(address(this));
        pair.transfer(alice, DEPOSIT);

        shares = new KubYieldShares(address(0), address(0), address(0), address(0), 18);
        vault = new KubYieldVault(IERC20(address(pair)), IKubYieldShares(address(shares)));
        shares.setVault(address(vault));
        strategy = _deployStrategy(IERC20(address(pair)), IERC20(address(reward)), farm);

        vault.setStrategy(address(strategy));

        vm.prank(alice);
        pair.approve(address(vault), type(uint256).max);
    }

    function _deployStrategy(IERC20 asset_, IERC20 reward_, MockSmartChefV2 farm_)
        private
        returns (SmartChefLpStrategy)
    {
        address[] memory path0 = new address[](2);
        path0[0] = address(reward_);
        path0[1] = address(token0);

        address[] memory path1 = new address[](2);
        path1[0] = address(reward_);
        path1[1] = address(token1);

        return new SmartChefLpStrategy(
            asset_, address(vault), ISmartChefV2(address(farm_)), router, reward_, path0, path1, MAX_SLIPPAGE_BPS
        );
    }

    function _depositAndInvest(uint256 amount) private {
        vm.prank(alice);
        vault.deposit(amount);
        vault.invest(amount);
    }

    function _staked() private view returns (uint256 amount) {
        (amount,,,,) = farm.userInfo(address(strategy));
    }

    function test_invest_stakes_lp() public {
        _depositAndInvest(600 ether);

        assertEq(pair.balanceOf(address(strategy)), 0);
        assertEq(_staked(), 600 ether);
        assertEq(strategy.totalAssets(), 600 ether);
        assertEq(vault.totalAssets(), 600 ether);
    }

    function test_total_assets_counts_idle_and_staked_lp() public {
        _depositAndInvest(400 ether);
        pair.transfer(address(strategy), 100 ether);

        assertEq(_staked(), 400 ether);
        assertEq(pair.balanceOf(address(strategy)), 100 ether);
        assertEq(strategy.totalAssets(), 500 ether);
        assertEq(vault.totalAssets(), 500 ether);
    }

    function test_harvest_compounds_rewards_and_pays_fee() public {
        _depositAndInvest(DEPOSIT);
        farm.setPending(address(strategy), 100 ether);

        uint256 assetsBefore = vault.totalAssets();
        uint256 bobBefore = pair.balanceOf(bob);
        vm.prank(bob);
        uint256 fee = vault.harvest();

        uint256 assetsAfter = vault.totalAssets();
        assertGt(assetsAfter, assetsBefore);
        assertGt(fee, 0);
        assertEq(pair.balanceOf(bob), bobBefore + fee);
        assertEq(strategy.totalAssets(), assetsAfter);
        assertEq(_staked(), assetsAfter);
        assertEq(vault.accountedAssets(), assetsAfter);
    }

    function test_harvest_twice_compounds_new_rewards() public {
        _depositAndInvest(DEPOSIT);
        farm.setPending(address(strategy), 100 ether);
        vault.harvest();
        uint256 firstTotal = vault.totalAssets();

        farm.setPending(address(strategy), 50 ether);
        vault.harvest();

        assertGt(vault.totalAssets(), firstTotal);
    }

    function test_harvest_without_rewards_reverts() public {
        _depositAndInvest(DEPOSIT);

        vm.expectRevert(SmartChefLpStrategy.NoRewards.selector);
        vault.harvest();
    }

    function test_harvest_only_vault() public {
        vm.expectRevert(SmartChefLpStrategy.OnlyVault.selector);
        strategy.harvest();
    }

    function test_invest_only_vault() public {
        vm.expectRevert(SmartChefLpStrategy.OnlyVault.selector);
        strategy.invest(1 ether);
    }

    function test_divest_only_vault() public {
        vm.expectRevert(SmartChefLpStrategy.OnlyVault.selector);
        strategy.divest(1 ether);
    }

    function test_divest_reverts_above_staked_assets() public {
        _depositAndInvest(100 ether);

        vm.prank(address(vault));
        vm.expectRevert(SmartChefLpStrategy.InsufficientAssets.selector);
        strategy.divest(101 ether);
    }

    function test_withdraw_divests_from_farm() public {
        _depositAndInvest(DEPOSIT);

        vm.prank(alice);
        uint256 assets = vault.withdraw(400 ether);

        assertEq(assets, 400 ether);
        assertEq(_staked(), 600 ether);
        assertEq(pair.balanceOf(alice), 400 ether);
        assertEq(vault.totalAssets(), 600 ether);
    }

    function test_withdraw_with_pending_reward_leaves_reward_for_next_harvest() public {
        _depositAndInvest(DEPOSIT);
        farm.setPending(address(strategy), 50 ether);

        vm.prank(alice);
        vault.withdraw(400 ether);

        assertEq(reward.balanceOf(address(strategy)), 50 ether);
        assertEq(reward.balanceOf(address(farm)), 0);

        uint256 assetsBefore = vault.totalAssets();
        vault.harvest();
        assertGt(vault.totalAssets(), assetsBefore);
    }

    function test_harvest_reverts_on_invalid_path() public {
        address[] memory badPath = new address[](2);
        badPath[0] = address(reward);
        badPath[1] = address(token0);

        vm.expectRevert(SmartChefLpStrategy.InvalidPath.selector);
        new SmartChefLpStrategy(
            IERC20(address(pair)),
            address(vault),
            ISmartChefV2(address(farm)),
            router,
            IERC20(address(reward)),
            badPath,
            badPath,
            MAX_SLIPPAGE_BPS
        );
    }

    function test_constructor_rejects_reward_equal_to_pair_token() public {
        MockSmartChefV2 badFarm = new MockSmartChefV2(IERC20(address(pair)), IERC20(address(token0)));

        address[] memory path0 = new address[](2);
        path0[0] = address(token0);
        path0[1] = address(token0);
        address[] memory path1 = new address[](2);
        path1[0] = address(token0);
        path1[1] = address(token1);

        vm.expectRevert(SmartChefLpStrategy.InvalidRewardToken.selector);
        new SmartChefLpStrategy(
            IERC20(address(pair)),
            address(vault),
            ISmartChefV2(address(badFarm)),
            router,
            IERC20(address(token0)),
            path0,
            path1,
            MAX_SLIPPAGE_BPS
        );
    }

    function test_constructor_rejects_wrong_farm() public {
        MockSmartChefV2 badFarm = new MockSmartChefV2(IERC20(address(reward)), IERC20(address(reward)));

        address[] memory path0 = new address[](2);
        path0[0] = address(reward);
        path0[1] = address(token0);
        address[] memory path1 = new address[](2);
        path1[0] = address(reward);
        path1[1] = address(token1);

        vm.expectRevert(SmartChefLpStrategy.InvalidFarm.selector);
        new SmartChefLpStrategy(
            IERC20(address(pair)),
            address(vault),
            ISmartChefV2(address(badFarm)),
            router,
            IERC20(address(reward)),
            path0,
            path1,
            MAX_SLIPPAGE_BPS
        );
    }

    function test_constructor_rejects_high_slippage() public {
        address[] memory path0 = new address[](2);
        path0[0] = address(reward);
        path0[1] = address(token0);
        address[] memory path1 = new address[](2);
        path1[0] = address(reward);
        path1[1] = address(token1);

        vm.expectRevert(SmartChefLpStrategy.InvalidSlippage.selector);
        new SmartChefLpStrategy(
            IERC20(address(pair)),
            address(vault),
            ISmartChefV2(address(farm)),
            router,
            IERC20(address(reward)),
            path0,
            path1,
            2_001
        );
    }

    function test_constructor_rejects_empty_pair() public {
        MockDiamonPair emptyPair = new MockDiamonPair(address(token0), address(token1));

        address[] memory path0 = new address[](2);
        path0[0] = address(reward);
        path0[1] = address(token0);
        address[] memory path1 = new address[](2);
        path1[0] = address(reward);
        path1[1] = address(token1);

        vm.expectRevert(SmartChefLpStrategy.InvalidPair.selector);
        new SmartChefLpStrategy(
            IERC20(address(emptyPair)),
            address(vault),
            ISmartChefV2(address(farm)),
            router,
            IERC20(address(reward)),
            path0,
            path1,
            MAX_SLIPPAGE_BPS
        );
    }
}
