// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../storages/FwReceiptStorage.sol";
import "../proxy/BaseProxy.sol";

// import "hardhat/console.sol";

contract FwReceiptProxy is BaseProxy, FwReceiptStorage {
    /* ========== DEPENDENCIES ========== */

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */
    function initialize(
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
        require(ton == address(0), "already initialize");
        ton = _ton;
        seigManagerV2 = _seigManagerV2;
        optimismL2Operator = _optimismL2Operator;
        candidate = _candidate;
    }

    /* ========== only TON ========== */


    /* ========== Anyone can execute ========== */


    /* ========== VIEW ========== */


    /* ========== internal ========== */


}