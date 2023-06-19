// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "../libraries/Layer2.sol";

/**
 * @title   Layer2Manager
 * @dev     Create and manage operator's and candidates.
 *          Manages the minimum deposit of the operator.
 */
interface ILayer2Manager {

    /**
     * @dev                 event that occurs when operator claims seigniorage assigned to him
     * @param _index        the operator index
     * @param _operator    the operator address
     * @param amount        the amount claimed
     */
    event Claimed(uint32 _index, address _operator, uint256 amount);

    /**
     * @dev                     event that occurs when create the optimism operator
     * @param _index            the operator index
     * @param _operator         the operator address
     * @param _name             name
     * @param addressManager    the addressManager address
     * @param l1Bridge          the l1 bridge address
     * @param l2Bridge          the l2 bridge address
     * @param l2ton             the l2 ton address
     * @param depositAmount     the amount deposited
     */
    event CreatedOptimismL2Operator(uint32 _index, address _operator, bytes32 _name, address addressManager, address l1Bridge, address l2Bridge, address l2ton, uint256 depositAmount);

    /**
     * @dev                     event that occurs when create the candidate
     * @param _index            the candidate index
     * @param _operator         the operator address
     * @param _name             name
     * @param _operatorIndex   the operator index to support
     * @param _commission       commission (used by divied 10000)
     * @param depositAmount     the amount staked
     */
    event CreatedCandidate(uint32 _index, address _operator, bytes32 _name, uint32 _operatorIndex, uint16 _commission, uint256 depositAmount);

    /**
     * @dev                         an event that occurs when seigniorage is distributed to operators
     * @param _totalSeigs           the total seigniorage to distribute
     * @param _distributedAmount    the amount distributed
     */
    event Distributed(uint256 _totalSeigs, uint256 _distributedAmount);

    /**
     * @dev                 an event that occurs when operator increases security deposit amount
     * @param _index        the sequnecer index
     * @param caller        caller address
     * @param amount        amount increased
     */
    event IncreasedSecurityDeposit(uint32 _index, address caller, uint256 amount);

    /**
     * @dev                 an event that occurs when operator decreased security deposit amount
     * @param _index        the sequnecer index
     * @param _operator    caller address
     * @param amount        amount decreased
     */
    event DecreasedSecurityDeposit(uint32 _index, address _operator, uint256 amount);


    /* ========== onlyOwner ========== */

    /**
     * @dev                     set MaxLayer2Count
     * @param _maxLayer2Count   the number of maximum count of layer2
     */
    function setMaxLayer2Count(uint256 _maxLayer2Count) external;

    /**
     * @dev                                 set minimum security deposit amount of operator
     * @param _minimumDepositForOperator   minimum security deposit amount
     */
    function setMinimumDepositForL2Operator(uint256 _minimumDepositForOperator) external;

    /**
     * @dev                                set what percentage of layer 2's TVL  as the minimum security deposit amount
     * @param _ratioSecurityDepositOfTvl   ratio of layer 2's TVL
     */
    function setRatioSecurityDepositOfTvl(uint16 _ratioSecurityDepositOfTvl) external;

    /**
     * @dev                                 set minimum staking amount of candidate
     * @param _minimumDepositForCandidate   minimum staking amount
     */
    function setMinimumDepositForCandidate(uint256 _minimumDepositForCandidate) external;

    /**
     * @dev                             set the delay blocks for withdrawal
     * @param _delayBlocksForWithdraw   the delay blocks for withdrawal
     */
    function setDelayBlocksForWithdraw(uint256 _delayBlocksForWithdraw) external;


    /* ========== only SeigManagerV2 ========== */

    /**
     * @dev             add seigniorage amount allocated to operator
     *                  function called by seigManagerV2 contract
     * @param amount    amount of seigniorage added
     * @return result   true
     */
    function addSeigs(uint256 amount) external returns (bool);


    /* ========== Sequncer can execute ========== */

    /**
     * @dev                     create an optimism operator
     * @param _name             title
     * @param addressManager    addressManager address
     * @param l1Bridge          l1Bridge address
     * @param l2Bridge          l2Bridge address
     * @param l2ton             l2ton address
     * @param amount            the security deposit amount
     * @return operatorIndex   the operator index
     */
    function createOptimismL2Operator(
        bytes32 _name,
        address addressManager,
        address l1Bridge,
        address l2Bridge,
        address l2ton,
        uint256 amount
    )  external returns (uint32);

    /**
     * @dev                     create candidate
     * @param _operatorIndex   operator index to support
     * @param _name             title
     * @param _commission       commission
     * @param amount            the staking amount
     * @return candidateIndex   the candidate index
     */
    function createCandidate(
        uint32 _operatorIndex,
        bytes32 _name,
        uint16 _commission,
        uint256 amount
    )   external returns (uint32);

    /**
     * @dev                     decrease the security deposit amount
     * @param _operatorIndex   the operator index
     * @param amount            the amount that want to decreased
     */
    function decreaseSecurityDeposit(uint32 _operatorIndex, uint256 amount) external ;


    /* ========== Anyone can execute ========== */

    /**
     * @dev                     increase the security deposit amount
     * @param _operatorIndex   the operator index
     * @param amount            the amount that want to increased
     */
    function increaseSecurityDeposit(uint32 _operatorIndex, uint256 amount) external ;

    /**
     * @dev                     distribute seigs to operators
     */
    function distribute() external ;

    /**
     * @dev                     operator claims seigniorage assigned to him
     * @param _layerIndex       the operator index
     */
    function claim(uint32 _layerIndex) external ;


    /* ========== VIEW ========== */
    /**
     * @dev                     view the minimum security deposit amount
     * @param l1Bridge          l1Bridge address
     * @param l2ton             l2ton address
     * @return amount           the minimum security deposit amount
     */
    function minimumSecurityDepositAmount(address l1Bridge, address l2ton) external view returns (uint256 amount) ;

    /**
     * @dev                     view the balance of Lton
     * @param account           account address
     * @return amount           the balane(LTON) of account
     *
     */
    function balanceOfLton(address account) external view returns (uint256 amount) ;

    /**
     * @dev                     view the current total layer2's deposit amount
     * @return amount           the current total layer2's deposit amount
     */
    function curTotalLayer2Deposits() external view returns (uint256 amount) ;

    /**
     * @dev                     view tßhe operator address
     * @param _layerIndex       the operator index
     * @return operator_       the operator address
     */
    function operator(uint32 _layerIndex) external view returns (address operator_);

    /**
     * @dev                     Does the sequence index exist?
     * @param _index            the _index
     * @return exist_           if exist, return true
     */
    function existedLayer2Index(uint32 _index) external view returns (bool exist_) ;

    /**
     * @dev                     Does the candidate index exist?
     * @param _index            the _index
     * @return exist_           if exist, return true
     */
    function existedCandidateIndex(uint32 _index) external view returns (bool exist_) ;

    /**
     * @dev                     view the current total amount of Layer2s
     * @return amount           the current total amount of Layer2s
     */
    function curTotalAmountsLayer2() external view returns (uint256 amount);

    /**
     * @dev                     view the total number of layer (operators)
     * @return total            the total number of layer
     */
    function totalLayers() external view returns (uint256 total);

    /**
     * @dev                     view the total number of candiates
     * @return total            the total number of candiates
     */
    function totalCandidates() external view returns (uint256 total) ;

    /**
     * @dev                     view the current deposit amount of layer(operator) : TVL
     * @param _layerIndex       the operator's index
     * @return amount           the current deposit amount of layer(operator)
     */
    function depositsOf(uint32 _layerIndex) external view returns (uint256 amount) ;

    /**
     * @dev                                 view all operator's infomation
     * @return optimismL2OperatorNames_      array of all operator's title
     * @return optimismL2OperatorIndexes_    array of all operator's index
     * @return holdings_                    array of all operator's holding
     * @return infos_                       array of all operator's information
     */
    function getAllLayers() external view
        returns (
            bytes32[] memory optimismL2OperatorNames_,
            uint32[] memory optimismL2OperatorIndexes_,
            Layer2.Layer2Holdings[] memory holdings_,
            bytes[] memory infos_
            );

    /**
     * @dev                                 view all candidate's infomation
     * @return candidateNames_              array of all candidate's title
     * @return candidateNamesIndexes_       array of all candidate's index
     * @return infos_                       array of all candidate's information
     */
    function getAllCandidates() external view
        returns (
            bytes32[] memory candidateNames_,
            uint32[] memory candidateNamesIndexes_,
            bytes[] memory infos_
            );

    /**
     * @dev                     view the Layer2Holdings's infomation
     * @return layer2Holdings   securityDeposit and seigs
     */
    function layerHoldings(uint32 layerKey_) external view  returns (Layer2.Layer2Holdings memory);

}