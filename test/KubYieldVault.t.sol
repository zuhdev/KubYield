// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KubYieldVault} from "../src/KubYieldVault.sol";
import {KubYieldShares} from "../src/KubYieldShares.sol";
import {IKubYieldShares} from "../src/interfaces/IKubYieldShares.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockStrategy} from "./mocks/MockStrategy.sol";

contract KubYieldVaultTest is Test {
    uint256 private constant INITIAL_BALANCE = 1_000 ether;

    MockERC20 private asset;
    KubYieldShares private shares;
    KubYieldVault private vault;

    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");

    function setUp() public {
        asset = new MockERC20("Mock LP", "MLP");
        shares = new KubYieldShares(address(0), address(0), address(0), address(0), 18);
        vault = new KubYieldVault(IERC20(address(asset)), IKubYieldShares(address(shares)));
        shares.setVault(address(vault));

        asset.mint(alice, INITIAL_BALANCE);
        asset.mint(bob, INITIAL_BALANCE);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);
    }

    function _deposit(address account, uint256 assets) private returns (uint256) {
        vm.prank(account);
        return vault.deposit(assets);
    }

    function test_deposit_mints_shares() public {
        uint256 minted = _deposit(alice, 100 ether);

        assertEq(minted, 100 ether);
        assertEq(shares.balanceOf(alice), 100 ether);
        assertEq(vault.totalAssets(), 100 ether);
        assertEq(vault.accountedAssets(), 100 ether);
    }

    function test_withdraw_burns_shares() public {
        _deposit(alice, 100 ether);

        vm.prank(alice);
        uint256 redeemed = vault.withdraw(50 ether);

        assertEq(redeemed, 50 ether);
        assertEq(shares.balanceOf(alice), 50 ether);
        assertEq(vault.totalAssets(), 50 ether);
        assertEq(asset.balanceOf(alice), INITIAL_BALANCE - 50 ether);
    }

    function test_deposit_zero_reverts() public {
        vm.prank(alice);
        vm.expectRevert(KubYieldVault.ZeroAmount.selector);
        vault.deposit(0);
    }

    function test_withdraw_zero_reverts() public {
        vm.prank(alice);
        vm.expectRevert(KubYieldVault.ZeroAmount.selector);
        vault.withdraw(0);
    }

    function test_withdraw_more_than_balance_reverts() public {
        _deposit(alice, 100 ether);

        vm.prank(alice);
        vm.expectRevert(KubYieldVault.InsufficientShares.selector);
        vault.withdraw(101 ether);
    }

    function test_harvest_pays_caller_fee() public {
        _deposit(alice, 100 ether);
        asset.mint(address(vault), 10 ether);

        vm.prank(bob);
        uint256 fee = vault.harvest();

        assertEq(fee, 0.5 ether);
        assertEq(asset.balanceOf(bob), INITIAL_BALANCE + 0.5 ether);
        assertEq(vault.totalAssets(), 109.5 ether);
        assertEq(vault.accountedAssets(), 109.5 ether);
    }

    function test_harvest_without_rewards_reverts() public {
        _deposit(alice, 100 ether);

        vm.expectRevert(KubYieldVault.NoRewards.selector);
        vault.harvest();
    }

    function test_deposit_reverts_when_paused() public {
        vault.pause();

        vm.prank(alice);
        vm.expectRevert("Pausable: paused");
        vault.deposit(1 ether);
    }

    function test_withdraw_works_when_paused() public {
        _deposit(alice, 100 ether);
        vault.pause();

        vm.prank(alice);
        vault.withdraw(100 ether);

        assertEq(asset.balanceOf(alice), INITIAL_BALANCE);
        assertEq(vault.totalAssets(), 0);
    }

    function test_pause_only_owner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.pause();
    }

    function test_set_strategy_only_owner() public {
        address newStrategy = address(new MockStrategy(IERC20(address(asset)), address(vault)));

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setStrategy(newStrategy);
    }

    function test_set_strategy_zero_reverts() public {
        vm.expectRevert(KubYieldVault.ZeroAddress.selector);
        vault.setStrategy(address(0));
    }

    function test_set_strategy_reverts_when_current_holds_assets() public {
        MockStrategy current = new MockStrategy(IERC20(address(asset)), address(vault));
        vault.setStrategy(address(current));

        _deposit(alice, 100 ether);
        vault.invest(10 ether);

        MockStrategy next = new MockStrategy(IERC20(address(asset)), address(vault));
        vm.expectRevert(KubYieldVault.StrategyNotEmpty.selector);
        vault.setStrategy(address(next));
    }

    function test_invest_moves_idle_assets_to_strategy() public {
        MockStrategy strategy = new MockStrategy(IERC20(address(asset)), address(vault));
        vault.setStrategy(address(strategy));

        _deposit(alice, 100 ether);
        vault.invest(60 ether);

        assertEq(asset.balanceOf(address(strategy)), 60 ether);
        assertEq(vault.totalAssets(), 100 ether);
    }

    function test_withdraw_divests_from_strategy() public {
        MockStrategy strategy = new MockStrategy(IERC20(address(asset)), address(vault));
        vault.setStrategy(address(strategy));

        _deposit(alice, 100 ether);
        vault.invest(100 ether);

        vm.prank(alice);
        uint256 redeemed = vault.withdraw(40 ether);

        assertEq(redeemed, 40 ether);
        assertEq(asset.balanceOf(address(strategy)), 60 ether);
        assertEq(vault.totalAssets(), 60 ether);
    }

    function test_harvest_recognizes_strategy_yield() public {
        MockStrategy strategy = new MockStrategy(IERC20(address(asset)), address(vault));
        vault.setStrategy(address(strategy));

        _deposit(alice, 100 ether);
        vault.invest(60 ether);
        asset.mint(address(strategy), 20 ether);

        uint256 fee = vault.harvest();

        assertEq(fee, 1 ether);
        assertEq(vault.totalAssets(), 119 ether);
        assertEq(vault.accountedAssets(), 119 ether);

        vm.prank(alice);
        uint256 redeemed = vault.withdraw(100 ether);
        assertApproxEqAbs(redeemed, 119 ether, 1e6);
        assertApproxEqAbs(vault.totalAssets(), 0, 1);
    }

    function test_shares_mint_only_vault() public {
        vm.expectRevert(KubYieldShares.OnlyVault.selector);
        shares.mint(alice, 1 ether);
    }

    function test_shares_vault_bound_once() public {
        vm.expectRevert(KubYieldShares.VaultAlreadySet.selector);
        shares.setVault(bob);
    }

    function test_shares_vault_zero_reverts() public {
        KubYieldShares fresh = new KubYieldShares(address(0), address(0), address(0), address(0), 18);

        vm.expectRevert(KubYieldShares.ZeroAddress.selector);
        fresh.setVault(address(0));
    }

    function test_max_deposit_respects_pause() public {
        assertEq(vault.maxDeposit(alice), type(uint256).max);

        vault.pause();
        assertEq(vault.maxDeposit(alice), 0);
    }

    function test_max_withdraw_matches_share_balance() public {
        _deposit(alice, 100 ether);

        assertEq(vault.maxWithdraw(alice), 100 ether);
        assertEq(vault.maxWithdraw(bob), 0);
    }

    function testFuzz_deposit_then_withdraw_all(uint96 rawAssets) public {
        uint256 deposited = bound(rawAssets, 1, INITIAL_BALANCE);

        uint256 minted = _deposit(alice, deposited);
        assertEq(minted, deposited);

        vm.prank(alice);
        uint256 redeemed = vault.withdraw(minted);

        assertEq(redeemed, deposited);
        assertEq(asset.balanceOf(alice), INITIAL_BALANCE);
        assertEq(shares.balanceOf(alice), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.accountedAssets(), 0);
    }
}
