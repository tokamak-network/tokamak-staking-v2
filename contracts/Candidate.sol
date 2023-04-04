// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;
import "./libraries/LibOperator.sol";
import "./storages/CandidateStorage.sol";
import "./Staking.sol";


contract Candidate is Staking, CandidateStorage {
    using BytesLib for bytes;
    using SafeERC20 for IERC20;
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
    function create(uint32 _candidateIndex, bytes memory _info)
        external onlyLayer2Manager returns (bool)
    {
        require(layerInfo[_candidateIndex].length == 0, "already created");
        require(_info.length > 57, "wrong _info");

        // console.log('create ' );
        // console.logBytes(_info);
        // console.log("operator %s ", _info.toAddress(0));
        // console.log("sequenceIndex %s ", _info.toUint32(20));
        // console.log("_commission %s ", _info.toUint16(24));
        // console.log("amount %s ", _info.toUint256(26));

        // 20+4+2+32 =  58
        // bytes
        //  address (operator)- uint32 (layerIndex) - uint256 (amount)
        uint16 commission = _info.toUint16(24);
        // if (commission != 0) commissions[_candidateIndex] = commission;

        require(commission < uint16(10000), "commission err");
        uint256 amount = _info.toUint256(26);

        layerInfo[_candidateIndex] = abi.encodePacked(_info.slice(0,26));
        // console.logBytes(layerInfo[_candidateIndex]);

        if(amount != 0) {
            IERC20(ton).safeTransferFrom(layer2Manager, address(this), amount);
            _stake(_candidateIndex, _info.toAddress(0), amount, address(0), 0);
        }

        return true;
    }

    /* ========== only TON ========== */
    function onApprove(
        address sender,
        address spender,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        require(ton == msg.sender, "EA");
        require(existedIndex(data.toUint32(0)), 'non-registered candidate');

        // data : (32 bytes) index
        uint32 _index = data.toUint32(0);
        if (amount != 0) IERC20(ton).safeTransferFrom(sender, address(this), amount);

        LibOperator.Info memory _layerInfo = getCandidateInfo(_index);
        if (_layerInfo.commission == 0 || sender == _layerInfo.operator) {
            _stake(_index, sender, amount, address(0), 0);
        } else {
            _stake(_index, sender, amount, _layerInfo.operator, _layerInfo.commission);
        }

        return true;
    }

    /* ========== Anyone can execute ========== */
    function stake(uint32 _index, uint256 amount) external
    {
        require(existedIndex(_index), 'non-registered candidate');
        LibOperator.Info memory _layerInfo = getCandidateInfo(_index);

        if (_layerInfo.commission == 0 || msg.sender == _layerInfo.operator) {
            stake_(_index, amount, address(0), 0);
        } else {
            stake_(_index, amount, _layerInfo.operator, _layerInfo.commission);
        }
    }

    function unstake(uint32 _index, uint256 lton_) external
    {
        if(msg.sender == operator(_index)) {
            uint256 minimumLton_ = SeigManagerV2I(seigManagerV2).getTonToLton(
                Layer2ManagerI(layer2Manager).minimumDepositForCandidate()
            );
            require(lton_ + minimumLton_ <= balanceOfLton(_index, msg.sender), "minimumDepositForCandidate E1");
        }
        _unstake(_index, lton_);
    }

    function existedIndex(uint32 _index) public view returns (bool) {
        require(Layer2ManagerI(layer2Manager).existedCandidateIndex(_index), 'non-registered layer');
        return true;
    }

    function getCandidateInfo(uint32 _index)
        public view returns (LibOperator.Info memory _layerInfo )
    {
        bytes memory data = layerInfo[_index];
        //
        // bytes
        //  address (operator)- uint32 (layerIndex) - uint16 (commission)
        // 20 + 4+ 2
        if (data.length > 25) {
            _layerInfo = LibOperator.Info({
                operator : data.toAddress(0),
                sequencerIndex : data.toUint32(20),
                commission : data.toUint16(24)
            });
        }
    }

    function getCandidateKey(uint32 _index) public view virtual  returns (bytes32 layerKey_) {
        bytes memory data = layerInfo[_index];
        layerKey_ = bytes32(keccak256(abi.encodePacked(data.slice(0,24), uint16(0))));
    }

    function operator(uint32 _index) public view returns (address operator_) {
        bytes memory data = layerInfo[_index];

        if(data.length > 23){
            operator_ = data.toAddress(0);
        }
    }

    /* === ======= internal ========== */

}