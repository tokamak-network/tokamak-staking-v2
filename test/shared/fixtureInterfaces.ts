
import { ethers } from 'hardhat'
import {  Wallet, Signer } from 'ethers'
import { SeigManagerV2Proxy } from '../../typechain-types/contracts/SeigManagerV2Proxy'
import { SeigManagerV2 } from '../../typechain-types/contracts/SeigManagerV2.sol'
import { Layer2ManagerProxy } from '../../typechain-types/contracts/Layer2ManagerProxy'
import { Layer2Manager } from '../../typechain-types/contracts/Layer2Manager.sol'
import { StakingLayer2Proxy } from '../../typechain-types/contracts/StakingLayer2Proxy'
import { StakingLayer2 } from '../../typechain-types/contracts/StakingLayer2.sol'
import { TON } from '../../typechain-types/contracts/test/TON.sol'
import { Lib_AddressManager } from '../../typechain-types/contracts/test/Lib_AddressManager'
import { MockL1Messenger } from '../../typechain-types/contracts/test/MockL1Messenger'
import { MockL2Messenger } from '../../typechain-types/contracts/test/MockL2Messenger'
import { MockL1Bridge } from '../../typechain-types/contracts/test/MockL1Bridge'
import { MockL2Bridge } from '../../typechain-types/contracts/test/MockL2Bridge'
import { TestERC20 } from '../../typechain-types/contracts/test/TestERC20'

interface Layer2Fixture  {
    addressManager: string,
    l1Messenger: string,
    l2Messenger: string,
    l1Bridge: string,
    l2Bridge: string,
    l2ton: string
}

interface TonStakingV2Fixture  {
    seigManagerV2Proxy: SeigManagerV2Proxy
    seigManagerV2: SeigManagerV2
    layer2ManagerProxy: Layer2ManagerProxy
    layer2Manager: Layer2Manager
    stakingLayer2Proxy: StakingLayer2Proxy
    stakingLayer2: StakingLayer2
    ton: TON,
    deployer: Signer,
    addr1: Signer,
    sequencer1: Signer,
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


export { Layer2Fixture, TonStakingV2Fixture }