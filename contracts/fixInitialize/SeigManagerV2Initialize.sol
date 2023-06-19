// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../storages/SeigManagerV2Storage.sol";
import "../proxy/BaseProxyStorage.sol";
import "../common/AccessibleCommon.sol";
import "../libraries/SafeERC20.sol";
import "../libraries/Layer2.sol";
import "../libraries/LibArrays.sol";

contract SeigManagerV2Initialize is AccessibleCommon, BaseProxyStorage, SeigManagerV2Storage {
    /* ========== DEPENDENCIES ========== */
    using SafeERC20 for IERC20;
    using LibArrays for uint256[];

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */
    function fixInitialize(
        address _ton,
        address _wton,
        address _tot,
        address[4] calldata addr, // _seigManagerV1, _layer2Manager, _optimismSequencer, _candidate
        uint256 _seigPerBlock,
        uint32 _minimumBlocksForUpdateSeig,
        uint16[4] calldata _rates   // ratesTonStakers, ratesDao, ratesStosHolders,ratesUnits
    )
        external onlyOwner
    {

        ratesUnits = _rates[3];
        ratesTonStakers = _rates[0];
        ratesDao = _rates[1];
        ratesStosHolders = _rates[2];

        seigManagerV1 = addr[0];
        ton = IERC20(_ton);
        wton = _wton;
        tot = _tot;
        layer2Manager =addr[1];
        optimismL2Operator = addr[2];
        candidate = addr[3];

        seigPerBlock = _seigPerBlock;
        minimumBlocksForUpdateSeig = _minimumBlocksForUpdateSeig;
        _indexLton = 1 ether;
    }

    /* ========== only Layer2Manager Or Optimism ========== */


    /* ========== Anyone can execute ========== */


    /* ========== VIEW ========== */


}
