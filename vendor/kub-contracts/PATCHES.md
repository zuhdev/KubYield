# kub-contracts patches

Vendored from <https://github.com/kub-chain/kub-contracts> at commit
`7b41e886181d405c74303ae17df0539ff737bed6` (MIT license).

## AccessController.sol

Upstream does not compile with solc 0.8.x: `setKYC(address)` passes an `address`
to `_setKYC(IKYCBitkubChain)` without an explicit cast. Applied:

- added `import {IKYCBitkubChain} from "../interfaces/IKYCBitkubChain.sol";`
- changed `_setKYC(_kyc)` to `_setKYC(IKYCBitkubChain(_kyc))`.

Re-diff against upstream before upgrading this dependency.
