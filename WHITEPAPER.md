# KubYield Whitepaper

Version 1.0 — October 2026

Repository: <https://github.com/zuhdev/KubYield>

## 1. Summary

KubYield is a vault protocol that auto-compounds liquidity provider (LP) rewards
on KUB Chain. Users deposit DEX LP tokens and receive KAP-20 receipt shares.
Rewards are harvested permissionlessly, swapped back into the LP asset, and
restaked. The caller of `harvest` receives 5% of the realized gain. The vault
uses ERC-4626-style share accounting with a virtual-share offset and a pluggable
strategy interface.

The first target is Diamond Finance, the largest DEX on KUB Chain. Additional
DEXs can be supported by implementing the same strategy interface.

## 2. Problem

KUB Chain has roughly $5M in DeFi TVL across 12 protocols (DefiLlama, October
2026) and no yield aggregator or auto-compounder. LPs who farm DEX rewards must
manually claim tokens, swap them, and redeposit liquidity. This has three
consequences:

- Rewards remain unclaimed, so advertised APRs are not realized.
- Compounding frequency depends on user attention, not on optimal yield.
- Liquidity is less sticky because managing a position requires repeated
  transactions.

The problem is not a lack of DEX liquidity. It is the absence of a compounding
layer on top of existing DEXs.

## 3. Protocol overview

Each vault is tied to one LP token:

1. A user deposits LP tokens with `deposit`.
2. The vault mints KAP-20 shares at the current share price.
3. The owner can move idle LP tokens into a strategy with `invest`.
4. Anyone can call `harvest`. The vault calls `strategy.harvest()`, measures the
   increase in `totalAssets()`, and pays the caller 5% of the increase.
5. A user redeems shares with `withdraw`. The vault divests from the strategy if
   idle liquidity is insufficient, then transfers the underlying LP tokens.

There is no governance token, no keeper key, and no off-chain dependency.
Harvesting is profitable for any caller when the gain exceeds gas cost.

## 4. Architecture

| Component | Responsibility |
| --- | --- |
| `KubYieldVault` | Deposits, withdrawals, share pricing, yield accounting, strategy management |
| `KubYieldShares` | KAP-20 receipt token; minting and burning restricted to the vault |
| `IStrategy` | Interface for deploying capital and realizing rewards |
| Diamond strategy (planned) | Claims Diamond rewards, swaps to the LP asset, restakes |

Asset flow:

- Deposit: `user -> vault` (LP tokens), `vault -> user` (shares).
- Invest: `vault -> strategy` (LP tokens).
- Harvest: strategy realizes rewards, value accrues to the vault's assets.
- Withdraw: `vault -> user` (LP tokens), user shares are burned.

The vault holds idle assets and tracks the value held by the strategy through
`strategy.totalAssets()`. The vault never assumes where assets are held; it only
requires the strategy to report and return them accurately.

## 5. Share accounting

Let:

- `S` = shares outstanding
- `A` = `totalAssets()` (idle + strategy assets)
- `a` = assets deposited or redeemed
- `s` = shares minted or burned

Shares minted on deposit:

```text
s = floor(a * (S + 1) / (A + 1))
```

Assets returned on redemption:

```text
a = floor(s * (A + 1) / (S + 1))
```

The `+1` terms are virtual shares and virtual assets. They make the
first-depositor inflation attack unprofitable: an attacker who donates assets to
raise the share price causes the next depositor to receive fewer shares, but the
attacker cannot profit from the rounding because the virtual offset bounds the
exchange rate.

Both conversions round down in favor of the vault. Rounding can leave a few wei
of dust in the vault after the last withdrawal; this is expected and is not
withdrawable by the owner.

## 6. Yield accounting and harvest

The vault stores `accountedAssets`, the asset value at the last accounting
event. On deposit it increases by the deposited amount; on withdrawal it
decreases by the redeemed amount.

Harvest:

```text
rewards = totalAssets() - accountedAssets
fee     = floor(rewards * 500 / 10000)
```

`accountedAssets` is set to `totalAssets() - fee` before the fee transfer, so the
same gain cannot be charged twice. If `totalAssets()` does not exceed
`accountedAssets`, `harvest` reverts with `NoRewards`.

The fee is paid in the underlying LP token. If idle liquidity is insufficient,
the vault divests the fee amount from the strategy. There are no deposit,
withdrawal, or management fees.

## 7. Strategy interface

```solidity
interface IStrategy {
    function totalAssets() external view returns (uint256);
    function invest(uint256 amount) external;
    function divest(uint256 amount) external;
    function harvest() external;
}
```

Requirements:

- `totalAssets` reports every asset the strategy controls.
- `invest` is called by the vault after approval; it pulls the specified amount.
- `divest` returns the specified amount to the vault.
- `harvest` realizes and restakes rewards. The vault measures the result through
  `totalAssets`, so the strategy does not need to report rewards.

The strategy is trusted code. The owner can replace it only while the current
strategy holds zero assets, which prevents migrating away from a strategy that
still custodies user funds.

## 8. Security model

- **Access control.** Vault ownership controls strategy changes, investment, and
  pausing. The shares contract binds the vault once; only that address can mint
  or burn shares.
- **Reentrancy.** All asset-moving vault entry points use `ReentrancyGuard`,
  `SafeERC20`, and checks-effects-interactions ordering.
- **Pause semantics.** Pausing blocks deposits, harvests, and new investments.
  Withdrawals remain available so users can always exit.
- **Strategy safety.** A strategy cannot be replaced while it holds assets.
- **No proxies.** Core contracts are immutable. The underlying asset and shares
  contract cannot be changed.
- **No oracle.** Share pricing depends only on token balances and strategy
  reporting, not on external price feeds.

Known risks:

- The contracts have not been audited. Test coverage does not replace review.
- A faulty or malicious strategy can misreport or lose assets. Strategy
  selection is an owner trust assumption.
- LP tokens carry DEX, impermanent loss, and underlying asset risk. The vault
  does not hedge these.
- KAP-20 shares depend on KUB's KYC registry, admin project router, and transfer
  router configuration for transfers and compliance.
- The owner key can pause deposits and change an empty strategy. It cannot
  transfer user assets directly.

## 9. Implementation status

- Solidity 0.8.24, `evm_version = "paris"` for KUB Chain compatibility.
- `KubYieldVault` and `KubYieldShares` implemented.
- 22 Foundry tests covering deposits, withdrawals, share math, harvest fees,
  pause behavior, access control, and strategy invest/divest/harvest flows,
  including fuzzed deposit/withdraw round-trips.
- Demo and production deployment scripts.
- No testnet or mainnet deployment yet.

## 10. Roadmap

1. **Diamond Finance strategy and testnet deployment.** Confirm the staking and
   router ABIs, implement the strategy, deploy and verify the vault on KUB
   testnet.
2. **Security review and mainnet launch.** External review, deployment for the
   KKUB/USDT LP pair, and public launch.
3. **Expansion.** Strategies for additional KUB DEXs, a TVL and yield dashboard,
   and liquidity incentives.

Grant funding of $30,000 covers the security review, Diamond strategy
development, and launch costs.

## 11. References

- KUB Chain documentation: <https://docs.kubchain.com>
- KUB testnet explorer: <https://testnet.kubscan.com>
- OpenZeppelin Contracts: <https://github.com/OpenZeppelin/openzeppelin-contracts>
- kub-chain/kub-contracts (vendored, MIT): <https://github.com/kub-chain/kub-contracts>
- KubYield repository: <https://github.com/zuhdev/KubYield>
