// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./BytesLib.sol";

import "hardhat/console.sol";


interface IFwReceipt {
    function finalizeFastWithdraw(bytes memory _l2Messages)
        external returns (uint8);
}

interface IL1ERC20Bridge {
    function finalizeERC20Withdrawal(
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data
    ) external;
}

interface IL1CrossDomainMessenger {
    function relayMessage(
            address _target,
            address _sender,
            bytes memory _message,
            uint256 _messageNonce
        )  external;
}

library LibFastWithdraw
{
    using BytesLib for bytes;

    enum STATUS {
        NONE,
        CANCELED,
        PROVIDE_LIQUIDITY,
        NORMAL_WITHDRAWAL,
        CANCEL_WITHDRAWAL,
        FINALIZE_WITHDRAWAL,
        CALLER_NOT_L1_BRIDGE,
        ZERO_L1_BRIDGE,
        ZERO_AMOUNT,
        ZERO_REQUESTOR,
        INVALID_LAYERINDEX,
        INVALID_AMOUNT,
        PAST_DEADLINE,
        WRONG_MESSAGE,
        FAIL_FINISH_FW,
        ALREADY_PROCESSED,
        INVALID_LENGTH,
        INVALID_FUNC_SIG
    }
    // uint32 layerIndex, uint256 amount
    uint256 private constant REQUEST_SIZE = 36;

    struct Request {
        address requestor;
        uint256 amount;
        uint16 feeRates;
        uint32 deadline;
        uint32 layerIndex;
    }

    struct Message {
        uint8 status;
        address provider;
        bytes data;
    }

    // struct RequestAmount {
    //     uint32 layerIndex;
    //     uint256 amount;
    // }

    function parseRelayMessage(bytes memory relayMessageData)
        public pure returns (uint8 status, address l1Bridge, address l2Bridge, bytes memory finalizeERC20WithdrawalData) {

        // 206
        if (relayMessageData.length < 206) {
            status = uint8(STATUS.INVALID_LENGTH);

        } else if (bytes4(relayMessageData.slice(0,4)) != IL1CrossDomainMessenger.relayMessage.selector) {
            status = uint8(STATUS.INVALID_FUNC_SIG);

        } else {
            l1Bridge = relayMessageData.toAddress(4);
            l2Bridge = relayMessageData.toAddress(24);
            finalizeERC20WithdrawalData = relayMessageData.slice(44,relayMessageData.length-44);
        }
    }

    function parseFinalizeERC20Withdrawal(bytes memory finalizeERC20WithdrawalData)
        public pure
        returns (uint8 status,
                address l1ton,
                address l2ton,
                address requestor,
                address to,
                uint256 amount,
                bytes memory fwReceiptData)
    {

        // 130
        if (finalizeERC20WithdrawalData.length < 130) {
            status = uint8(STATUS.INVALID_LENGTH);

        } else if (bytes4(finalizeERC20WithdrawalData.slice(0,4)) != IL1ERC20Bridge.finalizeERC20Withdrawal.selector) {
            status = uint8(STATUS.INVALID_FUNC_SIG);

        } else {
            amount = finalizeERC20WithdrawalData.toUint256(84);
            requestor = finalizeERC20WithdrawalData.toAddress(44);
            l2ton = finalizeERC20WithdrawalData.toAddress(24);
            l1ton = finalizeERC20WithdrawalData.toAddress(4);
            to = finalizeERC20WithdrawalData.toAddress(64);

            if (amount == 0) {
                status = uint8(STATUS.ZERO_AMOUNT);

            } else if (requestor == address(0)) {
                status = uint8(STATUS.ZERO_REQUESTOR);

            } else if (to == address(0) || l2ton == address(0) || l1ton == address(0)) {
                status = uint8(STATUS.WRONG_MESSAGE);

            } else {
                fwReceiptData = finalizeERC20WithdrawalData.slice(116,finalizeERC20WithdrawalData.length-116);
            }
        }
    }

    function parseFwReceiptData(bytes memory fwReceiptData)
        public pure
        returns (uint8 status,
                uint16 feeRates,
                uint32 deadline,
                uint32 layerIndex)
    {
        //14
        if (fwReceiptData.length < 14) {
            status = uint8(STATUS.INVALID_LENGTH);

        } else if (bytes4(fwReceiptData.slice(0,4)) != IFwReceipt.finalizeFastWithdraw.selector) {
            status = uint8(STATUS.INVALID_FUNC_SIG);

        } else {
            feeRates = fwReceiptData.toUint16(4);
            deadline = fwReceiptData.toUint32(6);
            layerIndex = fwReceiptData.toUint32(10);
        }
    }
    /*
    function parseRequestAmount(bytes memory requestAmountData)
        public pure returns (RequestAmount[] memory info)
    {
        uint8 PACKET_LEN = 36;

        if (requestAmountData.length == 4) {
            info = new RequestAmount[](1);
            info[0] = RequestAmount({
                        layerIndex: requestAmountData.toUint32(0),
                        amount: 0
                    });

        } else {
            uint256 len = requestAmountData.length / PACKET_LEN;
            info = new RequestAmount[](len);
            for (uint256 i = 0; i < len; i++) {
                if (requestAmountData.length >= i*PACKET_LEN + PACKET_LEN) {
                    RequestAmount memory _r = parseRequestAmountSet(requestAmountData.slice(i*PACKET_LEN, PACKET_LEN));
                    if (_r.layerIndex != uint32(0)) info[i] =_r;
                } else {
                    break;
                }
            }
        }
    }

    function parseRequestAmountSet(bytes memory data)
        public pure returns (RequestAmount memory pack)
    {
        if (data.length == 36 ) {
            pack = RequestAmount({
                layerIndex: data.toUint32(0),
                amount: data.toUint256(4)
            });
        } else if (data.length > 3) {
            pack = RequestAmount({
                layerIndex: data.toUint32(0),
                amount: 0
            });
        }
    }
    */
    function parseXDomainCalldata(bytes memory xDomainCalldata)
        public pure
        returns (uint8 status, bytes32 xDomainCalldataHash, Request memory info)
    {
        xDomainCalldataHash = keccak256(xDomainCalldata);
        (uint8 status1_, , , bytes memory finalizeERC20WithdrawalData)
            = parseRelayMessage(xDomainCalldata);

        if (status1_ != 0) {
            status = status1_;

        } else {

            (   uint8 status2_,
                ,
                ,
                address requestor,
                ,
                uint256 amount,
                bytes memory fwReceiptData) = parseFinalizeERC20Withdrawal(finalizeERC20WithdrawalData);


            if (status2_ != 0) {
                status = status2_;

            } else {
                (   uint8 status3_,
                    uint16 feeRates,
                    uint32 deadline,
                    uint32 layerIndex) = parseFwReceiptData(fwReceiptData);

                if (status3_ != 0) {
                    status = status3_;

                } else if (layerIndex == 0) {
                    status = uint8(STATUS.INVALID_LAYERINDEX);

                } else {
                    info = Request({
                            requestor: requestor,
                            amount: amount,
                            feeRates: feeRates,
                            deadline: deadline,
                            layerIndex: layerIndex
                        });
                }
            }
        }
    }

    /*
    function parseTx(bytes memory data) public view returns (uint8 status, Request memory info){

        bytes4 funcSig = 0x3fb23df0; //finalizeFastWithdraw(bytes,uint256);

        if (data.length < 66) {
            status = uint8(STATUS.INVALID_LENGTH);

        } else if (data.length < 4 || bytes4(data.slice(0,4)) != funcSig) {
            status = uint8(STATUS.INVALID_FUNC_SIG);

        } else {
            info = Request({
                requestor : data.toAddress(4),
                amount :  data.toUint256(24),
                feeRates: data.toUint16(56),
                deadline: data.toUint32(58),
                layerIndex: data.toUint32(62)
            });

            if (info.layerIndex == uint32(0)) {
                status = uint8(STATUS.INVALID_LAYERINDEX);

            } else if (info.requestor == address(0)) {
                status = uint8(STATUS.ZERO_REQUESTOR);

            } else if (info.amount == 0) {
                status = uint8(STATUS.ZERO_AMOUNT);

            } else if (info.deadline < uint32(block.timestamp)) {
                status = uint8(STATUS.PAST_DEADLINE);
            }

        }
    }
    */
}