// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface IKAP721Receiver {
    function onKAP721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}