// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IKAP1155Receiver {
    function onKAP1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    function onKAP1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}