# KUB Contracts

A library of Solidity smart contracts implementing the **KAP token standards** and supporting access-control, KYC, and utility primitives for the [KUB](https://kubchain.com/) ecosystem.

## Overview

This repository provides reusable, abstract base contracts for building KAP-compliant tokens and applications on KUB:

- **KAP token standards** - fungible (KAP-20, KAP-22), non-fungible (KAP-721), and multi-token (KAP-1155) implementations.
- **Access control** — owner, committee, and project-router-based authorization models.
- **KYC integration** — hooks into KUB's on-chain KYC registry to enforce KYC-level requirements.
- **Utilities & libraries** — pausing, introspection (KAP-165), and gas-efficient enumerable data structures.

All contracts target Solidity `^0.8.0` and are released under the MIT license.

## Repository structure

```
contracts/
├── token/
│   ├── KAP-20/      Fungible token standard (ERC-20-like) with KYC + admin routing
│   ├── KAP-22/      Period/stamp-based fungible token with transfer routing & whitelist
│   ├── KAP-721/     Non-fungible token standard (ERC-721-like), enumerable + metadata
│   └── KAP-1155/    Multi-token standard (ERC-1155-like), enumerable + metadata
├── access/          Ownable, Committee, Authorization(KAP), AccessController(KAP)
├── kyc/             KYCHandler — KYC level enforcement against the KUB KYC registry
├── utils/           Pausable, Context, KAP-165 introspection
├── libs/            Address, String, EnumerableSet (uint/address), EnumerableMap
└── interfaces/      IAdminProjectRouter, IKYCBitkubChain
```

### Token standards

| Standard | Type | Description |
| --- | --- | --- |
| **KAP-20** | Fungible | ERC-20-style token integrated with KYC, the admin project router, committee control, and a transfer router. |
| **KAP-22** | Fungible | Period-based ("stamp") token tracking balances per period, with a transfer router and address whitelist. |
| **KAP-721** | Non-fungible | ERC-721-style NFT with enumerable and metadata extensions. |
| **KAP-1155** | Multi-token | ERC-1155-style token with enumerable and metadata extensions. |

### Access & KYC

- **Ownable / Committee** — single-owner and committee-governed roles.
- **Authorization / AuthorizationKAP** — permissioning via an `AdminProjectRouter`.
- **AccessController / AccessControllerKAP** — compose Ownable, Committee, Authorization, and KYCHandler, adding helpers such as `onlyOwnerOrCommittee` and transfer-router management.
- **KYCHandler** — stores the accepted KYC level and toggles whether only KYC-verified addresses may interact, validating against `IKYCBitkubChain`.

## Usage

These are abstract base contracts intended to be inherited and configured by your concrete token. For example, a KAP-20 token is constructed with its name, symbol, project name, decimals, and the addresses of the KYC registry, admin project router, committee, and transfer router, along with the accepted KYC level:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KAP20} from "./contracts/token/KAP-20/KAP20.sol";

contract MyToken is KAP20 {
    constructor(
        address kyc,
        address adminProjectRouter,
        address committee,
        address transferRouter
    )
        KAP20(
            "My Token",      // name
            "MTK",           // symbol
            "my-project",    // project name
            18,              // decimals
            kyc,
            adminProjectRouter,
            committee,
            transferRouter,
            4                // accepted KYC level
        )
    {}
}
```

Use the contracts as provided rather than copying and modifying them, so deployments stay consistent with the KAP standards and KUB's KYC and admin-routing requirements. For more information, visit [KUB Docs](https://docs.kubchain.com).

## Security

These contracts integrate with privileged roles (owner, committee, admin project router) and an external KYC registry. Configure those addresses carefully, and review the access-control wiring before deploying to mainnet. Using this code is not a substitute for an independent security audit.

## License

Released under the [MIT License](https://opensource.org/licenses/MIT).
