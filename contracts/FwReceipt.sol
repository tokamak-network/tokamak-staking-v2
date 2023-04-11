// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./storages/FwReceiptStorage.sol";
import "./proxy/BaseProxyStorage.sol";
import "./common/AccessibleCommon.sol";

interface SequencerI {
    function sequencer(uint32 _index) external view returns (address);
    function L1StandardBridge(uint32 _index) external view returns (address);

    function balanceOf(uint32 _index, address account) external view returns (uint256 amount);
    function fwStake(uint32 _index, address from, uint256 amount) external ;

}

contract FwReceipt is AccessibleCommon, BaseProxyStorage, FwReceiptStorage {

    /* ========== DEPENDENCIES ========== */

    event SetFWFee(address account, uint16 feeRate);
    event AddedReceipt(bytes32 txIndex, LibFastWithdraw.Request request, uint256 providedAmount, uint256 feeAmount);
    event CanceledReceipt(bytes32 txIndex, address from);
    // event CalculatedFastWithdrawal(bytes32 txIndex, LibFastWithdraw.Receipt receipt, uint8 status);
    event CalculatedFastWithdrawal(bytes32 txIndex, uint8 status);
    event ClaimedFastWithdrawal(bytes32 txIndex, address caller);

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

    /* ========== onlySequencer ========== */

    function calculateFastWithdraw(bytes32 txIndex, uint256 amount)
        external  returns (uint8 status)
    {
        if (amount == 0) {
            emit CalculatedFastWithdrawal(txIndex, uint8(LibFastWithdraw.STATUS.ZERO_AMOUNT));
            return uint8(LibFastWithdraw.STATUS.ZERO_AMOUNT);

        } else if (receipts[txIndex].from == address(0)) {
            emit CalculatedFastWithdrawal(txIndex, uint8(LibFastWithdraw.STATUS.ZERO_FROM));
            return uint8(LibFastWithdraw.STATUS.ZERO_FROM);

        } else {

            // 영수증이 존재함. 정산하자.
            LibFastWithdraw.Receipt storage _receipt = receipts[txIndex];
            require(msg.sender == SequencerI(optimismSequencer).L1StandardBridge(_receipt.layerIndex),
                "sender is not L1StandardBridge");

            require(amount == receipts[txIndex].providedAmount + _receipt.feeAmount,
                "wrong amount");

            // _receipt.providedAmount 이 금액이.. l2 사용자가 가져가는 금액
            sumOfReceipts[msg.sender] -= receipts[txIndex].providedAmount;
            // _receipt.feeAmount 이 금액이.. l1 사용자가 다시 스테이킹하는 금액
            SequencerI(optimismSequencer).fwStake(_receipt.layerIndex, receipts[txIndex].from, _receipt.feeAmount);

            // from의 영수증에서 삭제,
            deleteTxsOfProviders(_receipt.from, txIndex);
            status = uint8(LibFastWithdraw.STATUS.FW_CALCULATE_SUCCESS);

            // emit CalculatedFastWithdrawal(txIndex, _receipt, status);
            emit CalculatedFastWithdrawal(txIndex, status);

            // to 의 영수증에 없다면 영수증을 삭제.
            if(!includedTxsOfRequestor(receipts[txIndex].to, txIndex)) delete receipts[txIndex];
        }
    }


    /* ========== Anyone can execute ========== */

    function setFWFee(uint16 _feeRate) external nonZeroUint16(_feeRate) {
        require(_feeRate < 10000, "wrong fee");
        require(providersFeeRate[msg.sender] != _feeRate, "same fee");
        providersFeeRate[msg.sender] = _feeRate;

        emit SetFWFee(msg.sender, _feeRate);
    }


    function addReceipt(uint32 _layerIndex, bytes32 txIndex) external
    {
        require(receipts[txIndex].from == address(0), "already added");

        LibFastWithdraw.Request memory _request = getRequestFromL2TxIndex(txIndex);
        require(receipts[txIndex].from == msg.sender, "you are not provider");
        require(block.timestamp < _request.deadline, "past deadline");

        uint256 approveAmount = _request.amount - (_request.amount * _request.feeRates / 10000);

        // uint256 balance = SequencerI(optimismSequencer).balanceOf(_layerIndex, msg.sender);
        require((approveAmount + sumOfReceipts[msg.sender]) <= SequencerI(optimismSequencer).balanceOf(_layerIndex, msg.sender),
            "provided liquidity is insufficient.");

        LibFastWithdraw.Receipt storage _receipt = receipts[txIndex];
        _receipt.from = _request.from;
        _receipt.to = _request.to;
        _receipt.providedAmount = approveAmount;
        _receipt.feeAmount = _request.amount - approveAmount;
        _receipt.deadline = _request.deadline;

        sumOfReceipts[msg.sender] += approveAmount;
        txsOfProviders[msg.sender].push(txIndex);
        txsOfRequestors[_receipt.to].push(txIndex);

        emit AddedReceipt(txIndex, _request, _receipt.providedAmount, _receipt.feeAmount);
    }

    function cancelReceipt(bytes32 txIndex) external
    {
        // 영수증에 있는 경우,
        require(receipts[txIndex].from == msg.sender, "already added");

        // 아직 fw 가져가지 않은 경우,
        require(!includedTxsOfRequestor(receipts[txIndex].to, txIndex), "already withdrew");

        sumOfReceipts[msg.sender] -= receipts[txIndex].providedAmount;

        deleteTxsOfRequestor(receipts[txIndex].to, txIndex);
        deleteTxsOfProviders(receipts[txIndex].from, txIndex);

        delete receipts[txIndex];

        emit CanceledReceipt(txIndex, msg.sender);
    }

    function claimFastWithdraw(bytes32 txIndex) external
    {
        require(receipts[txIndex].to == msg.sender, "calller is not the requestor");

        // 이미 가져간경우, 리스트에 없다.
        require(includedTxsOfRequestor(receipts[txIndex].to, txIndex), "already claimed");

        deleteTxsOfRequestor(receipts[txIndex].to, txIndex);

        // from 의 영수증에 없다면 영수증을 삭제.
        if(!includedTxsOfProvider(receipts[txIndex].from, txIndex)) delete receipts[txIndex];

        emit ClaimedFastWithdrawal(txIndex, msg.sender);
    }


    function getRequestFromL2TxIndex(bytes32 txIndex) public view returns (LibFastWithdraw.Request memory ) {
        //LibFastWithdraw.getDataFromL2TxIndex(txIndex);
        // return bytes0x;
    }


    function includedTxsOfRequestor(address account, bytes32 txIndex) public view returns (bool included) {
        uint256 len = txsOfRequestors[account].length;

        for(uint256 i = 0; i < len; i++){
            if (txsOfRequestors[account][i] == txIndex) {
                return true;
            }
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

    function deleteTxsOfRequestor(address account, bytes32 txIndex) internal {
        uint256 len = txsOfRequestors[account].length;

        for(uint256 i = 0; i < len; i++){
            if (txsOfRequestors[account][i] == txIndex) {
                if(i < len-1) txsOfRequestors[account][i] = txsOfProviders[account][len-1];
                txsOfRequestors[account].pop();
                break;
            }
        }
    }

}