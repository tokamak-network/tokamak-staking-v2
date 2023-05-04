// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {IERC20} from "../interfaces/IERC20.sol";
import {Layer2} from "../libraries/Layer2.sol";
import {LibOperator} from "../libraries/LibOperator.sol";

contract Layer2ManagerStorage {

    IERC20 public wton;
    address public seigManagerV2;
    address public optimismSequencer;
    address public candidate;

    /// When creating a sequencer, the minimum deposit amount in WTON
    uint256 public minimumDepositForSequencer;

    /// When Candidate is created, minimum staking amount in WTON
    uint256 public minimumDepositForCandidate;

    /// Number of waiting blocks after unstaking request before withdrawal
    uint256 public delayBlocksForWithdraw;

    /// Maximum number of sequencers we can create
    uint256 public maxLayer2Count;

    /// Sequencer's total security deposit amount
    uint256 public totalSecurityDeposit;

    /// SSeignorage not yet distributed to Sequencer
    uint256 public totalSeigs;

    uint32[] public optimismSequencerIndexes ;
    mapping (uint32 => bytes32) public optimismSequencerNames;
    mapping (uint32 => bytes32) public candidateNames;

    /// Sequencer's security deposit amount and seigniorage
    mapping (uint32 => Layer2.Layer2Holdings) public holdings;

    /// hashMessage - (true or false)
    mapping (bytes32 => bool) public layerKeys;

    uint32[] public candidatesIndexes ; // 길이가 총 개수
    uint32 public indexSequencers ;  // 계속 증가만 함. 인덱스로 사용
    uint32 public indexCandidates ;  // 계속 증가만 함. 인덱스로 사용

    // What percentage of Sequencer's layerer's TVL will be used as a minimum security deposit
    uint16 public ratioSecurityDepositOfTvl;

    bool internal free = true;

    // 등록된 레이어를 삭제하는 기능: 슬래싱 기능이 필요하다

    modifier nonZero(uint256 value) {
        require(value != 0, "Z1");
        _;
    }

    modifier nonZeroUint32(uint32 value) {
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