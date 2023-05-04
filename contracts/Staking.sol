// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./libraries/BytesParserLib.sol";
import "./storages/StakingStorage.sol";
import "./proxy/BaseProxyStorage.sol";
import "./common/AccessibleCommon.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/LibArrays.sol";

// import "hardhat/console.sol";

interface L1BridgeI {
    function deposits(address l1token, address l2token) external view returns (uint256);
}

interface AddressManagerI {
    function getAddress(string memory _name) external view returns (address);
}

interface FwReceiptI {
    function debtInStaked(bool isCandidate, uint32 layerIndex, address account) external view returns (uint256);
}

interface SeigManagerV2I {
    function getLwtonToWton(uint256 lwton) external view returns (uint256);
    function getWtonToLwton(uint256 amount) external view returns (uint256);

    function updateSeigniorage() external returns (bool);
    function claim(address to, uint256 amount) external;

    function getCurrentSnapshotId() external view returns (uint256);
    function snapshot() external returns (uint256);
    function getLwtonToWtonAt(uint256 lwton, uint256 snapshotId) external view returns (uint256);
    function getWtonToLwtonAt(uint256 amount, uint256 snapshotId) external view returns (uint256);
}

interface Layer2ManagerI {
    function delayBlocksForWithdraw() external view returns (uint256 amount);
    function totalSecurityDeposit() external view returns (uint256 amount);
    function totalLayer2Deposits() external view returns (uint256 amount);
    function existedLayer2Index(uint32 _index) external view returns (bool exist_);
    function existedCandidateIndex(uint32 _index) external view returns (bool exist_);

    function securityDeposit(uint32 layerIndex) external view returns (uint256 amount);
    function layer2Deposits(uint32 layerIndex) external view returns (uint256 amount);

    function minimumDepositForCandidate() external view returns (uint256);
}


contract Staking is AccessibleCommon, BaseProxyStorage, StakingStorage {
    /* ========== DEPENDENCIES ========== */
    using SafeERC20 for IERC20;
    using BytesParserLib for bytes;
    using LibArrays for uint256[];

    event Staked(uint32 _index, address sender, uint256 amount, uint256 lwton, address commissionTo, uint16 commission);
    event Unstaked(uint32 _index, address sender, uint256 amount, uint256 lwton);
    event Restaked(uint32 _index, address sender, uint256 amount, uint256 lwton);
    event Withdrawal(uint32 _index, address sender, uint256 amount);
    event FastWithdrawalClaim(bytes32 hashMessage, uint32 layerIndex, address from, address to, uint256 amount);
    event FastWithdrawalStaked(bytes32 hashMessage, uint32 layerIndex, address staker, uint256 amount, uint256 lwton);

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */


    /* ========== onlySeigManagerV2 ========== */

    /* ========== only Receipt ========== */

    function fastWithdrawClaim(bytes32 hashMessage, uint32 layerIndex, address from, address to, uint256 amount) external ifFree returns (bool){
        require(fwReceipt == msg.sender, "FW_CALLER_ERR");
        require(balanceOf(layerIndex, from) >= amount, "liquidity is insufficient");
        _beforeUpdate(layerIndex, from);

        uint256 bal = IERC20(wton).balanceOf(address(this));

        if (bal < amount) {
            if (bal > 0) IERC20(wton).safeTransfer(to, bal);
            SeigManagerV2I(seigManagerV2).claim(to, (amount - bal));
        } else {
            IERC20(wton).safeTransfer(to, amount);
        }

        emit FastWithdrawalClaim(hashMessage, layerIndex, from, to, amount);
        return true;
    }

    function fastWithdrawStake(bytes32 hashMessage, uint32 layerIndex, address staker, uint256 _amount) external returns (bool){
        require(fwReceipt == msg.sender, "FW_CALLER_ERR");
        _beforeUpdate(layerIndex, staker);

        uint256 lwton_ = SeigManagerV2I(seigManagerV2).getWtonToLwton(_amount);
        layerStakedLwton[layerIndex] += lwton_;
        _totalStakedLwton += lwton_;
        LibStake.StakeInfo storage info_ = layerStakes[layerIndex][staker];
        info_.stakePrincipal += _amount;
        info_.stakelwton += lwton_;
        emit FastWithdrawalStaked(hashMessage, layerIndex, staker, _amount, lwton_);
        return true;
    }

    /* ========== Anyone can execute ========== */

    function stake_(uint32 _index, uint256 amount, address commissionTo, uint16 commission) internal
    {
        IERC20(wton).safeTransferFrom(msg.sender, address(this), amount);
        _stake(_index, msg.sender, amount, commissionTo, commission);
    }

    function _stake(uint32 _index, address sender, uint256 amount, address commissionTo, uint16 commission) internal ifFree nonZero(amount)
    {
        _beforeUpdate(_index, sender);

        uint256 lwton_ = SeigManagerV2I(seigManagerV2).getWtonToLwton(amount);

        layerStakedLwton[_index] += lwton_;
        _totalStakedLwton += lwton_;

        LibStake.StakeInfo storage info_ = layerStakes[_index][sender];

        if (!info_.stake) {
            info_.stake = true;
            stakeAccountList.push(sender);
        }

        uint256 commissionLton = 0;
        if (commission != 0 && commissionTo != address(0) && commission < 10000) {
            commissionLton = lwton_ * commission / 10000;
            lwton_ -= commissionLton;

            uint256 amount1 = SeigManagerV2I(seigManagerV2).getLwtonToWton(lwton_);
            info_.stakePrincipal += amount1;
            info_.stakelwton += lwton_;

            LibStake.StakeInfo storage commissionInfo_ = layerStakes[_index][commissionTo];
            commissionInfo_.stakePrincipal += (amount - amount1);
            commissionInfo_.stakelwton += commissionLton;

        } else {
            info_.stakePrincipal += amount;
            info_.stakelwton += lwton_;
        }

        emit Staked(_index, sender, amount, lwton_, commissionTo, commission);
    }

    function _unstake(uint32 _index, uint256 lwton_, uint256 _debtWton) internal ifFree nonZero(lwton_)
    {
        // require(SeigManagerV2I(seigManagerV2).updateSeigniorage(), 'fail updateSeig');
        address sender = msg.sender;
        _beforeUpdate(_index, sender);

        uint256 amount = SeigManagerV2I(seigManagerV2).getLwtonToWton(lwton_);

        LibStake.StakeInfo storage info_ = layerStakes[_index][sender];

        if (_debtWton != 0) {
            require(lwton_ + SeigManagerV2I(seigManagerV2).getWtonToLwton(_debtWton) <= info_.stakelwton,'unstake_err_1');
        } else {
            require(lwton_ <= info_.stakelwton,'unstake_err_2');
        }

        info_.stakelwton -= lwton_;
        if (info_.stakePrincipal < amount) info_.stakePrincipal = 0;
        else info_.stakePrincipal -= amount;

        layerStakedLwton[_index] -= lwton_;
        _totalStakedLwton -= lwton_;

        uint256 delay = Layer2ManagerI(layer2Manager).delayBlocksForWithdraw();

        withdrawalRequests[_index][sender].push(LibStake.WithdrawalReqeust({
            withdrawableBlockNumber: uint32(block.number + delay),
            amount: uint128(amount),
            processed: false
        }));

        pendingUnstaked[_index][sender] += amount;
        pendingUnstakedLayer2[_index] += amount;
        pendingUnstakedAccount[sender] += amount;

        emit Unstaked(_index, sender, amount, lwton_);
    }

    function restake(uint32 _index) public
    {
        // require(SeigManagerV2I(seigManagerV2).updateSeigniorage(), 'fail updateSeig');
        uint256 i = withdrawalRequestIndex[_index][msg.sender];
        require(_restake(_index, msg.sender, i, 1),'SL_E_RESTAKE');
    }

    function restakeMulti(uint32 _index, uint256 n) public
    {
        // require(SeigManagerV2I(seigManagerV2).updateSeigniorage(), 'fail updateSeig');
        uint256 i = withdrawalRequestIndex[_index][msg.sender];
        require(_restake(_index, msg.sender, i, n),'SL_E_RESTAKE');
    }

    function _restake(uint32 _index, address sender, uint256 i, uint256 nlength) internal ifFree returns (bool) {

        _beforeUpdate(_index, sender);

        uint256 accAmount;
        uint256 totalRequests = withdrawalRequests[_index][sender].length;

        require(totalRequests > 0, "no unstake");
        require(totalRequests - i >= nlength, "n exceeds num of pending");

        uint256 e = i + nlength;
        for (; i < e; i++) {
            LibStake.WithdrawalReqeust storage r = withdrawalRequests[_index][sender][i];
            uint256 amount = r.amount;
            require(!r.processed, "already withdrawal");
            if (amount > 0) accAmount += amount;
            r.processed = true;
        }

        require(accAmount > 0, "no valid restake amount");

        // deposit-related storages
        uint256 lwton_ = SeigManagerV2I(seigManagerV2).getWtonToLwton(accAmount);
        LibStake.StakeInfo storage info_ = layerStakes[_index][sender];
        info_.stakePrincipal += accAmount;
        info_.stakelwton += lwton_;
        layerStakedLwton[_index] += lwton_;
        _totalStakedLwton += lwton_;

        // withdrawal-related storages
        pendingUnstaked[_index][sender] -= accAmount;
        pendingUnstakedLayer2[_index] -= accAmount;
        pendingUnstakedAccount[sender] -= accAmount;

        withdrawalRequestIndex[_index][sender] += nlength;

        emit Restaked(_index, sender, accAmount, lwton_);
        return true;
    }

    function withdraw(uint32 _index) public ifFree {
        address sender = msg.sender;

        uint256 totalRequests = withdrawalRequests[_index][sender].length;
        uint256 len = 0;
        uint256 amount = 0;

        for(uint256 i = withdrawalRequestIndex[_index][sender]; i < totalRequests ; i++){
            LibStake.WithdrawalReqeust storage r = withdrawalRequests[_index][sender][i];
            if (r.withdrawableBlockNumber < block.number && r.processed == false) {
                r.processed = true;
                amount += uint256(r.amount);
                len++;
            } else {
                break;
            }
        }
        require (amount > 0, 'zero available withdrawal amount');

        withdrawalRequestIndex[_index][sender] += len;
        pendingUnstaked[_index][sender] -= amount;
        pendingUnstakedLayer2[_index] -= amount;
        pendingUnstakedAccount[sender] -= amount;

        uint256 bal = IERC20(wton).balanceOf(address(this));

        if (bal < amount) {
            if (bal > 0) IERC20(wton).safeTransfer(sender, bal);
            SeigManagerV2I(seigManagerV2).claim(sender, (amount - bal));
        } else {
            IERC20(wton).safeTransfer(sender, amount);
        }

        emit Withdrawal(_index, sender, amount);
    }

    /* ========== VIEW ========== */

    function numberOfPendings(uint32 layerIndex, address account)
        public view returns (uint256 totalRequests, uint256 withdrawIndex, uint256 pendingLength)
    {
        totalRequests = withdrawalRequests[layerIndex][account].length;
        withdrawIndex = withdrawalRequestIndex[layerIndex][account];
        if (totalRequests >= withdrawIndex) pendingLength = totalRequests - withdrawIndex;
    }

    function amountOfPendings(uint32 layerIndex, address account)
        public view returns (uint256 amount, uint32 startIndex, uint32 len, uint32 nextWithdrawableBlockNumber)
    {
        uint256 totalRequests = withdrawalRequests[layerIndex][account].length;
        startIndex = uint32(withdrawalRequestIndex[layerIndex][account]);

        for (uint256 i = startIndex; i < totalRequests; i++) {
            LibStake.WithdrawalReqeust memory r = withdrawalRequests[layerIndex][account][i];
            if (r.processed == false) {
                if (nextWithdrawableBlockNumber == 0) nextWithdrawableBlockNumber = r.withdrawableBlockNumber;
                amount += uint256(r.amount);
                len += 1;
            }
        }
    }

    function availableWithdraw(uint32 _index, address account)
        public view returns (uint256 amount, uint32 startIndex, uint32 len)
    {
        uint256 totalRequests = withdrawalRequests[_index][account].length;
        startIndex = uint32(withdrawalRequestIndex[_index][account]);

        for (uint256 i = startIndex; i < totalRequests; i++) {
            LibStake.WithdrawalReqeust memory r = withdrawalRequests[_index][account][i];
            if (r.withdrawableBlockNumber < block.number && r.processed == false) {
                amount += uint256(r.amount);
                len += 1;
            } else {
                break;
            }
        }
    }

    function totalStakedLwton() public view returns (uint256 amount) {
        return _totalStakedLwton;
    }

    function totalStakedLwtonAt(uint256 snapshotId) public view returns (uint256 amount) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _totalStakedLwtonSnapshot);
        return snapshotted ? value : totalStakedLwton();
    }

    function totalStakedLwtonAtSnapshot(uint256 snapshotId) public view returns (bool snapshotted, uint256 amount) {
        return _valueAt(snapshotId, _totalStakedLwtonSnapshot);
    }

    function balanceOfLwton(uint32 _index) public view returns (uint256 amount) {
        amount = layerStakedLwton[_index];
    }

    function balanceOfLwtonAt(uint32 _index, uint256 snapshotId) public view returns (uint256 amount) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _layerStakedLwtonSnapshot[_index]);

        return snapshotted ? value : balanceOfLwton(_index);
    }

    function balanceOfLwtonAtSnapshot(uint32 _index, uint256 snapshotId) public view returns (bool snapshotted, uint256 amount) {
        return _valueAt(snapshotId, _layerStakedLwtonSnapshot[_index]);
    }

    function balanceOfLwton(uint32 _index, address account) public view returns (uint256 amount) {
        LibStake.StakeInfo memory info = layerStakes[_index][account];
        amount = info.stakelwton;
    }

    function balanceOfLwtonAt(uint32 _index, address account, uint256 snapshotId) public view returns (uint256 amount) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _layerStakesSnapshot[_index][account]);
        return snapshotted ? value :  balanceOfLwton(_index, account);
    }

     function balanceOfLwtonAtSnapshot(uint32 _index, address account, uint256 snapshotId) public view returns (bool snapshotted, uint256 amount) {
        return _valueAt(snapshotId, _layerStakesSnapshot[_index][account]);
    }

    function getLayerStakes(uint32 _index, address account) public view returns (LibStake.StakeInfo memory info) {
        info = layerStakes[_index][account];
    }

    function balanceOf(uint32 _index, address account) public view returns (uint256 amount) {
        amount = SeigManagerV2I(seigManagerV2).getLwtonToWton(balanceOfLwton(_index, account));
    }

    function balanceOfAt(uint32 _index, address account, uint256 snapshotId) public view returns (uint256 amount) {
        amount = SeigManagerV2I(seigManagerV2).getLwtonToWtonAt(balanceOfLwtonAt(_index, account, snapshotId), snapshotId);
    }

    function totalLayer2Deposits() public view returns (uint256 amount) {
        amount = Layer2ManagerI(layer2Manager).totalLayer2Deposits();
    }

    function layer2Deposits(uint32 _index) public view returns (uint256 amount) {
        amount = Layer2ManagerI(layer2Manager).layer2Deposits(_index);
    }

    function totalStakeAccountList() public view returns (uint256) {
        return stakeAccountList.length;
    }

    function getTotalLwton() public view returns (uint256) {
        return _totalStakedLwton;
    }

    function getStakeAccountList() public view returns (address[] memory) {
        return stakeAccountList;
    }

    function getPendingUnstakedAmount(uint32 _index, address account) public view returns (uint256) {
        return pendingUnstaked[_index][account];
    }

    function getCurrentSnapshotId() public view virtual returns (uint256) {
        return SeigManagerV2I(seigManagerV2).getCurrentSnapshotId();
    }

    /* ========== internal ========== */

    function _beforeUpdate(uint32 _layerIndex, address account) internal {
        _updateSnapshot(_totalStakedLwtonSnapshot, totalStakedLwton());
        _updateSnapshot(_layerStakedLwtonSnapshot[_layerIndex], balanceOfLwton(_layerIndex));
        _updateSnapshot(_layerStakesSnapshot[_layerIndex][account], balanceOfLwton(_layerIndex, account));
    }

    function _valueAt(uint256 snapshotId, Snapshots storage snapshots) private view returns (bool, uint256) {
        // require(snapshotId > 0, "Snapshot: id is 0");
        require(snapshotId <= getCurrentSnapshotId(), "Snapshot: nonexistent id");

        if (snapshots.ids.length > 0 && snapshotId > snapshots.ids[snapshots.ids.length-1])
            return (false, snapshots.values[snapshots.ids.length-1]);

        uint256 index = snapshots.ids.findIndex(snapshotId);

        if (index >= snapshots.ids.length) return (false, 0);
        return (true, snapshots.values[index]);

    }

    function _updateSnapshot(Snapshots storage snapshots, uint256 currentValue) private {
        uint256 currentId = getCurrentSnapshotId();

        if (snapshots.ids.length == 0 || _lastSnapshotId(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(currentValue);
        }
    }

    function _lastSnapshotId(uint256[] storage ids) private view returns (uint256) {
        if (ids.length == 0) {
            return 0;
        } else {
            return ids[ids.length - 1];
        }
    }

}