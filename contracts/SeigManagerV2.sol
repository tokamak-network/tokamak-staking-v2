// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./storages/SeigManagerV2Storage.sol";
import "./proxy/BaseProxyStorage.sol";
import "./common/AccessibleCommon.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/Layer2.sol";
import "./libraries/LibArrays.sol";

// import "hardhat/console.sol";

interface AutoRefactorCoinageI {
    function totalSupply() external view returns (uint256);
}

interface Layer2ManagerI {
    function curTotalAmountsLayer2() external view returns (uint256 amount);
    function addSeigs(uint256 amount) external returns (bool);
}

interface StakingI {
    function getTotalLton() external view returns (uint256) ;
}

contract SeigManagerV2 is AccessibleCommon, BaseProxyStorage, SeigManagerV2Storage {
    /* ========== DEPENDENCIES ========== */
    using SafeERC20 for IERC20;
    using LibArrays for uint256[];

    event Snapshot(uint256 id, uint256 snapshotTime);
    event UpdatedSeigniorage(
                    uint256 lastSeigBlock_,
                    uint256 increaseSeig_,
                    uint256 totalSupplyOfTon_,
                    uint256[4] amount_,
                    uint256 prevIndex_,
                    uint256 index_
                    );

    event Claimed(address caller, address to, uint256 amount);

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */

    function setSeigPerBlock(uint256 _seigPerBlock) external onlyOwner {
        require(seigPerBlock != _seigPerBlock, "same");
        seigPerBlock = _seigPerBlock;
    }

    function setMinimumBlocksForUpdateSeig(uint32 _minimumBlocksForUpdateSeig) external onlyOwner {
        require(minimumBlocksForUpdateSeig != _minimumBlocksForUpdateSeig, "same");
        minimumBlocksForUpdateSeig = _minimumBlocksForUpdateSeig;
    }

    function setLastSeigBlock(uint256 _lastSeigBlock) external onlyOwner nonZero(_lastSeigBlock) {
        require(lastSeigBlock != _lastSeigBlock, "same");
        lastSeigBlock = _lastSeigBlock;
        if (startBlock == 0) startBlock = _lastSeigBlock;
    }

    function setDividendRates(uint16 _ratesDao, uint16 _ratesStosHolders, uint16 _ratesTonStakers, uint16 _ratesUnits) external onlyOwner {
        require(
            !(ratesDao == _ratesDao  &&
            ratesStosHolders == _ratesStosHolders &&
            ratesTonStakers == _ratesTonStakers &&
            ratesUnits == _ratesUnits), "same");
        require(_ratesUnits != 0, "wrong ratesUnits");
        require((_ratesDao + _ratesStosHolders + _ratesTonStakers) ==  _ratesUnits, 'sum of ratio is wrong');

        ratesDao = _ratesDao;
        ratesStosHolders = _ratesStosHolders;
        ratesTonStakers = _ratesTonStakers;
        ratesUnits = _ratesUnits;
    }

    function setAddress(address _dao, address _stosDistribute) external onlyOwner {
        require(!(dao == _dao && stosDistribute == _stosDistribute), "same");

        dao = _dao;
        stosDistribute = _stosDistribute;
    }

    /* ========== only Layer2Manager Or Optimism ========== */

    function claim(address _to, uint256 _amount) external {

        require(
            msg.sender != address(0) ||
            msg.sender == layer2Manager ||
            msg.sender == optimismSequencer ||
            msg.sender == candidate
            , "SM_E1"
        );

        require(_amount <= ton.balanceOf(address(this)), 'insufficient TON balance');
        ton.safeTransfer(_to, _amount);

        emit Claimed(msg.sender, _to, _amount);
    }

    /* ========== Anyone can execute ========== */

    function snapshot() external virtual returns (uint256) {
        return _snapshot();
    }

    function getCurrentSnapshotId() public view virtual returns (uint256) {
        return _currentSnapshotId;
    }

    function getSnapshotTime() public view returns (uint32[] memory) {
        return snapshotTime;
    }

    function indexLton() public view returns (uint256) {
        return _indexLton;
    }

    function indexLtonAt(uint256 snapshotId) public view returns (uint256) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _indexLtonSnapshots);

        return snapshotted ? value : indexLton();
    }

    function indexLtonAtSnapshot(uint256 snapshotId) public view returns (bool snapshotted, uint256 value) {
        return _valueAt(snapshotId, _indexLtonSnapshots);
    }

    function updateSeigniorage() external returns (bool res) {
        if (lastSeigBlock + uint256(minimumBlocksForUpdateSeig) < getCurrentBlockNumber()) {
            res = runUpdateSeigniorage();
        }
        return true;
    }

    function runUpdateSeigniorage() public ifFree nonZero(startBlock) returns (bool res) {
        // console.log('-------------------');

        if (lastSeigBlock <  getCurrentBlockNumber() && lastSeigBlock != 0) {
            // 총 증가량  increaseSeig
            uint256 increaseSeig = (getCurrentBlockNumber() - lastSeigBlock) * seigPerBlock;
            // console.log('increaseSeig %s',increaseSeig);

            // update L2 TVL
            // Layer2ManagerI(layer2Manager).updateLayer2Deposits();

            uint256 totalLton = getTotalLton();
            // console.log('totalLton %s',totalLton);

            // calculate the increase amount of seig
            (
                uint256 totalSupplyOfTon,
                uint256 amountOfstaker,
                uint256 amountOfsequencer,
                uint256 amountOfDao,
                uint256 amountOfStosHolders
            ) = _distribute(increaseSeig, totalLton);

            uint256 prevIndex = _indexLton;

            // 1. update indexLton
            if (totalLton != 0 && amountOfstaker != 0){
                _indexLton = calculateIndex(prevIndex, getLtonToTon(totalLton), amountOfstaker);

            }

            // 2. mint increaseSeig of ton in address(this)
            if (increaseSeig != 0) ton.mint(address(this), increaseSeig);

            // 3. give amountOfsequencer
            if (amountOfsequencer != 0)
                require(Layer2ManagerI(layer2Manager).addSeigs(amountOfsequencer),'FAIL addSeigs');

            // 3. transfer amountOfDao,amountOfStosHolders  (to dao, powerTON for tosHolders)
            if (amountOfDao != 0 && dao != address(0)) ton.safeTransfer(dao, amountOfDao);
            if (amountOfStosHolders != 0 && stosDistribute != address(0)) ton.safeTransfer(stosDistribute, amountOfStosHolders);

            lastSeigBlock = getCurrentBlockNumber();

            emit UpdatedSeigniorage(
                lastSeigBlock,
                increaseSeig,
                totalSupplyOfTon,
                [amountOfstaker, amountOfsequencer, amountOfDao, amountOfStosHolders],
                prevIndex,
                _indexLton
                );
        }
        return true;
    }

    /* ========== VIEW ========== */

    function mintableSeigsAmount() external view returns (uint256 amount) {
        if (lastSeigBlock <  getCurrentBlockNumber() && lastSeigBlock != 0) {
            amount = (getCurrentBlockNumber() - lastSeigBlock) * seigPerBlock;
        }
    }

    function getTonToLton(uint256 _amount) public view returns (uint256 amount) {
        if (_amount > 0) amount = (_amount * 1e18) / indexLton();
    }

    function getTonToLtonAt(uint256 _amount, uint256 _snapshotId) public view returns (uint256 amount) {
        if (_amount > 0) amount = (_amount * 1e18) / indexLtonAt(_snapshotId);
    }

    function getLtonToTon(uint256 lton) public view returns (uint256 amount) {
        if (lton > 0) amount = (lton * indexLton()) / 1e18;
    }

    function getLtonToTonAt(uint256 lton, uint256 _snapshotId) public view returns (uint256 amount) {
        if (lton > 0) amount = (lton * indexLtonAt(_snapshotId)) / 1e18;
    }

    function getCurrentBlockNumber() public view returns (uint256) {
        return block.number;
    }

    function calculateIndex(uint256 curIndex, uint256 curTotal, uint256 increaseAmount)
        public pure returns (uint256 nextIndex)
    {
        if (curTotal != 0 && increaseAmount !=0) nextIndex = curIndex * (curTotal + increaseAmount) / curTotal;
        else nextIndex = curIndex;
    }

    function totalSupplyTON() public view returns (uint256 amount) {
        // 톤의 총공급량 = ton.totalSupply() - ton.balacneOf(wton)
        // + ((total staked amount in stakingV1)/1e-9)
        amount = ton.totalSupply() + ton.balanceOf(wton) + AutoRefactorCoinageI(tot).totalSupply();

        // l2로 들어간것과 스테이킹 되는 것이 ton으로 이루어진다면 위의 총공급량으로만 집계 해도 된다.
    }

    function getTotalLton() public view returns (uint256 amount) {
        amount = StakingI(optimismSequencer).getTotalLton() + StakingI(candidate).getTotalLton();
    }

    function getTotalLtonAt(uint256 _snapshotId) public view returns (uint256 amount) {
        amount = StakingI(optimismSequencer).getTotalLtonAt(_snapshotId) + StakingI(candidate).getTotalLtonAt(_snapshotId);
    }

    /* ========== internal ========== */

    function _distribute(uint256 amount, uint256 totalLton) internal view returns (
        uint256 totalSupplyOfTon,
        uint256 amountOfstaker,
        uint256 amountOfsequencer,
        uint256 amountOfDao,
        uint256 amountOfStosHolders
    ){
        totalSupplyOfTon = totalSupplyTON();
        if (totalSupplyOfTon != 0) {
            // console.log('amount %s', amount);
            // console.log('getLtonToTon(totalLton) %s', getLtonToTon(totalLton));

            // 1. (S/T) * TON seigniorage
            //    TON stakers
            if (totalLton != 0) amountOfstaker = amount *  getLtonToTon(totalLton) / totalSupplyOfTon  ;

            // 2. ((D+C)/T) * TON seigniorage
            //    to sequencer, D layer 2 reserve, C sequencer deposit
            uint256 amountOfCD = Layer2ManagerI(layer2Manager).curTotalAmountsLayer2();

            if (amountOfCD != 0){
                amountOfsequencer = amount * amountOfCD / totalSupplyOfTon ;
            }

            uint256 amount1 = amount - amountOfstaker - amountOfsequencer;

            if (amount1 > 0 && ratesUnits != 0) {
                // 3. 0.4 * ((T-S-D-C)/T) * TON seigniorage
                //    TON stakers
                if (ratesTonStakers != 0) amountOfstaker += amount1 * ratesTonStakers / ratesUnits;

                // 4. 0.5 * ((T-S-D-C)/T) * TON seigniorage
                //    TON DAO
                if (ratesDao != 0) amountOfDao = amount1 * ratesDao / ratesUnits;

                // 5. 0.1 * ((T-S-D-C)/T) * TON seigniorage
                //    sTOS holders
                if (ratesStosHolders != 0) amountOfStosHolders = amount1 * ratesStosHolders / ratesUnits;
            }
        }
    }


    function _snapshot() internal virtual returns (uint256) {
        if (snapshotTime.length == 0) {
            snapshotTime.push(uint32(0));
            _indexLtonSnapshots.ids.push(0);
            _indexLtonSnapshots.values.push(1 ether);
        }

        snapshotTime.push(uint32(block.timestamp));
        _currentSnapshotId += 1;
        _updateSnapshot(_indexLtonSnapshots, _indexLton);

        emit Snapshot(_currentSnapshotId, block.timestamp);
        return _currentSnapshotId;
    }

    function _valueAt(uint256 snapshotId, Snapshots storage snapshots) private view returns (bool, uint256) {
        // require(snapshotId > 0, "Snapshot: id is 0");
        require(snapshotId <= getCurrentSnapshotId(), "Snapshot: nonexistent id");

        if (snapshots.ids.length > 0 && snapshotId > snapshots.ids[snapshots.ids.length-1])
            return (false, snapshots.values[snapshots.ids.length-1]);

        uint256 index = snapshots.ids.findIndex(snapshotId);
        if (index == snapshots.ids.length) return (false, 0);
        return (true, snapshots.values[index]);
    }

    function _updateSnapshot(Snapshots storage snapshots, uint256 currentValue) private {
        uint256 currentId = getCurrentSnapshotId();
        if (_lastSnapshotId(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(currentValue);
        }
    }

    function _lastSnapshotId(uint256[] storage ids) private view returns (uint256) {
        if (ids.length == 0)  return 0;
        return ids[ids.length - 1];

    }

}
