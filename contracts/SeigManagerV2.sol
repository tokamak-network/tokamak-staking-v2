// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./SeigManagerV2Storage.sol";
import "./proxy/BaseProxyStorage.sol";
import "./common/AccessibleCommon.sol";
import "./libraries/SafeERC20.sol";

import "hardhat/console.sol";

interface AutoRefactorCoinageI {
    function totalSupply() external view returns (uint256);
}

interface Layer2ManagerI {
    function updateLayer2Deposits() external returns (uint256 prevTotal, uint256 curTotal);

    function totalSecurityDeposit() external view returns (uint256 amount);
    function totalLayer2Deposits() external view returns (uint256 amount);
    function curTotalLayer2Deposits() external view returns (uint256 amount);

    function securityDeposit(bytes32 _key) external view returns (uint256 amount);
    function layer2Deposits(bytes32 _key) external view returns (uint256 amount);
}

interface StakingLayer2I {
    function getTotalLton() external view returns (uint256) ;
}

contract SeigManagerV2 is AccessibleCommon, BaseProxyStorage, SeigManagerV2Storage {
    /* ========== DEPENDENCIES ========== */
    using SafeERC20 for IERC20;

    event UpdatedSeigniorage(
                    uint256 lastSeigBlock_,
                    uint256 increaseSeig_,
                    uint256 totalSupplyOfTon_,
                    uint256[4] amount_,
                    uint256[2] prevIndex_,
                    uint256[2] index_
                    );

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

        ratesDao = _ratesDao;
        ratesStosHolders = _ratesStosHolders;
        ratesTonStakers = _ratesTonStakers;
        ratesUnits = _ratesUnits;
    }

    function setAddress(address _dao, address _stosDistribute) external onlyOwner {
        require(
            !(dao == _dao  &&
            stosDistribute == _stosDistribute), "same");

        dao = _dao;
        stosDistribute = _stosDistribute;
    }

    /* ========== Anyone can execute ========== */

    function updateSeigniorage() public returns (bool res) {
        if (lastSeigBlock + uint256(minimumBlocksForUpdateSeig) < getCurrentBlockNumber()) {
            res = runUpdateSeigniorage();
        }
        return true;
    }

    function runUpdateSeigniorage() public ifFree nonZero(startBlock) returns (bool res) {
        // console.log('-------------------');
        // console.log('lastSeigBlock %s',lastSeigBlock);
        // console.log('getCurrentBlockNumber() %s',getCurrentBlockNumber());

        if (lastSeigBlock <  getCurrentBlockNumber()) {
            // 총 증가량  increaseSeig
            uint256 increaseSeig = (getCurrentBlockNumber() - lastSeigBlock) * seigPerBlock;

            // update L2 TVL
            // Layer2ManagerI(layer2Manager).updateLayer2Deposits();

            uint256 totalLton = getTotalLton();
            // console.log('totalLton %s',totalLton);

            // calculate the increase amount of seig
            (
                uint256 totalSupplyOfTon,
                uint256 amountOflton,
                uint256 amountOfston,
                uint256 amountOfDao,
                uint256 amountOfStosHolders
            ) = _distribute(increaseSeig, totalLton);

            // console.log('increaseSeig %s',increaseSeig);
            // console.log('totalSupplyOfTon %s',totalSupplyOfTon);
            // console.log('amountOflton %s',amountOflton);
            // console.log('amountOfston %s',amountOfston);
            // console.log('amountOfDao %s',amountOfDao);
            // console.log('amountOfStosHolders %s',amountOfStosHolders);

            uint256[2] memory prevIndex = [indexLton, indexSton];

            // 1. update indexLton, indexSton
            if (totalLton != 0 && amountOflton != 0)
                indexLton = calculateIndex(indexLton, getLtonToTon(totalLton), amountOflton);
            if (indexSton == 1 ether && totalSton == 0) {
                totalSton = amountOfston;
            } else if (amountOfston != 0) indexSton = calculateIndex(indexSton, getStonToTon(totalSton), amountOfston);

            // console.log('indexLton %s',indexLton);
            // 2. mint increaseSeig of ton in address(this)
            if (increaseSeig != 0) ton.mint(address(this), increaseSeig);

            // 3. transfer amountOfDao,amountOfStosHolders  (to dao, powerTON for tosHolders)
            if (amountOfDao != 0 && dao != address(0)) ton.safeTransfer(dao, amountOfDao);
            if (amountOfStosHolders != 0 && stosDistribute != address(0)) ton.safeTransfer(stosDistribute, amountOfStosHolders);

            lastSeigBlock = getCurrentBlockNumber();
            // console.log('lastSeigBlock %s',lastSeigBlock);

            // console.log('indexLton %s',indexLton);
            // console.log('indexSton %s',indexSton);

            emit UpdatedSeigniorage(
                lastSeigBlock,
                increaseSeig,
                totalSupplyOfTon,
                [amountOflton, amountOfston, amountOfDao, amountOfStosHolders],
                prevIndex,
                [indexLton, indexSton]
                );
        }
        return true;
    }

    /* ========== VIEW ========== */
    function getTonToLton(uint256 _amount) public view returns (uint256 amount) {
        if (_amount > 0) amount = (_amount * 1e18) / indexLton;
    }

    function getTonToSton(uint256 _amount) public view returns (uint256 amount) {
        if (_amount > 0)  amount = (_amount * 1e18) / indexSton;
    }

    function getLtonToTon(uint256 lton) public view returns (uint256 amount) {
        if (lton > 0) amount = (lton * indexLton) / 1e18;
    }

    function getStonToTon(uint256 ston) public view returns (uint256 amount) {
        if (ston > 0) amount = (ston * indexSton) / 1e18;
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

    function totalSecurityDeposit() public view returns (uint256 amount) {
        amount = Layer2ManagerI(layer2Manager).totalSecurityDeposit();
    }

    function curTotalLayer2Deposits() public view returns (uint256 amount) {
        amount = Layer2ManagerI(layer2Manager).curTotalLayer2Deposits();
    }

    function totalSupplyTON() public view returns (uint256 amount) {
        // 톤의 총공급량 = ton.totalSupply() - ton.balacneOf(wton)
        // + ((total staked amount in stakingV1)/1e-9)
        amount = ton.totalSupply() + ton.balanceOf(wton) + AutoRefactorCoinageI(tot).totalSupply();

        // l2로 들어간것과 스테이킹 되는 것이 ton으로 이루어진다면 위의 총공급량으로만 집계 해도 된다.
    }

    function getTotalLton() public view returns (uint256 amount) {
        amount = StakingLayer2I(stakingLayer2).getTotalLton();
    }

    /* ========== internal ========== */

    function _distribute(uint256 amount, uint256 totalLton) internal view returns (
        uint256 totalSupplyOfTon,
        uint256 amountOflton,
        uint256 amountOfston,
        uint256 amountOfDao,
        uint256 amountOfStosHolders
    ){
        totalSupplyOfTon = totalSupplyTON();
        if (totalSupplyOfTon != 0) {
            // console.log('amount %s', amount);
            // console.log('getLtonToTon(totalLton) %s', getLtonToTon(totalLton));

            // 1. (S/T) * TON seigniorage
            //    TON stakers
            if (totalLton != 0) amountOflton = amount *  getLtonToTon(totalLton) / totalSupplyOfTon  ;

            // 2. ((D+C)/T) * TON seigniorage
            //    to sequencer, D layer 2 reserve, C sequencer deposit
            uint256 amountOfCD = curTotalLayer2Deposits() + totalSecurityDeposit();

            if (amountOfCD != 0) amountOfston = amount * amountOfCD / totalSupplyOfTon ;

            uint256 amount1 = amount - amountOflton - amountOfston;

            if (amount1 > 0 && ratesUnits != 0) {
                // 3. 0.4 * ((T-S-D-C)/T) * TON seigniorage
                //    TON stakers
                if (ratesTonStakers != 0) amountOflton += amount1 * ratesTonStakers / ratesUnits;

                // 4. 0.5 * ((T-S-D-C)/T) * TON seigniorage
                //    TON DAO
                if (ratesDao != 0) amountOfDao = amount1 * ratesDao / ratesUnits;

                // 5. 0.1 * ((T-S-D-C)/T) * TON seigniorage
                //    sTOS holders
                if (ratesStosHolders != 0) amountOfStosHolders = amount1 * ratesStosHolders / ratesUnits;
            }
        }
    }


}
