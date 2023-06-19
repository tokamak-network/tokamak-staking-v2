// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "../storages/StakingStorage.sol";
import "../proxy/BaseProxyStorage.sol";
import "../common/AccessibleCommon.sol";
import "../storages/OptimismL2OperatorStorage.sol";

contract OptimismL2OperatorInitialize is AccessibleCommon, BaseProxyStorage, StakingStorage, OptimismL2OperatorStorage {

    /* ========== DEPENDENCIES ========== */

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */
    function fixInitialize(
        address _ton,
        address _seigManagerV2,
        address _layer2Manager,
        address _fwReceipt
    )
        external onlyOwner
        nonZeroAddress(_ton)
        nonZeroAddress(_seigManagerV2)
        nonZeroAddress(_layer2Manager)
        nonZeroAddress(_fwReceipt)
    {
        seigManagerV2 = _seigManagerV2;
        ton = _ton;
        layer2Manager =_layer2Manager;
        fwReceipt = _fwReceipt;
    }

}