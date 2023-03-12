// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

library LibStaking
{

    struct UserBalance {
        address staker;
        uint256 deposit;    //tos staking 양
        uint256 ltos;       //변환된 LTOS 양
        uint256 endTime;    //끝나는 endTime
        uint256 marketId;   //bondMarketId
    }


}