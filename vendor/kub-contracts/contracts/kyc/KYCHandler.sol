//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IKYCBitkubChain} from "../interfaces/IKYCBitkubChain.sol";

abstract contract KYCHandler {
    IKYCBitkubChain public kyc;

    uint256 public acceptedKYCLevel;
    bool public isActivatedOnlyKYCAddress;

    function _activateOnlyKYCAddress() internal virtual {
        isActivatedOnlyKYCAddress = true;
    }

    function _setKYC(IKYCBitkubChain _kyc) internal virtual {
        kyc = _kyc;
    }

    function _setAcceptedKYCLevel(uint256 _kycLevel) internal virtual {
        acceptedKYCLevel = _kycLevel;
    }
}
