// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

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

    mapping (bytes32 => uint256) public layerStakedLton;
    mapping (bytes32 => mapping(address => LibStake.StakeInfo)) public layerStakes; // ltos uint

    // layer2Key => msg.sender => withdrawal requests (언스테이크시 등록 )
    mapping (bytes32 => mapping (address => LibStake.WithdrawalReqeust[])) public withdrawalRequests;
    // layer2Key => msg.sender => index
    mapping (bytes32 => mapping (address => uint256)) public withdrawalRequestIndex;

    // pending unstaked amount
    // layer2 => msg.sender => ton amount
    mapping (bytes32 => mapping (address => uint256)) public _pendingUnstaked;
    // layer2 => ton amount
    mapping (bytes32 => uint256) public _pendingUnstakedLayer2;
    // msg.sender =>  ton amount
    mapping (address => uint256) public _pendingUnstakedAccount;

    address[] public stakeAccountList;
    address[] public bondAccountList;

    bytes4 constant ERC20_ONAPPROVE = 0x4273ca16;
     // As per the EIP-165 spec, no interface should ever match 0xffffffff
    bytes4 internal constant InterfaceId_Invalid = 0xffffffff;
    bytes4 internal constant InterfaceId_ERC165 = 0x01ffc9a7;
    mapping(bytes4 => bool) internal _supportedInterfaces;

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