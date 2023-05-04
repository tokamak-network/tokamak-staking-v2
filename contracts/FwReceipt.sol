// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./storages/FwReceiptStorage.sol";
import "./proxy/BaseProxyStorage.sol";
import "./common/AccessibleCommon.sol";
import {LibFastWithdraw} from "./libraries/LibFastWithdraw.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/BytesParserLib.sol";
import "./libraries/LibOperator.sol";
import "./libraries/LibOptimism.sol";
import "hardhat/console.sol";

interface L1CrossDomainMessangerI {
    function successfulMessages(bytes32 xDomainCalldataHash) external view returns (bool) ;
    function relayMessage(
            address _target,
            address _sender,
            bytes memory _message,
            uint256 _messageNonce
        )  external;
}

interface SequencerI {
    function getLayerInfo(uint32 _index)
        external view returns (LibOptimism.Info memory _layerInfo);

    function bridges(uint32 _index) external view returns (address, address);
    function balanceOf(uint32 _index, address account) external view returns (uint256 amount);
    function fastWithdrawClaim(bytes32 hashMessage, uint32 layerIndex, address from, address to, uint256 amount) external returns (bool);
    function fastWithdrawStake(bytes32 hashMessage, uint32 layerIndex, address staker, uint256 amount) external returns (bool);
}

interface CandidateI {
    function getCandidateInfo(uint32 _index) external view returns (LibOperator.Info memory info);
}

interface L1BridgeI {
    function finalizeERC20Withdrawal(
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data
    ) external;
}

interface FwReceiptI {
    function finalizeFastWithdraw(
        uint16 feeRate,
        uint32 deadline,
        uint32 layerIndex
    )
        external returns (uint8);
}

contract FwReceipt is AccessibleCommon, BaseProxyStorage, FwReceiptStorage {
    using SafeERC20 for IERC20;
    using BytesParserLib for bytes;

    /* ========== DEPENDENCIES ========== */
    event ProvidedLiquidity(bytes32 key, address provider, uint256 provideAmount, uint256 feeAmount, bool isCandidate, uint32 indexNo);
    event CanceledRequest(bytes32 key, address caller);
    // event InvalidMessageFastWithdrawal(bytes32 key, uint8 status);
    event NormalWithdrawal(bytes32 key, address from, address to, uint256 amount, uint8 status);
    event FinalizedFastWithdrawal(bytes32 key, address from, address to, uint256 providedAmount, uint256 feeAmount, bool isCandidate, uint32 indexNo);
    // event FailFinishFastWithdrawal(bytes32 key, address from, address to, uint256 providedAmount, uint256 feeAmount, uint8 status);
    // event AlreadyProcessed(bytes32 key, uint8 status);

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


    /* === ======= public ========== */

    function finalizeFastWithdraw(
        address requestor,
        uint256 requestAmount,
        uint32 deadline,
        uint16 feeRate,
        uint32 layerIndex,
        uint256 messageNonce,
        bytes32 hashMessage
        )
        external returns (uint8)
    {
        require(requestAmount != 0 && layerIndex != uint32(0), "Z1");
        require(validateHashMessage(
            requestor,
            requestAmount,
            feeRate,
            deadline,
            layerIndex,
            messageNonce,
            hashMessage
        ), "fail validateHashMessage");

        LibFastWithdraw.Message storage _message = messages[hashMessage];

        if (_message.status == uint8(LibFastWithdraw.STATUS.NONE) ){
            _message.status = uint8(LibFastWithdraw.STATUS.NORMAL_WITHDRAWAL);
            IERC20(wton).safeTransfer(requestor, requestAmount);
            emit NormalWithdrawal(hashMessage, requestor, requestor, requestAmount, _message.status);

        } else if (_message.status == uint8(LibFastWithdraw.STATUS.CANCELED)) {
            _message.status = uint8(LibFastWithdraw.STATUS.CANCEL_WITHDRAWAL);
            IERC20(wton).safeTransfer(requestor, requestAmount);
            emit NormalWithdrawal(hashMessage, requestor, requestor, requestAmount, _message.status);

        } else if (_message.status == uint8(LibFastWithdraw.STATUS.PROVIDE_LIQUIDITY)) {
            if (_message.data.length > 0 && _message.liquidities.length != 0) {

                LibFastWithdraw.Liquidity[] memory _liquidities = LibFastWithdraw.decodeLiquidities(_message.liquidities);
                uint256 len = _liquidities.length;
                uint256 sumOfProvidedOfSequencer = 0;
                uint256 sumOfProvidedOfCandidate = 0;
                address _requestor = requestor;
                uint256 _requestAmount = requestAmount;

                for (uint256 i = 0; i < len; i++) {
                    LibFastWithdraw.Liquidity memory _liquidity = _liquidities[i];
                    uint256 provideAmount = _liquidity.amount - (_liquidity.amount * feeRate / 10000);
                    uint256 fee = _liquidity.amount - provideAmount;
                    bool fwStake = false;
                    if (!_liquidity.isCandidate) {
                        sumOfProvidedOfSequencer += _liquidity.amount;
                        sumOfReceiptsOfSequencers[_liquidity.provider][_liquidity.indexNo] -= provideAmount;
                        fwStake = SequencerI(optimismSequencer).fastWithdrawStake(hashMessage, _liquidity.indexNo, _liquidity.provider, fee);

                    } else {
                        sumOfProvidedOfCandidate += _liquidity.amount;
                        sumOfReceiptsOfCandidates[_liquidity.provider][_liquidity.indexNo] -= provideAmount;
                        fwStake = SequencerI(candidate).fastWithdrawStake(hashMessage, _liquidity.indexNo, _liquidity.provider, fee);
                    }
                    deleteTxsOfProviders(_liquidity.provider, hashMessage);
                    require(fwStake, 'fail fwStake');
                    emit FinalizedFastWithdrawal(hashMessage, _liquidity.provider, _requestor, provideAmount, fee, _liquidity.isCandidate, _liquidity.indexNo);
                }

                _message.status = uint8(LibFastWithdraw.STATUS.FINALIZE_WITHDRAWAL);

                if (sumOfProvidedOfSequencer != 0) IERC20(wton).safeTransfer(optimismSequencer, sumOfProvidedOfSequencer);
                if (sumOfProvidedOfCandidate != 0) IERC20(wton).safeTransfer(candidate, sumOfProvidedOfCandidate);

                if ((sumOfProvidedOfSequencer + sumOfProvidedOfCandidate) < _requestAmount) {
                     IERC20(wton).safeTransfer(_requestor, _requestAmount-(sumOfProvidedOfSequencer + sumOfProvidedOfCandidate));
                     emit FinalizedFastWithdrawal(hashMessage, _requestor, _requestor, _requestAmount-(sumOfProvidedOfSequencer + sumOfProvidedOfCandidate), 0, false, 0);
                }

             } else {
                // emit InvalidMessageFastWithdrawal(hashMessage, uint8(LibFastWithdraw.STATUS.WRONG_MESSAGE));
                // return uint8(LibFastWithdraw.STATUS.WRONG_MESSAGE);
                require(false, "WRONG_MESSAGE");
            }
        } else {
            // emit AlreadyProcessed(hashMessage, uint8(LibFastWithdraw.STATUS.ALREADY_PROCESSED));
            // return uint8(LibFastWithdraw.STATUS.ALREADY_PROCESSED);
            require(false, "ALREADY_PROCESSED");
        }

        return _message.status;
    }

    function validateHashMessage(
        address requestor,
        uint256 amount,
        uint16 feeRate,
        uint32 deadline,
        uint32 layerIndex,
        uint256 messageNonce,
        bytes32 hashMessage
    ) public view returns(bool){

        LibOptimism.Info memory _layerInfo = SequencerI(optimismSequencer).getLayerInfo(layerIndex);

        bytes memory _l1BridgeMessage = abi.encodeWithSelector(
                L1BridgeI.finalizeERC20Withdrawal.selector,
                wton,
                _layerInfo.l2wton,
                requestor,
                address(this),
                amount,
                abi.encodePacked(feeRate, deadline, layerIndex)
            );

        bytes memory _message = abi.encodeWithSelector(
                L1CrossDomainMessangerI.relayMessage.selector,
                _layerInfo.l1Bridge,
                _layerInfo.l2Bridge,
                _l1BridgeMessage,
                messageNonce
            );

        return (keccak256(_message) == hashMessage);
    }

    function provideLiquidity(
        address requestor,
        uint256 requestAmount,
        uint256 provideAmount,
        uint32 deadline,
        bool isCandidate,
        uint32 indexNo,
        uint16 feeRate,
        uint32 layerIndex,
        uint256 messageNonce,
        bytes32 hashMessage
        )
        external nonZero(provideAmount)
    {
        require(validateHashMessage(
            requestor,
            requestAmount,
            feeRate,
            deadline,
            layerIndex,
            messageNonce,
            hashMessage
        ), "fail validateHashMessage");

        require(block.timestamp < deadline, "past deadline");

        if (!isCandidate) {
            require(layerIndex == indexNo, 'it is not same L2');
        } else {
            LibOperator.Info memory _candidateInfo = CandidateI(candidate).getCandidateInfo(indexNo);
            require(_candidateInfo.sequencerIndex  == layerIndex, 'it is not same L2');
        }

        LibFastWithdraw.Message storage _message = messages[hashMessage];
        require(requestor != msg.sender, "The requester and provider cannot be the same.");

        address _requestor = requestor;
        uint256 leftAmount = 0;
        if (_message.data.length == 0){
            require(_message.status == uint8(0), "already processed");
            _message.data = abi.encodePacked(_requestor, requestAmount, deadline, feeRate, layerIndex, messageNonce);
            _message.status = uint8(LibFastWithdraw.STATUS.PROVIDE_LIQUIDITY);
        } else {
            require(_message.status == uint8(LibFastWithdraw.STATUS.PROVIDE_LIQUIDITY), "already processed");
            leftAmount = requestAmount - LibFastWithdraw.totalLiquidity(_message.liquidities);
            require(leftAmount > 0, "zero leftAmount");
        }

        uint256 _provideAmount = provideAmount;
        if (leftAmount == 0) leftAmount = requestAmount;
        require(leftAmount >= _provideAmount, "leftAmount is insufficient");

        bool _isCandidate = isCandidate;
        uint32 _indexNo = indexNo;
        uint256 feeAmount = _provideAmount * feeRate / 10000;
        uint256 provideAmount1 = _provideAmount - feeAmount;
        require(provideAmount1 <= availableLiquidity(_isCandidate, _indexNo, msg.sender), "liquidity is insufficient.");

        if (_isCandidate) {
            require(SequencerI(candidate).fastWithdrawClaim(hashMessage, _indexNo, msg.sender, _requestor, provideAmount1),
                "fail fastWithdrawCalim ");
            sumOfReceiptsOfCandidates[msg.sender][_indexNo] += provideAmount1;
        } else {
            require(SequencerI(optimismSequencer).fastWithdrawClaim(hashMessage, _indexNo, msg.sender, _requestor, provideAmount1),
                 "fail fastWithdrawCalim ");
            sumOfReceiptsOfSequencers[msg.sender][_indexNo] += provideAmount1;
        }
        _message.liquidities = LibFastWithdraw.encodeLiquidity(
            LibFastWithdraw.Liquidity({
                provider: msg.sender,
                amount: _provideAmount,
                isCandidate: _isCandidate,
                indexNo: _indexNo
            })
        );
        txsOfProviders[msg.sender].push(hashMessage);
        emit ProvidedLiquidity(hashMessage, msg.sender, provideAmount1, feeAmount, _isCandidate, _indexNo);
    }

    function cancelRequest(
        address requestor,
        uint256 requestAmount,
        uint32 deadline,
        uint16 feeRate,
        uint32 layerIndex,
        uint256 messageNonce,
        bytes32 hashMessage) external
    {
        require(validateHashMessage(
            requestor,
            requestAmount,
            feeRate,
            deadline,
            layerIndex,
            messageNonce,
            hashMessage
        ), "fail validateHashMessage");

        require(block.timestamp < deadline, "past deadline");

        LibFastWithdraw.Message storage _message = messages[hashMessage];
        require(_message.status == uint8(0), "already processed");
        require(requestor == msg.sender, "caller is not requestor.");

        _message.status = uint8(LibFastWithdraw.STATUS.CANCELED);
        _message.data = abi.encodePacked(requestor, requestAmount, deadline, feeRate, layerIndex, messageNonce);

        emit CanceledRequest(hashMessage, msg.sender);
    }


    function availableLiquidity(bool isCandidate, uint32 layerIndex, address account) public view returns (uint256 amount) {
        if (isCandidate) {
            uint256 balance = SequencerI(candidate).balanceOf(layerIndex, account);
            if (balance > sumOfReceiptsOfCandidates[account][layerIndex]) {
                amount = balance - sumOfReceiptsOfCandidates[account][layerIndex];
            }
        } else {
            uint256 balance = SequencerI(optimismSequencer).balanceOf(layerIndex, account);
            if (balance > sumOfReceiptsOfSequencers[account][layerIndex]) {
                amount = balance - sumOfReceiptsOfSequencers[account][layerIndex];
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

    function debtInStaked(bool isCandidate, uint32 layerIndex, address account) external view returns (uint256) {
        if (isCandidate) return sumOfReceiptsOfCandidates[account][layerIndex];
        else  return sumOfReceiptsOfSequencers[account][layerIndex];
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