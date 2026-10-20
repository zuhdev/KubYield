// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IKAP165} from "./IKAP165.sol";

// Minimal KAP165 abstract
abstract contract KAP165 is IKAP165 {
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IKAP165).interfaceId;
    }
}
