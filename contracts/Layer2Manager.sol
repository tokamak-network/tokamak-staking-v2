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

interface SeigManagerV2I {
    // function getLtonToTon(uint256 lton) external view returns (uint256);
    // function getTonToLton(uint256 amount) external view returns (uint256);
    // function getTonToSton(uint256 amount) external view returns (uint256);
    // function getStonToTon(uint256 ston) external view returns (uint256);
    // function updateSeigniorage() external returns (bool);
    function claim(address to, uint256 amount) external;
}
contract  Layer2Manager is AccessibleCommon, BaseProxyStorage, Layer2ManagerStorage {
    /* ========== DEPENDENCIES ========== */
    using SafeERC20 for IERC20;
    using Layer2 for mapping(bytes32 => Layer2.Info);
    using Layer2 for Layer2.Info;

    event Claimed(bytes32 layerKey_, address to, uint256 amount);

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */

    function setMaxLayer2Count(uint256 _maxLayer2Count)
        external nonZero(_maxLayer2Count)
        onlyOwner
    {
        require(maxLayer2Count != _maxLayer2Count, "same");
        maxLayer2Count = _maxLayer2Count;
    }

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

    /* ========== only SeigManagerV2 ========== */
    function addSeigs(uint256 amount) external returns (bool)
    {
        require(msg.sender == seigManagerV2, "caller is not SeigManagerV2");
        if (amount > 0) totalSeigs += amount;
        return true;
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
    {
        require(
            addressManager != address(0) && l1Messenger != address(0) &&
            l2Messenger != address(0) && l1Bridge != address(0) &&
            l2Bridge != address(0) && l2ton != address(0), "zero address"
        );

        require(layerKeys.length < maxLayer2Count, 'exceeded maxLayer2Count');
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

        // securityDeposit[_key] = minimumDepositForSequencer;

        Layer2.Holdings storage holding = holdings[_key];
        holding.securityDeposit = minimumDepositForSequencer;
        totalSecurityDeposit += minimumDepositForSequencer;

        layerKeys.push(_key);
    }

    /* ========== Anyone can execute ========== */

    function distribute() public {
        require (totalSeigs != 0, 'no distributable amount');
        uint256 len = layerKeys.length;
        uint256 sum = 0;

        for(uint256 i = 0; i < len; i++){
            bytes32 _key = layerKeys[i];
            Layer2.Holdings storage holding = holdings[_key];
            if (holding.securityDeposit >= minimumDepositForSequencer) {
                holding.deposits = depositsOf(layers[_key].l1Bridge, layers[_key].l2ton);
                sum += holding.deposits;
            } else {
                holding.deposits = 0;
            }
        }

        if (sum > 0) {
            for(uint256 i = 0; i < len; i++){
                bytes32 _key = layerKeys[i];
                Layer2.Holdings storage holding = holdings[_key];
                if (holding.deposits > 0) {
                    uint256 amount = totalSeigs * holding.deposits / sum;
                    holding.seigs += amount;
                    totalSeigs -= amount;
                }
            }
        }
    }

    function claim(bytes32 layerKey_) public {
        require(holdings[layerKey_].seigs != 0, 'no amount to claim');
        address sequencer_ = sequencer(layerKey_);
        require(sequencer_ != address(0), 'zero sequencer');
        uint256 amount = holdings[layerKey_].seigs;
        holdings[layerKey_].seigs = 0;
        SeigManagerV2I(seigManagerV2).claim(sequencer_, amount);

        emit Claimed(layerKey_, sequencer_, amount);
    }

    /* ========== VIEW ========== */
    function curTotalAmountsLayer2() public view returns (uint256 amount) {
        amount = curTotalLayer2Deposits() + totalSecurityDeposit;
    }

    function registeredLayerKeys(bytes32 layerKey_) public view returns (bool exist_) {

        Layer2.Info memory layer = layers[layerKey_];
        if (layer.addressManager != address(0)) exist_ = true;
    }

    function totalLayerKeys() public view returns (uint256 total) {
        total = layerKeys.length;
    }

    function getAllLayerKeys() public view returns (bytes32[] memory) {
        return layerKeys;
    }

    function getLayerInfo(bytes32 _key) public view returns (Layer2.Info memory) {
        return layers[_key];
    }

    function curlayer2DepositsOf(bytes32 _key) public view returns (uint256 amount) {
        Layer2.Info memory layer = layers[_key];
        if (layer.l1Bridge != address(0)) amount = depositsOf(layer.l1Bridge, layer.l2ton);
    }

    function depositsOf(address l1bridge, address l2ton) public view returns (uint256 amount) {
        try
            L1BridgeI(l1bridge).deposits(address(ton), l2ton) returns (uint256 a) {
                amount = a;
        } catch (bytes memory ) {
            amount = 0;
        }
    }

    function curTotalLayer2Deposits() public view returns (uint256 amount) {
        uint256 len = layerKeys.length;
        for(uint256 i = 0; i < len; i++){
            // Layer2.Info memory layer = getLayerInfo(layerKeys[i]);
            amount += depositsOf(layers[layerKeys[i]].l1Bridge, layers[layerKeys[i]].l2ton);
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

    function sequencer(bytes32 _key) public view returns (address sequencer_) {
            Layer2.Info memory layer = getLayerWithKey(_key);
            if (layer.addressManager != address(0)) {
                try
                    AddressManagerI(layer.addressManager).getAddress('OVM_Sequencer') returns (address a) {
                        sequencer_ = a;
                } catch (bytes memory ) {
                    sequencer_ = address(0);
                }
            }
    }

    /* ========== internal ========== */


}
