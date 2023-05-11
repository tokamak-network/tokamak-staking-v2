// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./BytesParserLib.sol";

// import "hardhat/console.sol";


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

    struct Request {
        address l1wton;
        address l2wton;
        address requestor;
        address fwReceipt;
        uint256 amount;
        uint16 feeRates;
        uint32 deadline;
        uint32 layerIndex;
    }

    struct FwRequestInfo {
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

    function decodeLiquidity (bytes memory data) public pure returns (Liquidity memory _liq) {
        if (data.length > 56) {
            _liq = Liquidity({
                provider : data.toAddress(0),
                amount : data.toUint256(20),
                isCandidate : (data.toUint8(52)==0?false:true),
                indexNo : data.toUint32(53)
            });
        }
    }

    function encodeLiquidity (Liquidity memory _data) public pure returns (bytes memory data) {
        data = abi.encodePacked(_data.provider, _data.amount, _data.isCandidate, _data.indexNo);
    }


    function totalLiquidity(bytes memory data) public pure returns (uint256 amount) {
        Liquidity[] memory _liquidities = decodeLiquidities (data);

        uint256 len = _liquidities.length;
        for(uint256 i = 0; i < len; i++){
            amount += _liquidities[i].amount;
        }
    }


    function decodeLiquidities (bytes memory data) public pure returns (Liquidity[] memory _liquidities) {
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

    function encodeLiquidities (Liquidity[] memory _datas) public pure returns (bytes memory data) {
        for (uint256 i = 0; i< _datas.length; i++){
            data = bytes.concat(data, encodeLiquidity(_datas[i]));
        }
    }


}