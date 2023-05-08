// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;
import "../libraries/LibStake.sol";

/**
 * @title   Staking
 * @dev     There are stake, unsatke, withdraw, fast withdraw functions.
 */
interface IStaking {

    event Staked(uint32 _index, address sender, uint256 amount, uint256 lton, address commissionTo, uint16 commission);
    event Unstaked(uint32 _index, address sender, uint256 amount, uint256 lton);
    event Restaked(uint32 _index, address sender, uint256 amount, uint256 lton);
    event Withdrawal(uint32 _index, address sender, uint256 amount);
    event FastWithdrawalClaim(bytes32 hashMessage, uint32 layerIndex, address from, address to, uint256 amount);
    event FastWithdrawalStaked(bytes32 hashMessage, uint32 layerIndex, address staker, uint256 amount, uint256 lton);

    /* ========== only Receipt ========== */
    function fastWithdrawClaim(bytes32 hashMessage, uint32 layerIndex, address from, address to, uint256 amount) external returns (bool);
    function fastWithdrawStake(bytes32 hashMessage, uint32 layerIndex, address staker, uint256 _amount) external returns (bool);


    /* ========== Anyone can execute ========== */
    function restake(uint32 _index) external;
    function restakeMulti(uint32 _index, uint256 n) external;
    function withdraw(uint32 _index) external ;

    /* ========== VIEW ========== */
    function numberOfPendings(uint32 layerIndex, address account)
        external view returns (uint256 totalRequests, uint256 withdrawIndex, uint256 pendingLength);

    function amountOfPendings(uint32 layerIndex, address account)
        external view returns (uint256 amount, uint32 startIndex, uint32 len, uint32 nextWithdrawableBlockNumber);

    function availableWithdraw(uint32 _index, address account)
        external view returns (uint256 amount, uint32 startIndex, uint32 len);

    function totalStakedLton() external view returns (uint256 amount);

    function totalStakedLtonAt(uint256 snapshotId) external view returns (uint256 amount) ;
    function totalStakedLtonAtSnapshot(uint256 snapshotId) external view returns (bool snapshotted, uint256 amount) ;
    function balanceOfLton(uint32 _index) external view returns (uint256 amount) ;
    function balanceOfLtonAt(uint32 _index, uint256 snapshotId) external view returns (uint256 amount) ;

    function balanceOfLtonAtSnapshot(uint32 _index, uint256 snapshotId) external view returns (bool snapshotted, uint256 amount) ;
    function balanceOfLton(uint32 _index, address account) external view returns (uint256 amount);
    function balanceOfLtonAt(uint32 _index, address account, uint256 snapshotId) external view returns (uint256 amount);
    function balanceOfLtonAtSnapshot(uint32 _index, address account, uint256 snapshotId) external view returns (bool snapshotted, uint256 amount) ;
    function getLayerStakes(uint32 _index, address account) external view returns (LibStake.StakeInfo memory info) ;
    function balanceOf(uint32 _index, address account) external view returns (uint256 amount);
    function balanceOfAt(uint32 _index, address account, uint256 snapshotId) external view returns (uint256 amount);
    function totalLayer2Deposits() external view returns (uint256 amount) ;
    function layer2Deposits(uint32 _index) external view returns (uint256 amount) ;
    function totalStakeAccountList() external view returns (uint256) ;
    function getTotalLton() external view returns (uint256);
    function getStakeAccountList() external view returns (address[] memory) ;
    function getPendingUnstakedAmount(uint32 _index, address account) external view returns (uint256) ;
    function getCurrentSnapshotId() external view returns (uint256);

}