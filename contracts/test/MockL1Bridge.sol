// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

// import "hardhat/console.sol";
contract MockL1Bridge is Ownable {
    using SafeERC20 for IERC20;

    /********************************
     * External Contract References *
     ********************************/
    address public l1Messenger;
    address public l2TokenBridge;

    // Maps L1 token to L2 token to balance of the L1 token deposited
    mapping(address => mapping(address => uint256)) public deposits;

    /** @dev Modifier requiring sender to be EOA.  This check could be bypassed by a malicious
     *  contract via initcode, but it takes care of the user error we want to avoid.
     */
    modifier onlyEOA() {
        // Used to stop deposits from contracts (avoid accidentally lost tokens)
        require(!Address.isContract(msg.sender), "Account not EOA");
        _;
    }

    modifier onlyFromCrossDomainAccount(address _sourceDomainAccount) {
        require(
            msg.sender == l1Messenger,
            "OVM_XCHAIN: messenger contract unauthenticated"
        );

        // require(
        //     getCrossDomainMessenger().xDomainMessageSender() == _sourceDomainAccount,
        //     "OVM_XCHAIN: wrong sender of cross-domain message"
        // );

        _;
    }

    constructor() {
    }

    function setAddress(address _l1Messenger, address _l2TokenBridge) external onlyOwner {
         l1Messenger = _l1Messenger;
        l2TokenBridge = _l2TokenBridge;
    }

    function depositERC20(
        address _l1Token,
        address _l2Token,
        uint256 _amount,
        uint32 _l2Gas,
        bytes calldata _data
    ) external virtual onlyEOA {
        _initiateERC20Deposit(_l1Token, _l2Token, msg.sender, msg.sender, _amount, _l2Gas, _data);
    }

    function depositERC20To(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _l2Gas,
        bytes calldata _data
    ) external virtual {

        _initiateERC20Deposit(_l1Token, _l2Token, msg.sender, _to, _amount, _l2Gas, _data);
    }

    function _initiateERC20Deposit(
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint256 _amount,
        uint32 _l2Gas,
        bytes calldata _data
    ) internal {

        IERC20(_l1Token).safeTransferFrom(_from, address(this), _amount);

        deposits[_l1Token][_l2Token] = deposits[_l1Token][_l2Token] + _amount;

    }

    function finalizeERC20Withdrawal(
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data
    // ) external onlyFromCrossDomainAccount(l2TokenBridge) {
    ) external {
        deposits[_l1Token][_l2Token] = deposits[_l1Token][_l2Token] - _amount;

        // When a withdrawal is finalized on L1, the L1 Bridge transfers the funds to the withdrawer
        // slither-disable-next-line reentrancy-events
        IERC20(_l1Token).safeTransfer(_to, _amount);

        // // slither-disable-next-line reentrancy-events
        // emit ERC20WithdrawalFinalized(_l1Token, _l2Token, _from, _to, _amount, _data);
    }
}
