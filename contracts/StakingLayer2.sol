// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./StakingLayer2Storage.sol";
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
    function registeredLayerKeys(bytes32 layerKey_) external view returns (bool exist_);

    function securityDeposit(bytes32 _key) external view returns (uint256 amount);
    function layer2Deposits(bytes32 _key) external view returns (uint256 amount);
}


contract StakingLayer2 is AccessibleCommon, BaseProxyStorage, StakingLayer2Storage {
    /* ========== DEPENDENCIES ========== */
    using SafeERC20 for IERC20;

    event Staked(bytes32 layerKey, address sender, uint256 amount, uint256 lton);
    event Unstaked(bytes32 layerKey, address sender, uint256 amount, uint256 lton);
    event Restaked(bytes32 layerKey, address sender, uint256 amount, uint256 lton);
    event Withdrawal(bytes32 layerKey, address sender, uint256 amount);

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return _supportedInterfaces[interfaceId] || super.supportsInterface(interfaceId);
    }

    /* ========== onlyOwner ========== */


    /* ========== only TON ========== */
    function onApprove(
        address sender,
        address spender,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {

        require(ton == msg.sender, "EA");
        // data : (32 bytes)layerKey
        require(Layer2ManagerI(layer2Manager).registeredLayerKeys(bytes32(data)), 'non-registered layer');
        require(SeigManagerV2I(seigManagerV2).updateSeigniorage(), 'fail updateSeig');

        IERC20(ton).safeTransferFrom(sender, address(this), amount);
        _stake(bytes32(data), sender, amount);

        return true;
    }

    /* ========== Anyone can execute ========== */

    function stake(bytes32 layerKey, uint256 amount) external nonZero(amount)
    {
        require(Layer2ManagerI(layer2Manager).registeredLayerKeys(layerKey), 'non-registered layer');
        require(SeigManagerV2I(seigManagerV2).updateSeigniorage(), 'fail updateSeig');
        address sender = msg.sender;
        IERC20(ton).safeTransferFrom(sender, address(this), amount);
        _stake(layerKey, sender, amount);
    }

    function _stake(bytes32 layerKey, address sender, uint256 amount) internal ifFree nonZero(amount)
    {
        uint256 lton_ = SeigManagerV2I(seigManagerV2).getTonToLton(amount);
        LibStake.StakeInfo storage info_ = layerStakes[layerKey][sender];

        if (!info_.staker) {
            info_.staker = true;
            stakeAccountList.push(sender);
        }

        info_.stakePrincipal += amount;
        info_.stakelton += lton_;

        layerStakedLton[layerKey] += lton_;
        totalStakedLton += lton_;

        emit Staked(layerKey, sender, amount, lton_);
    }


    function unstake(bytes32 layerKey, uint256 lton_)
        public ifFree nonZero(lton_)
    {
        // require(SeigManagerV2I(seigManagerV2).updateSeigniorage(), 'fail updateSeig');
        address sender = msg.sender;

        uint256 amount = SeigManagerV2I(seigManagerV2).getLtonToTon(lton_);
        LibStake.StakeInfo storage info_ = layerStakes[layerKey][sender];
        require(lton_ <= info_.stakelton,'SL_1');

        info_.stakelton -= lton_;
        if (info_.stakePrincipal < amount) info_.stakePrincipal = 0;
        else info_.stakePrincipal -= amount;

        layerStakedLton[layerKey] -= lton_;
        totalStakedLton -= lton_;

        uint256 delay = Layer2ManagerI(layer2Manager).delayBlocksForWithdraw();

        withdrawalRequests[layerKey][sender].push(LibStake.WithdrawalReqeust({
            withdrawableBlockNumber: uint32(block.number + delay),
            amount: uint128(amount),
            processed: false
        }));

        _pendingUnstaked[layerKey][sender] += amount;
        _pendingUnstakedLayer2[layerKey] += amount;
        _pendingUnstakedAccount[sender] += amount;

        emit Unstaked(layerKey, sender, amount, lton_);
    }

    function restake(bytes32 layerKey) public
    {
        require(SeigManagerV2I(seigManagerV2).updateSeigniorage(), 'fail updateSeig');
        uint256 i = withdrawalRequestIndex[layerKey][msg.sender];
        require(_restake(layerKey, msg.sender, i, 1),'SL_E_RESTAKE');
    }

    function restakeMulti(bytes32 layerKey, uint256 n) public
    {
        require(SeigManagerV2I(seigManagerV2).updateSeigniorage(), 'fail updateSeig');
        uint256 i = withdrawalRequestIndex[layerKey][msg.sender];
        require(_restake(layerKey, msg.sender, i, n),'SL_E_RESTAKE');
    }

    function _restake(bytes32 layerKey, address sender, uint256 i, uint256 nlength) internal ifFree returns (bool) {
        uint256 accAmount;
        uint256 totalRequests = withdrawalRequests[layerKey][sender].length;

        require(totalRequests > 0, "no unstake");
        require(totalRequests - i >= nlength, "n exceeds num of pending");

        uint256 e = i + nlength;
        for (; i < e; i++) {
            LibStake.WithdrawalReqeust storage r = withdrawalRequests[layerKey][sender][i];
            uint256 amount = r.amount;
            require(!r.processed, "already withdrawal");
            if (amount > 0) accAmount += amount;
            r.processed = true;
        }

        require(accAmount > 0, "no valid restake amount");

        // deposit-related storages
        uint256 lton_ = SeigManagerV2I(seigManagerV2).getTonToLton(accAmount);
        LibStake.StakeInfo storage info_ = layerStakes[layerKey][sender];
        info_.stakePrincipal += accAmount;
        info_.stakelton += lton_;
        layerStakedLton[layerKey] += lton_;
        totalStakedLton += lton_;

        // withdrawal-related storages
        _pendingUnstaked[layerKey][sender] -= accAmount;
        _pendingUnstakedLayer2[layerKey] -= accAmount;
        _pendingUnstakedAccount[sender] -= accAmount;

        withdrawalRequestIndex[layerKey][sender] += nlength;

        emit Restaked(layerKey, sender, accAmount, lton_);
        return true;
    }



    function withdraw(bytes32 layerKey) public ifFree {
        address sender = msg.sender;

        uint256 totalRequests = withdrawalRequests[layerKey][sender].length;
        uint256 len = 0;
        uint256 amount = 0;

        for(uint256 i = withdrawalRequestIndex[layerKey][sender]; i < totalRequests ; i++){
            LibStake.WithdrawalReqeust storage r = withdrawalRequests[layerKey][sender][i];
            if (r.withdrawableBlockNumber < block.number && r.processed == false) {
                r.processed = true;
                amount += uint256(r.amount);
                len++;
            } else {
                break;
            }
        }
        require (amount > 0, 'zero available withdrawal amount');

        withdrawalRequestIndex[layerKey][sender] += len;
        _pendingUnstaked[layerKey][sender] -= amount;
        _pendingUnstakedLayer2[layerKey] -= amount;
        _pendingUnstakedAccount[sender] -= amount;

        uint256 bal = IERC20(ton).balanceOf(address(this));

        if (bal < amount) {
            if (bal > 0) IERC20(ton).safeTransfer(sender, bal);
            SeigManagerV2I(seigManagerV2).claim(sender, (amount - bal));
        } else {
            IERC20(ton).safeTransfer(sender, amount);
        }

        emit Withdrawal(layerKey, sender, amount);
    }

    /* ========== VIEW ========== */

    function numberOfPendings(bytes32 layerKey, address account)
        public view returns (uint256 totalRequests, uint256 withdrawIndex, uint256 pendingLength)
    {
        totalRequests = withdrawalRequests[layerKey][account].length;
        withdrawIndex = withdrawalRequestIndex[layerKey][account];
        if (totalRequests >= withdrawIndex) pendingLength = totalRequests - withdrawIndex;
    }

    function amountOfPendings(bytes32 layerKey, address account)
        public view returns (uint256 amount, uint32 startIndex, uint32 len, uint32 nextWithdrawableBlockNumber)
    {
        uint256 totalRequests = withdrawalRequests[layerKey][account].length;
        startIndex = uint32(withdrawalRequestIndex[layerKey][account]);

        for (uint256 i = startIndex; i < totalRequests; i++) {
            LibStake.WithdrawalReqeust memory r = withdrawalRequests[layerKey][account][i];
            if (r.processed == false) {
                if (nextWithdrawableBlockNumber == 0) nextWithdrawableBlockNumber = r.withdrawableBlockNumber;
                amount += uint256(r.amount);
                len += 1;
            }
        }
    }

    function availableWithdraw(bytes32 layerKey, address account)
        public view returns (uint256 amount, uint32 startIndex, uint32 len)
    {
        uint256 totalRequests = withdrawalRequests[layerKey][account].length;
        startIndex = uint32(withdrawalRequestIndex[layerKey][account]);

        for (uint256 i = startIndex; i < totalRequests; i++) {
            LibStake.WithdrawalReqeust memory r = withdrawalRequests[layerKey][account][i];
            if (r.withdrawableBlockNumber < block.number && r.processed == false) {
                amount += uint256(r.amount);
                len += 1;
            } else {
                break;
            }
        }
    }

    function balanceOfLton(bytes32 layerKey) public view returns (uint256 amount) {
        amount = layerStakedLton[layerKey];
    }

    function balanceOfLton(bytes32 layerKey, address account) public view returns (uint256 amount) {
        LibStake.StakeInfo memory info = layerStakes[layerKey][account];
        amount = info.stakelton;
    }

    function balanceOf(bytes32 layerKey, address account) public view returns (uint256 amount) {
        amount = SeigManagerV2I(seigManagerV2).getLtonToTon(balanceOfLton(layerKey, account));
    }

    function liquidityOfLton(bytes32 layerKey, address account) public view returns (uint256 amount) {
        LibStake.StakeInfo memory info = layerStakes[layerKey][account];
        amount = info.bondlton;
    }

    function liquidityOf(bytes32 layerKey, address account) public view returns (uint256 amount) {
        amount = SeigManagerV2I(seigManagerV2).getLtonToTon(liquidityOfLton(layerKey, account));
    }

    function totalLayer2Deposits() public view returns (uint256 amount) {
        amount = Layer2ManagerI(layer2Manager).totalLayer2Deposits();
    }

    function layer2Deposits(bytes32 layerKey) public view returns (uint256 amount) {
        amount = Layer2ManagerI(layer2Manager).layer2Deposits(layerKey);
    }

    function totalStakeAccountList() public view returns (uint256) {
        return stakeAccountList.length;
    }

    function totalBondAccountList() public view returns (uint256) {
        return bondAccountList.length;
    }

    function getTotalLton() public view returns (uint256) {
        return (totalStakedLton + totalBondedLton);
    }


    /* ========== internal ========== */


}