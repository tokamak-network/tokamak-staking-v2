// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../storages/Layer2ManagerStorage.sol";
import "../proxy/BaseProxy.sol";

contract Layer2ManagerProxy is BaseProxy, Layer2ManagerStorage {

    function initialize(
        address _ton,
        address _seigManagerV2,
        address _optimismL2Operator,
        address _candidate,
        uint256 _minimumDepositForL2Operator,
        uint256 _minimumDepositForCandidate,
        uint32 _delayBlocksForWithdraw
    )
        external onlyOwner
        nonZeroAddress(_ton)
        nonZeroAddress(_seigManagerV2)
        nonZeroAddress(_optimismL2Operator)
        nonZeroAddress(_candidate)
        nonZero(_delayBlocksForWithdraw)
    {
        require(address(ton) == address(0), "already initialize");

        ton = IERC20(_ton);
        seigManagerV2 = _seigManagerV2;
        optimismL2Operator = _optimismL2Operator;
        candidate = _candidate;

        minimumDepositForL2Operator = _minimumDepositForL2Operator;
        minimumDepositForCandidate = _minimumDepositForCandidate;
        delayBlocksForWithdraw = _delayBlocksForWithdraw;

        maxLayer2Count = 5;
    }
}