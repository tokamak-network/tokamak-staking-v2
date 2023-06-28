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
    ) public pure returns (uint256 SeigRateForV1Stakers, uint256 SeigRateForV2Stakers)
    {
        uint256 totalStaked = totalStakedV1 + totalStakedV2;
        // uint256 v1StakeRate = totalStakedV1 * 1e18 / totalSupplyOfTon; // / 1e18 ;
        // uint256 v2StakeRate = totalStakedV2 * 1e18 / totalSupplyOfTon; // / 1e18 ;

        // console.log('v1StakeRate %s', v1StakeRate);
        // console.log('v2StakeRate %s', v2StakeRate);

        SeigRateForV1Stakers = (totalStakedV1 + totalStakedV2) * 1e18 / totalSupplyOfTon;
        SeigRateForV2Stakers = (totalStakedV1 + totalStakedV2) * 1e18 / totalSupplyOfTon;

        uint256 v1StakeRate1Minus = ((totalSupplyOfTon - totalStakedV1) * 1e18 / totalSupplyOfTon);
        uint256 v2StakeRate1Minus = ((totalSupplyOfTon - totalStakedV2) * 1e18 / totalSupplyOfTon);

        uint256 a1 = relativeSeigRate * totalStakedV1 * ((totalSupplyOfTon - totalStaked) * 1e18 / totalSupplyOfTon) / 1e27;
        uint256 a2 = relativeSeigRate * totalStakedV2 * ((totalSupplyOfTon - totalStaked) * 1e18 / totalSupplyOfTon) / 1e27;
        uint256 b = (totalStaked - v1StakeRate1Minus) ;
        uint256 b2 = (totalStaked - v2StakeRate1Minus) ;

        if (b == 0) SeigRateForV1Stakers += a1 / v1StakeRate1Minus;
        else SeigRateForV1Stakers += (a1 / (totalStaked - v1StakeRate1Minus)) * 1e18 / v1StakeRate1Minus ;

        if (b2 == 0) SeigRateForV2Stakers = a2 / v2StakeRate1Minus;
        else SeigRateForV2Stakers = (a2 / (totalStaked - v2StakeRate1Minus)) * 1e18 / v2StakeRate1Minus ;

    }

}
