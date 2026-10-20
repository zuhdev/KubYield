// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {WhitelistAddress} from "../token/KAP-22/utils/WhitelistAddress.sol";
import {TransferRouter} from "../token/KAP-22/utils/TransferRouter.sol";
// import {KYCHandler} from "../kyc/KYCHandler.sol";
// import {IKYCBitkubChain} from "../interfaces/IKYCBitkubChain.sol";

interface IKYCBitkubChain {
    function kycsLevel(address _addr) external view returns (uint256);
}

abstract contract KYCHandler {
    event OnlyKYCAddressActivated(address indexed caller);
    event KYCSet(
        address indexed oldKYC,
        address indexed newKYC,
        address indexed caller
    );
    event AcceptedKYCLevelSet(
        uint256 indexed oldAcceptedKYCLevelSet,
        uint256 indexed newAcceptedKYCLevelSet,
        address indexed caller
    );

    IKYCBitkubChain public kyc;

    uint256 public acceptedKycLevel;
    bool public isActivatedOnlyKycAddress;

    modifier onlyBitkubNext(address bitkubNext_) {
        _onlyBitkubNext(bitkubNext_);
        _;
    }

    constructor(address kyc_, uint256 acceptedKycLevel_) {
        _setKyc(IKYCBitkubChain(kyc_));
        _setAcceptedKycLevel(acceptedKycLevel_);
    }

    function _activateOnlyKycAddress() internal virtual {
        isActivatedOnlyKycAddress = true;
        emit OnlyKYCAddressActivated(msg.sender);
    }

    function _setKyc(IKYCBitkubChain _kyc) internal virtual {
        emit KYCSet(address(kyc), address(_kyc), msg.sender);
        kyc = _kyc;
    }

    function _setAcceptedKycLevel(uint256 _kycLevel) internal virtual {
        emit AcceptedKYCLevelSet(acceptedKycLevel, _kycLevel, msg.sender);
        acceptedKycLevel = _kycLevel;
    }

    function _onlyBitkubNext(address bitkubNext_) internal view {
        require(
            _isBitkubNext(bitkubNext_),
            "KYCHandler: only Bitkub NEXT user"
        );
    }

    function _isBitkubNext(address bitkubNext_) internal view returns (bool) {
        return kyc.kycsLevel(bitkubNext_) >= acceptedKycLevel;
    }
}


abstract contract AccessControllerKAP is WhitelistAddress, TransferRouter, KYCHandler {
    address public owner;

    event OwnerSet(address indexed oldOwner, address indexed newOwner, address indexed caller);

    modifier onlyOwner() {
        require(msg.sender == owner, "AccessControllerKAP: restricted only owner");
        _;
    }

    constructor(
        address owner_,
        address transferRouter_,
        address kyc_,
        uint256 acceptedKycLevel_
    ) TransferRouter(transferRouter_) KYCHandler(kyc_, acceptedKycLevel_) {
        owner = owner_;
    }

    function setTransferRouter(address _transferRouter) public virtual {
        _setTransferRouter(_transferRouter);
    }

    function setKyc(IKYCBitkubChain _kyc) public virtual {
        _setKyc(_kyc);
    }

    function setAcceptedKycLevel(uint256 _kycLevel) public virtual {
        _setAcceptedKycLevel(_kycLevel);
    }

    function activateOnlyKycAddress() public virtual {
        _activateOnlyKycAddress();
    }

    function setOwner(address _owner) public virtual onlyOwner {
        emit OwnerSet(owner, _owner, msg.sender);
        owner = _owner;
    }

    function addWhitelistAddress(address _addr) public virtual override onlyOwner {
        WhitelistAddress.addWhitelistAddress(_addr);
    }

    function revokeWhitelistAddress(address _addr) public virtual override onlyOwner {
        WhitelistAddress.revokeWhitelistAddress(_addr);
    }
}