// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {EnumerableSetAddress} from "../../../libs/EnumerableSetAddress.sol";

abstract contract WhitelistAddress {
    using EnumerableSetAddress for EnumerableSetAddress.AddressSet;

    EnumerableSetAddress.AddressSet private _whitelistAddr;

    function isWhitelistAddr(address _addr) public view returns (bool) {
        return _whitelistAddr.contains(_addr);
    }

    function whitelistAddrLength() external view returns (uint256) {
        return _whitelistAddr.length();
    }

    function whitelistAddrByIndex(uint256 _index) external view returns (address) {
        return _whitelistAddr.at(_index);
    }

    function whitelistAddrByPage(uint256 _page, uint256 _limit) external view returns (address[] memory) {
        return _whitelistAddr.get(_page, _limit);
    }

    function addWhitelistAddress(address _addr) public virtual {
        require(_addr != address(0) && _addr != address(this), "WhitelistAddress: invalid address");
        require(_whitelistAddr.add(_addr), "WhitelistAddress: address already exists");
    }

    function revokeWhitelistAddress(address _addr) public virtual {
        require(_whitelistAddr.remove(_addr), "WhitelistAddress: address does not exist");
    }
}