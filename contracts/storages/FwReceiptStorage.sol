// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {LibFastWithdraw} from "../libraries/LibFastWithdraw.sol";

contract FwReceiptStorage {

    address public optimismSequencer;

    mapping(address => uint16) public providersFeeRate;

    // l2Index - bill
    mapping(bytes32 => LibFastWithdraw.Receipt) public receipts;

    // address - sum of bill's amount
    mapping(address => uint256) sumOfReceipts;

    mapping(address => bytes32[]) txsOfProviders;
    mapping(address => bytes32[]) txsOfRequestors;

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