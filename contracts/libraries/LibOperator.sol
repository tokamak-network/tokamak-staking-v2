// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

library LibOperator
{
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

}