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
        require(_info.length > 55, "wrong _info");

        // console.log('create ' );
        // console.logBytes(_info);
        // console.log("operator %s ", _info.toAddress(0));
        // console.log("sequenceIndex %s ", _info.toUint32(20));
        // console.log("amount %s ", _info.toUint256(24));

        // 20+4+32 =  56
        // bytes
        //  address (operator)- uint32 (layerIndex) - uint256 (amount)
        uint256 amount = _info.toUint256(24);

        layerInfo[_candidateIndex] = abi.encodePacked(_info.slice(0,24), bytes2(uint16(0)));
        // console.logBytes(layerInfo[_candidateIndex]);

        IERC20(ton).safeTransferFrom(layer2Manager, address(this), amount);
        _stake(_candidateIndex, _info.toAddress(0), amount);

        return true;
    }

    /* ========== only TON ========== */
    function onApprove(
        address sender,
        address spender,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        require(existedIndex(data.toUint32(0)), 'non-registered candidate');
        return _onApprove(sender, spender, amount, data);
    }

    /* ========== Anyone can execute ========== */
    function stake(uint32 _index, uint256 amount) external
    {
        require(existedIndex(_index), 'non-registered candidate');

        stake_(_index, amount);
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
        layerKey_ = bytes32(keccak256(data));
    }

    function operator(uint32 _index) public view returns (address operator_) {
        bytes memory data = layerInfo[_index];

        if(data.length > 23){
            operator_ = data.toAddress(0);
        }
    }

    /* === ======= internal ========== */

}