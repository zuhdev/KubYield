// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract TransferRouter {
    address public transferRouter;

    event TransferRouterSet(
        address indexed oldTransferRouter,
        address indexed newTransferRouter,
        address indexed caller
    );

    modifier onlyTransferRouter() {
        require(
            msg.sender == transferRouter,
            "TransferRouter: restricted only transferRouter"
        );
        _;
    }

    constructor(address transferRouter_) {
        transferRouter = transferRouter_;
    }

    function _setTransferRouter(address _transferRouter) internal virtual {
        emit TransferRouterSet(transferRouter, _transferRouter, msg.sender);
        transferRouter = _transferRouter;
    }
}