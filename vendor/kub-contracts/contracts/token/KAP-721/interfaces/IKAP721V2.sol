//SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface IKAP721V2 {
    function tokenOfOwnerByPage(
        address owner,
        uint256 page,
        uint256 limit
    ) external view returns (uint256[] memory);

    function tokenOfOwnerAll(address owner) external view returns (uint256[] memory);

    function adminApprove(address to, uint256 tokenId) external;

    function adminSetApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) external;
}