// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;
import "./libraries/LibOptimism.sol";
import "./storages/OptimismSequencerStorage.sol";
import "./Staking.sol";
import "./Sequencer.sol";

import "hardhat/console.sol";

interface L1BridgeI {
    function deposits(address l1token, address l2token) external view returns (uint256);
}

interface AddressManagerI {
    function getAddress(string memory _name) external view returns (address);
}

contract OptimismSequencer is Staking, Sequencer, OptimismSequencerStorage {
    using BytesLib for bytes;
    using Layer2 for mapping(bytes32 => Layer2.Layer2Info);
    using Layer2 for Layer2.Layer2Info;
    /* ========== DEPENDENCIES ========== */

    modifier onlyLayer2Manager() {
        require(msg.sender == layer2Manager, "not Layer2Manager");
        _;
    }

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */


    /* ========== LayerManager ========== */
    function create(uint32 _index, bytes memory _layerInfo)
        external onlyLayer2Manager override returns (bool)
    {

        require(_layerInfo.length == 80, "wrong layerInfo");
        require(layerInfo[_index].length == 0, "already created");
        layerInfo[_index] = _layerInfo;

        return true;
    }

    /* ========== only TON ========== */
    function onApprove(
        address sender,
        address spender,
        uint256 amount,
        bytes calldata data
    ) external override returns (bool) {
        require(existedIndex(data.toUint32(0)), 'non-registered layer');
        return _onApprove(sender, spender, amount, data);
    }

    /* ========== Anyone can execute ========== */

    function stake(uint32 _index, uint256 amount) external override
    {
        require(existedIndex(_index), 'non-registered layer');
        stake_(_index, amount);
    }

    function unstake(uint32 _index, uint256 lton_) external
    {
        _unstake(_index, lton_);
    }

    function existedIndex(uint32 _index) public view override returns (bool) {
        require(Layer2ManagerI(layer2Manager).existedLayer2Index(_index), 'non-registered layer');
        return true;
    }

    function getLayerInfo(uint32 _index)
        public view returns (LibOptimism.Info memory _layerInfo )
    {
        bytes memory data = layerInfo[_index];

        if (data.length > 79) {
            _layerInfo = LibOptimism.Info({
                addressManager : data.toAddress(0),
                l1Messenger : data.toAddress(20),
                l1Bridge : data.toAddress(40),
                l2ton : data.toAddress(60)
            });
        }
    }

    function getLayerKey(uint32 _index) public view virtual override returns (bytes32 layerKey_) {
        bytes memory data = layerInfo[_index];
        layerKey_ = bytes32(keccak256(data));
    }

    function getTvl(uint32 _index) public view override returns (uint256 amount) {

        LibOptimism.Info memory _layerInfo = getLayerInfo(_index);
        try
            L1BridgeI(_layerInfo.l1Bridge).deposits(ton, _layerInfo.l2ton) returns (uint256 a) {
                amount = a;
        } catch (bytes memory ) {
            amount = 0;
        }
    }


    function getTvl(address l1Bridge, address l2ton) public view returns (uint256 amount) {

        try
            L1BridgeI(l1Bridge).deposits(ton, l2ton) returns (uint256 a) {
                amount = a;
        } catch (bytes memory ) {
            amount = 0;
        }
    }

    function sequencer(uint32 _index) public view override returns (address sequencer_) {
        bytes memory data = layerInfo[_index];
        try
            AddressManagerI(data.toAddress(0)).getAddress('OVM_Sequencer') returns (address a) {
                sequencer_ = a;
        } catch (bytes memory ) {
            sequencer_ = address(0);
        }
    }

    function sequencer(address addressManager) public view returns (address sequencer_) {
        try
            AddressManagerI(addressManager).getAddress('OVM_Sequencer') returns (address a) {
                sequencer_ = a;
        } catch (bytes memory ) {
            sequencer_ = address(0);
        }
    }

    /* ========== internal ========== */


}