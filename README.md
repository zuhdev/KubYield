# KubYield

Auto-compounding yield vaults for KUB Chain DEX liquidity providers. Depositors
receive KAP-20 receipt shares; anyone can harvest, and the caller earns a fee.

Whitepaper: [WHITEPAPER.md](WHITEPAPER.md)

KUB Builder Grant category: **Other Liquidity Growth dApps** (max $30,000).

## Architecture

- `KubYieldVault` - ERC-4626-style vault: deposits, withdrawals, share pricing,
  strategy accounting, and permissionless harvests.
- `KubYieldShares` - KAP-20 receipt token. The vault is bound once by the owner
  and is the only address allowed to mint or burn.
- `IStrategy` - strategy hook used by the vault (`invest`, `divest`,
  `totalAssets`, `harvest`).
- `SmartChefLpStrategy` - stakes Diamon LP in a SmartChefV2 farm, claims the
  reward token, swaps it into both LP tokens, adds liquidity, and restakes.
- The earlier `KubYieldStrategy` draft was removed because it assumed an
  unverified Diamon staking ABI. `SmartChefLpStrategy` is implemented against
  the verified live SmartChefV2 interface.

### Design decisions

- Share math uses OpenZeppelin's virtual-share offset, making the classic
  first-depositor inflation attack unprofitable.
- `SafeERC20` and `ReentrancyGuard` guard all asset flows; state is updated
  before external calls (checks-effects-interactions).
- Harvest is permissionless: any caller receives `HARVEST_FEE_BPS` (5%) of the
  yield, so compounding needs no keeper infrastructure or privileged key.
- Withdrawals are never paused by the vault; only deposits, harvests, and
  investments pause. The external farm can still pause withdrawals of staked LP.
- A strategy can only be replaced while it holds no LP assets.
- `SmartChefLpStrategy` accepts only the vault as caller and applies an
  immutable maximum slippage to reward swaps and liquidity addition.
- Custom errors instead of revert strings, pinned Solidity 0.8.24, optimizer on.

## KUB Chain specifics

- `evm_version = "paris"` (no PUSH0), `--legacy` transactions (no EIP-1559)
- Chain ID: 25925 testnet / 96 mainnet
- Testnet RPC: `https://rpc-testnet.kubchain.io`
- Mainnet RPC: `https://rpc.kubchain.io`
- Explorer: `https://kubscan.com` (Blockscout, 12 req/min)
- Faucet: `https://faucet.kubchain.com`

Confirmed mainnet addresses:

| Contract | Address |
|----------|---------|
| Diamon router | `0xAb30a29168D792c5e6a54E4bcF1Aec926a3b20FA` |
| Diamon factory | `0x6E906Dc4749642a456907deCB323A0065dC6F26E` |
| KUSDT/LUMI Diamon LP | `0x7Bf51541208A70b784006eF7Bd6F774F4012Cd38` |
| SmartChefV2 `Tomato-LKUSDT V2` | `0xd6693F73C0eC5EA56A6C25CE37Ad58820485794a` |
| TOMATO reward | `0x9Ea7E0435B5E50e1DCBB8Eacd63F0dbD3003BdAA` |
| KUSDT | `0x7d984C24d2499D840eB3b7016077164e15E5faA6` |
| LUMI | `0x95013Dcb6A561e6C003AED9C43Fb8B64008aA361` |

Confirmed testnet KAP-20 tokens:

| Token | Address |
|-------|---------|
| KKUB | `0x1de8A5c87d421f53eE4ae398cc766e62E88e9518` |
| USDT | `0x4de09F9E7282C1E66ED13ed930942E7fAb9915E9` |

## Strategy

The first live strategy targets KUSDT/LUMI Diamon LP:

1. `invest` pulls LP from the vault and deposits it into the SmartChefV2 farm.
2. `harvest` calls the farm, receives TOMATO (the farm keeps a 1% claim fee),
   swaps TOMATO into KUSDT and LUMI, adds liquidity, and restakes the new LP.
3. `divest` withdraws LP from the farm and returns it to the vault.

`totalAssets` counts idle LP plus staked LP. Pending farm rewards are not counted
until a harvest realizes them. The strategy uses a 3% maximum slippage default
and reverts rather than accepting a worse quote.

The only live Diamon LP farms were found on the third-party Moon Village
SmartChefV2 deployment, not on an official Diamon farm. TOMATO reward liquidity
is thin, so harvests can revert or realize a low value for large reward amounts.
The farm can also pause deposits and withdrawals. These are known risks, not
guarantees of yield.

A live mainnet-fork test deposited 1,000 LP, advanced 1,000 blocks, and harvested
about 2.316 TOMATO into about 0.2355 new LP. It confirms that claim, swap,
add-liquidity, and restake work for a newly deployed strategy address.

## Development

```bash
forge install OpenZeppelin/openzeppelin-contracts foundry-rs/forge-std
forge build
forge test
```

The test suite has 38 deterministic Foundry tests, including mock AMM/router/farm
coverage for the strategy and the existing vault accounting tests. An additional
mainnet-fork test is opt-in:

```powershell
$env:RUN_KUB_FORK = "1"
forge test --match-path test/ForkSmartChef.t.sol -vv
```

It forks KUB mainnet, deposits 1,000 KUSDT/LUMI LP, advances 1,000 blocks,
harvests, and checks that the strategy compounds rewards.

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

Deploy the vault and shares first. The KYC registry, admin project router,
committee, transfer router, and Diamon LP address are supplied as environment
variables:

```bash
$env:PRIVATE_KEY = "0x..."
$env:KYC_REGISTRY = "0x..."
$env:ADMIN_PROJECT_ROUTER = "0x..."
$env:COMMITTEE = "0x..."
$env:TRANSFER_ROUTER = "0x..."
$env:DIAMON_LP = "0x7Bf51541208A70b784006eF7Bd6F774F4012Cd38"
forge script script/DeployKubYield.s.sol:DeployKubYield `
  --rpc-url https://rpc.kubchain.io --legacy --broadcast -vv
```

Deploy the strategy against the resulting vault, then attach it:

```bash
$env:PRIVATE_KEY = "0x..."
$env:VAULT_ADDRESS = "0x..."
forge script script/DeploySmartChefLpStrategy.s.sol:DeploySmartChefLpStrategy `
  --rpc-url https://rpc.kubchain.io --legacy --broadcast -vv

$env:STRATEGY_ADDRESS = "0x..."
cast send $env:VAULT_ADDRESS "setStrategy(address)" $env:STRATEGY_ADDRESS `
  --rpc-url https://rpc.kubchain.io --legacy --private-key $env:PRIVATE_KEY
```

Verification:

```bash
forge verify-contract <ADDRESS> src/KubYieldVault.sol:KubYieldVault `
  --verifier blockscout --verifier-url https://kubscan.com/api `
  --rpc-url https://rpc.kubchain.io --legacy
```

## Roadmap

1. Deploy and verify the vault, shares, and SmartChef LP strategy on KUB testnet;
   run a small live harvest and monitor reward liquidity.
2. Mainnet launch for KUSDT/LUMI Diamon LP with verified contracts and public
   TVL/yield reporting.
3. Keeperless harvest bot and public TVL dashboard.
4. Additional strategies (Kublerx, Ponder) behind the same `IStrategy` interface.

## Grant milestones

1. Mainnet launch with Diamond Finance vaults, verified contracts, and DEX
   listings; 150+ UAW and $25,000 TVL in the first four weeks
2. Strategies for Kublerx and Ponder plus KUB Wallet / Bitkub NEXT deposits;
   500+ cumulative UAW and $100,000 TVL
3. Independent audit, strategy migration tooling, and zapper deposits;
   1,500+ cumulative UAW and $250,000 TVL
4. Referral and partner program plus institutional onboarding;
   3,000+ cumulative UAW and $500,000 TVL
