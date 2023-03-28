// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./storages/Layer2ManagerStorage.sol";
import "./proxy/BaseProxyStorage.sol";
import "./common/AccessibleCommon.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/Layer2.sol";
import "./libraries/LibOptimism.sol";

import "hardhat/console.sol";

interface AddressManagerI {
    function getAddress(string memory _name) external view returns (address);
}

interface SeigManagerV2I {
    function claim(address to, uint256 amount) external;
}

interface StakingLayer2I {
    function balanceOfLton(uint32 layerKey, address account) external view returns (uint256 amount);
}

interface SequencerI {
    function create (uint32 _index, bytes memory _layerInfo) external returns (bool);
    function getTvl (uint32 _index) external view returns (uint256);
    function sequencer(uint32 _index) external view returns (address);
    function layerInfo (uint32 _index) external view returns (bytes memory);
}

interface CandidateI {
    function create (uint32 _candidateIndex, bytes memory _data) external returns (bool);
    function layerInfo (uint32 _index) external view returns (bytes memory);
}

contract  Layer2Manager is AccessibleCommon, BaseProxyStorage, Layer2ManagerStorage {
    /* ========== DEPENDENCIES ========== */
    using SafeERC20 for IERC20;

    event Claimed(uint32 _index, address to, uint256 amount);
    event CreatedOptimismSequencer(uint32 _index, address _sequencer, bytes32 _name, address addressManager, address l1Messenger, address l1Bridge, address l2ton);
    event CreatedCandidate(uint32 _index, address _operator, bytes32 _name, uint32 _sequenceIndex);
    event Distributed(uint256 _totalSeigs, uint256 _distributedAmount);

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */
    function setMaxLayer2Count(uint256 _maxLayer2Count)
        external nonZero(_maxLayer2Count)
        onlyOwner
    {
        require(maxLayer2Count != _maxLayer2Count, "same");
        maxLayer2Count = _maxLayer2Count;
    }

    function setMinimumDepositForSequencer(uint256 _minimumDepositForSequencer)
        external
        onlyOwner
    {
        require(minimumDepositForSequencer != _minimumDepositForSequencer, "same");
        minimumDepositForSequencer = _minimumDepositForSequencer;
    }

    function setRatioSecurityDepositOfTvl(uint16 _ratioSecurityDepositOfTvl)
        external
        onlyOwner
    {
        require(ratioSecurityDepositOfTvl != _ratioSecurityDepositOfTvl, "same");
        ratioSecurityDepositOfTvl = _ratioSecurityDepositOfTvl;
    }

    function setMinimumDepositForCandidate(uint256 _minimumDepositForCandidate)
        external
        onlyOwner
    {
        require(minimumDepositForCandidate != _minimumDepositForCandidate, "same");
        minimumDepositForCandidate = _minimumDepositForCandidate;
    }

    function setDelayBlocksForWithdraw(uint256 _delayBlocksForWithdraw)
        external
        onlyOwner
    {
        require(delayBlocksForWithdraw != _delayBlocksForWithdraw, "same");
        delayBlocksForWithdraw = _delayBlocksForWithdraw;
    }

    /* ========== only SeigManagerV2 ========== */
    function addSeigs(uint256 amount) external returns (bool)
    {
        require(msg.sender == seigManagerV2, "caller is not SeigManagerV2");
        if (amount > 0) totalSeigs += amount;
        return true;
    }

    /* ========== Sequncer can execute ========== */

    function createOptimismSequencer(
        bytes32 _name,
        address addressManager,
        address l1Messenger,
        address l1Bridge,
        address l2ton
    )
        external ifFree
    {
        require(msg.sender == AddressManagerI(addressManager).getAddress('OVM_Sequencer'), 'NOT Sequencer');

        require(indexSequencers < maxLayer2Count, 'exceeded maxLayer2Count');

        require(
            addressManager != address(0) &&
            l1Messenger != address(0) &&
            l1Bridge != address(0) &&
            l2ton != address(0), "zero address"
        );

        bytes32 _key = LibOptimism.getKey(addressManager, l1Messenger, l1Bridge, l2ton);
        require(!layerKeys[_key], 'already created');
        layerKeys[_key] = true;

        uint32 _index = ++indexSequencers;

        totalSecurityDeposit += minimumDepositForSequencer;
        ton.safeTransferFrom(msg.sender, address(this), minimumDepositForSequencer);

        require(
            SequencerI(optimismSequencer).create(_index, abi.encodePacked(addressManager, l1Messenger, l1Bridge, l2ton)),
            "Fail createOptimismSequencer"
        );

        optimismSequencerIndexes.push(_index);
        Layer2.Layer2Holdings storage holding = holdings[_index];
        holding.securityDeposit = minimumDepositForSequencer;
        optimismSequencerNames[_index] = _name;

        emit CreatedOptimismSequencer(
            _index, msg.sender, _name, addressManager, l1Messenger, l1Bridge, l2ton);
    }

    function createCandidate(
        uint32 _sequenceIndex,
        bytes32 _name
    )   external nonZeroUint32(_sequenceIndex) ifFree
    {
        require(_sequenceIndex <= indexSequencers, "wrong index");

        bytes32 _key = LibOperator.getKey(msg.sender, _sequenceIndex);
        require(!layerKeys[_key], 'already created');
        layerKeys[_key] = true;

        uint32 _index = ++indexCandidates;

        candidatesIndexes.push(_index);
        candidateNames[_index] = _name;

        ton.safeTransferFrom(msg.sender, address(this), minimumDepositForCandidate);

        if (ton.allowance(address(this), candidate) < minimumDepositForCandidate) {
            ton.approve(candidate, ton.totalSupply());
        }

        require(
            CandidateI(candidate).create(
                _index,
                abi.encodePacked(msg.sender, _sequenceIndex, minimumDepositForCandidate)),
            "Fail createCandidate"
        );

        emit CreatedCandidate(_index, msg.sender, _name, _sequenceIndex);
    }

    /* ========== Anyone can execute ========== */

    function distribute() external {
        require (totalSeigs != 0, 'no distributable amount');
        uint256 len = optimismSequencerIndexes.length;
        uint256 sum = 0;

        uint256[] memory amountLayer = new uint256[](len);
        for(uint256 i = 0; i < len; i++){
            uint32 _layerIndex = optimismSequencerIndexes[i];
            Layer2.Layer2Holdings memory holding = holdings[_layerIndex];

            if (holding.securityDeposit >= minimumDepositForSequencer ) {
                amountLayer[i] += depositsOf(_layerIndex);
            }
            amountLayer[i] += holding.securityDeposit;
            sum += amountLayer[i];
        }
        uint256 amount1 = 0;
        if (sum > 0) {
            for(uint256 i = 0; i < len; i++){
                uint32 _layerIndex = optimismSequencerIndexes[i];
                Layer2.Layer2Holdings storage holding = holdings[_layerIndex];
                if (amountLayer[i] > 0 ) {
                    uint256 amount = totalSeigs * amountLayer[i] / sum;
                    holding.seigs += amount;
                    amount1 += amount;
                }
            }
            if (amount1 > 0)  totalSeigs -= amount1;
        }

        emit Distributed(totalSeigs, amount1);
    }

    function claim(uint32 _layerIndex) external {
        uint256 amount = holdings[_layerIndex].seigs;
        require(amount != 0, 'no amount to claim');
        address sequencer_ = sequencer(_layerIndex);
        require(sequencer_ != address(0), 'zero sequencer');
        holdings[_layerIndex].seigs = 0;
        SeigManagerV2I(seigManagerV2).claim(sequencer_, amount);
        emit Claimed(_layerIndex, sequencer_, amount);
    }

    /* ========== VIEW ========== */

    function balanceOfLton(address account) public view returns (uint256 amount) {
        uint256 len = optimismSequencerIndexes.length;
        for(uint256 i = 0; i < len; i++){
            amount += StakingLayer2I(optimismSequencer).balanceOfLton(optimismSequencerIndexes[i], account);
        }
    }

    function curTotalLayer2Deposits() public view returns (uint256 amount) {
        uint256 len = optimismSequencerIndexes.length;
        for(uint256 i = 0; i < len; i++){
            amount += SequencerI(optimismSequencer).getTvl(optimismSequencerIndexes[i]);
        }
    }

    function sequencer(uint32 _layerIndex) public view returns (address sequencer_) {
        if (_layerIndex <= indexSequencers ){
            sequencer_ = SequencerI(optimismSequencer).sequencer(_layerIndex);
        }
    }

    function existedLayer2Index(uint32 _index) external view returns (bool exist_) {
        if (_index <= indexSequencers) exist_ = true;
    }

    function existedCandidateIndex(uint32 _index) external view returns (bool exist_) {
        if (_index <= indexCandidates) exist_ = true;
    }

    function curTotalAmountsLayer2() external view returns (uint256 amount) {
        amount = curTotalLayer2Deposits() + totalSecurityDeposit;
    }

    function totalLayers() external view returns (uint256 total) {
        total = optimismSequencerIndexes.length;
    }

    function totalCandidates() external view returns (uint256 total) {
        total = candidatesIndexes.length;
    }

    function curlayer2DepositsOf(uint32 _layerIndex) external view returns (uint256 amount) {
        amount = depositsOf(_layerIndex);
    }

    function depositsOf(uint32 _layerIndex) public view returns (uint256 amount) {
        try
            SequencerI(optimismSequencer).getTvl(_layerIndex) returns (uint256 a) {
                amount = a;
        } catch (bytes memory ) {
            amount = 0;
        }
    }

    function getAllLayers()
        external view
        returns (
            bytes32[] memory optimismSequencerNames_,
            uint32[] memory optimismSequencerIndexes_,
            Layer2.Layer2Holdings[] memory holdings_,
            bytes[] memory infos_
            )
    {
        uint256 len = optimismSequencerIndexes.length;

        optimismSequencerNames_ = new bytes32[](len);
        optimismSequencerIndexes_ = optimismSequencerIndexes;
        holdings_ = new Layer2.Layer2Holdings[](len);
        infos_ = new bytes[](len);
        for (uint256 i = 0; i < len ; i++){
            optimismSequencerNames_[i] = optimismSequencerNames[optimismSequencerIndexes[i]];
            holdings_[i] = holdings[optimismSequencerIndexes[i]];
            infos_[i] = SequencerI(optimismSequencer).layerInfo(optimismSequencerIndexes[i]);
        }
    }

    function getAllCandidates()
        external view
        returns (
            bytes32[] memory candidateNames_,
            uint32[] memory candidateNamesIndexes_,
            bytes[] memory infos_
            )
    {
        uint256 len = candidatesIndexes.length;

        candidateNames_ = new bytes32[](len);
        candidateNamesIndexes_ = candidatesIndexes;
        infos_ = new bytes[](len);
        for (uint256 i = 0; i < len ; i++){
            candidateNames_[i] = candidateNames[candidatesIndexes[i]];
            infos_[i] = CandidateI(candidate).layerInfo(candidatesIndexes[i]);
        }
    }

    function layerHoldings(uint32 layerKey_)
        external view
        returns (Layer2.Layer2Holdings memory)
    {
        return holdings[layerKey_];
    }

    /* ========== internal ========== */


}
