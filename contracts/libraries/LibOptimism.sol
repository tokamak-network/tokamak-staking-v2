// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

library LibOptimism
{
    struct Info {
        address addressManager;
        address l1Messenger;
        address l1Bridge;
        address l2ton;
    }

    function getKey(
        address addressManager,
        address l1Messenger,
        address l1Bridge,
        address l2ton
    ) external pure returns (bytes32 key_) {
        key_ = bytes32(keccak256(abi.encodePacked(addressManager, l1Messenger, l1Bridge, l2ton)));
    }


}