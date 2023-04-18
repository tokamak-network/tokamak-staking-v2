// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./storages/FwReceiptStorage.sol";
import "./proxy/BaseProxyStorage.sol";
import "./common/AccessibleCommon.sol";
import {LibFastWithdraw} from "./libraries/LibFastWithdraw.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/BytesParserLib.sol";
import "./libraries/LibOperator.sol";

import "hardhat/console.sol";

interface L1CrossDomainMessangerI {
    function successfulMessages(bytes32 xDomainCalldataHash) external view returns (bool) ;
}

interface SequencerI {
    function L1StandardBridge(uint32 _index) external view returns (address);
    function balanceOf(uint32 _index, address account) external view returns (uint256 amount);
    function fastWithdrawClaim(uint32 layerIndex, address from, address to, uint256 amount) external returns (bool);
    function fastWithdrawStake(uint32 layerIndex, address staker, uint256 amount) external returns (bool);
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
    function finalizeFastWithdraw(bytes memory _l2Messages)
        external returns (uint8);
}

contract FwReceipt is AccessibleCommon, BaseProxyStorage, FwReceiptStorage {
    using SafeERC20 for IERC20;
    using BytesParserLib for bytes;

    /* ========== DEPENDENCIES ========== */
    event ProvidedLiquidity(bytes32 key, address provider, uint256 provideAmount, uint256 feeAmount, bool isCandidate, uint32 indexNo);
    event CanceledRequest(bytes32 key, address caller);
    event InvalidMessageFastWithdrawal(bytes32 key, uint8 status);
    event NormalWithdrawal(bytes32 key, address from, address to, uint256 amount, uint8 status);
    event FinalizedFastWithdrawal(bytes32 key, address from, address to, uint256 providedAmount, uint256 feeAmount, bool isCandidate, uint32 indexNo);
    // event FailFinishFastWithdrawal(bytes32 key, address from, address to, uint256 providedAmount, uint256 feeAmount, uint8 status);
    event AlreadyProcessed(bytes32 key, uint8 status);

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

    function getKey(uint8 ver, address l2ton, address requestor, uint256 amount, bytes memory _l2Messages)
        public view returns(bytes32)
    {
        return keccak256(abi.encodeWithSelector(
                L1BridgeI.finalizeERC20Withdrawal.selector,
                ton,
                l2ton,
                requestor,
                address(this),
                amount,
                abi.encodeWithSelector(FwReceiptI.finalizeFastWithdraw.selector, _l2Messages)
            ));
    }

    function finalizeFastWithdraw_Ver0(bytes memory _l2Messages) internal ifFree returns (uint8)
    {
        bytes memory _mm = abi.encodeWithSelector(FwReceiptI.finalizeFastWithdraw.selector, _l2Messages);

        (   uint8 status,
            ,
            address l2ton,
            address requestor,
            address fwReceipt,
            uint256 fwAmount,
            uint16 feeRates,
            ,
            uint32 layerIndex) =  LibFastWithdraw.parseFwReceiptBytes(_l2Messages);

        require(fwReceipt == address(this), "wrong fwReceipt");

        bytes memory _key = abi.encodeWithSelector(
                L1BridgeI.finalizeERC20Withdrawal.selector,
                ton,
                l2ton,
                requestor,
                address(this),
                fwAmount,
                _mm
            );

        bytes32 key = keccak256(_key);

        require(L1CrossDomainMessangerI(l1CrossDomainMessenger).successfulMessages(key), "It is not successful messages.");

        if (status != 0) {
            emit InvalidMessageFastWithdrawal(key, status);
            return status;
        }

        LibFastWithdraw.Message storage _message = messages[key];

        if (_message.status == uint8(LibFastWithdraw.STATUS.NONE) ){
            _message.status = uint8(LibFastWithdraw.STATUS.NORMAL_WITHDRAWAL);
            status = _message.status;
            IERC20(ton).safeTransfer(requestor, fwAmount);
            emit NormalWithdrawal(key, requestor, requestor, fwAmount, status);

        } else if (_message.status == uint8(LibFastWithdraw.STATUS.CANCELED)) {
            _message.status = uint8(LibFastWithdraw.STATUS.CANCEL_WITHDRAWAL);
            status = _message.status;
            IERC20(ton).safeTransfer(requestor, fwAmount);
            emit NormalWithdrawal(key, requestor, requestor, fwAmount, status);

        } else if (_message.status == uint8(LibFastWithdraw.STATUS.PROVIDE_LIQUIDITY)) {
            if (key == keccak256(_message.data) && _message.liquidities.length != 0) {
                // 한명이상, 유동성을 공급했을 경우,
                // 유동성을 공급한 사람에게 정산하고, 나머지 금액이 있다면 요청자에게 돌려준다.

                LibFastWithdraw.Liquidity[] memory _liquidities = LibFastWithdraw.decodeLiquidities(_message.liquidities);
                uint256 len = _liquidities.length;
                uint256 sumOfProvidedOfSequencer = 0;
                uint256 sumOfProvidedOfCandidate = 0;
                address _requestor = requestor;

                for (uint256 i = 0; i < len; i++) {
                    LibFastWithdraw.Liquidity memory _liquidity = _liquidities[i];

                    uint256 provideAmount = _liquidity.amount - (_liquidity.amount * feeRates / 10000);
                    uint256 fee = _liquidity.amount - provideAmount;
                    bool fwStake = false;
                    if (!_liquidity.isCandidate) {
                        sumOfProvidedOfSequencer += _liquidity.amount;
                        sumOfReceiptsOfSequencers[_liquidity.provider][_liquidity.indexNo] -= provideAmount;
                        fwStake = SequencerI(optimismSequencer).fastWithdrawStake(_liquidity.indexNo, _liquidity.provider, fee);

                    } else {
                        sumOfProvidedOfCandidate += _liquidity.amount;
                        sumOfReceiptsOfCandidates[_liquidity.provider][_liquidity.indexNo] -= provideAmount;
                        fwStake = SequencerI(candidate).fastWithdrawStake(_liquidity.indexNo, _liquidity.provider, fee);
                    }

                    deleteTxsOfProviders(_liquidity.provider, key);
                    require(fwStake, 'fail fwStake');
                    emit FinalizedFastWithdrawal(key, _liquidity.provider, _requestor, provideAmount, fee, _liquidity.isCandidate, _liquidity.indexNo);
                }

                _message.status = uint8(LibFastWithdraw.STATUS.FINALIZE_WITHDRAWAL);
                status = _message.status;

                if (sumOfProvidedOfSequencer != 0) IERC20(ton).safeTransfer(optimismSequencer, sumOfProvidedOfSequencer);
                if (sumOfProvidedOfCandidate != 0) IERC20(ton).safeTransfer(candidate, sumOfProvidedOfCandidate);

                if ((sumOfProvidedOfSequencer + sumOfProvidedOfCandidate) < fwAmount) {
                     IERC20(ton).safeTransfer(requestor, fwAmount-(sumOfProvidedOfSequencer + sumOfProvidedOfCandidate));
                     emit FinalizedFastWithdrawal(key, requestor, requestor, fwAmount-(sumOfProvidedOfSequencer + sumOfProvidedOfCandidate), 0, false, 0);
                }

             } else {
                status = uint8(LibFastWithdraw.STATUS.WRONG_MESSAGE);
                // uint8 status1 = status;
                emit InvalidMessageFastWithdrawal(key, status);
            }

        } else {
            status = uint8(LibFastWithdraw.STATUS.ALREADY_PROCESSED);
            // uint8 status1 = status;
            emit AlreadyProcessed(key, status);

        }

        return status;
    }

    function finalizeFastWithdraw(bytes memory _l2Messages)
        external returns (uint8)
    {
        if (_l2Messages.length > 1) {
            uint8 ver;
            assembly { ver := mload(add(_l2Messages, 1)) }
            if (ver == uint8(0)) {
                return finalizeFastWithdraw_Ver0(_l2Messages);
            }
        }

        return uint8(LibFastWithdraw.STATUS.UNSUPPORTED_VERSION);
    }


    /* ========== Anyone can execute ========== */
    function provideLiquidity(bool isCandidate, uint32 indexNo, bytes calldata _l2Messages) external ifFree
    {
        (uint8 status, LibFastWithdraw.Request memory _request)
            = LibFastWithdraw.parseL1BridgeFinalizeERC20Withdrawal(_l2Messages);

        require(status == 0, string(abi.encodePacked("InvalidMessageFastWithdrawal:",Strings.toHexString(status))));
        require(_request.fwReceipt == address(this), "wrong fwReceipt");
        require(_request.l1ton == ton, "It is not ton");
        require(block.timestamp < _request.deadline, "past deadline");

        bytes32 key = keccak256(_l2Messages);
        LibFastWithdraw.Message storage _message = messages[key];
        require(_request.requestor != msg.sender, "The requester and provider cannot be the same.");

        //
        if (!isCandidate) {
            require(_request.layerIndex == indexNo, 'it is not same L2');

        } else {
            LibOperator.Info memory _candidateInfo = CandidateI(candidate).getCandidateInfo(indexNo);
            require(_candidateInfo.sequencerIndex  == indexNo, 'it is not same L2');
        }

        // 여러번 나누어서 할 수 있다면 수정해야 한다.
        require(_message.status == uint8(0) && _message.data.length == 0, "already processed");

        uint256 feeAmount = _request.amount * _request.feeRates / 10000;
        uint256 provideAmount = _request.amount - feeAmount;
        require(provideAmount > 0, "zero approveAmount");

        require(provideAmount <= availableLiquidity(isCandidate, indexNo, msg.sender), "liquidity is insufficient.");

        bool fastWithdrawClaim = false;

        if (isCandidate) {
            fastWithdrawClaim = SequencerI(candidate).fastWithdrawClaim(indexNo, msg.sender, _request.requestor, provideAmount) ;
            sumOfReceiptsOfCandidates[msg.sender][indexNo] += provideAmount;
        } else {
            fastWithdrawClaim = SequencerI(optimismSequencer).fastWithdrawClaim(indexNo, msg.sender, _request.requestor, provideAmount) ;
            sumOfReceiptsOfSequencers[msg.sender][indexNo] += provideAmount;
        }
        require(fastWithdrawClaim, "fail fastWithdrawCalim ");

        emit ProvidedLiquidity(key, msg.sender, provideAmount, feeAmount, isCandidate, indexNo);

        _message.status = uint8(LibFastWithdraw.STATUS.PROVIDE_LIQUIDITY);
        _message.data = _l2Messages;
        _message.liquidities = LibFastWithdraw.encodeLiquidity(
            LibFastWithdraw.Liquidity({
                provider: msg.sender,
                amount: _request.amount,
                isCandidate: isCandidate,
                indexNo: indexNo
            })
        );
        txsOfProviders[msg.sender].push(key);
    }

    function cancelRequest(bytes calldata _l2Messages) external
    {
        (uint8 status, LibFastWithdraw.Request memory _request) = LibFastWithdraw.parseL1BridgeFinalizeERC20Withdrawal(_l2Messages);
        require(status == 0, "InvalidMessageFastWithdrawal");
        require(_request.fwReceipt == address(this), "wrong fwReceipt");
        require(_request.l1ton == ton, "It is not ton");
        require(block.timestamp < _request.deadline, "past deadline");

        bytes32 key = keccak256(_l2Messages);
        LibFastWithdraw.Message storage _message = messages[key];
        require(_message.status == uint8(0), "already processed");
        require(_request.requestor == msg.sender, "caller is not requestor.");

        _message.status = uint8(LibFastWithdraw.STATUS.CANCELED);
        _message.data = _l2Messages;

        emit CanceledRequest(key, msg.sender);
    }

    /* === ======= public ========== */

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