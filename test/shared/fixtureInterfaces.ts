
import { ethers } from 'hardhat'
import { BigNumber } from 'ethers'
import {  Wallet, Signer } from 'ethers'
import { SeigManagerV2Proxy } from '../../typechain-types/contracts/proxy/SeigManagerV2Proxy'
import { SeigManagerV2 } from '../../typechain-types/contracts/SeigManagerV2.sol'
import { Layer2ManagerProxy } from '../../typechain-types/contracts/proxy/Layer2ManagerProxy'
import { Layer2Manager } from '../../typechain-types/contracts/Layer2Manager.sol'

import { OptimismL2OperatorProxy } from '../../typechain-types/contracts/proxy/OptimismL2OperatorProxy'
import { OptimismL2Operator } from '../../typechain-types/contracts/OptimismL2Operator'
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

interface StakeSnapshotFixture  {
    id: BigNumber,
    layerIndex: number,
    account: string,
    indexLton: BigNumber,
    totalStakedLton: BigNumber,
    balanceOfLayer: BigNumber,
    balanceOfAccount: BigNumber
}

interface ParseMessageFixture  {
    xDomainCalldata: string,
    finalizeERC20WithdrawalData: string,
    fwReceiptData: string,
    fwRequestBytes: string,
    hashMessage: string
}

interface DomainMessageFixture  {
    messageNonce: number,
    fwReceipt: string,
    l1ton: string,
    layerInfo: Layer2Fixture,
    messageInfo: FastWithdrawMessageFixture,
    provider: string,
    isCandidate: boolean,
    indexNo: number,
    parseMessage: ParseMessageFixture
    // xDomainCalldata: string,
    // finalizeERC20WithdrawalData: string,
    // fwReceiptData: string,
    // fwRequestBytes: string
}

interface FastWithdrawMessageFixture  {
    version: number,
    requestor: string,
    amount: BigNumber,
    feeRates: number,
    deadline: number,
    layerIndex: number,
    messageNonce: BigNumber
}
interface Layer2Fixture  {
    addressManager: string,
    l1Messenger: string,
    l2Messenger: string,
    l1Bridge: string,
    l2Bridge: string,
    l2ton: string
}

interface OperatorFixture  {
    operator: string,
    operatorIndex: number,
    commission: number
}

interface TonStakingV2Fixture  {
    seigManagerV2Proxy: SeigManagerV2Proxy
    seigManagerV2: SeigManagerV2
    layer2ManagerProxy: Layer2ManagerProxy
    layer2Manager: Layer2Manager
    optimismL2OperatorProxy: OptimismL2OperatorProxy
    optimismL2Operator: OptimismL2Operator
    candidateProxy: CandidateProxy
    candidate: Candidate
    fwReceiptProxy: FwReceiptProxy
    fwReceipt: FwReceipt
    ton: TON,
    deployer: Signer,
    addr1: Signer,
    addr2: Signer,
    operator1: Signer,
    tonAdmin: Signer,
    addressManager: Lib_AddressManager,
    l1Messenger: MockL1Messenger,
    l2Messenger: MockL2Messenger,
    l1Bridge: MockL1Bridge,
    l2Bridge: MockL2Bridge,
    l2ton: TestERC20,
    dao: Signer,
    stosDistribute: Signer
}


export { StakeSnapshotFixture, ParseMessageFixture, DomainMessageFixture, FastWithdrawMessageFixture, Layer2Fixture, TonStakingV2Fixture, OperatorFixture }