// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library LibCommon
{

    function assemblyHash(uint256 a, uint256 b) public pure returns (bytes32 hashedVal){
        //optimized
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            hashedVal := keccak256(0x00, 0x40)
        }
    }
}