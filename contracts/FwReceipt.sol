// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./storages/FwReceiptStorage.sol";
import "./proxy/BaseProxyStorage.sol";
import "./common/AccessibleCommon.sol";
import {LibFastWithdraw} from "./libraries/LibFastWithdraw.sol";
import "./libraries/SafeERC20.sol";

import "hardhat/console.sol";
interface SequencerI {
    function L1StandardBridge(uint32 _index) external view returns (address);
    function balanceOf(uint32 _index, address account) external view returns (uint256 amount);
    function fastWithdrawClaim(uint32 layerIndex, address from, address to, uint256 amount) external returns (bool);
    function fastWithdrawStake(uint32 layerIndex, address staker, uint256 amount) external returns (bool);
}

contract FwReceipt is AccessibleCommon, BaseProxyStorage, FwReceiptStorage {
    using SafeERC20 for IERC20;

    /* ========== DEPENDENCIES ========== */
    event ProvidedLiquidity(bytes32 key, bytes message, uint256 provideAmount, uint256 feeAmount);
    event CanceledRequest(bytes32 key, address caller);
    event InvalidMessageFastWithdrawal(bytes message, uint8 status);
    event NormalWithdrawal(bytes message, address from, address to, uint256 amount, uint8 status);
    event FinalizedFastWithdrawal(bytes message, address from, address to, uint256 providedAmount, uint256 feeAmount, uint8 status);
    event FailFinishFastWithdrawal(bytes message, address from, address to, uint256 providedAmount, uint256 feeAmount, uint8 status);
    event AlreadyProcessed(bytes message, uint8 status);

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */

    function setOptimismSequencer(address _optimismSequencer)
        external onlyOwner nonZeroAddress(_optimismSequencer)
    {
        require(optimismSequencer != _optimismSequencer, "same");
        optimismSequencer = _optimismSequencer;
    }

    function setCandidate(address _candidate)
        external onlyOwner nonZeroAddress(_candidate)
    {
        require(candidate != _candidate, "same");
        candidate = _candidate;
    }

    /* ========== onlySequencer ========== */

    function finalizeFastWithdraw(bytes memory _l2Messages)
        external  ifFree returns (uint8)
    {
        bytes32 key = keccak256(_l2Messages);
        (uint8 status,  , LibFastWithdraw.Request memory _request) = LibFastWithdraw.parseXDomainCalldata(_l2Messages);

        if (status != 0) {
            emit InvalidMessageFastWithdrawal(_l2Messages, status);
            return status;

        } else if (SequencerI(optimismSequencer).L1StandardBridge(_request.layerIndex) == address(0)) {
            status = uint8(LibFastWithdraw.STATUS.ZERO_L1_BRIDGE);
            emit  InvalidMessageFastWithdrawal(_l2Messages, status);
            return status;

        } else if (msg.sender == address(0) ||
            msg.sender != SequencerI(optimismSequencer).L1StandardBridge(_request.layerIndex)) {
            status = uint8(LibFastWithdraw.STATUS.CALLER_NOT_L1_BRIDGE);
            emit  InvalidMessageFastWithdrawal(_l2Messages, status);
            return status;
        }

        LibFastWithdraw.Message storage _message = messages[key];

        if (_message.status == uint8(LibFastWithdraw.STATUS.NONE) ){
            _message.status == uint8(LibFastWithdraw.STATUS.NORMAL_WITHDRAWAL);
            status = _message.status;
            IERC20(ton).safeTransfer(_request.requestor, _request.amount);
            emit NormalWithdrawal(_l2Messages, _request.requestor, _request.requestor, _request.amount, status);

        } else if (_message.status == uint8(LibFastWithdraw.STATUS.CANCELED)) {
            _message.status == uint8(LibFastWithdraw.STATUS.CANCEL_WITHDRAWAL);
            status = _message.status;
            IERC20(ton).safeTransfer(_request.requestor, _request.amount);
            emit NormalWithdrawal(_l2Messages, _request.requestor, _request.requestor, _request.amount, status);

        } else if (_message.status == uint8(LibFastWithdraw.STATUS.PROVIDE_LIQUIDITY)) {
            if (key == bytes32(keccak256(_message.data)) && _message.provider != address(0)) {

                uint256 provideAmount = _request.amount - (_request.amount * _request.feeRates / 10000);
                // bool result = SequencerI(optimismSequencer).fastWithdrawStake(_request.layerIndex, _message.provider, (
                //     _request.amount - provideAmount
                // ));

                // 여러곳에 보내게 될 때가 아니고 한 경우만 지원 하면..

                if (SequencerI(optimismSequencer).fastWithdrawStake(_request.layerIndex, _message.provider, (
                    _request.amount - provideAmount
                    ))) {
                    _message.status == uint8(LibFastWithdraw.STATUS.FINALIZE_WITHDRAWAL);
                    status = _message.status;
                    sumOfReceipts[_message.provider][_request.layerIndex] -= provideAmount;
                    deleteTxsOfProviders(_message.provider, key);
                    IERC20(ton).safeTransfer(optimismSequencer, _request.amount);
                    emit FinalizedFastWithdrawal(_l2Messages, _message.provider, _request.requestor, provideAmount, _request.amount - provideAmount, status);

                } else {
                    _message.status == uint8(LibFastWithdraw.STATUS.FAIL_FINISH_FW);
                    status = uint8(LibFastWithdraw.STATUS.FAIL_FINISH_FW);
                    emit FailFinishFastWithdrawal(_l2Messages, _message.provider, _request.requestor, provideAmount, _request.amount - provideAmount, status);
                }

            } else {
                status = uint8(LibFastWithdraw.STATUS.WRONG_MESSAGE);
                emit InvalidMessageFastWithdrawal(_l2Messages, status);
            }

        } else {
            status = uint8(LibFastWithdraw.STATUS.ALREADY_PROCESSED);
            emit AlreadyProcessed(_l2Messages, status);
        }

        return status;
    }


    /* ========== Anyone can execute ========== */
    function provideLiquidity(bytes calldata _l2Messages) external ifFree
    {
        (uint8 status, ,LibFastWithdraw.Request memory _request) = LibFastWithdraw.parseXDomainCalldata(_l2Messages);

        require(status == 0, "InvalidMessageFastWithdrawal");

        bytes32 key = bytes32(keccak256(_l2Messages));
        LibFastWithdraw.Message storage _message = messages[key];
        require(_request.requestor != msg.sender, "wrong requestor");

        // 여러번에 나누어서 할 수 있다면..
        require(_message.status == uint8(0) && _message.data.length == 0, "already provided");

        uint256 feeAmount = _request.amount * _request.feeRates / 10000;
        uint256 provideAmount = _request.amount - feeAmount;
        require(provideAmount > 0, "zero approveAmount");

        require(provideAmount <= availableLiquidity(_request.layerIndex, msg.sender), "liquidity is insufficient.");

        require(
            SequencerI(optimismSequencer).fastWithdrawClaim(_request.layerIndex, msg.sender, _request.requestor, provideAmount),
            "fail fastWithdrawCalim ");

        _message.status = uint8(LibFastWithdraw.STATUS.PROVIDE_LIQUIDITY);
        _message.data = _l2Messages;
        _message.provider = msg.sender;
        sumOfReceipts[msg.sender][_request.layerIndex] += provideAmount;
        txsOfProviders[msg.sender].push(key);
        emit ProvidedLiquidity(key, _l2Messages, provideAmount, feeAmount);
    }

    function cancelRequest(bytes calldata _l2Messages) external
    {
        (uint8 status, ,LibFastWithdraw.Request memory _request) = LibFastWithdraw.parseXDomainCalldata(_l2Messages);
        require(status == 0, "InvalidMessageFastWithdrawal");

        bytes32 key = bytes32(keccak256(_l2Messages));
        LibFastWithdraw.Message storage _message = messages[key];
        require(_message.status == uint8(0), "already processed");
        require(_request.requestor == msg.sender, "caller is not requestor.");

        _message.status = uint8(LibFastWithdraw.STATUS.CANCELED);
        _message.data = _l2Messages;

        emit CanceledRequest(key, msg.sender);
    }

    /* === ======= public ========== */

    function availableLiquidity(uint32 layerIndex, address account) public view returns (uint256 amount) {
        uint256 balance = SequencerI(optimismSequencer).balanceOf(layerIndex, account);
        if (balance > sumOfReceipts[account][layerIndex]) {
            amount = balance - sumOfReceipts[account][layerIndex];
        }
    }

    function includedTxsOfProvider(address account, bytes32 txIndex) public view returns (bool included) {
        uint256 len = txsOfProviders[account].length;

        for(uint256 i = 0; i < len; i++){
            if (txsOfProviders[account][i] == txIndex) {
                return true;
            }
        }
    }

    function debtForFastWithdraw(address account, uint32 layerIndex) external view returns (uint256) {
        return sumOfReceipts[account][layerIndex];
    }

    /* === ======= internal ========== */

    function deleteTxsOfProviders(address account, bytes32 txIndex) internal {
        uint256 len = txsOfProviders[account].length;

        for(uint256 i = 0; i < len; i++){
            if (txsOfProviders[account][i] == txIndex) {
                if(i < len-1) txsOfProviders[account][i] = txsOfProviders[account][len-1];
                txsOfProviders[account].pop();
                break;
            }
        }
    }

}