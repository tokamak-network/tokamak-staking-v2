// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

library Layer2
{
    struct Info {
        address addressManager;
        address l1Messenger;
        address l1Bridge;
        address l2ton;
    }

    struct Holdings {
        uint256 securityDeposit;    // ton unit
        uint256 seigs;              // ton unit
        bool bonding;
    }

    function get(
        mapping(bytes32 => Info) storage self,
        address addressManage,
        address l1Messenger,
        address l1Bridge,
        address l2ton
    ) internal view returns (Layer2.Info storage layer) {
        layer = self[keccak256(abi.encodePacked(addressManage, l1Messenger, l1Bridge, l2ton))];
    }

    function getWithLayerKey(
        mapping(bytes32 => Info) storage self,
        bytes32 layerKey
    ) internal view returns (Layer2.Info storage layer) {
        layer = self[layerKey];
    }
}