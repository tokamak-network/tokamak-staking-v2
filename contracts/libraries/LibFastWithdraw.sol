// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./BytesLib.sol";

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
        NOT_L1_BRIDGE,
        ZERO_AMOUNT,
        ZERO_REQUESTOR,
        WRONG_MESSAGE,
        FAIL_FINISH_FW,
        ETC
    }

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

    function parseTx(bytes memory data) public pure returns (Request memory info){
        bytes4 funcSig = 0xdddddddd;

        if (data.length > 65 && bytes4(data.slice(0,4)) == funcSig) {
            info = Request({
                requestor : data.toAddress(4),
                amount :  data.toUint256(24),
                feeRates: data.toUint16(56),
                deadline: data.toUint32(58),
                layerIndex: data.toUint32(62)
            });
         }
    }
}