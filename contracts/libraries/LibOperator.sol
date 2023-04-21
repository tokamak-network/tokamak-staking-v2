// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./BytesParserLib.sol";

library LibOperator
{
    using BytesParserLib for bytes;
    struct Info {
        address operator;
        uint32 sequencerIndex;
        uint16 commission;  // denomitor 10000
    }

    function getKey(
        address operator,
        uint32 sequencerIndex
    ) external pure returns (bytes32 key_) {
        key_ = bytes32(keccak256(abi.encodePacked(operator, sequencerIndex)));
    }

    function parseKey(bytes memory data) public pure returns (Info memory info){
         if (data.length > 25) {
            info = Info({
                operator : data.toAddress(0),
                sequencerIndex : data.toUint32(20),
                commission : data.toUint16(24)
            });
         }
    }
}