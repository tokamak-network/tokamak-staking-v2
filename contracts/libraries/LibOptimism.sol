// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./BytesLib.sol";

library LibOptimism
{
    using BytesLib for bytes;

    struct Info {
        address addressManager;
        // address l1Messenger;
        // address l1Bridge;
        address l2ton;
    }

    function getKey(
        address addressManager,
        // address l1Messenger,
        // address l1Bridge,
        address l2ton
    ) external pure returns (bytes32 key_) {
        key_ = bytes32(keccak256(abi.encodePacked(addressManager, l2ton)));
    }

    function parseKey(bytes memory data) public pure returns (Info memory info){
         if (data.length > 39) {
            info = Info({
                addressManager : data.toAddress(0),
                // l1Messenger : data.toAddress(20),
                // l1Bridge : data.toAddress(40),
                l2ton : data.toAddress(20)
            });
         }
    }
}