// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./storages/OptimismL2OperatorStorage.sol";
import "./Staking.sol";
import "./L2Operator.sol";
import "./libraries/LibOptimism.sol";
import "./interfaces/IOptimismL2Operator.sol";
// import "hardhat/console.sol";

contract OptimismL2Operator is Staking, L2Operator, OptimismL2OperatorStorage, IOptimismL2Operator {
    using BytesParserLib for bytes;
    using SafeERC20 for IERC20;

    /* ========== DEPENDENCIES ========== */

    /* ========== CONSTRUCTOR ========== */
    constructor() {
    }

    /* ========== onlyOwner ========== */


    /* ========== only TON ========== */

    /// @inheritdoc IOptimismL2Operator
    function onApprove(
        address sender,
        address spender,
        uint256 amount,
        bytes calldata data
    ) external override(L2Operator, IOptimismL2Operator) returns (bool) {
        require(ton == msg.sender, "EA");
        require(existedIndex(data.toUint32(0)), 'non-registered layer');

        // data : (32 bytes) index
        uint32 _index = data.toUint32(0);
        if(amount != 0) IERC20(ton).safeTransferFrom(sender, address(this), amount);
        _stake(_index, 0, sender, amount, address(0), 0);

        return true;
    }

    /* ========== only LayerManager ========== */

    /// @inheritdoc IOptimismL2Operator
    function create(uint32 _index, bytes memory _layerInfo)
        external onlyLayer2Manager override(L2Operator, IOptimismL2Operator) returns (bool)
    {
        require(_layerInfo.length == 80, "wrong layerInfo");
        require(layerInfo[_index].length == 0, "already created");
        layerInfo[_index] = _layerInfo;

        return true;
    }

    /* ========== Anyone can execute ========== */

    /// @inheritdoc IOptimismL2Operator
    function stake(uint32 _index, uint256 amount) external override(L2Operator, IOptimismL2Operator)
    {
        require(existedIndex(_index), 'non-registered layer');
        require(amount >= IERC20(ton).allowance(msg.sender, address(this)), "allowance allowance is insufficient is insufficient");

        stake_(_index, 0, amount, address(0), 0);
    }

    /// @inheritdoc IOptimismL2Operator
    function unstake(uint32 _index, uint256 lton_) external override
    {
        _unstake(_index, 0, lton_, FwReceiptI(fwReceipt).debtInStaked(false, _index, msg.sender));
    }

    /// @inheritdoc IOptimismL2Operator
    function existedIndex(uint32 _index) public view override(L2Operator, IOptimismL2Operator) returns (bool) {
        require(Layer2ManagerI(layer2Manager).existedLayer2Index(_index), 'non-registered layer');
        return true;
    }

    /// @inheritdoc IOptimismL2Operator
    function getLayerInfo(uint32 _index)
        public view override returns (LibOptimism.Info memory _layerInfo)
    {
        _layerInfo = LibOptimism.parseKey(layerInfo[_index]);
    }

    function getLayerKey(uint32 _index) public view virtual override(L2Operator, IOptimismL2Operator) returns (bytes32 layerKey_) {
        layerKey_ = keccak256(layerInfo[_index]);
    }

    /// @inheritdoc IOptimismL2Operator
    function getTvl(uint32 _index) public view override(L2Operator, IOptimismL2Operator) returns (uint256 amount) {

        LibOptimism.Info memory _layerInfo = getLayerInfo(_index);
        try
            L1BridgeI(L1StandardBridge(_layerInfo.addressManager)).deposits(ton, _layerInfo.l2ton) returns (uint256 a) {
                amount = a;
        } catch (bytes memory ) {
            amount = 0;
        }
    }

    /// @inheritdoc IOptimismL2Operator
    function getTvl(address l1Bridge, address l2ton) public view override returns (uint256 amount) {
        try
            L1BridgeI(l1Bridge).deposits(ton, l2ton) returns (uint256 a) {
                amount = a;
        } catch (bytes memory ) {
            amount = 0;
        }
    }

    /// @inheritdoc IOptimismL2Operator
    function operator(uint32 _index) public view override(L2Operator, IOptimismL2Operator) returns (address operator_) {
        address manager = LibOptimism.getAddressManager(layerInfo[_index]);
        if (manager == address(0)) return address(0);
        try
            AddressManagerI(LibOptimism.getAddressManager(layerInfo[_index])).getAddress('OVM_TONStakingManager') returns (address a) {
                operator_ = a;
        } catch (bytes memory ) {
            operator_ = address(0);
        }
    }

    /// @inheritdoc IOptimismL2Operator
    function operator(address addressManager) public view override returns (address operator_) {
        try
            AddressManagerI(addressManager).getAddress('OVM_TONStakingManager') returns (address a) {
                operator_ = a;
        } catch (bytes memory ) {
            operator_ = address(0);
        }
    }

    /// @inheritdoc IOptimismL2Operator
    function L1CrossDomainMessenger(address addressManager) public view returns (address account_) {
        try
            AddressManagerI(addressManager).getAddress('OVM_L1CrossDomainMessenger') returns (address a) {
                account_ = a;
        } catch (bytes memory ) {
            account_ = address(0);
        }
    }

    /// @inheritdoc IOptimismL2Operator
    function L1StandardBridge(address addressManager) public view override returns (address account_) {
        if (addressManager == address(0)) return address(0);
        try
            AddressManagerI(addressManager).getAddress('Proxy__OVM_L1StandardBridge') returns (address a) {
                account_ = a;
        } catch (bytes memory ) {
            account_ = address(0);
        }
    }

    /// @inheritdoc IOptimismL2Operator
    function bridges(uint32 _index) public view override returns (address, address) {
        LibOptimism.Info memory _layerInfo = LibOptimism.parseKey(layerInfo[_index]);
        return (_layerInfo.l1Bridge, _layerInfo.l2Bridge) ;
    }

    /* ========== internal ========== */


}