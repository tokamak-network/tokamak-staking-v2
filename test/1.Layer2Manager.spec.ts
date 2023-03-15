import { expect } from './shared/expect'
import { ethers, network } from 'hardhat'

import { Signer } from 'ethers'
import {stakingV2Fixtures} from './shared/fixtures'
import {TonStakingV2Fixture } from './shared/fixtureInterfaces'
/*
import { SeigManagerV2Proxy } from '../typechain-types/contracts/SeigManagerV2Proxy'
import { SeigManagerV2 } from '../typechain-types/contracts/SeigManagerV2.sol'
import { Layer2ManagerProxy } from '../typechain-types/contracts/Layer2ManagerProxy'
import { Layer2Manager } from '../typechain-types/contracts/Layer2Manager.sol'
import { StakingLayer2Proxy } from '../typechain-types/contracts/StakingLayer2Proxy'
import { StakingLayer2 } from '../typechain-types/contracts/StakingLayer2.sol'
import { TON } from '../typechain-types/contracts/test/TON.sol'
import { Lib_AddressManager } from '../typechain-types/contracts/test/Lib_AddressManager'
import { MockL1Messenger } from '../typechain-types/contracts/test/MockL1Messenger'
import { MockL2Messenger } from '../typechain-types/contracts/test/MockL2Messenger'
import { MockL1Bridge } from '../typechain-types/contracts/test/MockL1Bridge'
import { MockL2Bridge } from '../typechain-types/contracts/test/MockL2Bridge'
import { TestERC20 } from '../typechain-types/contracts/test/TestERC20'

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
    addr2: Signer,
    tonAdmin: Signer,
    addressManager: Lib_AddressManager,
    l1Messenger: MockL1Messenger,
    l2Messenger: MockL2Messenger,
    l1Bridge: MockL1Bridge,
    l2Bridge: MockL2Bridge,
    l2ton: TestERC20
}
*/
describe('Layer2Manager', () => {
    let deployer: Signer, addr1: Signer, sequencer1:Signer

    let deployed: TonStakingV2Fixture

    // mainnet
    let seigManagerInfo = {
        ton: "0x2be5e8c109e2197D077D13A82dAead6a9b3433C5",
        wton: "0xc4A11aaf6ea915Ed7Ac194161d2fC9384F15bff2",
        tot: "0x6FC20Ca22E67aAb397Adb977F092245525f7AeEf",
        seigManagerV1: "0x710936500aC59e8551331871Cbad3D33d5e0D909",
        layer2Manager: "",
        seigPerBlock: ethers.BigNumber.from("3920000000000000000"),
        minimumBlocksForUpdateSeig: 300,
    }

    let layer2ManagerInfo = {
        minimumDepositForSequencer: ethers.utils.parseEther("100"),
        delayBlocksForWithdraw: 300,
    }

    before('create fixture loader', async () => {
        // deployed = await loadFixture(stakingV2Fixtures)

        deployed = await stakingV2Fixtures()
        deployer = deployed.deployer;
        addr1 = deployed.addr1;
        sequencer1 = deployed.sequencer1;
    })

    describe('# initialize', () => {

        it('initialize can not be executed by not owner', async () => {
            await expect(
                deployed.layer2ManagerProxy.connect(addr1).initialize(
                    seigManagerInfo.ton,
                    deployed.seigManagerV2Proxy.address,
                    deployed.stakingLayer2Proxy.address,
                    layer2ManagerInfo.minimumDepositForSequencer,
                    layer2ManagerInfo.delayBlocksForWithdraw
                )
                ).to.be.revertedWith("Accessible: Caller is not an admin")
        })

        it('initialize can be executed by only owner', async () => {
            await deployed.layer2ManagerProxy.connect(deployer).initialize(
                    seigManagerInfo.ton,
                    deployed.seigManagerV2Proxy.address,
                    deployed.stakingLayer2Proxy.address,
                    layer2ManagerInfo.minimumDepositForSequencer,
                    layer2ManagerInfo.delayBlocksForWithdraw
                );

            expect(await deployed.layer2ManagerProxy.ton()).to.eq(seigManagerInfo.ton)
            expect(await deployed.layer2ManagerProxy.seigManagerV2()).to.eq(deployed.seigManagerV2Proxy.address)
            expect(await deployed.layer2ManagerProxy.stakingLayer2()).to.eq(deployed.stakingLayer2Proxy.address)
            expect(await deployed.layer2ManagerProxy.minimumDepositForSequencer()).to.eq(layer2ManagerInfo.minimumDepositForSequencer)
            expect(await deployed.layer2ManagerProxy.delayBlocksForWithdraw()).to.eq(layer2ManagerInfo.delayBlocksForWithdraw)
        })

        it('can execute only once.', async () => {
            await expect(
                deployed.layer2ManagerProxy.connect(deployer).initialize(
                    seigManagerInfo.ton,
                    deployed.seigManagerV2Proxy.address,
                    deployed.stakingLayer2Proxy.address,
                    layer2ManagerInfo.minimumDepositForSequencer,
                    layer2ManagerInfo.delayBlocksForWithdraw
                )
                ).to.be.revertedWith("already initialize")
        })
    });

    describe('# setMaxLayer2Count', () => {

        it('setMaxLayer2Count can not be executed by not owner', async () => {
            const maxLayer2Count = ethers.BigNumber.from("2");
            await expect(
                deployed.layer2Manager.connect(addr1).setMaxLayer2Count(maxLayer2Count)
                ).to.be.revertedWith("Accessible: Caller is not an admin")
        })

        it('setMaxLayer2Count can be executed by only owner ', async () => {
            const maxLayer2Count = ethers.BigNumber.from("2");
            await deployed.layer2Manager.connect(deployer).setMaxLayer2Count(maxLayer2Count)
            expect(await deployed.layer2Manager.maxLayer2Count()).to.eq(maxLayer2Count)

            await deployed.layer2Manager.connect(deployer).setMaxLayer2Count(ethers.constants.One)
            expect(await deployed.layer2Manager.maxLayer2Count()).to.eq(ethers.constants.One)
        })

        it('cannot be changed to the same value', async () => {
            const maxLayer2Count = ethers.constants.One
            await expect(
                deployed.layer2Manager.connect(deployer).setMaxLayer2Count(maxLayer2Count)
                ).to.be.revertedWith("same")
        })
    });

    describe('# setMinimumDepositForSequencer', () => {

        it('setMinimumDepositForSequencer can not be executed by not owner', async () => {
            const minimumDepositForSequencer = ethers.utils.parseEther("200");
            await expect(
                deployed.layer2Manager.connect(addr1).setMinimumDepositForSequencer(minimumDepositForSequencer)
                ).to.be.revertedWith("Accessible: Caller is not an admin")
        })

        it('setMinimumDepositForSequencer can be executed by only owner ', async () => {
            const minimumDepositForSequencer = ethers.utils.parseEther("200");
            await deployed.layer2Manager.connect(deployer).setMinimumDepositForSequencer(minimumDepositForSequencer)
            expect(await deployed.layer2Manager.minimumDepositForSequencer()).to.eq(minimumDepositForSequencer)

            await deployed.layer2Manager.connect(deployer).setMinimumDepositForSequencer(layer2ManagerInfo.minimumDepositForSequencer)
            expect(await deployed.layer2Manager.minimumDepositForSequencer()).to.eq(layer2ManagerInfo.minimumDepositForSequencer)
        })

        it('cannot be changed to the same value', async () => {
            await expect(
                deployed.layer2Manager.connect(deployer).setMinimumDepositForSequencer(layer2ManagerInfo.minimumDepositForSequencer)
                ).to.be.revertedWith("same")
        })
    });

    describe('# setDelayBlocksForWithdraw', () => {

        it('setDelayBlocksForWithdraw can not be executed by not owner', async () => {
            const delayBlocksForWithdraw = ethers.BigNumber.from("100");
            await expect(
                deployed.layer2Manager.connect(addr1).setDelayBlocksForWithdraw(delayBlocksForWithdraw)
                ).to.be.revertedWith("Accessible: Caller is not an admin")
        })

        it('setDelayBlocksForWithdraw can be executed by only owner ', async () => {
            const delayBlocksForWithdraw = ethers.BigNumber.from("100");
            await deployed.layer2Manager.connect(deployer).setDelayBlocksForWithdraw(delayBlocksForWithdraw)
            expect(await deployed.layer2Manager.delayBlocksForWithdraw()).to.eq(delayBlocksForWithdraw)


            await deployed.layer2Manager.connect(deployer).setDelayBlocksForWithdraw(layer2ManagerInfo.delayBlocksForWithdraw)
            expect(await deployed.layer2Manager.delayBlocksForWithdraw()).to.eq(layer2ManagerInfo.delayBlocksForWithdraw)
        })

        it('cannot be changed to the same value', async () => {
            await expect(
                deployed.layer2Manager.connect(deployer).setDelayBlocksForWithdraw(layer2ManagerInfo.delayBlocksForWithdraw)
                ).to.be.revertedWith("same")
        })
    });

    describe('#create', () => {

        it('Cannot be created unless the caller is the layer\'s sequencer.', async () => {
            expect(await deployed.addressManager.getAddress("OVM_Sequencer")).to.not.eq(addr1.address)
            await expect(
                deployed.layer2Manager.connect(addr1).create(
                    deployed.addressManager.address,
                    deployed.l1Messenger.address,
                    deployed.l2Messenger.address,
                    deployed.l1Bridge.address,
                    deployed.l2Bridge.address,
                    deployed.l2ton.address
                )
                ).to.be.revertedWith("NOT Sequencer")
        })

        it('If the minimum security deposit is not provided, it cannot be created.', async () => {

            expect(await deployed.addressManager.getAddress("OVM_Sequencer")).to.eq(sequencer1.address)
            await expect(
                deployed.layer2Manager.connect(sequencer1).create(
                    deployed.addressManager.address,
                    deployed.l1Messenger.address,
                    deployed.l2Messenger.address,
                    deployed.l1Bridge.address,
                    deployed.l2Bridge.address,
                    deployed.l2ton.address
                )).to.be.reverted;
        })

        it('Approve the minimum security deposit and create.', async () => {

            expect(await deployed.addressManager.getAddress("OVM_Sequencer")).to.eq(sequencer1.address)
            let totalSecurityDeposit = await deployed.layer2Manager.totalSecurityDeposit();
            let amount = await deployed.layer2Manager.minimumDepositForSequencer();

            if (amount.gt(await deployed.ton.balanceOf(sequencer1.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(sequencer1.address, amount)).wait();


            if (amount.gte(await deployed.ton.allowance(sequencer1.address, deployed.layer2Manager.address)))
                await (await deployed.ton.connect(sequencer1).approve(deployed.layer2Manager.address, amount)).wait();

            await deployed.layer2Manager.connect(sequencer1).create(
                    deployed.addressManager.address,
                    deployed.l1Messenger.address,
                    deployed.l2Messenger.address,
                    deployed.l1Bridge.address,
                    deployed.l2Bridge.address,
                    deployed.l2ton.address
                );

            expect(await deployed.layer2Manager.totalSecurityDeposit()).to.eq(totalSecurityDeposit.add(amount))
        })

    });

});

