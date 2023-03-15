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

import TON_ABI from '../../artifacts/contracts/test/TON.sol/TON.json'
import {Layer2Fixture, TonStakingV2Fixture } from './fixtureInterfaces'
// mainnet
let tonAddress = "0x2be5e8c109e2197D077D13A82dAead6a9b3433C5";
let tonAdminAddress = "0xDD9f0cCc044B0781289Ee318e5971b0139602C26";
/*
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
*/
export const stakingV2Fixtures = async function (): Promise<TonStakingV2Fixture> {

    const [deployer, addr1, sequencer1, dao, stosDistribute ] = await ethers.getSigners();

    await ethers.provider.send("hardhat_impersonateAccount",[tonAdminAddress]);
    const tonAdmin = await ethers.getSigner(tonAdminAddress);


    const factoryLogic = await ethers.getContractFactory('SeigManagerV2')
    const seigManagerV2Logic = (await factoryLogic.connect(deployer).deploy()) as SeigManagerV2

    const factoryProxy = await ethers.getContractFactory('SeigManagerV2Proxy')
    const seigManagerV2Proxy = (await factoryProxy.connect(deployer).deploy()) as SeigManagerV2Proxy
    await seigManagerV2Proxy.connect(deployer).upgradeTo(seigManagerV2Logic.address);

    const seigManagerV2 = seigManagerV2Logic.attach(seigManagerV2Proxy.address) as SeigManagerV2

    //
    const Layer2Manager_ = await ethers.getContractFactory('Layer2Manager')
    const Layer2ManagerLogic_ = (await Layer2Manager_.connect(deployer).deploy()) as Layer2Manager

    const Layer2ManagerProxy_ = await ethers.getContractFactory('Layer2ManagerProxy')
    const layer2ManagerProxy = (await Layer2ManagerProxy_.connect(deployer).deploy()) as Layer2ManagerProxy
    await layer2ManagerProxy.connect(deployer).upgradeTo(Layer2ManagerLogic_.address);

    const layer2Manager = Layer2ManagerLogic_.attach(layer2ManagerProxy.address) as Layer2Manager

    //
    const StakingLayer2_ = await ethers.getContractFactory('StakingLayer2')
    const StakingLayer2Logic_ = (await StakingLayer2_.connect(deployer).deploy()) as StakingLayer2

    const StakingLayer2Proxy_ = await ethers.getContractFactory('StakingLayer2Proxy')
    const stakingLayer2Proxy = (await StakingLayer2Proxy_.connect(deployer).deploy()) as StakingLayer2Proxy
    await stakingLayer2Proxy.connect(deployer).upgradeTo(StakingLayer2Logic_.address);
    const stakingLayer2 = StakingLayer2Logic_.attach(stakingLayer2Proxy.address) as StakingLayer2

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

    const TestERC20 = await ethers.getContractFactory('TestERC20')
    const l2ton = (await TestERC20.connect(deployer).deploy()) as TestERC20

    return  {
        seigManagerV2Proxy: seigManagerV2Proxy,
        seigManagerV2: seigManagerV2,
        layer2ManagerProxy: layer2ManagerProxy,
        layer2Manager: layer2Manager,
        stakingLayer2Proxy: stakingLayer2Proxy,
        stakingLayer2: stakingLayer2,
        ton: ton,
        deployer: deployer,
        addr1: addr1,
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
    const constructorArgumentsEncoded = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'address', 'address', 'address', 'address'],
        [   info.addressManager,
            info.l1Messenger,
            info.l2Messenger,
            info.l1Bridge,
            info.l2Bridge,
            info.l2ton]
      )
   return ethers.utils.keccak256(constructorArgumentsEncoded) ;
}