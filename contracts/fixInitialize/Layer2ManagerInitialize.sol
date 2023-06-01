// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../storages/Layer2ManagerStorage.sol";
import "../proxy/BaseProxyStorage.sol";
import "../common/AccessibleCommon.sol";
import "../libraries/SafeERC20.sol";
import "../libraries/Layer2.sol";
import "../libraries/LibOptimism.sol";

contract  Layer2ManagerInitialize is AccessibleCommon, BaseProxyStorage, Layer2ManagerStorage {
    /* ========== DEPENDENCIES ========== */
    using SafeERC20 for IERC20;

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */
    function fixInitialize(
        address _ton,
        address _seigManagerV2,
        address _optimismSequencer,
        address _candidate,
        uint256 _minimumDepositForSequencer,
        uint256 _minimumDepositForCandidate,
        uint32 _delayBlocksForWithdraw
    )
        external onlyOwner
        nonZeroAddress(_ton)
        nonZeroAddress(_seigManagerV2)
        nonZeroAddress(_optimismSequencer)
        nonZeroAddress(_candidate)
        nonZero(_delayBlocksForWithdraw)
    {
        ton = IERC20(_ton);
        seigManagerV2 = _seigManagerV2;
        optimismSequencer = _optimismSequencer;
        candidate = _candidate;

        minimumDepositForSequencer = _minimumDepositForSequencer;
        minimumDepositForCandidate = _minimumDepositForCandidate;
        delayBlocksForWithdraw = _delayBlocksForWithdraw;

        maxLayer2Count = 5;
    }

    /* ========== only SeigManagerV2 ========== */

    /* ========== Anyone can execute ========== */

    /* ========== VIEW ========== */

    /* ========== internal ========== */
}