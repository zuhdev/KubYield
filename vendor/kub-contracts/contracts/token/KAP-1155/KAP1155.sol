// SPDX-License-Identifier: MIT
// Sources flattened with hardhat v2.5.0 https://hardhat.org

pragma solidity ^0.8.0;

import {KAP165, IKAP165} from "../../utils/introspections/KAP165.sol";
import {IAdminProjectRouter} from "../../interfaces/IAdminProjectRouter.sol";
import {IKYCBitkubChain} from "../../interfaces/IKYCBitkubChain.sol";
import {KYCHandler} from "../../kyc/KYCHandler.sol";
import {AuthorizationKAP} from "../../access/AuthorizationKAP.sol";
import {Pausable} from "../../utils/Pausable.sol";
import {IKAP1155} from "./interfaces/IKAP1155.sol";
import {IKAP1155Metadata} from "./interfaces/IKAP1155Metadata.sol";
import {IKAP1155Enumerable} from "./interfaces/IKAP1155Enumerable.sol";
import {IKAP1155Receiver} from "./interfaces/IKAP1155Receiver.sol";
import {Address} from "../../libs/Address.sol";
import {Strings} from "../../libs/String.sol";
import {EnumerableSetUint} from "../../libs/EnumerableSetUint.sol";

abstract contract KAP1155 is
    IKAP1155,
    IKAP1155Metadata,
    IKAP1155Enumerable,
    KAP165,
    AuthorizationKAP,
    KYCHandler,
    Pausable
{
    using Address for address;
    using Strings for uint256;

    // Token name
    string public override name;

    // Token symbol
    string public override symbol;

    // Base URI
    string public baseURI;

    // Base KAP URI
    string public baseKapURI;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) internal _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Mapping from ID to totalSupply
    mapping(uint256 => uint256) public totalSupplyById;

    // Mapping from ID to uri
    mapping(uint256 => string) private _tokenURIs;

    // Mapping for kap URIs
    mapping(uint256 => string) private _kapURIs;

    // Total supply
    uint256 public override totalSupply;

    constructor(
        string memory name_,
        string memory symbol_,
        address adminRouter_,
        address kyc_,
        address committee_,
        uint256 acceptedKycLevel_
    ) {
        name = name_;
        symbol = symbol_;
        adminRouter = IAdminProjectRouter(adminRouter_);
        kyc = IKYCBitkubChain(kyc_);
        committee = committee_;
        acceptedKYCLevel = acceptedKycLevel_;
    }

    function activateOnlyKYCAddress() public onlyCommittee {
        _activateOnlyKYCAddress();
    }

    function setKYC(IKYCBitkubChain _kyc) public onlyCommittee {
        _setKYC(_kyc);
    }

    function setAcceptedKYCLevel(uint256 _kycLevel) public onlyCommittee {
        _setAcceptedKYCLevel(_kycLevel);
    }

    function pause() public onlyCommittee {
        _pause();
    }

    function unpause() public onlyCommittee {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(KAP165, IKAP165) returns (bool) {
        return
            interfaceId == type(IKAP1155).interfaceId ||
            interfaceId == type(IKAP1155Metadata).interfaceId ||
            interfaceId == type(IKAP1155Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function exists(uint256 id) public view virtual returns (bool) {
        return totalSupplyById[id] > 0;
    }

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        require(totalSupplyById[tokenId] > 0, "KAP1155: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];

        // If there is no base URI, return the token URI.
        if (bytes(baseURI).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(baseURI, _tokenURI));
        }

        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    function kapURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(totalSupplyById[tokenId] > 0, "KAP1155: URI query for nonexistent token");

        string memory _kapURI = _kapURIs[tokenId];

        // If there is no base KAP URI, return the kapURI.
        if (bytes(baseKapURI).length == 0) {
            return _kapURI;
        }
        // If both are set, concatenate the base KAP URI and kapURI (via abi.encodePacked).
        if (bytes(_kapURI).length > 0) {
            return string(abi.encodePacked(baseKapURI, _kapURI));
        }

        // If there is a base KAP URI but no kapURI, concatenate the tokenID to the base KAP URI.
        return string(abi.encodePacked(baseKapURI, tokenId.toString()));
    }

    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "KAP1155: balance query for the zero address");
        return _balances[id][account];
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "KAP1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(msg.sender != operator, "KAP1155: setting approval status for self");

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function adminTransfer(
        address sender,
        address recipient,
        uint256 id,
        uint256 amount
    ) external override onlyCommittee {
        _safeTransferFrom(sender, recipient, id, amount, "");
    }

    function internalTransfer(
        address sender,
        address recipient,
        uint256 id,
        uint256 amount
    ) external override onlySuperAdminOrTransferRouter whenNotPaused returns (bool) {
        require(
            kyc.kycsLevel(sender) >= acceptedKYCLevel && kyc.kycsLevel(recipient) >= acceptedKYCLevel,
            "KAP1155: only internal purpose"
        );

        _safeTransferFrom(sender, recipient, id, amount, "");
        return true;
    }

    function externalTransfer(
        address sender,
        address recipient,
        uint256 id,
        uint256 amount
    ) external override onlySuperAdminOrTransferRouter whenNotPaused returns (bool) {
        require(kyc.kycsLevel(sender) >= acceptedKYCLevel, "KAP1155: only external purpose");

        _safeTransferFrom(sender, recipient, id, amount, "");
        return true;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override whenNotPaused {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "KAP1155: caller is not owner nor approved");
        _safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override whenNotPaused {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "KAP1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "KAP1155: transfer to the zero address");

        address operator = msg.sender;

        _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "KAP1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "KAP1155: ids and amounts length mismatch");
        require(to != address(0), "KAP1155: transfer to the zero address");

        address operator = msg.sender;

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "KAP1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(account != address(0), "KAP1155: mint to the zero address");

        address operator = msg.sender;

        _beforeTokenTransfer(operator, address(0), account, _asSingletonArray(id), _asSingletonArray(amount), data);

        _balances[id][account] += amount;
        totalSupply += amount;
        totalSupplyById[id] += amount;

        emit TransferSingle(operator, address(0), account, id, amount);

        _doSafeTransferAcceptanceCheck(operator, address(0), account, id, amount, data);
    }

    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "KAP1155: mint to the zero address");
        require(ids.length == amounts.length, "KAP1155: ids and amounts length mismatch");

        address operator = msg.sender;

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
            totalSupply += amounts[i];
            totalSupplyById[ids[i]] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    function _burn(
        address account,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(account != address(0), "KAP1155: burn from the zero address");

        address operator = msg.sender;

        _beforeTokenTransfer(operator, account, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");

        uint256 accountBalance = _balances[id][account];
        require(accountBalance >= amount, "KAP1155: burn amount exceeds balance");
        unchecked {
            _balances[id][account] = accountBalance - amount;
        }
        totalSupply -= amount;
        totalSupplyById[id] -= amount;

        if (totalSupplyById[id] == 0) {
            // Clear metadata (if any)
            if (bytes(_tokenURIs[id]).length != 0) {
                delete _tokenURIs[id];
            }

            // Clear metadata (if any)
            if (bytes(_kapURIs[id]).length != 0) {
                delete _kapURIs[id];
            }
        }

        emit TransferSingle(operator, account, address(0), id, amount);
    }

    function _burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(account != address(0), "KAP1155: burn from the zero address");
        require(ids.length == amounts.length, "KAP1155: ids and amounts length mismatch");

        address operator = msg.sender;

        _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 accountBalance = _balances[id][account];
            require(accountBalance >= amount, "KAP1155: burn amount exceeds balance");
            unchecked {
                _balances[id][account] = accountBalance - amount;
            }
            totalSupply -= amount;
            totalSupplyById[id] -= amount;

            if (totalSupplyById[id] == 0) {
                // Clear metadata (if any)
                if (bytes(_tokenURIs[id]).length != 0) {
                    delete _tokenURIs[id];
                }

                // Clear metadata (if any)
                if (bytes(_kapURIs[id]).length != 0) {
                    delete _kapURIs[id];
                }
            }
        }

        emit TransferBatch(operator, account, address(0), ids, amounts);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        if (to.isContract()) {
            try IKAP1155Receiver(to).onKAP1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IKAP1155Receiver.onKAP1155Received.selector) {
                    revert("KAP1155: KAP1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("KAP1155: transfer to non KAP1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        if (to.isContract()) {
            try IKAP1155Receiver(to).onKAP1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IKAP1155Receiver.onKAP1155BatchReceived.selector) {
                    revert("KAP1155: KAP1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("KAP1155: transfer to non KAP1155Receiver implementer");
            }
        }
    }

    function _setURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(totalSupplyById[tokenId] > 0, "KAP1155: URI query for nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function _setBaseURI(string memory _baseURI) internal virtual {
        baseURI = _baseURI;
    }

    function _setKapURI(uint256 tokenId, string memory _kapURI) internal virtual {
        require(totalSupplyById[tokenId] > 0, "KAP1155: URI query for nonexistent token");
        _kapURIs[tokenId] = _kapURI;
    }

    function _setBaseKapURI(string memory baseKapURI_) internal virtual {
        baseKapURI = baseKapURI_;
    }

    function _asSingletonArray(uint256 element) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}