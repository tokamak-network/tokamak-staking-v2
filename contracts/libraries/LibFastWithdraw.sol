// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./BytesParserLib.sol";

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
    using BytesParserLib for bytes;

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
        INVALID_FUNC_SIG,
        UNSUPPORTED_VERSION
    }
    // uint32 layerIndex, uint256 amount
    uint256 private constant REQUEST_SIZE = 36;

    struct Request {
        address l1ton;
        address l2ton;
        address requestor;
        address fwReceipt;
        uint256 amount;
        uint16 feeRates;
        uint32 deadline;
        uint32 layerIndex;
    }

    struct Message {
        uint8 status;
        bytes data;
        bytes liquidities;
    }

    // liquidities : 1 byte length | 57 bytes |
    // 20+32+1+4 = 57 byte
    struct Liquidity {
        address provider;
        uint256 amount;
        bool isCandidate;
        uint32 indexNo;
    }

    function decodeLiquidity (bytes memory data) public view returns (Liquidity memory _liq) {
        if (data.length > 56) {
            _liq = Liquidity({
                provider : data.toAddress(0),
                amount : data.toUint256(20),
                isCandidate : (data.toUint8(52)==0?false:true),
                indexNo : data.toUint32(53)
            });
        }
    }

    function encodeLiquidity (Liquidity memory _data) public view returns (bytes memory data) {
        data = abi.encodePacked(_data.provider, _data.amount, _data.isCandidate, _data.indexNo);
    }

    function decodeLiquidities (bytes memory data) public view returns (Liquidity[] memory _liquidities) {
        uint256 _packetSize = 57;
        if (data.length > (_packetSize-1)) {
            uint256 _count = data.length / _packetSize;
            _liquidities = new Liquidity[](_count);
            for (uint256 i = 0 ; i < _count; i++) {
                uint256 startPos = i * _packetSize;
                _liquidities[i] = decodeLiquidity(data.slice(startPos, _packetSize));
            }
        }
    }

    function encodeLiquidities (Liquidity[] memory _datas) public view returns (bytes memory data) {
        for (uint256 i = 0; i< _datas.length; i++){
            data = bytes.concat(data, encodeLiquidity(_datas[i]));
        }
    }

    function parseL1BridgeFinalizeERC20Withdrawal(bytes memory data)
        public pure
        returns (uint8 status, Request memory _request)
    {
        if (data.length < 452) {
            status = uint8(STATUS.INVALID_LENGTH);

        } else if (bytes4(data.slice(0,4)) != IL1ERC20Bridge.finalizeERC20Withdrawal.selector) {
            status = uint8(STATUS.INVALID_FUNC_SIG);

        } else {
            (address l1ton, address l2ton, address requestor, address to, uint256 amount, bytes memory fwReceiptData) =
                abi.decode(data.slice(4, data.length-4),(address,address,address,address,uint256,bytes));

            if (amount == 0)   status = uint8(STATUS.ZERO_AMOUNT);
            else if (requestor == address(0))  status = uint8(STATUS.ZERO_REQUESTOR);
            else if (to == address(0) || l2ton == address(0) || l1ton == address(0))
                    status = uint8(STATUS.WRONG_MESSAGE);
            else if (fwReceiptData.length < 196)  status = uint8(STATUS.INVALID_LENGTH);
            else if (bytes4(fwReceiptData.slice(0,4)) != IFwReceipt.finalizeFastWithdraw.selector)
                status = uint8(STATUS.INVALID_FUNC_SIG);

            else if (status == uint8(0)){

                (
                    uint8 status_,
                    ,
                    address l2ton_,
                    address requestor_,
                    address fwReceipt_,
                    uint256 fwamount_,
                    uint16 feeRates_,
                    uint32 deadline_,
                    uint32 layerIndex_
                ) = parseFwReceiptBytes(abi.decode(fwReceiptData.slice(4, fwReceiptData.length-4),(bytes)));

                status = status_;

                _request = Request({
                    l1ton: l1ton,
                    l2ton: l2ton,
                    requestor: requestor,
                    fwReceipt: fwReceipt_,
                    amount: fwamount_,
                    feeRates: feeRates_,
                    deadline: deadline_,
                    layerIndex: layerIndex_
                });

            }
        }
        // console.log('status %s', status);
    }

    function parseFwReceiptBytes(bytes memory fwReceiptBytes)
        public pure
        returns (
                uint8 status,
                uint8 version,
                address l2ton,
                address requestor,
                address fwReceipt,
                uint256 fwamount,
                uint16 feeRates,
                uint32 deadline,
                uint32 layerIndex)
    {
        // 1+20+20+20+32+2+4+4 = 103
        //  ["uint8","address","address","address","uint256","uint16","uint32","uint32"],
        // [info.version, layerInfo.l2ton, info.requestor, fwReceiptContract, info.amount, info.feeRates, info.deadline, info.layerIndex]

        //103
        if (fwReceiptBytes.length < 103) {
            status = uint8(STATUS.INVALID_LENGTH);

        } else {
            version = fwReceiptBytes.toUint8(0);
            l2ton = fwReceiptBytes.toAddress(1);
            requestor = fwReceiptBytes.toAddress(21);
            fwReceipt = fwReceiptBytes.toAddress(41);
            fwamount = fwReceiptBytes.toUint256(61);
            feeRates = fwReceiptBytes.toUint16(93);
            deadline = fwReceiptBytes.toUint32(95);
            layerIndex = fwReceiptBytes.toUint32(99);
        }
    }

}