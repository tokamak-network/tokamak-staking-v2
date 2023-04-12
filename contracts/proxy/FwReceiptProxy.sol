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
        address _optimismSequencer
    )
        external onlyOwner
        nonZeroAddress(_ton)
        nonZeroAddress(_optimismSequencer)
    {
        require(ton == address(0), "already initialize");
        ton = _ton;
        optimismSequencer = _optimismSequencer;
    }

    /* ========== only TON ========== */


    /* ========== Anyone can execute ========== */


    /* ========== VIEW ========== */


    /* ========== internal ========== */


}