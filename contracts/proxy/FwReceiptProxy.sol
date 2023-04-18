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
        address _l1CrossDomainMessenger,
        address _seigManagerV2,
        address _optimismSequencer,
        address _candidate
    )
        external onlyOwner
        nonZeroAddress(_ton)
        nonZeroAddress(_seigManagerV2)
        nonZeroAddress(_l1CrossDomainMessenger)
        nonZeroAddress(_optimismSequencer)
        nonZeroAddress(_candidate)
    {
        require(ton == address(0), "already initialize");
        ton = _ton;
        l1CrossDomainMessenger = _l1CrossDomainMessenger;
        seigManagerV2 = _seigManagerV2;
        optimismSequencer = _optimismSequencer;
        candidate = _candidate;
    }

    /* ========== only TON ========== */


    /* ========== Anyone can execute ========== */


    /* ========== VIEW ========== */


    /* ========== internal ========== */


}