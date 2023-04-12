// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./libraries/BytesLib.sol";
import "./storages/StakingStorage.sol";
import "./proxy/BaseProxyStorage.sol";
import "./common/AccessibleCommon.sol";
import "./libraries/SafeERC20.sol";

import "hardhat/console.sol";

interface SeigManagerV2I {
    function getLtonToTon(uint256 lton) external view returns (uint256);
    function getTonToLton(uint256 amount) external view returns (uint256);
    function getTonToSton(uint256 amount) external view returns (uint256);
    function getStonToTon(uint256 ston) external view returns (uint256);
    function updateSeigniorage() external returns (bool);
    function claim(address to, uint256 amount) external;
}

interface Layer2ManagerI {
    function delayBlocksForWithdraw() external view returns (uint256 amount);
    function totalSecurityDeposit() external view returns (uint256 amount);
    function totalLayer2Deposits() external view returns (uint256 amount);
    // function registeredLayerKeys(bytes32 layerKey_) external view returns (bool exist_);
    function existedLayer2Index(uint32 _index) external view returns (bool exist_);
    function existedCandidateIndex(uint32 _index) external view returns (bool exist_);

    function securityDeposit(uint32 layerIndex) external view returns (uint256 amount);
    function layer2Deposits(uint32 layerIndex) external view returns (uint256 amount);

    function minimumDepositForCandidate() external view returns (uint256);
}


contract Staking is AccessibleCommon, BaseProxyStorage, StakingStorage {
    /* ========== DEPENDENCIES ========== */
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    event Staked(uint32 _index, address sender, uint256 amount, uint256 lton, address commissionTo, uint16 commission);
    event Unstaked(uint32 _index, address sender, uint256 amount, uint256 lton);
    event Restaked(uint32 _index, address sender, uint256 amount, uint256 lton);
    event Withdrawal(uint32 _index, address sender, uint256 amount);

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */

    /* ========== Anyone can execute ========== */

    function stake_(uint32 _index, uint256 amount, address commissionTo, uint16 commission) internal
    {
        IERC20(ton).safeTransferFrom(msg.sender, address(this), amount);
        _stake(_index, msg.sender, amount, commissionTo, commission);
    }

    function _stake(uint32 _index, address sender, uint256 amount, address commissionTo, uint16 commission) internal ifFree nonZero(amount)
    {
        uint256 lton_ = SeigManagerV2I(seigManagerV2).getTonToLton(amount);
        layerStakedLton[_index] += lton_;
        totalStakedLton += lton_;

        LibStake.StakeInfo storage info_ = layerStakes[_index][sender];

        if (!info_.stake) {
            info_.stake = true;
            stakeAccountList.push(sender);
        }

        uint256 commissionLton = 0;
        if (commission != 0 && commissionTo != address(0) && commission < 10000) {
            commissionLton = lton_ * commission / 10000;
            lton_ -= commissionLton;

            uint256 amount1 = SeigManagerV2I(seigManagerV2).getLtonToTon(lton_);
            info_.stakePrincipal += amount1;
            info_.stakelton += lton_;

            LibStake.StakeInfo storage commissionInfo_ = layerStakes[_index][commissionTo];
            commissionInfo_.stakePrincipal += (amount - amount1);
            commissionInfo_.stakelton += commissionLton;

        } else {
            info_.stakePrincipal += amount;
            info_.stakelton += lton_;
        }

        emit Staked(_index, sender, amount, lton_, commissionTo, commission);
    }

    function _unstake(uint32 _index, uint256 lton_, uint256 _debtTon) internal ifFree nonZero(lton_)
    {
        // require(SeigManagerV2I(seigManagerV2).updateSeigniorage(), 'fail updateSeig');
        address sender = msg.sender;

        uint256 amount = SeigManagerV2I(seigManagerV2).getLtonToTon(lton_);

        LibStake.StakeInfo storage info_ = layerStakes[_index][sender];

        if (_debtTon != 0) {
            require(lton_ + SeigManagerV2I(seigManagerV2).getTonToLton(_debtTon) <= info_.stakelton,'unstake_err_1');
        } else {
            require(lton_ <= info_.stakelton,'unstake_err_2');
        }

        info_.stakelton -= lton_;
        if (info_.stakePrincipal < amount) info_.stakePrincipal = 0;
        else info_.stakePrincipal -= amount;

        layerStakedLton[_index] -= lton_;
        totalStakedLton -= lton_;

        uint256 delay = Layer2ManagerI(layer2Manager).delayBlocksForWithdraw();

        withdrawalRequests[_index][sender].push(LibStake.WithdrawalReqeust({
            withdrawableBlockNumber: uint32(block.number + delay),
            amount: uint128(amount),
            processed: false
        }));

        pendingUnstaked[_index][sender] += amount;
        pendingUnstakedLayer2[_index] += amount;
        pendingUnstakedAccount[sender] += amount;

        emit Unstaked(_index, sender, amount, lton_);
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
        uint256 lton_ = SeigManagerV2I(seigManagerV2).getTonToLton(accAmount);
        LibStake.StakeInfo storage info_ = layerStakes[_index][sender];
        info_.stakePrincipal += accAmount;
        info_.stakelton += lton_;
        layerStakedLton[_index] += lton_;
        totalStakedLton += lton_;

        // withdrawal-related storages
        pendingUnstaked[_index][sender] -= accAmount;
        pendingUnstakedLayer2[_index] -= accAmount;
        pendingUnstakedAccount[sender] -= accAmount;

        withdrawalRequestIndex[_index][sender] += nlength;

        emit Restaked(_index, sender, accAmount, lton_);
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

        uint256 bal = IERC20(ton).balanceOf(address(this));

        if (bal < amount) {
            if (bal > 0) IERC20(ton).safeTransfer(sender, bal);
            SeigManagerV2I(seigManagerV2).claim(sender, (amount - bal));
        } else {
            IERC20(ton).safeTransfer(sender, amount);
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

    function balanceOfLton(uint32 _index) public view returns (uint256 amount) {
        amount = layerStakedLton[_index];
    }

    function balanceOfLton(uint32 _index, address account) public view returns (uint256 amount) {
        LibStake.StakeInfo memory info = layerStakes[_index][account];
        amount = info.stakelton;
    }

    function getLayerStakes(uint32 _index, address account) public view returns (LibStake.StakeInfo memory info) {
        info = layerStakes[_index][account];
    }

    function balanceOf(uint32 _index, address account) public view returns (uint256 amount) {
        amount = SeigManagerV2I(seigManagerV2).getLtonToTon(balanceOfLton(_index, account));
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

    function getTotalLton() public view returns (uint256) {
        return totalStakedLton;
    }


    function getStakeAccountList() public view returns (address[] memory) {
        return stakeAccountList;
    }

    function getPendingUnstakedAmount(uint32 _index, address account) public view returns (uint256) {
        return pendingUnstaked[_index][account];
    }



    /* ========== internal ========== */


}