// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {LibFastWithdraw} from "../libraries/LibFastWithdraw.sol";

contract FwReceiptStorage {

    address public ton;
    address public optimismSequencer;
    uint256 public receiptNo;

    // receiptKey bytes32(keccak256(_l2Messages))
    mapping(bytes32 => LibFastWithdraw.Message) public messages;

    // address - sum of tx's amount
    mapping(address => mapping(uint32 => uint256)) sumOfReceipts;

    mapping(address => bytes32[]) txsOfProviders;

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
}