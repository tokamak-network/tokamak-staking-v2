// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestDAO is Ownable {
    using SafeERC20 for IERC20;
    address public ton;
    address public seigManagerV2;

    constructor(){
    }

    function setAddress(address _ton, address _seigManagerV2) external onlyOwner {
        ton = _ton;
        seigManagerV2 = _seigManagerV2;
    }

    function claimStaker(address to, uint256 value) external {
        require(msg.sender == seigManagerV2, "caller is not seigManagerV2");
        require(value <= IERC20(ton).balanceOf(address(this)), "insifficient TON in DAO");

        IERC20(ton).safeTransfer(to, value);
    }

    function claimOperator(address to, uint256 value) external {
        require(msg.sender == seigManagerV2, "caller is not seigManagerV2");
        require(value <= IERC20(ton).balanceOf(address(this)), "insifficient TON in DAO");

        IERC20(ton).safeTransfer(to, value);
    }

}
