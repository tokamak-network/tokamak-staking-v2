// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";

library LibSeigManager
{

    function calculateStakedSeig(
        uint256 totalSupplyOfTon,
        uint256 relativeSeigRate,
        uint256 totalStakedV1,
        uint256 totalStakedV2
    ) public view returns (uint256 SeigRateForV1Stakers, uint256 SeigRateForV2Stakers)
    {
        console.log('relativeSeigRate %s', relativeSeigRate);

        uint256 totalStaked = totalStakedV1 + totalStakedV2;
        uint256 stakeRate = totalStaked * 1e18 / totalSupplyOfTon ; // /1e8
        uint256 v1StakeRate = totalStakedV1 * 1e18 / totalSupplyOfTon; // / 1e18 ;
        uint256 v2StakeRate = totalStakedV2 * 1e18 / totalSupplyOfTon; // / 1e18 ;

        console.log('stakeRate %s', stakeRate);
        console.log('v1StakeRate %s', v1StakeRate);
        console.log('v2StakeRate %s', v2StakeRate);

        uint256 a = (stakeRate + v1StakeRate * (1e18 - stakeRate) * relativeSeigRate/1e27 / 1e18) ;
        console.log('a %s', a);
        uint256 b = (stakeRate - v1StakeRate);
        console.log('b %s', b);
        uint256 c = (1e18 - v1StakeRate);
        console.log('c %s',  c);

        if (b == 0) SeigRateForV1Stakers = a / c;
        else SeigRateForV1Stakers = a * 1e18/ b / c;

        console.log('SeigRateForV1Stakers %s', SeigRateForV1Stakers);


        uint256 a1 = (stakeRate + v2StakeRate * (1e18 - stakeRate) * relativeSeigRate/1e27/1e18) ;
        console.log('a1 %s', a1);
        uint256 b1 = (stakeRate - v2StakeRate);
        console.log('b1 %s', b1);
        uint256 c1 = (1e18 - v2StakeRate);
        console.log('c1 %s',  c1);

        if (b1 == 0) SeigRateForV2Stakers = a1 / c1;
        else SeigRateForV2Stakers = a1 / b1 / c1;
        console.log('SeigRateForV2Stakers %s', SeigRateForV2Stakers);

    }

}
