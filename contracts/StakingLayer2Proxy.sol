// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./StakingLayer2Storage.sol";
import "./proxy/BaseProxy.sol";

contract StakingLayer2Proxy is BaseProxy, StakingLayer2Storage {

    function initialize(
        address _ton,
        address _seigManagerV2,
        address _layer2Manager
    )
        external onlyOwner
        nonZeroAddress(_ton)
        nonZeroAddress(_seigManagerV2)
        nonZeroAddress(_layer2Manager)
    {
        require(address(ton) == address(0), "already initialize");

        seigManagerV2 = _seigManagerV2;
        ton = _ton;
        layer2Manager =_layer2Manager;
    }
}