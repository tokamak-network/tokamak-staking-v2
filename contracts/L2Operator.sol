// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

abstract contract L2Operator  {
    /* ========== DEPENDENCIES ========== */

    /* ========== CONSTRUCTOR ========== */

    /* ========== onlyOwner ========== */

    /* ========== only TON ========== */
    function onApprove(
        address sender,
        address spender,
        uint256 amount,
        bytes calldata data
    ) external virtual returns (bool) ;

    /* ========== only Layer2Manager ========== */
    function create (uint32 _index, bytes memory _layerInfo) external virtual returns (bool) ;

    /* ========== Anyone can execute ========== */
    function stake(uint32 _index, uint256 amount) external virtual;

    /* ========== VIEW ========== */
    function existedIndex(uint32 _index) public virtual returns (bool);
    function getLayerKey(uint32 _index) public virtual returns (bytes32 layerKey_);
    function getTvl(uint32 _index) public virtual returns (uint256);
    function operator(uint32 _index) public virtual returns (address);

    /* ========== internal ========== */


}