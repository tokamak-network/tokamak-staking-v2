// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {IERC20} from "./interfaces/IERC20.sol";
import {Layer2} from "./libraries/Layer2.sol";

contract Layer2ManagerStorage {

    IERC20 public ton;
    address public seigManagerV2;
    address public stakingLayer2;
    uint256 public minimumDepositForSequencer;
    uint256 public delayBlocksForWithdraw;
    uint256 public maxLayer2Count;

    uint256 public totalSecurityDeposit; //시퀀서의 담보금
    // uint256 public totalLayer2Deposits; // L1브릿지를 거처간 모든 L2의 톤 보유량 총액

    // 레이어2의 담보금(시퀀서가 입금한다.)
    mapping (bytes32 => uint256) public securityDeposit;

    // L1브릿지를 거처간 L2의 톤 보유량
    mapping (bytes32 => uint256) public layer2Deposits;

    mapping (bytes32 => Layer2.Info) public layers;

    bytes32[] public layerKeys;

    bool internal free = true;

    // 등록된 레이어를 삭제하는 기능: 슬래싱 기능이 필요하다

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