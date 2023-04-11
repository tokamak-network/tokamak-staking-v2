// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

// import "./BytesLib.sol";

library LibFastWithdraw
{
    // using BytesLib for bytes;
    enum STATUS {
        NONE,
        ZERO_AMOUNT,
        ZERO_FROM,
        FW_CALCULATE_SUCCESS,
        FAIL
    }

    struct Request {
        address from;
        address to;
        uint256 amount;
        uint32 feeRates;
        uint32 deadline;
    }

    struct Receipt {
        address from;
        address to;
        uint256 providedAmount;
        uint256 feeAmount;
        uint32 deadline;
        uint32 layerIndex;
    }


    function parseTx(bytes memory data) public view returns (Request memory info){
         if (data.length > 25) {
            info = Request({
                from : address(0),
                to :address(0),
                amount : 0,
                feeRates: 0,
                deadline: uint32(block.timestamp)
            });
         }
    }
}