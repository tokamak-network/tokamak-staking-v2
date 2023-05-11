// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LibFastWithdraw} from "../libraries/LibFastWithdraw.sol";

contract FwReceiptStorage {

    address public ton;
    address public seigManagerV2;
    address public optimismSequencer;
    address public candidate;

    /// hashMessage keccak256(_l2Messages)
    mapping(bytes32 => LibFastWithdraw.Message) public messages;

    /// account - layerIndex - sum of providing liquidity
    mapping(address => mapping(uint32 => uint256)) sumOfReceiptsOfSequencers;
    mapping(address => mapping(uint32 => uint256)) sumOfReceiptsOfCandidates;

    /// account - hashMessages
    mapping(address => bytes32[]) txsOfProviders;
    bool internal free = true;

    modifier nonZero(uint256 value) {
        require(value != 0, "Z1");
        _;
    }

    modifier nonZeroUint16(uint16 value) {
        require(value != 0, "Z1");
        _;
    }

    modifier nonZeroUint32(uint32 value) {
        require(value != 0, "Z1");
        _;
    }

    modifier nonZeroAddress(address account) {
        require(account != address(0), "Z2");
        _;
    }

    modifier ifFree {
        require(free, "lock");
        free = false;
        _;
        free = true;
    }
}