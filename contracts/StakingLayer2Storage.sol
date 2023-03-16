// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

// import {IERC20} from "./interfaces/IERC20.sol";
import {Layer2} from "./libraries/Layer2.sol";
import "./libraries/LibStake.sol";

contract StakingLayer2Storage {
    using Layer2 for mapping(bytes32 => Layer2.Info);
    using Layer2 for Layer2.Info;

    address public ton;
    address public seigManagerV2;
    address public layer2Manager;
    uint256 public totalStakedLton;
    uint256 public totalBondedLton;

    mapping (bytes32 => mapping(address => LibStake.StakeInfo)) public layerStakes; // ltos uint

    // layer2Key => msg.sender => withdrawal requests (언스테이크시 등록 )
    mapping (bytes32 => mapping (address => LibStake.WithdrawalReqeust[])) public withdrawalRequests;
    // layer2Key => msg.sender => index
    mapping (bytes32 => mapping (address => uint256)) public withdrawalRequestIndex;

    // pending unstaked amount
    // layer2 => msg.sender => wton amount
    mapping (bytes32 => mapping (address => uint256)) public _pendingUnstaked;
    // layer2 => wton amount
    mapping (bytes32 => uint256) public _pendingUnstakedLayer2;
    // msg.sender => wton amount
    mapping (address => uint256) public _pendingUnstakedAccount;

    address[] public stakeAccountList;
    address[] public bondAccountList;

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