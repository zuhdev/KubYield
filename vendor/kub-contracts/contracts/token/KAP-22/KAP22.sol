// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import {IKAP20} from "../KAP-20/interfaces/IKAP20.sol";
import {IKAP22} from "./interfaces/IKAP22.sol";
import {IKToken} from "../KAP-20/interfaces/IKToken.sol";
import {TransferRouter} from "./utils/TransferRouter.sol";
import {IKYCBitkubChain} from "../../interfaces/IKYCBitkubChain.sol";
import {KYCHandler} from "../../kyc/KYCHandler.sol";
import {AccessControllerKAP} from "../../access/AccessControllerKAP.sol";
import {WhitelistAddress} from "./utils/WhitelistAddress.sol";
import {EnumerableSetAddress} from "../../libs/EnumerableSetAddress.sol";

abstract contract KAP22 is IKAP20, IKAP22, IKToken, AccessControllerKAP {
    mapping(address => mapping(uint256 => uint256)) private _balances; // owner => period => balance
    mapping(address => uint256) private _unStampBalance; // owner => balance
    mapping(address => mapping(address => uint256)) private _allowances; // owner => spender => amount

    string public override name;
    string public override symbol;
    uint8 public immutable override decimals;
    uint256 public override cap;
    uint256 public override totalSupply;
    uint256 public override currentIndex;
    uint256 public override startTime;
    uint256 public override periodLength;

    modifier updatePeriod() {
        _updatePeriod();
        _;
    }

    // constructor(
    //     // string memory name_,
    //     // string memory symbol_,
    //     // uint8 decimals_,
    //     address owner_,
    //     address vault_,
    //     address minter_,
    //     address burner_,
    //     address transferRouter_,
    //     address kyc_,
    //     uint256 acceptedKycLevel_,
    //     uint256 startTime_,
    //     uint256 periodLength_
    // ) AccessControllerKAP(owner_, vault_, minter_, burner_, transferRouter_, kyc_, acceptedKycLevel_) {
    //     name = "name_";
    //     symbol = "symbol_";
    //     decimals = 18;
    //     startTime = startTime_;
    //     periodLength = periodLength_;
    // }

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_,
        uint256 startTime_,
        uint256 periodLength_,
        uint256 cap_
    ) AccessControllerKAP(owner_, address(0), address(0), 4) {
        name = name_;
        symbol = symbol_;
        decimals = 18;
        startTime = startTime_;
        periodLength = periodLength_;
        cap = cap_;
    }

    function setCap(uint256 amount) external onlyOwner updatePeriod returns (bool) {
        require(cap <= amount, "KAP22: can't set less than older cap");

        cap = amount;

        return true;
    }

    function adminApprove(
    address _owner,
    address _spender,
    uint256 _amount
) external override onlyOwner returns (bool) {
    _approve(_owner, _spender, _amount);
    return true;
}

    function mint(uint256 amount, address receiver) external override onlyOwner updatePeriod returns (bool) {
        require(totalSupply + amount <= cap, "KAP22: cap exceeded");

        totalSupply += amount;

        _balances[receiver][currentIndex + 1] += amount;

        emit Mint(currentIndex, receiver, amount);

        return true;
    }

    function burn(
        uint256 period,
        uint256 amount,
        address _owner
    ) external override onlyOwner updatePeriod returns (bool) {
        // _totalSupply -= amount;

        // _balances[_owner][period] -= amount;

        // emit Burn(period, _owner, amount);

        return true;
    }

    function currentPeriod() external view override returns (uint256) {
        return _currentPeriod(currentIndex);
    }

    function balanceOf(address _owner) external view override returns (uint256 balance) {
        uint256 tmpBalances;
        uint256 tmpPeriod = _currentPeriod(currentIndex);

        if (isWhitelistAddr(_owner)) {
            for (uint256 i = 0; i <= tmpPeriod + 1; i++) {
                tmpBalances += _balances[_owner][i];
            }
        } else {
            tmpBalances += _balances[_owner][tmpPeriod];
            tmpBalances += _balances[_owner][tmpPeriod + 1];
        }

        return tmpBalances;
    }

    function balanceOfCurrentPeriod(address _owner) external view returns (uint256 balance) {
        uint256 tmpPeriod = _currentPeriod(currentIndex);

        return _balances[_owner][tmpPeriod];
    }

    function balanceOfNextPeriod(address _owner) external view returns (uint256 balance) {
        uint256 tmpPeriod = _currentPeriod(currentIndex);

        return _balances[_owner][tmpPeriod + 1];
    }

    function balanceOfByPeriod(address _owner, uint256 _period) external view returns (uint256 balance) {
        return _balances[_owner][_period];
    }

    function transfer(address _recipient, uint256 _amount) external override returns (bool) {
        if ((isWhitelistAddr(msg.sender) || msg.sender == owner) && isWhitelistAddr(_recipient)) {
            _transferPreviousPeriod(msg.sender, _recipient, _amount, 0);
        } else if (msg.sender == owner) {
            _transferSpecificPeriod(msg.sender, _recipient, _amount, currentIndex + 1);
        } else {
            _transfer(msg.sender, _recipient, _amount);
        }

        return true;
    }

    function allowance(address _owner, address _spender) external view override returns (uint256 remaining) {
        return _allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external override returns (bool) {
        uint256 currentAllowance = _allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "KAP22: transfer amount exceeds allowance");
        _approve(_sender, msg.sender, currentAllowance - _amount);

        if ((isWhitelistAddr(msg.sender) || msg.sender == owner) && isWhitelistAddr(_recipient)) {
            _transferPreviousPeriod(msg.sender, _recipient, _amount, 0);
        } else if (msg.sender == owner) {
            _transferSpecificPeriod(msg.sender, _recipient, _amount, currentIndex + 1);
        } else {
            _transfer(msg.sender, _recipient, _amount);
        }

        return true;
    }

    function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool) {
        _approve(msg.sender, _spender, _allowances[msg.sender][_spender] + _addedValue);
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, "KAP22: decreased allowance below zero");
        _approve(msg.sender, _spender, currentAllowance - _subtractedValue);

        return true;
    }

    function adminTransfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external override onlyOwner returns (bool) {
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function adminTransferPreviousPeriod(
        address _sender,
        address _recipient,
        uint256 _amount,
        uint256 _period
    ) external onlyOwner returns (bool) {
        _transferPreviousPeriod(_sender, _recipient, _amount, _period);
        return true;
    }

    function internalTransfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external override onlyTransferRouter returns (bool) {
        require(_isBitkubNext(_sender) && _isBitkubNext(_recipient), "KAP22: only internal purpose");

        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function externalTransfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external override onlyTransferRouter returns (bool) {
        require(_isBitkubNext(_sender), "KAP22: only internal purpose");

        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function updatePeriodNow() external {
        _updatePeriod();
    }

    function _updatePeriod() internal {
        while (block.timestamp > (currentIndex * periodLength) + startTime) {
            currentIndex++;
        }
    }

    function _currentPeriod(uint256 _period) internal view returns (uint256) {
        uint256 newCurrentPeriod = _period;

        while (block.timestamp > (newCurrentPeriod * periodLength) + startTime) {
            newCurrentPeriod++;
        }

        return newCurrentPeriod;
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal updatePeriod {
        require(_balances[_from][currentIndex] >= _amount, "KAP22: transfer amount exceeds balance");

        _balances[_from][currentIndex] -= _amount;
        _balances[_to][currentIndex] += _amount;

        emit Transfer(_from, _to, _amount);
    }

    function _transferSpecificPeriod(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _period
    ) internal updatePeriod {
        require(_balances[_from][_period] >= _amount, "KAP22: transfer amount exceeds balance");

        _balances[_from][_period] -= _amount;
        _balances[_to][_period] += _amount;

        emit Transfer(_from, _to, _amount);
    }

    function _transferNextPeriod(
        address _from,
        address _to,
        uint256 _amount
    ) internal updatePeriod {
        require(
            _balances[_from][currentIndex] + _balances[_from][currentIndex + 1] >= _amount,
            "KAP22: transfer amount exceeds balance"
        );

        if (_balances[_from][currentIndex] >= _amount) {
            _balances[_from][currentIndex] -= _amount;
            _balances[_to][currentIndex] += _amount;
        } else {
            uint256 balanceCurrentPeriod = _balances[_from][currentIndex];

            _balances[_from][currentIndex] = 0;
            _balances[_to][currentIndex] += balanceCurrentPeriod;

            _balances[_from][currentIndex + 1] -= _amount - balanceCurrentPeriod;
            _balances[_to][currentIndex + 1] += _amount - balanceCurrentPeriod;
        }

        emit Transfer(_from, _to, _amount);
    }

    function _transferPreviousPeriod(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _period
    ) internal updatePeriod {
        uint256 remainingToTransfer = _amount;
        for (uint256 i = _period; i <= currentIndex; i++) {
            uint256 amountToTransfer = _balances[_from][i];
            if (amountToTransfer > remainingToTransfer) {
                amountToTransfer = remainingToTransfer;
            }

            _balances[_from][i] -= amountToTransfer;
            _balances[_to][i] += amountToTransfer;

            remainingToTransfer -= amountToTransfer;

            if (remainingToTransfer == 0) {
                break;
            }
        }

        require(remainingToTransfer == 0, "KAP22: transfer amount exceeds balance");

        emit Transfer(_from, _to, _amount);
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal updatePeriod {
        require(_owner != address(0), "KAP22: approve from the zero address");
        require(_spender != address(0), "KAP22: approve to the zero address");

        _allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }
}