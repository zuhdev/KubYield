# KubYield

Auto-compounding yield vaults for KUB Chain DEX liquidity providers. Depositors
receive KAP-20 receipt shares; anyone can harvest, and the caller earns a fee.

Whitepaper: [WHITEPAPER.md](WHITEPAPER.md)

KUB Builder Grant category: **Other Liquidity Growth dApps** (max $30,000).

## Architecture

- `KubYieldVault` — ERC-4626-style vault: deposits, withdrawals, share pricing,
  strategy accounting, and permissionless harvests.
- `KubYieldShares` — KAP-20 receipt token. The vault is bound once by the owner
  and is the only address allowed to mint or burn.
- `IStrategy` — strategy hook used by the vault (`invest`, `divest`,
  `totalAssets`, `harvest`). A Diamond Finance strategy is the next milestone.
- `KubYieldStrategy` (removed for now) — the previous draft made unreviewable
  assumptions about Diamond's staking ABI. It will return against a confirmed
  interface rather than shipping speculative integration code.

### Design decisions

- Share math uses OpenZeppelin's virtual-share offset, making the classic
  first-depositor inflation attack unprofitable.
- `SafeERC20` and `ReentrancyGuard` guard all asset flows; state is updated
  before external calls (checks-effects-interactions).
- Harvest is permissionless: any caller receives `HARVEST_FEE_BPS` (5%) of the
  yield, so compounding needs no keeper infrastructure or privileged key.
- Withdrawals are never paused; only deposits, harvests, and investments pause.
- A strategy can only be replaced while it holds no assets.
- Custom errors instead of revert strings, pinned Solidity 0.8.24, optimizer on.

## KUB Chain specifics

- `evm_version = "paris"` (no PUSH0), `--legacy` transactions (no EIP-1559)
- Chain ID: 25925 testnet / 96 mainnet
- RPC: `https://rpc-testnet.kubchain.io`
- Explorer: `https://testnet.kubscan.com` (Blockscout, 12 req/min)
- Faucet: `https://faucet.kubchain.com`

Confirmed testnet KAP-20 tokens:

| Token | Address |
|-------|---------|
| KKUB | `0x1de8A5c87d421f53eE4ae398cc766e62E88e9518` |
| USDT | `0x4de09F9E7282C1E66ED13ed930942E7fAb9915E9` |

## Development

```bash
forge install OpenZeppelin/openzeppelin-contracts foundry-rs/forge-std
forge build
forge test
```

> `vendor/kub-contracts` is a vendored, patched copy of
> [kub-chain/kub-contracts](https://github.com/kub-chain/kub-contracts) (MIT).
> See `vendor/kub-contracts/PATCHES.md` for the one-line compile fix it carries.

## Local end-to-end run

```bash
anvil
# in a second terminal:
$env:PRIVATE_KEY = "0x..."  # use an Anvil account key printed at startup; never commit it
forge script script/DeployKubYieldDemo.s.sol:DeployKubYieldDemo --rpc-url http://127.0.0.1:8545 --broadcast
```

## Testnet demo deployment

```bash
$env:PRIVATE_KEY = "0x..."
forge script script/DeployKubYieldDemo.s.sol:DeployKubYieldDemo `
  --rpc-url https://rpc-testnet.kubchain.io --legacy --broadcast -vv
```

## Production deployment

Resolve the placeholder addresses in `script/DeployKubYield.s.sol` first:

```bash
forge script script/DeployKubYield.s.sol:DeployKubYield `
  --rpc-url https://rpc-testnet.kubchain.io --legacy --broadcast -vv
```

Verification:

```bash
forge verify-contract <ADDRESS> src/KubYieldVault.sol:KubYieldVault `
  --verifier blockscout --verifier-url https://testnet.kubscan.com/api `
  --rpc-url https://rpc-testnet.kubchain.io --legacy
```

## Roadmap

1. Diamond Finance strategy (claim → swap → restake) against a confirmed ABI
2. Mainnet vaults for KKUB/USDT and KUSDT/USDC LP pairs, verified on Kub Scan
3. Keeperless harvest bot and public TVL dashboard
4. Additional strategies (Kublerx, Ponder) behind the same `IStrategy` interface

## Grant milestones

- Testnet vaults deployed and verified
- Staked LP TVL and depositor count
- Harvests executed and compounded value
- Mainnet launch with Diamond Finance liquidity
