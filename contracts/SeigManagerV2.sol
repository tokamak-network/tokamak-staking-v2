// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./SeigManagerV2Storage.sol";
import "./proxy/BaseProxyStorage.sol";
import "./common/AccessibleCommon.sol";
import "./libraries/SafeERC20.sol";

// import "hardhat/console.sol";

interface AutoRefactorCoinageI {
    function totalSupply() external view returns (uint256);
}

interface Layer2ManagerI {
    function updateLayer2Deposits() external returns (uint256 prevTotal, uint256 curTotal);

    function totalSecurityDeposit() external view returns (uint256 amount);
    function totalLayer2Deposits() external view returns (uint256 amount);

    function securityDeposit(bytes32 _key) external view returns (uint256 amount);
    function layer2Deposits(bytes32 _key) external view returns (uint256 amount);
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

    function setLastSeigBlock(uint256 _lastSeigBlock) external onlyOwner nonZero(_lastSeigBlock){
        require(lastSeigBlock == 0, "already setLastSeigBlock");
        lastSeigBlock = _lastSeigBlock;
        startBlock = _lastSeigBlock;
    }

    /* ========== Anyone can execute ========== */


    function updateSeigniorage() public ifFree nonZero(startBlock) returns (bool res) {

        // 최근 이자 적용 이후, minimumBlocksforUpdateSeig 블록이 지나면 이자가 적용될 수 있다.
        if (lastSeigBlock + uint256(minimumBlocksforUpdateSeig) < getCurrentBlockNumber()) {

            // 총 증가량  increaseSeig
            uint256 increaseSeig = (getCurrentBlockNumber() - lastSeigBlock) * seigPerBlock;

            // update L2 TVL
            (, uint256 curTvlTon) = Layer2ManagerI(layer2Manager).updateLayer2Deposits();
            totalSton = getTonToSton(curTvlTon);

            // calculate the increase amount of seig
            (
                uint256 totalSupplyOfTon,
                uint256 amountOflton,
                uint256 amountOfston,
                uint256 amountOfDao,
                uint256 amountOfStosHolders
            ) = _distribute(increaseSeig);

            uint256[2] memory prevIndex = [indexLton, indexSton];

            // 1. update indexLton, indexSton
            indexLton = calculateIndex(indexLton, getLtonToTon(totalLton), amountOflton);
            indexSton = calculateIndex(indexSton, curTvlTon, amountOfston);

            // 2. mint increaseSeig of ton in address(this)
            ton.mint(address(this), increaseSeig);

            // 3. transfer amountOfDao,amountOfStosHolders  (to dao, powerTON for tosHolders)
            ton.safeTransfer(dao, amountOfDao);
            ton.safeTransfer(stosDistribute, amountOfStosHolders);

            lastSeigBlock = getCurrentBlockNumber();

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
        nextIndex = curIndex * (curTotal + increaseAmount) / (curTotal * 1e18);
    }

    function totalSecurityDeposit() public view returns (uint256 amount) {
        amount = Layer2ManagerI(layer2Manager).totalSecurityDeposit();
    }

    function totalSupplyTON() public view returns (uint256 amount) {
        // 톤의 총공급량 = ton.totalSupply() - ton.balacneOf(wton)
        // + ((total staked amount in stakingV1)/1e-9)
        amount = ton.totalSupply() + ton.balanceOf(wton) + AutoRefactorCoinageI(tot).totalSupply();

        // l2로 들어간것과 스테이킹 되는 것이 ton으로 이루어진다면 위의 총공급량으로만 집계 해도 된다.

    }

    /* ========== internal ========== */

    function _distribute(uint256 amount) internal view returns (
        uint256 totalSupplyOfTon,
        uint256 amountOflton,
        uint256 amountOfston,
        uint256 amountOfDao,
        uint256 amountOfStosHolders
    ){
        totalSupplyOfTon = totalSupplyTON();

        // 1. (S/T) * TON seigniorage
        //    TON stakers
        //    스테이킹과 본더유동성 총량에 제공하는 시뇨리지
        //    스테이킹과 본더유동성이 점유하고 있는 비율  = getLtonToTon(totalLton) / totalSupplyTON()
        //    lton에 부여되는 시뇨리지 = 전체 톤 발행량에서 lton이 보유하고 있는 비율만큼의 시뇨리지를 부여한다.
        amountOflton = amount * ( getLtonToTon(totalLton) / totalSupplyOfTon );

        // 2. ((D+C)/T) * TON seigniorage
        //    시퀀서에게 할당되는 비율 , D 레이어2 적립금, C 시퀀서 예치금 -> 아래 시퀀서 예치금 반영해야 함
        //    톤 총 공급량에서 레이어2안에 예치된 금액의 비율  = getStonToTon(totalSton) / totalSupplyTON()
        //    ston에 부여되는 시뇨리지 = 전체 톤 발행량에서 ston이 보유하고 있는 비율만큼의 시뇨리지를 부여한다.
        amountOfston = amount * ( (getLtonToTon(totalSton) + totalSecurityDeposit()) / totalSupplyOfTon  );

        uint256 amount1 = amount - amountOflton - amountOfston;

        if (amount1 > 0) {
            // 3. 0.4 * ((T-S-D-C)/T) * TON seigniorage
            //    TON stakers
            amountOflton += amount1 * ratesTonStakers / ratesUnits;

            // 4. 0.5 * ((T-S-D-C)/T) * TON seigniorage
            //    TON DAO
            amountOfDao = amount1 * ratesDao / ratesUnits;

            // 5. 0.1 * ((T-S-D-C)/T) * TON seigniorage
            //    sTOS holders
            amountOfStosHolders = amount1 * ratesDao / ratesUnits;
        }
    }


}
