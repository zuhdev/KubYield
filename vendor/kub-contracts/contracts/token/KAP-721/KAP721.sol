// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {AccessController} from "../../access/AccessController.sol";
import {Pausable} from "../../utils/Pausable.sol";
import {IKAP721} from "./interfaces/IKAP721.sol";
import {IKAP721V2} from "./interfaces/IKAP721V2.sol";
import {IKAP721Metadata} from "./interfaces/IKAP721Metadata.sol";
import {IKAP721Enumerable} from "./interfaces/IKAP721Enumerable.sol";
import {KAP165, IKAP165} from "../../utils/introspections/KAP165.sol";
import {IKYCBitkubChain} from "../../interfaces/IKYCBitkubChain.sol";
import {IAdminProjectRouter} from "../../interfaces/IAdminProjectRouter.sol";
import {Address} from "../../libs/Address.sol";
import {Strings} from "../../libs/String.sol";
import {EnumerableSetUint} from "../../libs/EnumerableSetUint.sol";
import {EnumerableMap} from "../../libs/EnumerateMap.sol";
import {IKAP721Receiver} from "./interfaces/IKAP721Receiver.sol";

abstract contract KAP721 is KAP165, IKAP721, IKAP721V2, IKAP721Metadata, IKAP721Enumerable, AccessController, Pausable {
    using Address for address;
    using EnumerableSetUint for EnumerableSetUint.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Strings for uint256;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping(address => EnumerableSetUint.UintSet) _holderTokens;

    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Token name
    string public override name;

    // Token symbol
    string public override symbol;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    // Base URI
    string public baseURI;

    /*
     *     bytes4(keccak256('balanceOf(address)')) == 0x70a08231
     *     bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
     *     bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
     *     bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c5 ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        string memory _projectName,
        address _kyc,
        address _adminProjectRouter,
        address _committee,
        address _transferRouter,
        uint256 _acceptedKYCLevel
    ) {
        name = _name;
        symbol = _symbol;
        baseURI = _baseURI;
        PROJECT = _projectName;
        kyc = IKYCBitkubChain(_kyc);
        adminProjectRouter = IAdminProjectRouter(_adminProjectRouter);
        committee = _committee;
        transferRouter = _transferRouter;
        acceptedKYCLevel = _acceptedKYCLevel;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(KAP165, IKAP165) returns (bool) {
        return
            interfaceId == _INTERFACE_ID_ERC721 ||
            interfaceId == type(IKAP721).interfaceId ||
            interfaceId == type(IKAP721Metadata).interfaceId ||
            interfaceId == type(IKAP721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "KAP721: balance query for the zero address");
        return _holderTokens[owner].length();
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        return _tokenOwners.get(tokenId, "KAP721: owner query for nonexistent token");
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "KAP721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = baseURI;

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    function tokenOfOwnerByPage(
        address _owner,
        uint256 _page,
        uint256 _limit
    ) public view virtual override returns (uint256[] memory) {
        return _holderTokens[_owner].get(_page, _limit);
    }

    function tokenOfOwnerAll(address _owner) public view virtual override returns (uint256[] memory) {
        return _holderTokens[_owner].getAll();
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        return _holderTokens[owner].at(index);
    }

    function totalSupply() public view virtual override returns (uint256) {
        // _tokenOwners are indexed by tokenIds, so .length() returns the number of tokenIds
        return _tokenOwners.length();
    }

    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        (uint256 tokenId, ) = _tokenOwners.at(index);
        return tokenId;
    }

    function approve(address to, uint256 tokenId) public virtual override whenNotPaused {
        address owner = KAP721.ownerOf(tokenId);
        require(to != owner, "KAP721: approval to current owner");

        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "KAP721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function adminApprove(address to, uint256 tokenId) public virtual override onlySuperAdmin whenNotPaused {
        address owner = ownerOf(tokenId);
        require(to != owner, "KAP721: approval to current owner");

        require(
            kyc.kycsLevel(owner) >= acceptedKYCLevel && (to == address(0) || kyc.kycsLevel(to) >= acceptedKYCLevel),
            "KAP721: owner or to address is not a KYC user"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "KAP721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual override whenNotPaused {
        require(operator != msg.sender, "KAP721: approve to caller");

        _setApprovalForAll(msg.sender, operator, approved);
    }

    function adminSetApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) public virtual override onlySuperAdmin whenNotPaused {
        require(operator != owner, "KAP721: approve to caller");

        require(
            kyc.kycsLevel(owner) >= acceptedKYCLevel && kyc.kycsLevel(operator) >= acceptedKYCLevel,
            "KAP721: owner or operator address is not a KYC user"
        );

        _setApprovalForAll(owner, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override whenNotPaused {
        require(_isApprovedOrOwner(msg.sender, tokenId), "KAP721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    function adminTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) public virtual override onlyCommittee {
        if (isActivatedOnlyKYCAddress) {
            require(kyc.kycsLevel(_from) > 0 && kyc.kycsLevel(_to) > 0, "KAP721: only internal purpose");
        }
        require(ownerOf(_tokenId) == _from, "KAP721: transfer of token that is not own"); // internal owner

        // Clear approvals from the previous owner
        _approve(address(0), _tokenId);

        _holderTokens[_from].remove(_tokenId);
        _holderTokens[_to].add(_tokenId);

        _tokenOwners.set(_tokenId, _to);

        emit Transfer(_from, _to, _tokenId);
    }

    function internalTransfer(
        address sender,
        address recipient,
        uint256 tokenId
    ) external override onlySuperAdminOrTransferRouter whenNotPaused returns (bool) {
        require(
            kyc.kycsLevel(sender) >= acceptedKYCLevel && kyc.kycsLevel(recipient) >= acceptedKYCLevel,
            "KAP721: only internal purpose"
        );

        _transfer(sender, recipient, tokenId);
        return true;
    }

    function externalTransfer(
        address sender,
        address recipient,
        uint256 tokenId
    ) external override onlySuperAdminOrTransferRouter whenNotPaused returns (bool) {
        require(kyc.kycsLevel(sender) >= acceptedKYCLevel, "KAP721: only internal purpose");

        _transfer(sender, recipient, tokenId);
        return true;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override whenNotPaused {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override whenNotPaused {
        require(_isApprovedOrOwner(msg.sender, tokenId), "KAP721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnKAP721Received(from, to, tokenId, _data), "KAP721: transfer to non KAP721Receiver implementer");
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _tokenOwners.contains(tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "KAP721: operator query for nonexistent token");
        address owner = KAP721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnKAP721Received(address(0), to, tokenId, _data),
            "KAP721: transfer to non KAP721Receiver implementer"
        );
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "KAP721: mint to the zero address");
        require(!_exists(tokenId), "KAP721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual {
        address owner = ownerOf(tokenId); // internal owner

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _holderTokens[owner].remove(tokenId);
        _holderTokens[address(0)].add(tokenId);

        _tokenOwners.set(tokenId, address(0));

        emit Transfer(owner, address(0), tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(KAP721.ownerOf(tokenId) == from, "KAP721: transfer of token that is not own");
        require(to != address(0), "KAP721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(from, to, tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "KAP721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function _setBaseURI(string memory baseURI_) internal virtual {
        baseURI = baseURI_;
    }

    function _checkOnKAP721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IKAP721Receiver(to).onKAP721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IKAP721Receiver.onKAP721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("KAP721: transfer to non KAP721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(KAP721.ownerOf(tokenId), to, tokenId);
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}
