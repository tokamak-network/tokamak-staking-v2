import { ethers } from 'hardhat'
import {  Wallet, Signer } from 'ethers'
import { SeigManagerV2Proxy } from '../../typechain-types/contracts/proxy/SeigManagerV2Proxy'
import { SeigManagerV2 } from '../../typechain-types/contracts/SeigManagerV2.sol'
import { Layer2ManagerProxy } from '../../typechain-types/contracts/proxy/Layer2ManagerProxy'
import { Layer2Manager } from '../../typechain-types/contracts/Layer2Manager.sol'

import { OptimismSequencerProxy } from '../../typechain-types/contracts/proxy/OptimismSequencerProxy'
import { OptimismSequencer } from '../../typechain-types/contracts/OptimismSequencer'
import { CandidateProxy } from '../../typechain-types/contracts/proxy/CandidateProxy'
import { Candidate } from '../../typechain-types/contracts/Candidate'
import { FwReceiptProxy } from '../../typechain-types/contracts/proxy/FwReceiptProxy'
import { FwReceipt } from '../../typechain-types/contracts/FwReceipt.sol'

import { TON } from '../../typechain-types/contracts/test/TON.sol'
import { Lib_AddressManager } from '../../typechain-types/contracts/test/Lib_AddressManager'
import { MockL1Messenger } from '../../typechain-types/contracts/test/MockL1Messenger'
import { MockL2Messenger } from '../../typechain-types/contracts/test/MockL2Messenger'
import { MockL1Bridge } from '../../typechain-types/contracts/test/MockL1Bridge.sol'
import { MockL2Bridge } from '../../typechain-types/contracts/test/MockL2Bridge'
import { TestERC20 } from '../../typechain-types/contracts/test/TestERC20'

import { LibOperator } from '../../typechain-types/contracts/libraries/LibOperator'
import { LibOptimism } from '../../typechain-types/contracts/libraries/LibOptimism'
import { LibFastWithdraw } from '../../typechain-types/contracts/libraries/LibFastWithdraw.sol'

import Web3EthAbi from 'web3-eth-abi';
import TON_ABI from '../../artifacts/contracts/test/TON.sol/TON.json'
import {
    ParseMessageFixture,
    FastWithdrawMessageFixture, Layer2Fixture, TonStakingV2Fixture, OperatorFixture } from './fixtureInterfaces'
import { keccak256 } from 'ethers/lib/utils'
// mainnet
let tonAddress = "0x2be5e8c109e2197D077D13A82dAead6a9b3433C5";
let tonAdminAddress = "0xDD9f0cCc044B0781289Ee318e5971b0139602C26";

const ifwReceiptAbi = [{
    "inputs": [
      {
        "internalType": "bytes",
        "name": "_l2Messages",
        "type": "bytes"
      }
    ],
    "name": "finalizeFastWithdraw",
    "outputs": [
      {
        "internalType": "uint8",
        "name": "",
        "type": "uint8"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  }];

const iL1BridgeFinalWithdrawAbi = [{
    "inputs": [
      {
        "internalType": "address",
        "name": "_l1Token",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_l2Token",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_from",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_to",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "_amount",
        "type": "uint256"
      },
      {
        "internalType": "bytes",
        "name": "_data",
        "type": "bytes"
      }
    ],
    "name": "finalizeERC20Withdrawal",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }];

const iL1CrossDomainMessengerAbi = [
    {
        "inputs": [
          {
            "internalType": "bytes32",
            "name": "",
            "type": "bytes32"
          }
        ],
        "name": "successfulMessages",
        "outputs": [
          {
            "internalType": "bool",
            "name": "",
            "type": "bool"
          }
        ],
        "stateMutability": "view",
        "type": "function"
      },
      {
        "inputs": [
          {
            "internalType": "address",
            "name": "_target",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "_sender",
            "type": "address"
          },
          {
            "internalType": "bytes",
            "name": "_message",
            "type": "bytes"
          },
          {
            "internalType": "uint256",
            "name": "_messageNonce",
            "type": "uint256"
          }
        ],
        "name": "relayMessage",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
      }
    ] ;
export const stakingV2Fixtures = async function (): Promise<TonStakingV2Fixture> {

    const [deployer, addr1, addr2, sequencer1, dao, stosDistribute ] = await ethers.getSigners();

    await ethers.provider.send("hardhat_impersonateAccount",[tonAdminAddress]);
    const tonAdmin = await ethers.getSigner(tonAdminAddress);


    const factoryLogic = await ethers.getContractFactory('SeigManagerV2')
    const seigManagerV2Logic = (await factoryLogic.connect(deployer).deploy()) as SeigManagerV2

    const factoryProxy = await ethers.getContractFactory('SeigManagerV2Proxy')
    const seigManagerV2Proxy = (await factoryProxy.connect(deployer).deploy()) as SeigManagerV2Proxy
    await seigManagerV2Proxy.connect(deployer).upgradeTo(seigManagerV2Logic.address);

    const seigManagerV2 = seigManagerV2Logic.attach(seigManagerV2Proxy.address) as SeigManagerV2

    // LibOptimism.sol
    const LibOptimism_ = await ethers.getContractFactory('LibOptimism');
    const libOptimism = (await LibOptimism_.connect(deployer).deploy()) as LibOptimism

    // LibOperator.sol
    const LibOperator_ = await ethers.getContractFactory('LibOperator');
    const libOperator = (await LibOperator_.connect(deployer).deploy()) as LibOperator

    // LibFastWithdraw.sol
    const LibFastWithdraw_ = await ethers.getContractFactory('LibFastWithdraw');
    const libFastWithdraw = (await LibFastWithdraw_.connect(deployer).deploy()) as LibFastWithdraw

    //
    const Layer2Manager_ = await ethers.getContractFactory('Layer2Manager', {
        signer: deployer, libraries: { LibOptimism: libOptimism.address, LibOperator: libOperator.address }
    })
    const Layer2ManagerLogic_ = (await Layer2Manager_.connect(deployer).deploy()) as Layer2Manager

    const Layer2ManagerProxy_ = await ethers.getContractFactory('Layer2ManagerProxy')
    const layer2ManagerProxy = (await Layer2ManagerProxy_.connect(deployer).deploy()) as Layer2ManagerProxy
    await layer2ManagerProxy.connect(deployer).upgradeTo(Layer2ManagerLogic_.address);

    const layer2Manager = Layer2ManagerLogic_.attach(layer2ManagerProxy.address) as Layer2Manager

    const OptimismSequencer_ = await ethers.getContractFactory('OptimismSequencer', {
        signer: deployer, libraries: { LibOptimism: libOptimism.address }
    })
    const OptimismSequencerLogic_ = (await OptimismSequencer_.connect(deployer).deploy()) as OptimismSequencer

    const OptimismSequencerProxy_ = await ethers.getContractFactory('OptimismSequencerProxy')
    const optimismSequencerProxy = (await OptimismSequencerProxy_.connect(deployer).deploy()) as OptimismSequencerProxy
    await optimismSequencerProxy.connect(deployer).upgradeTo(OptimismSequencerLogic_.address);
    const optimismSequencer = OptimismSequencerLogic_.attach(optimismSequencerProxy.address) as OptimismSequencer

    //
    const Candidate_ = await ethers.getContractFactory('Candidate' , {
        signer: deployer, libraries: { LibOperator: libOperator.address }
    })
    // const Candidate_ = await ethers.getContractFactory('Candidate')
    const CandidateLogic_ = (await Candidate_.connect(deployer).deploy()) as Candidate

    const CandidateProxy_ = await ethers.getContractFactory('CandidateProxy')
    const candidateProxy = (await CandidateProxy_.connect(deployer).deploy()) as CandidateProxy
    await candidateProxy.connect(deployer).upgradeTo(CandidateLogic_.address);
    const candidate = CandidateLogic_.attach(candidateProxy.address) as Candidate

    //
    const FwReceipt_ = await ethers.getContractFactory('FwReceipt' , {
        signer: deployer, libraries: { LibFastWithdraw: libFastWithdraw.address }
    })
    const FwReceiptLogic_ = (await FwReceipt_.connect(deployer).deploy()) as FwReceipt
    const FwReceiptProxy_ = await ethers.getContractFactory('FwReceiptProxy')
    const fwReceiptProxy = (await FwReceiptProxy_.connect(deployer).deploy()) as FwReceiptProxy
    await fwReceiptProxy.connect(deployer).upgradeTo(FwReceiptLogic_.address);
    const fwReceipt = FwReceiptLogic_.attach(fwReceiptProxy.address) as FwReceipt


    //
    const ton = (await ethers.getContractAt(TON_ABI.abi, tonAddress, deployer)) as TON

    //
    await ethers.provider.send("hardhat_setBalance", [
        tonAdmin.address,
        "0x8ac7230489e80000",
      ]);
    await ton.connect(tonAdmin).addMinter(seigManagerV2Proxy.address);

    //---------

    //--------
    const Lib_AddressManager = await ethers.getContractFactory('Lib_AddressManager')
    const addressManager = (await Lib_AddressManager.connect(deployer).deploy()) as Lib_AddressManager

    await addressManager.connect(deployer).setAddress("OVM_Sequencer", sequencer1.address);

    //---
    const MockL1Messenger = await ethers.getContractFactory('MockL1Messenger')
    const l1Messenger = (await MockL1Messenger.connect(deployer).deploy()) as MockL1Messenger
    const MockL2Messenger = await ethers.getContractFactory('MockL2Messenger')
    const l2Messenger = (await MockL2Messenger.connect(deployer).deploy()) as MockL2Messenger
    const MockL1Bridge = await ethers.getContractFactory('MockL1Bridge')
    const l1Bridge = (await MockL1Bridge.connect(deployer).deploy()) as MockL1Bridge
    const MockL2Bridge = await ethers.getContractFactory('MockL1Bridge')
    const l2Bridge = (await MockL2Bridge.connect(deployer).deploy()) as MockL2Bridge

    await l1Bridge.connect(deployer).setAddress(l1Messenger.address, l2Bridge.address);

    await addressManager.connect(deployer).setAddress("OVM_L1CrossDomainMessenger", l1Messenger.address);
    await addressManager.connect(deployer).setAddress("Proxy__OVM_L1StandardBridge", l1Bridge.address);

    const TestERC20 = await ethers.getContractFactory('TestERC20')
    const l2ton = (await TestERC20.connect(deployer).deploy()) as TestERC20

    return  {
        seigManagerV2Proxy: seigManagerV2Proxy,
        seigManagerV2: seigManagerV2,
        layer2ManagerProxy: layer2ManagerProxy,
        layer2Manager: layer2Manager,
        optimismSequencerProxy: optimismSequencerProxy,
        optimismSequencer: optimismSequencer,
        candidateProxy: candidateProxy,
        candidate: candidate,
        fwReceiptProxy: fwReceiptProxy,
        fwReceipt: fwReceipt,
        ton: ton,
        deployer: deployer,
        addr1: addr1,
        addr2: addr2,
        sequencer1: sequencer1,
        tonAdmin: tonAdmin,
        addressManager: addressManager,
        l1Messenger: l1Messenger,
        l2Messenger: l2Messenger,
        l1Bridge: l1Bridge,
        l2Bridge: l2Bridge,
        l2ton: l2ton,
        dao: dao,
        stosDistribute: stosDistribute
    }
}


export const getLayerKey = async function (info: Layer2Fixture): Promise<string> {

    const constructorArgumentsEncoded = ethers.utils.concat([
            ethers.utils.arrayify(info.addressManager),
            ethers.utils.arrayify(info.l1Bridge),
            ethers.utils.arrayify(info.l2Bridge),
            ethers.utils.arrayify(info.l2ton)
        ]
      )
   return ethers.utils.keccak256(constructorArgumentsEncoded) ;
}

export const getCandidateKey = function (info: OperatorFixture): string{

    const constructorArgumentsEncoded = ethers.utils.concat([
            ethers.utils.arrayify(info.operator),
            ethers.utils.hexZeroPad(ethers.utils.hexlify(info.sequencerIndex), 4),
            ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 2)
        ]
      )
   return ethers.utils.keccak256(constructorArgumentsEncoded) ;
}


export const getCandidateLayerKey = function (info: OperatorFixture): string {
    const constructorArgumentsEncoded = ethers.utils.concat([
            ethers.utils.arrayify(info.operator),
            ethers.utils.hexZeroPad(ethers.utils.hexlify(info.sequencerIndex), 4)
        ]
      )
   return ethers.utils.keccak256(constructorArgumentsEncoded) ;
}

// export const bytesFastWithdrawMessage = async function (
//     fwReceiptContract: string,
//     l1ton: string,
//     layerInfo: Layer2Fixture,
//     info: FastWithdrawMessageFixture): Promise<ParseMessageFixture> {

//     let ifwReceipt = new ethers.utils.Interface(ifwReceiptAbi);
//     let iBridge = new ethers.utils.Interface(iL1BridgeFinalWithdrawAbi);
//     let iL1CrossDomainMessenger = new ethers.utils.Interface(iL1CrossDomainMessengerAbi);

//     // 1+20+20+20+32+2+4+4 = 103
//     let fwRequestBytes = ethers.utils.solidityPack(
//         ["uint8","address","address","address","uint256","uint16","uint32","uint32"],
//         [
//             info.version,
//             layerInfo.l2ton,
//             info.requestor,
//             fwReceiptContract,
//             info.amount.toString(),
//             info.feeRates,
//             info.deadline,
//             info.layerIndex
//         ]
//         );
//     // console.log('fwRequestBytes solidityPack',fwRequestBytes)

//     let fwRequestBytes1 = ethers.utils.solidityPack(
//       ["uint16","uint32","uint32"],
//       [
//           info.feeRates,
//           info.deadline,
//           info.layerIndex
//       ]
//       );
//       let fwReceiptData1 = ifwReceipt.encodeFunctionData("finalizeFastWithdraw",[ fwRequestBytes ]);

//     // 4+103 = 107
//     let fwReceiptData = ifwReceipt.encodeFunctionData("finalizeFastWithdraw",[ fwRequestBytes ]);
//     // console.log('*** fwReceiptData ',fwReceiptData);

//     // 4+20+20+20+20+32+107 = 223
//     let finalizeERC20WithdrawalData = iBridge.encodeFunctionData("finalizeERC20Withdrawal",
//         [
//             l1ton,
//             layerInfo.l2ton,
//             info.requestor,
//             fwReceiptContract,
//             info.amount,
//             fwRequestBytes1 ]
//         );

//     // console.log('finalizeERC20WithdrawalData', finalizeERC20WithdrawalData);

//     // 4+20+20+223+32 = 299
//     let xDomainCalldata = iL1CrossDomainMessenger.encodeFunctionData("relayMessage",
//     [
//         layerInfo.l1Bridge,
//         layerInfo.l2Bridge,
//         finalizeERC20WithdrawalData,
//         info.messageNonce ]);

//     // console.log('relayMessage', xDomainCalldata);

//     let hashMessage = await ethers.utils.keccak256(xDomainCalldata);

//     return  {
//         xDomainCalldata: xDomainCalldata,
//         finalizeERC20WithdrawalData: finalizeERC20WithdrawalData,
//         fwReceiptData: fwReceiptData,
//         fwRequestBytes: fwRequestBytes,
//         hashMessage: hashMessage
//     }
// }

export const bytesFastWithdrawMessage1 = async function (
  fwReceiptContract: string,
  l1ton: string,
  layerInfo: Layer2Fixture,
  info: FastWithdrawMessageFixture): Promise<ParseMessageFixture> {

  let ifwReceipt = new ethers.utils.Interface(ifwReceiptAbi);
  let iBridge = new ethers.utils.Interface(iL1BridgeFinalWithdrawAbi);
  let iL1CrossDomainMessenger = new ethers.utils.Interface(iL1CrossDomainMessengerAbi);

  // 1+20+20+20+32+2+4+4 = 103
  let fwRequestBytes = ethers.utils.solidityPack(
    ["uint16","uint32","uint32"],
    [
        info.feeRates,
        info.deadline,
        info.layerIndex
    ]
    );
  // console.log('fwRequestBytes solidityPack',fwRequestBytes)

  // 4+103 = 107
  let fwReceiptData = ifwReceipt.encodeFunctionData("finalizeFastWithdraw",[ fwRequestBytes ]);
  // console.log('*** fwReceiptData ',fwReceiptData);

  // 4+20+20+20+20+32+107 = 223
  let finalizeERC20WithdrawalData = iBridge.encodeFunctionData("finalizeERC20Withdrawal",
      [
          l1ton,
          layerInfo.l2ton,
          info.requestor,
          fwReceiptContract,
          info.amount,
          fwRequestBytes ]
      );

  // console.log('finalizeERC20WithdrawalData', finalizeERC20WithdrawalData);

  // 4+20+20+223+32 = 299
  let xDomainCalldata = iL1CrossDomainMessenger.encodeFunctionData("relayMessage",
  [
      layerInfo.l1Bridge,
      layerInfo.l2Bridge,
      finalizeERC20WithdrawalData,
      info.messageNonce ]);

  // console.log('relayMessage', xDomainCalldata);

  let hashMessage = await ethers.utils.keccak256(xDomainCalldata);

  return  {
      xDomainCalldata: xDomainCalldata,
      finalizeERC20WithdrawalData: finalizeERC20WithdrawalData,
      fwReceiptData: fwReceiptData,
      fwRequestBytes: fwRequestBytes,
      hashMessage: hashMessage
  }
}
/*
export const bytesFastWithdrawMessage = function (
    fwReceiptContract: string,
    l1ton: string,
    layerInfo: Layer2Fixture,
    info: FastWithdrawMessageFixture): ParseMessageFixture {


    let ifwReceipt = new ethers.utils.Interface(ifwReceiptAbi);
    let iBridge = new ethers.utils.Interface(iL1BridgeFinalWithdrawAbi);
    let erc20WithdrawFunctionSig = Web3EthAbi.encodeFunctionSignature(
            "finalizeERC20Withdrawal(address,address,address,address,uint256,bytes)") ;

    // 1+20+20+20+32+2+4+4 = 103
    let fwRequestBytes = ethers.utils.solidityPack(
        ["uint8","address","address","address","uint256","uint16","uint32","uint32"],
        [
            info.version,
            layerInfo.l2ton,
            info.requestor,
            fwReceiptContract,
            info.amount.toString(),
            info.feeRates,
            info.deadline,
            info.layerIndex
        ]
        );
    // console.log('fwRequestBytes solidityPack',fwRequestBytes)

    // 4+192 = 196
    let fwReceiptData = ifwReceipt.encodeFunctionData("finalizeFastWithdraw",[ fwRequestBytes ]);
    // console.log('*** fwReceiptData ',fwReceiptData);

    // 4+20+20+20+20+32+196 = 312
    // L1Bridge.finalizeERC20Withdrawal(address _l1Token, address _l2Token, address _from, address _to, uint256 _amount, bytes calldata _data  )
    // let finalizeERC20WithdrawalData1 = ethers.utils.solidityPack(
    //     ["bytes4","address","address","address","address","uint256","bytes"],
    //     [erc20WithdrawFunctionSig,
    //         l1ton,
    //         layerInfo.l2ton,
    //         info.requestor,
    //         fwReceiptContract,
    //         info.amount, fwReceiptData]
    //     );

        // 4+ (12byte offset) +  = 452
    let finalizeERC20WithdrawalData = iBridge.encodeFunctionData("finalizeERC20Withdrawal",
        [
            l1ton,
            layerInfo.l2ton,
            info.requestor,
            fwReceiptContract,
            info.amount,
            fwReceiptData ]
        );

    // console.log('finalizeERC20WithdrawalData', finalizeERC20WithdrawalData);

    return  {
        xDomainCalldata: '',
        finalizeERC20WithdrawalData: finalizeERC20WithdrawalData,
        fwReceiptData: fwReceiptData,
        fwRequestBytes: fwRequestBytes
    }
}
*/
export const bytesInvalidFastWithdrawMessage = function (info: FastWithdrawMessageFixture): string {

    let data = ethers.utils.solidityPack(
        [  "address", "uint256", "uint16", "uint32" ],
        [ info.requestor, info.amount, info.feeRates, info.deadline ]
        )

    return data;
}

export enum FW_STATUS {
    NONE,
        CANCELED,
        PROVIDE_LIQUIDITY,
        NORMAL_WITHDRAWAL,
        CANCEL_WITHDRAWAL,
        FINALIZE_WITHDRAWAL,
        CALLER_NOT_L1_BRIDGE,
        ZERO_L1_BRIDGE,
        ZERO_AMOUNT,
        ZERO_REQUESTOR,
        INVALID_LAYERINDEX,
        INVALID_AMOUNT,
        PAST_DEADLINE,
        WRONG_MESSAGE,
        FAIL_FINISH_FW,
        ALREADY_PROCESSED,
        INVALID_LENGTH,
        INVALID_FUNC_SIG,
        UNSUPPORTED_VERSION
}
