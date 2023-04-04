// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {IERC20} from "../interfaces/IERC20.sol";

contract SeigManagerV2Storage {

    IERC20 public ton;
    address public wton;
    address public dao;
    address public stosDistribute;
    address public seigManagerV1;
    address public tot;
    address public layer2Manager;
    address public optimismSequencer;
    address public candidate;

    uint256 public seigPerBlock;
    uint256 public lastSeigBlock;
    uint256 public startBlock;
    uint256 public indexLton; // for staker or bonder

    uint16 public ratesTonStakers; // divided ratesUnits
    uint16 public ratesDao;   // divided ratesUnits
    uint16 public ratesStosHolders; // divided ratesUnits

    uint16 public ratesUnits; // divided uint. 10000
    uint32 public minimumBlocksForUpdateSeig; // the number of block
    bool internal free = true;

    modifier nonZero(uint256 value) {
        require(value != 0, "Z1");
        _;
    }

    modifier nonZeroAddress(address account) {
        require(account != address(0), "Z2");
        _;
    }

    modifier ifFree {
        require(free, "lock");
        free = false;
        _;
        free = true;
    }

}