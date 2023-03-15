// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./SeigManagerV2Storage.sol";
import "./proxy/BaseProxy.sol";

contract SeigManagerV2Proxy is BaseProxy, SeigManagerV2Storage {

    /* ========== onlyOwner ========== */

    function initialize(
        address _ton,
        address _wton,
        address _tot,
        address _seigManagerV1,
        address _layer2Manager,
        address _stakingLayer2,
        uint256 _seigPerBlock,
        uint32 _minimumBlocksForUpdateSeig
    )
        external onlyOwner
    {
        require(
            _ton != address(0) &&
            _wton != address(0) &&
            _tot != address(0) &&
            _seigManagerV1 != address(0) &&
            _stakingLayer2 != address(0) &&
            _layer2Manager != address(0) &&
            _seigPerBlock != 0
            , "P1");

        require(address(ton) == address(0), "already initialize");

        seigManagerV1 = _seigManagerV1;
        ton = IERC20(_ton);
        wton = _wton;
        tot = _tot;
        layer2Manager =_layer2Manager;
        stakingLayer2 = _stakingLayer2;
        seigPerBlock = _seigPerBlock;
        minimumBlocksForUpdateSeig = _minimumBlocksForUpdateSeig;

        indexSton = 1 ether;
        indexLton = 1 ether;
    }
}