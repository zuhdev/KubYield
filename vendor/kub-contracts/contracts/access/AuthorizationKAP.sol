// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAdminProjectRouter} from "../interfaces/IAdminProjectRouter.sol";

abstract contract AuthorizationKAP {
    IAdminProjectRouter public adminRouter;
    string public constant PROJECT = "kap-token";
    address public transferRouter;

    address public committee;

    event SetAdmin(address indexed oldAdmin, address indexed newAdmin, address indexed caller);
    event SetCommittee(address indexed oldCommittee, address indexed newCommittee, address indexed caller);

    modifier onlySuperAdmin() {
        require(adminRouter.isSuperAdmin(msg.sender, PROJECT), "Restricted only super admin");
        _;
    }

    modifier onlyAdmin() {
        require(adminRouter.isAdmin(msg.sender, PROJECT), "Restricted only admin");
        _;
    }

    modifier onlySuperAdminOrAdmin() {
        require(
            adminRouter.isSuperAdmin(msg.sender, PROJECT) || adminRouter.isAdmin(msg.sender, PROJECT),
            "Restricted only super admin or admin"
        );
        _;
    }

    modifier onlySuperAdminOrTransferRouter() {
        require(
            adminRouter.isSuperAdmin(msg.sender, PROJECT) || msg.sender == transferRouter,
            "Restricted only super admin ot transfer router"
        );
        _;
    }

    modifier onlyCommittee() {
        require(msg.sender == committee, "Restricted only committee");
        _;
    }

    function setAdmin(address _adminRouter) external onlySuperAdmin {
        emit SetAdmin(address(adminRouter), _adminRouter, msg.sender);
        adminRouter = IAdminProjectRouter(_adminRouter);
    }

    function setCommittee(address _committee) external onlyCommittee {
        emit SetCommittee(committee, _committee, msg.sender);
        committee = _committee;
    }

    function setTransferRouter(address _transferRouter) external onlySuperAdmin {
        transferRouter = _transferRouter;
    }
}