// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IKAP1155Metadata {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function uri(uint256 tokenId) external view returns (string memory);

    function kapURI(uint256 tokenId) external view returns (string memory);
}