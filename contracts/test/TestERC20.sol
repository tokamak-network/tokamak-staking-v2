// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor() ERC20("WTON", "WTON") {}

    function mint(address to, uint256 value) public {
        _mint(to, value);
    }

    function decimals() public view virtual override returns (uint8) {
        return 27;
    }

}
