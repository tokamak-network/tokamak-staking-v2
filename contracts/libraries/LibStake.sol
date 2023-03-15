// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

library LibStake
{
    struct StakeInfo {
        uint256 stakePrincipal;
        uint256 bondPrincipal;
        // uint256 fwPrincipal;
        uint256 stakelton;
        uint256 bondlton;
        // uint256 fwlton;
        bool staker;
        bool bonder;
    }

    struct WithdrawalReqeust {
        uint32 withdrawableBlockNumber;
        uint128 amount;
        bool processed;
    }

}