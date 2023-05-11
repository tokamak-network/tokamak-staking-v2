// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "../libraries/LibOperator.sol";
import "../libraries/LibOptimism.sol";

/**
 * @title   FwReceipt
 * @dev
 */
interface IFwReceipt {

    /**
     * @dev                     this event occurs when liquidity is provided for fast withdrawal.
     * @param key               hashMessage of fast withdrawal
     * @param provider          liquidity provider address
     * @param provideAmount     the amount of liquidity provided
     * @param feeAmount         the fee amount
     * @param isCandidate       whether a candidate, if candidate, true
     * @param indexNo           the sequencer index or candidate index
     */
    event ProvidedLiquidity(bytes32 key, address provider, uint256 provideAmount, uint256 feeAmount, bool isCandidate, uint32 indexNo);

    /**
     * @dev                     event that occurs when canceling fast withdrawal
     * @param key               hashMessage of fast withdrawal
     * @param caller            This is the account address where the fast withdrawal was canceled, and the address of the fast withdrawal requester.
     */
    event CanceledRequest(bytes32 key, address caller);

    /**
     * @dev                     an event that occurs when a fast withdrawal is requested, but there is no liquidity provider, so a general withdrawal is made after DTD
     * @param key               hashMessage of fast withdrawal
     * @param from              from address
     * @param to                to address
     * @param amount            the amount of withdrawal
     * @param status            the status
     */
    event NormalWithdrawal(bytes32 key, address from, address to, uint256 amount, uint8 status);

    /**
     * @dev                     an event that occurs when the fee for fast withdrawal is paid and completed
     * @param key               hashMessage of fast withdrawal
     * @param from              from address
     * @param to                to address
     * @param providedAmount    the amount of liquidity provided
     * @param feeAmount         the fee amount
     * @param isCandidate       whether a candidate, if candidate, true
     * @param indexNo           the sequencer index or candidate index
     */
    event FinalizedFastWithdrawal(bytes32 key, address from, address to, uint256 providedAmount, uint256 feeAmount, bool isCandidate, uint32 indexNo);


    /* ========== onlyOwner ========== */

    /**
     * @dev                         set optimism sequencer address
     * @param _optimismSequencer    the optimism sequencer address
     */
    function setOptimismSequencer(address _optimismSequencer) external;

    /**
     * @dev                         set candidate address
     * @param _candidate            the candidate address
     */
    function setCandidate(address _candidate) external;

    /* ========== Anyone can execute ========== */

    /**
     * @dev                     the fee for fast withdrawal is paid and completed
     * @param requestor         the account address for which the fast withdrawal was requested
     * @param requestAmount     fast withdrawal amount
     * @param deadline          deadline (sec unit)
     * @param feeRate           fee rate ( divided 10000 )
     * @param layerIndex        the sequencer index
     * @param messageNonce      the message nonce used in l2's fast withdraw transaction
     * @param hashMessage       the message hash
     * @return result           status
     */
    function finalizeFastWithdraw(
        address requestor,
        uint256 requestAmount,
        uint32 deadline,
        uint16 feeRate,
        uint32 layerIndex,
        uint256 messageNonce,
        bytes32 hashMessage
        )
        external returns (uint8);


    /**
     * @dev                     functions that provide liquidity for quick withdrawals
     * @param requestor         the account address for which the fast withdrawal was requested
     * @param requestAmount     fast withdrawal amount
     * @param provideAmount     the amount of liquidity provided
     * @param deadline          deadline (sec unit)
     * @param isCandidate       whether a candidate, if candidate, true
     * @param indexNo           the sequencer index or candidate index
     * @param feeRate           fee rate ( divided 10000 )
     * @param layerIndex        the sequencer index
     * @param messageNonce      the message nonce used in l2's fast withdraw transaction
     * @param hashMessage       the message hash
     */
    function provideLiquidity(
        address requestor,
        uint256 requestAmount,
        uint256 provideAmount,
        uint32 deadline,
        bool isCandidate,
        uint32 indexNo,
        uint16 feeRate,
        uint32 layerIndex,
        uint256 messageNonce,
        bytes32 hashMessage
        ) external;


     /**
     * @dev                     cancel fast withdrawal
     * @param requestor         the account address for which the fast withdrawal was requested
     * @param requestAmount     fast withdrawal amount
     * @param deadline          deadline (sec unit)
     * @param feeRate           fee rate ( divided 10000 )
     * @param layerIndex        the sequencer index
     * @param messageNonce      the message nonce used in l2's fast withdraw transaction
     * @param hashMessage       the message hash
     */
    function cancelRequest(
        address requestor,
        uint256 requestAmount,
        uint32 deadline,
        uint16 feeRate,
        uint32 layerIndex,
        uint256 messageNonce,
        bytes32 hashMessage) external;

    /* ========== VIEW ========== */

    /**
     * @dev                     validate the hash message
     * @param requestor         the account address for which the fast withdrawal was requested
     * @param amount            fast withdrawal amount
     * @param feeRate           fee rate ( divided 10000 )
     * @param deadline          deadline
     * @param layerIndex        the sequencer index
     * @param messageNonce      the message nonce used in l2's fast withdraw transaction
     * @param hashMessage       the message hash
     * @return result
     */
    function validateHashMessage(
        address requestor,
        uint256 amount,
        uint16 feeRate,
        uint32 deadline,
        uint32 layerIndex,
        uint256 messageNonce,
        bytes32 hashMessage
    ) external view returns(bool);

    /**
     * @dev                     view how much liquidity that account in that sequencer can provide
     * @param isCandidate       whether a candidate, if candidate, true
     * @param layerIndex        the sequencer index or candidate index
     * @param account           the account address
     * @return amount           amount of liquidity available
     */
    function availableLiquidity(bool isCandidate, uint32 layerIndex, address account) external view returns (uint256 amount);

    /**
     * @dev                     With that hashMessage, account provide liquidity but account has not received a fee yet.
     * @param account           the account address
     * @param hashMessage       the hash message
     * @return included         if provide liquidity, not yet recieve fee, true
     */
    function includedTxsOfProvider(address account, bytes32 hashMessage) external view returns (bool included);

    /**
     * @dev                     total liquidities (not yet finalized) by accounts in a particular sequencer or candidate.
     * @param isCandidate       whether a candidate, if candidate, true
     * @param layerIndex        the sequencer index or candidate index
     * @param account           the account address
     * @return liquidities      Total liquidities
     */
    function debtInStaked(bool isCandidate, uint32 layerIndex, address account) external view returns (uint256);

}