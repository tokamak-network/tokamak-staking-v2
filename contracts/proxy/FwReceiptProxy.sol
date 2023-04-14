// SPDX-License-Identifier: AGPL-3.0-or-later
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
        address _optimismSequencer,
        address _candidate
    )
        external onlyOwner
        nonZeroAddress(_ton)
        nonZeroAddress(_optimismSequencer)
         nonZeroAddress(_candidate)
    {
        require(ton == address(0), "already initialize");
        ton = _ton;
        optimismSequencer = _optimismSequencer;
        candidate = _candidate;
    }

    /* ========== only TON ========== */


    /* ========== Anyone can execute ========== */


    /* ========== VIEW ========== */


    /* ========== internal ========== */


}