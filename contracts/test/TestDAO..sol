// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function mint(address to, uint256 value) external;
}

contract TestDAO is Ownable {

    address public ton;
    address public seigManagerV2;
    address public layer2Manager;

    constructor(){
    }


    function claimStaker(address to, uint256 value) public {
        require(msg.sender == seigManagerV2, "caller is not seigManagerV2");
        IERC20(ton).mint(to, value);
    }

    function claimOperator(address to, uint256 value) public {
        require(msg.sender == layer2Manager, "caller is not layer2Manager");
        IERC20(ton).mint(to, value);
    }

}
