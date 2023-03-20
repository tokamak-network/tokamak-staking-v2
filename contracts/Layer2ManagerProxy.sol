// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./Layer2ManagerStorage.sol";
import "./proxy/BaseProxy.sol";

contract Layer2ManagerProxy is BaseProxy, Layer2ManagerStorage {

    function initialize(
        address _ton,
        address _seigManagerV2,
        address _stakingLayer2,
        uint256 _minimumDepositForSequencer,
        uint32 _delayBlocksForWithdraw
    )
        external onlyOwner
        nonZeroAddress(_ton)
        nonZeroAddress(_seigManagerV2)
        nonZeroAddress(_stakingLayer2)
        nonZero(_minimumDepositForSequencer)
        nonZero(_delayBlocksForWithdraw)
    {
        require(address(ton) == address(0), "already initialize");

        ton = IERC20(_ton);
        seigManagerV2 = _seigManagerV2;
        stakingLayer2 = _stakingLayer2;

        minimumDepositForSequencer = _minimumDepositForSequencer;
        delayBlocksForWithdraw = _delayBlocksForWithdraw;

        maxLayer2Count = 5;
    }
}