// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./storages/Layer2ManagerStorage.sol";
import "./proxy/BaseProxyStorage.sol";
import "./common/AccessibleCommon.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/Layer2.sol";
import "./libraries/LibOptimism.sol";
import "./interfaces/ILayer2Manager.sol";
// import "hardhat/console.sol";

interface AddressManagerI {
    function getAddress(string memory _name) external view returns (address);
}

interface SeigManagerV2I {
    function claim(address to, uint256 amount) external;
}

interface StakingLayer2I {
    function balanceOfLton(uint32 layerKey, address account) external view returns (uint256 amount);
}

interface OperatorI {
    function create(uint32 _index, bytes memory _layerInfo) external returns (bool);
    function getTvl(uint32 _index) external view returns (uint256);
    function getTvl(address l1Bridge, address l2ton) external view returns (uint256 amount);
    function operator(uint32 _index) external view returns (address);
    function operator(address addressManager) external view returns (address);
    function layerInfo(uint32 _index) external view returns (bytes memory);
    function getLayerInfo(uint32 _index) external view returns (LibOptimism.Info memory _layerInfo );
    function L1StandardBridge(address addressManager) external view returns (address);

}

interface CandidateI {
    function create (uint32 _candidateIndex, bytes memory _data) external returns (bool);
    function layerInfo (uint32 _index) external view returns (bytes memory);
}

contract  Layer2Manager is AccessibleCommon, BaseProxyStorage, Layer2ManagerStorage, ILayer2Manager {
    /* ========== DEPENDENCIES ========== */
    using SafeERC20 for IERC20;

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */

    /// @inheritdoc ILayer2Manager
    function setMaxLayer2Count(uint256 _maxLayer2Count)
        external override nonZero(_maxLayer2Count)
        onlyOwner
    {
        require(maxLayer2Count != _maxLayer2Count, "same");
        maxLayer2Count = _maxLayer2Count;
    }

    /// @inheritdoc ILayer2Manager
    function setMinimumDepositForL2Operator(uint256 _minimumDepositForL2Operator)
        external override
        onlyOwner
    {
        require(minimumDepositForL2Operator != _minimumDepositForL2Operator, "same");
        minimumDepositForL2Operator = _minimumDepositForL2Operator;
    }

    /// @inheritdoc ILayer2Manager
    function setRatioSecurityDepositOfTvl(uint16 _ratioSecurityDepositOfTvl)
        external override
        onlyOwner
    {
        require(ratioSecurityDepositOfTvl != _ratioSecurityDepositOfTvl, "same");
        ratioSecurityDepositOfTvl = _ratioSecurityDepositOfTvl;
    }

    /// @inheritdoc ILayer2Manager
    function setMinimumDepositForCandidate(uint256 _minimumDepositForCandidate)
        external override
        onlyOwner
    {
        require(minimumDepositForCandidate != _minimumDepositForCandidate, "same");
        minimumDepositForCandidate = _minimumDepositForCandidate;
    }

    /// @inheritdoc ILayer2Manager
    function setDelayBlocksForWithdraw(uint256 _delayBlocksForWithdraw)
        external override
        onlyOwner
    {
        require(delayBlocksForWithdraw != _delayBlocksForWithdraw, "same");
        delayBlocksForWithdraw = _delayBlocksForWithdraw;
    }

    /* ========== only SeigManagerV2 ========== */

    /// @inheritdoc ILayer2Manager
    function addSeigs(uint256 amount) external override returns (bool)
    {
        require(msg.sender == seigManagerV2, "caller is not SeigManagerV2");
        if (amount > 0) totalSeigs += amount;
        return true;
    }

    /* ========== Sequncer can execute ========== */

    /// @inheritdoc ILayer2Manager
    function createOptimismL2Operator(
        bytes32 _name,
        address addressManager,
        address l1Bridge,
        address l2Bridge,
        address l2ton,
        uint256 amount
    )
        external override ifFree returns (uint32)
    {
        // for test
        require(msg.sender == AddressManagerI(addressManager).getAddress('OVM_TONStakingManager'), 'NOT OVM_TONStakingManager');
        require(amount >= ton.allowance(msg.sender, address(this)), "allowance allowance is insufficient is insufficient");
        require(indexOperators < maxLayer2Count, 'exceeded maxLayer2Count');

        require(
            addressManager != address(0) &&
            l2ton != address(0), "zero address"
        );

        bytes32 _key = LibOptimism.getKey(addressManager, l1Bridge, l2Bridge, l2ton);
        require(!layerKeys[_key], 'already created');

        address _l1Bridge = OperatorI(optimismL2Operator).L1StandardBridge(addressManager);
        require(l1Bridge == _l1Bridge, 'different l1Bridge');

        require(amount >= minimumSecurityDepositAmount(l1Bridge, l2ton), 'security deposit is insufficent');

        layerKeys[_key] = true;
        uint32 _index = ++indexOperators;
        totalSecurityDeposit += amount;
        optimismL2OperatorIndexes.push(_index);

        Layer2.Layer2Holdings storage holding = holdings[_index];
        holding.securityDeposit = amount;
        optimismL2OperatorNames[_index] = _name;

        require(
            OperatorI(optimismL2Operator).create(
                _index,
                abi.encodePacked(addressManager, l1Bridge, l2Bridge, l2ton)),
            "Fail createOptimismL2Operator"
        );

        if (amount != 0) ton.safeTransferFrom(msg.sender, address(this), amount);

        emit CreatedOptimismL2Operator(
            _index, msg.sender, _name, addressManager, l1Bridge, l2Bridge, l2ton, amount);

        return _index;
    }

    /// @inheritdoc ILayer2Manager
    function createCandidate(
        uint32 _operatorIndex,
        bytes32 _name,
        uint16 _commission,
        uint256 amount
    )   external override nonZeroUint32(_operatorIndex) ifFree returns (uint32)
    {
        require(_operatorIndex <= indexOperators, "wrong index");
        bytes32 _key = LibOperator.getKey(msg.sender, _operatorIndex);
        require(!layerKeys[_key], 'already created');
        require(amount >= minimumDepositForCandidate, 'security deposit is insufficent');

        layerKeys[_key] = true;

        uint32 _index = ++indexCandidates;

        candidatesIndexes.push(_index);
        candidateNames[_index] = _name;

        if (amount != 0) ton.safeTransferFrom(msg.sender, address(this), amount);

        if (ton.allowance(address(this), candidate) < amount) {
            ton.approve(candidate, ton.totalSupply());
        }

        require(
            CandidateI(candidate).create(
                _index,
                abi.encodePacked(msg.sender, _operatorIndex, _commission, amount)),
            "Fail createCandidate"
        );

        emit CreatedCandidate(_index, msg.sender, _name, _operatorIndex, _commission, amount);
        return _index;
    }

    /// @inheritdoc ILayer2Manager
    function decreaseSecurityDeposit(uint32 _operatorIndex, uint256 amount)
        external override ifFree nonZeroUint32(_operatorIndex) nonZero(amount)
    {
        require(_operatorIndex <= indexOperators, "wrong index");

        LibOptimism.Info memory _layerInfo = OperatorI(optimismL2Operator).getLayerInfo(_operatorIndex);
        address _operator = OperatorI(optimismL2Operator).operator(_layerInfo.addressManager);
        require(_operator != address(0) && _operator == msg.sender, "operator is zero or not caller." );

        address l1Bridge = OperatorI(optimismL2Operator).L1StandardBridge(_layerInfo.addressManager);
        require(l1Bridge != address(0), 'zero l1Bridge');

        uint256 minDepositAmount = minimumSecurityDepositAmount(l1Bridge, _layerInfo.l2ton);
        Layer2.Layer2Holdings storage holding = holdings[_operatorIndex];
        require(amount + minDepositAmount <= holding.securityDeposit, "insufficient deposit");

        holding.securityDeposit -= amount;
        totalSecurityDeposit -= amount;
        ton.safeTransfer(msg.sender, amount);

        emit DecreasedSecurityDeposit(_operatorIndex, msg.sender, amount);
    }

    /* ========== Anyone can execute ========== */

    /// @inheritdoc ILayer2Manager
    function increaseSecurityDeposit(uint32 _operatorIndex, uint256 amount)
        external override ifFree nonZeroUint32(_operatorIndex) nonZero(amount)
    {
        require(_operatorIndex <= indexOperators, "wrong index");
        ton.safeTransferFrom(msg.sender, address(this), amount);

        Layer2.Layer2Holdings storage holding = holdings[_operatorIndex];
        holding.securityDeposit += amount;
        totalSecurityDeposit += amount;
        emit IncreasedSecurityDeposit(_operatorIndex, msg.sender, amount);
    }

    /// @inheritdoc ILayer2Manager
    function distribute() external override {
        require (totalSeigs != 0, 'no distributable amount');
        uint256 len = optimismL2OperatorIndexes.length;
        uint256 sum = 0;

        uint256[] memory amountLayer = new uint256[](len);
        for(uint256 i = 0; i < len; i++){
            uint32 _layerIndex = optimismL2OperatorIndexes[i];
            Layer2.Layer2Holdings memory holding = holdings[_layerIndex];

            if (holding.securityDeposit >= minimumDepositForL2Operator ) {
                amountLayer[i] += holding.securityDeposit + depositsOf(_layerIndex);
                sum += amountLayer[i];
            } else {
                sum += holding.securityDeposit + depositsOf(_layerIndex);
            }
        }
        uint256 amount1 = 0;
        if (sum > 0) {
            for(uint256 i = 0; i < len; i++){
                if (amountLayer[i] > 0 ) {
                    uint256 amount = totalSeigs * amountLayer[i] / sum;
                    Layer2.Layer2Holdings storage holding = holdings[optimismL2OperatorIndexes[i]];
                    holding.seigs += amount;
                    amount1 += amount;
                }
            }
            if (amount1 > 0)  totalSeigs -= amount1;
        }

        emit Distributed(totalSeigs, amount1);
    }

    /// @inheritdoc ILayer2Manager
    function claim(uint32 _layerIndex) external override {
        uint256 amount = holdings[_layerIndex].seigs;
        require(amount != 0, 'no amount to claim');
        address operator_ = operator(_layerIndex);
        require(operator_ != address(0), 'zero operator');
        holdings[_layerIndex].seigs = 0;
        SeigManagerV2I(seigManagerV2).claim(operator_, amount);
        emit Claimed(_layerIndex, operator_, amount);
    }

    /* ========== VIEW ========== */

    /// @inheritdoc ILayer2Manager
    function minimumSecurityDepositAmount(address l1Bridge, address l2ton) public view override returns (uint256 amount) {
        if (ratioSecurityDepositOfTvl == 0) amount = minimumDepositForL2Operator;
        else {
            amount = Math.max(
                OperatorI(optimismL2Operator).getTvl(l1Bridge, l2ton) * ratioSecurityDepositOfTvl / 10000,
                minimumDepositForL2Operator);
        }
    }

    /// @inheritdoc ILayer2Manager
    function balanceOfLton(address account) public view override returns (uint256 amount) {
        uint256 len = optimismL2OperatorIndexes.length;
        for(uint256 i = 0; i < len; i++){
            amount += StakingLayer2I(optimismL2Operator).balanceOfLton(optimismL2OperatorIndexes[i], account);
        }
    }

    /// @inheritdoc ILayer2Manager
    function curTotalLayer2Deposits() public view override returns (uint256 amount) {
        uint256 len = optimismL2OperatorIndexes.length;
        for(uint256 i = 0; i < len; i++){
            amount += OperatorI(optimismL2Operator).getTvl(optimismL2OperatorIndexes[i]);
        }
    }

    /// @inheritdoc ILayer2Manager
    function operator(uint32 _layerIndex) public view override returns (address operator_) {
        if (_layerIndex <= indexOperators ){
            operator_ = OperatorI(optimismL2Operator).operator(_layerIndex);
        }
    }

    /// @inheritdoc ILayer2Manager
    function existedLayer2Index(uint32 _index) external view override returns (bool exist_) {
        if (_index <= indexOperators) exist_ = true;
    }

    /// @inheritdoc ILayer2Manager
    function existedCandidateIndex(uint32 _index) external view override returns (bool exist_) {
        if (_index <= indexCandidates) exist_ = true;
    }

    /// @inheritdoc ILayer2Manager
    function curTotalAmountsLayer2() external view override returns (uint256 amount) {
        amount = curTotalLayer2Deposits() + totalSecurityDeposit;
    }

    /// @inheritdoc ILayer2Manager
    function totalLayers() external view override returns (uint256 total) {
        total = optimismL2OperatorIndexes.length;
    }

    /// @inheritdoc ILayer2Manager
    function totalCandidates() external view override returns (uint256 total) {
        total = candidatesIndexes.length;
    }

    /// @inheritdoc ILayer2Manager
    function depositsOf(uint32 _layerIndex) public view override returns (uint256 amount) {
        try
            OperatorI(optimismL2Operator).getTvl(_layerIndex) returns (uint256 a) {
                amount = a;
        } catch (bytes memory ) {
            amount = 0;
        }
    }

    /// @inheritdoc ILayer2Manager
    function getAllLayers()
        external view override
        returns (
            bytes32[] memory optimismL2OperatorNames_,
            uint32[] memory optimismL2OperatorIndexes_,
            Layer2.Layer2Holdings[] memory holdings_,
            bytes[] memory infos_
            )
    {
        uint256 len = optimismL2OperatorIndexes.length;

        optimismL2OperatorNames_ = new bytes32[](len);
        optimismL2OperatorIndexes_ = optimismL2OperatorIndexes;
        holdings_ = new Layer2.Layer2Holdings[](len);
        infos_ = new bytes[](len);
        for (uint256 i = 0; i < len ; i++){
            optimismL2OperatorNames_[i] = optimismL2OperatorNames[optimismL2OperatorIndexes[i]];
            holdings_[i] = holdings[optimismL2OperatorIndexes[i]];
            infos_[i] = OperatorI(optimismL2Operator).layerInfo(optimismL2OperatorIndexes[i]);
        }
    }

    /// @inheritdoc ILayer2Manager
    function getAllCandidates()
        external view override
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

    /// @inheritdoc ILayer2Manager
    function layerHoldings(uint32 layerKey_)
        external view override
        returns (Layer2.Layer2Holdings memory)
    {
        return holdings[layerKey_];
    }

    /* ========== internal ========== */
}
