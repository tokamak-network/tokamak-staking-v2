// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./SeigManagerV2Storage.sol";
import "./proxy/BaseProxy.sol";

contract SeigManagerV2Proxy is BaseProxy, SeigManagerV2Storage {

    function initialize(
        address _ton,
        address _wton,
        address _tot,
        address _seigManagerV1,
        address _layer2Manager,
        uint256 _seigPerBlock,
        uint32 _minimumBlocksforUpdateSeig
    )
        external onlyOwner
        nonZeroAddress(_ton)
        nonZeroAddress(_wton)
        nonZeroAddress(_tot)
        nonZeroAddress(_seigManagerV1)
        nonZeroAddress(_layer2Manager)
        nonZero(_seigPerBlock)
    {
        require(_minimumBlocksforUpdateSeig != 0, "P1");
        require(address(ton) == address(0), "already initialize");

        seigManagerV1 = _seigManagerV1;
        ton = IERC20(_ton);
        wton = _wton;
        tot = _tot;
        layer2Manager =_layer2Manager;

        seigPerBlock = _seigPerBlock;
        minimumBlocksforUpdateSeig = _minimumBlocksforUpdateSeig;

        indexSton = 1 ether;
        indexLton = 1 ether;
    }
}