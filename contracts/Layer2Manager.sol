// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./Layer2ManagerStorage.sol";
import "./proxy/BaseProxyStorage.sol";
import "./common/AccessibleCommon.sol";
import "./libraries/SafeERC20.sol";

// import "hardhat/console.sol";

interface L1BridgeI {
    function deposits(address l1token, address l2token) external view returns (uint256);
}

interface AddressManagerI {
    function getAddress(string memory _name) external view returns (address);
}

contract  Layer2Manager is AccessibleCommon, BaseProxyStorage, Layer2ManagerStorage {
    /* ========== DEPENDENCIES ========== */
    using SafeERC20 for IERC20;
    using Layer2 for mapping(bytes32 => Layer2.Info);
    using Layer2 for Layer2.Info;

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */

    function setMinimumDepositForSequencer(uint256 _minimumDepositForSequencer)
        external
        onlyOwner
    {
        require(minimumDepositForSequencer != _minimumDepositForSequencer, "same");
        minimumDepositForSequencer = _minimumDepositForSequencer;
    }

    function setDelayBlocksForWithdraw(uint256 _delayBlocksForWithdraw)
        external
        onlyOwner
    {
        require(delayBlocksForWithdraw != _delayBlocksForWithdraw, "same");
        delayBlocksForWithdraw = _delayBlocksForWithdraw;
    }

    /* ========== Sequncer can execute ========== */
     function create(
        address addressManager,
        address l1Messenger,
        address l2Messenger,
        address l1Bridge,
        address l2Bridge,
        address l2ton
    )
        external
        nonZeroAddress(addressManager)
        nonZeroAddress(l1Messenger)
        nonZeroAddress(l2Messenger)
        nonZeroAddress(l1Bridge)
        nonZeroAddress(l2Bridge)
        nonZeroAddress(l2ton)
    {
        require(msg.sender == AddressManagerI(addressManager).getAddress('OVM_Sequencer'), 'NOT Sequencer');

        bytes32 _key = layerKey(addressManager, l1Messenger, l2Messenger, l1Bridge, l2Bridge, l2ton);
        Layer2.Info storage layer = layers[_key];
        require(layer.addressManager == address(0), 'already created');

        // check minimumDepositForSequencer
        ton.safeTransferFrom(msg.sender, address(this), minimumDepositForSequencer);

        layer.addressManager = addressManager;
        layer.l1Messenger = l1Messenger;
        layer.l2Messenger = l2Messenger;
        layer.l1Bridge = l1Bridge;
        layer.l2Bridge = l2Bridge;
        layer.l2ton = l2ton;

        securityDeposit[_key] = minimumDepositForSequencer;
        totalSecurityDeposit += minimumDepositForSequencer;

        layerKeys.push(_key);
    }

    /* ========== SeigManager2 can execute ========== */
    function updateLayer2Deposits() external returns (uint256 prevTotal, uint256 curTotal) {
        require(msg.sender == seigManagerV2, 'NOT SeigManager2');

        prevTotal = totalLayer2Deposits;
        curTotal = 0;
        uint256 len = layerKeys.length;
        address _ton = address(ton);
        for(uint256 i = 0; i < len; i++){
            bytes32 _key = layerKeys[i];
            uint256 amount = L1BridgeI(layers[_key].l1Bridge).deposits(_ton, layers[_key].l2ton);
            layer2Deposits[_key] = amount;
            curTotal += amount;
        }

        totalLayer2Deposits = curTotal;
    }

    /* ========== Anyone can execute ========== */


    /* ========== VIEW ========== */
    function totalLayerKeys() public view returns (uint256 total) {
        total = layerKeys.length;
    }

    function getAllLayerKeys() public view returns (bytes32[] memory) {
        return layerKeys;
    }

    function getLayerInfo(bytes32 _key) public view returns (Layer2.Info memory) {
        return layers[_key];
    }

    function curlayer2Deposits(bytes32 _key) public view returns (uint256 amount) {
        Layer2.Info memory layer = layers[_key];
        if (layer.l1Bridge != address(0)) amount = deposits(layer.l1Bridge, layer.l2ton);
    }

    function deposits(address l1bridge, address l2ton) public view returns (uint256 amount) {
        amount = L1BridgeI(l1bridge).deposits(address(ton), l2ton);
    }

    function curTotalDeposits() public view returns (uint256 amount) {
        uint256 len = layerKeys.length;
        for(uint256 i = 0; i < len; i++){
            // Layer2.Info memory layer = getLayerInfo(layerKeys[i]);
            amount += deposits(layers[layerKeys[i]].l1Bridge, layers[layerKeys[i]].l2ton);
        }
    }

    function getLayer(
        address addressManager,
        address l1Messenger,
        address l2Messenger,
        address l1Bridge,
        address l2Bridge,
        address l2ton
    ) public view returns (Layer2.Info memory layer) {
            layer = layers.get(
                addressManager,
                l1Messenger,
                l2Messenger,
                l1Bridge,
                l2Bridge,
                l2ton);
    }

    function getLayerWithKey(bytes32 _key) public view returns (Layer2.Info memory layer) {
        layer = layers.getWithLayerKey(_key);
    }

    function layerKey(
        address addressManager,
        address l1Messenger,
        address l2Messenger,
        address l1Bridge,
        address l2Bridge,
        address l2ton
    ) public pure returns (bytes32 key) {
            key = bytes32(keccak256(abi.encode(
                addressManager,
                l1Messenger,
                l2Messenger,
                l1Bridge,
                l2Bridge,
                l2ton
            )));
    }

    function sequncer(bytes32 _key) public view returns (address sequncer_) {
            Layer2.Info memory layer = getLayerWithKey(_key);
            if (layer.addressManager != address(0)) sequncer_ = AddressManagerI(layer.addressManager).getAddress('OVM_Sequencer');
    }

    /* ========== internal ========== */


}
