// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../storages/FwReceiptStorage.sol";
import "../proxy/BaseProxyStorage.sol";
import "../common/AccessibleCommon.sol";

contract FwReceiptInitialize is AccessibleCommon, BaseProxyStorage, FwReceiptStorage {
    /* ========== DEPENDENCIES ========== */

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */
    function fixInitialize(
        address _ton,
        address _seigManagerV2,
        address _optimismL2Operator,
        address _candidate
    )
        external onlyOwner
        nonZeroAddress(_ton)
        nonZeroAddress(_seigManagerV2)
        nonZeroAddress(_optimismL2Operator)
        nonZeroAddress(_candidate)
    {
        ton = _ton;
        seigManagerV2 = _seigManagerV2;
        optimismL2Operator = _optimismL2Operator;
        candidate = _candidate;
    }

}