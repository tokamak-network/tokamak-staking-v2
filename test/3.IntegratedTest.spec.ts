import { expect } from './shared/expect'
import { ethers, network } from 'hardhat'

import { Signer } from 'ethers'
import { stakingV2Fixtures, getLayerKey} from './shared/fixtures'
import { TonStakingV2Fixture } from './shared/fixtureInterfaces'

describe('Integrated Test', () => {
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

        it('SeigManagerV2 : initialize can be executed by only owner', async () => {
            await deployed.seigManagerV2Proxy.connect(deployer).initialize(
                    seigManagerInfo.ton,
                    seigManagerInfo.wton,
                    seigManagerInfo.tot,
                    seigManagerInfo.seigManagerV1,
                    deployed.layer2ManagerProxy.address,
                    deployed.stakingLayer2Proxy.address,
                    seigManagerInfo.seigPerBlock,
                    seigManagerInfo.minimumBlocksForUpdateSeig
                );

            expect(await deployed.seigManagerV2Proxy.ton()).to.eq(seigManagerInfo.ton)
            expect(await deployed.seigManagerV2Proxy.wton()).to.eq(seigManagerInfo.wton)
            expect(await deployed.seigManagerV2Proxy.tot()).to.eq(seigManagerInfo.tot)
            expect(await deployed.seigManagerV2Proxy.seigManagerV1()).to.eq(seigManagerInfo.seigManagerV1)
            expect(await deployed.seigManagerV2Proxy.layer2Manager()).to.eq(deployed.layer2ManagerProxy.address)
            expect(await deployed.seigManagerV2Proxy.seigPerBlock()).to.eq(seigManagerInfo.seigPerBlock)
            expect(await deployed.seigManagerV2Proxy.minimumBlocksForUpdateSeig()).to.eq(seigManagerInfo.minimumBlocksForUpdateSeig)

        })


        it('Layer2Manager : initialize can be executed by only owner', async () => {
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

        it('StakingLayer2 : initialize can be executed by only owner', async () => {
            await deployed.stakingLayer2Proxy.connect(deployer).initialize(
                seigManagerInfo.ton,
                deployed.seigManagerV2Proxy.address,
                deployed.layer2ManagerProxy.address
                );

            expect(await deployed.stakingLayer2Proxy.ton()).to.eq(seigManagerInfo.ton)
            expect(await deployed.stakingLayer2Proxy.seigManagerV2()).to.eq(deployed.seigManagerV2Proxy.address)
            expect(await deployed.stakingLayer2Proxy.layer2Manager()).to.eq(deployed.layer2ManagerProxy.address)

        })

    });

    describe('# setLastSeigBlock', () => {

        it('LastSeigBlock can be executed by only owner ', async () => {
            const block = await ethers.provider.getBlock('latest')
            await deployed.seigManagerV2.connect(deployer).setLastSeigBlock(block.number)
            expect(await deployed.seigManagerV2.lastSeigBlock()).to.eq(block.number)
        })

    });

    describe('# setMaxLayer2Count', () => {

        it('setMaxLayer2Count can be executed by only owner ', async () => {
            const maxLayer2Count = ethers.BigNumber.from("2");
            await deployed.layer2Manager.connect(deployer).setMaxLayer2Count(maxLayer2Count)
            expect(await deployed.layer2Manager.maxLayer2Count()).to.eq(maxLayer2Count)

            await deployed.layer2Manager.connect(deployer).setMaxLayer2Count(ethers.constants.One)
            expect(await deployed.layer2Manager.maxLayer2Count()).to.eq(ethers.constants.One)
        })

    });

    describe('# create', () => {

        it('Approve the minimum security deposit and create.', async () => {
            let totalLayerKeys = await deployed.layer2Manager.totalLayerKeys()

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

            expect(await deployed.layer2Manager.totalLayerKeys()).to.eq(totalLayerKeys.add(1))
            expect(await deployed.layer2Manager.totalSecurityDeposit()).to.eq(totalSecurityDeposit.add(amount))

            let layerKey = await getLayerKey({
                    addressManager: deployed.addressManager.address,
                    l1Messenger: deployed.l1Messenger.address,
                    l2Messenger: deployed.l2Messenger.address,
                    l1Bridge: deployed.l1Bridge.address,
                    l2Bridge: deployed.l2Bridge.address,
                    l2ton: deployed.l2ton.address
                }
            );

            expect(await deployed.layer2Manager.layerKeys(totalLayerKeys)).to.eq(layerKey)

            let layer = await deployed.layer2Manager.getLayerInfo(layerKey);
            expect(layer.addressManager).to.eq(deployed.addressManager.address)
            expect(layer.l1Messenger).to.eq(deployed.l1Messenger.address)
            expect(layer.l2Messenger).to.eq(deployed.l2Messenger.address)
            expect(layer.l1Bridge).to.eq(deployed.l1Bridge.address)
            expect(layer.l2Bridge).to.eq(deployed.l2Bridge.address)
            expect(layer.l2ton).to.eq(deployed.l2ton.address)

            let getAllLayerKeys = await deployed.layer2Manager.getAllLayerKeys();
            expect(getAllLayerKeys[getAllLayerKeys.length-1]).to.eq(layerKey)
        })

    });

    describe('# stake', () => {

        it('You cannot stake on unregistered layers.', async () => {
            let amount = ethers.utils.parseEther("100");
            let addressOne ="0x0000000000000000000000000000000000000001";
            let layerOne = {
                addressManager: addressOne,
                l1Messenger: deployed.l2ton.address,
                l2Messenger: deployed.l2ton.address,
                l1Bridge: deployed.l2ton.address,
                l2Bridge:deployed.l2ton.address,
                l2ton: deployed.l2ton.address
            }

            let layerKey = await getLayerKey(layerOne);

            await expect(
                deployed.stakingLayer2.connect(addr1).stake(
                    layerKey,
                    amount
                )
                ).to.be.revertedWith("non-registered layer")

        })

        it('If TON are not approved prior to staking, staking is not possible.', async () => {
            let amount = ethers.utils.parseEther("100");

            let layerOne = {
                addressManager: deployed.addressManager.address,
                l1Messenger: deployed.l1Messenger.address,
                l2Messenger: deployed.l2Messenger.address,
                l1Bridge: deployed.l1Bridge.address,
                l2Bridge:deployed.l2Bridge.address,
                l2ton: deployed.l2ton.address
            }

            let layerKey = await getLayerKey(layerOne);

            await expect(
                deployed.stakingLayer2.connect(addr1).stake(
                    layerKey,
                    amount
                )).to.be.reverted;

        })

        it('If it is a registered layer, you can stake it.', async () => {
            let amount = ethers.utils.parseEther("5000");

            let layerOne = {
                addressManager: deployed.addressManager.address,
                l1Messenger: deployed.l1Messenger.address,
                l2Messenger: deployed.l2Messenger.address,
                l1Bridge: deployed.l1Bridge.address,
                l2Bridge:deployed.l2Bridge.address,
                l2ton: deployed.l2ton.address
            }

            let layerKey = await getLayerKey(layerOne);

            // let totalStakedPrincipal = await deployed.stakingLayer2.totalStakedPrincipal()
            let totalStakedLton = await deployed.stakingLayer2.totalStakedLton()
            let totalStakeAccountList = await deployed.stakingLayer2.totalStakeAccountList()

            if (amount.gt(await deployed.ton.balanceOf(addr1.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(addr1.address, amount)).wait();

            if (amount.gte(await deployed.ton.allowance(addr1.address, deployed.stakingLayer2.address)))
                await (await deployed.ton.connect(addr1).approve(deployed.stakingLayer2.address, amount)).wait();

            await (await deployed.stakingLayer2.connect(addr1).stake(
                    layerKey,
                    amount
                )).wait();

            // expect(await deployed.stakingLayer2.totalStakedPrincipal()).to.eq(totalStakedPrincipal.add(amount))
            expect(await deployed.stakingLayer2.totalStakedLton()).to.gt(totalStakedLton)
            expect(await deployed.stakingLayer2.totalStakeAccountList()).to.eq(totalStakeAccountList.add(1))
            expect(await deployed.stakingLayer2.stakeAccountList(totalStakeAccountList)).to.eq(addr1.address)

            let lton = await deployed.seigManagerV2.getTonToLton(amount);
            expect(await deployed.stakingLayer2.balanceOfLton(layerKey, addr1.address)).to.eq(lton)
            expect(await deployed.stakingLayer2.balanceOf(layerKey, addr1.address)).to.eq(amount)
        })
    });


    describe('# updateSeigniorage', () => {
        it('After the recent seignorage issuance, seignorage will not be issued unless the minimum block has passed.', async () => {
            const lastSeigBlock = await deployed.seigManagerV2.lastSeigBlock()
            const minimumBlocksForUpdateSeig = await deployed.seigManagerV2.minimumBlocksForUpdateSeig()
            const block = await ethers.provider.getBlock('latest')

            await deployed.seigManagerV2.connect(addr1).updateSeigniorage()

            if (block.number - lastSeigBlock.toNumber() < minimumBlocksForUpdateSeig ) {
                expect(await deployed.seigManagerV2.lastSeigBlock()).to.eq(lastSeigBlock)
            } else {
                expect(await deployed.seigManagerV2.lastSeigBlock()).to.gt(lastSeigBlock)
            }
        })

        it("      pass blocks", async function () {
            const minimumBlocksForUpdateSeig = await deployed.seigManagerV2.minimumBlocksForUpdateSeig()
            let i
            for (i = 0; i < minimumBlocksForUpdateSeig; i++){
                await ethers.provider.send('evm_mine');
            }
        });

        it('If the sum of the staking amount and the bonding liquidity amount is greater than 0, indexLton increase.', async () => {
            let layerOne = {
                addressManager: deployed.addressManager.address,
                l1Messenger: deployed.l1Messenger.address,
                l2Messenger: deployed.l2Messenger.address,
                l1Bridge: deployed.l1Bridge.address,
                l2Bridge:deployed.l2Bridge.address,
                l2ton: deployed.l2ton.address
            }

            let layerKey = await getLayerKey(layerOne);
            let prevBalanceOf = await deployed.stakingLayer2.balanceOf(layerKey, addr1.address);
            let prevBalanceLtonOf =await deployed.stakingLayer2.balanceOfLton(layerKey, addr1.address)

            expect(await deployed.seigManagerV2.ratesDao()).to.eq(0)
            expect(await deployed.seigManagerV2.ratesStosHolders()).to.eq(0)

            expect(await deployed.seigManagerV2.getTotalLton()).to.gt(ethers.constants.Zero)
            const indexLton = await deployed.seigManagerV2.indexLton();
            await deployed.seigManagerV2.connect(addr1).updateSeigniorage()
            expect(await deployed.seigManagerV2.indexLton()).to.gt(indexLton)

            expect(await deployed.ton.balanceOf(deployed.dao.address)).to.eq(0)
            expect(await deployed.ton.balanceOf(deployed.stosDistribute.address)).to.eq(0)

            expect(await deployed.stakingLayer2.balanceOfLton(layerKey, addr1.address)).to.eq(prevBalanceLtonOf)
            expect(await deployed.stakingLayer2.balanceOf(layerKey, addr1.address)).to.gt(prevBalanceOf)
        });

        it("      pass blocks", async function () {
            const minimumBlocksForUpdateSeig = await deployed.seigManagerV2.minimumBlocksForUpdateSeig()
            let i
            for (i = 0; i < minimumBlocksForUpdateSeig; i++){
                await ethers.provider.send('evm_mine');
            }
        });

        it('setDividendRates can be executed by only owner ', async () => {
            let rates = {
                ratesDao: 5000,           // 0.5 , 0.002 %
                ratesStosHolders: 2000,  // 0.2
                ratesTonStakers: 3000,   // 0.3
                ratesUnits: 10000
            }

            await deployed.seigManagerV2.connect(deployer).setDividendRates(
                    rates.ratesDao,
                    rates.ratesStosHolders,
                    rates.ratesTonStakers,
                    rates.ratesUnits
                )
            expect(await deployed.seigManagerV2.ratesDao()).to.eq(rates.ratesDao)
            expect(await deployed.seigManagerV2.ratesStosHolders()).to.eq(rates.ratesStosHolders)
            expect(await deployed.seigManagerV2.ratesTonStakers()).to.eq(rates.ratesTonStakers)
            expect(await deployed.seigManagerV2.ratesUnits()).to.eq(rates.ratesUnits)
        })

        it('setAddress can be executed by only owner ', async () => {
            await deployed.seigManagerV2.connect(deployer).setAddress(
                    deployed.dao.address,
                    deployed.stosDistribute.address
                )
            expect(await deployed.seigManagerV2.dao()).to.eq(deployed.dao.address)
            expect(await deployed.seigManagerV2.stosDistribute()).to.eq(deployed.stosDistribute.address)

        })

        it('If you set the DAO and dividend rate for seig, seig is granted to the DAO.', async () => {
            let layerOne = {
                addressManager: deployed.addressManager.address,
                l1Messenger: deployed.l1Messenger.address,
                l2Messenger: deployed.l2Messenger.address,
                l1Bridge: deployed.l1Bridge.address,
                l2Bridge:deployed.l2Bridge.address,
                l2ton: deployed.l2ton.address
            }

            let layerKey = await getLayerKey(layerOne);
            let prevBalanceOf = await deployed.stakingLayer2.balanceOf(layerKey, addr1.address);
            let prevBalanceLtonOf =await deployed.stakingLayer2.balanceOfLton(layerKey, addr1.address)

            const topic = deployed.seigManagerV2.interface.getEventTopic('UpdatedSeigniorage');
            const balanceOfDao = await deployed.ton.balanceOf(deployed.dao.address)
            const balanceOfStosDistribute = await deployed.ton.balanceOf(deployed.stosDistribute.address)

            expect(await deployed.seigManagerV2.ratesDao()).to.gt(0)
            expect(await deployed.seigManagerV2.ratesStosHolders()).to.gt(0)

            expect(await deployed.seigManagerV2.getTotalLton()).to.gt(ethers.constants.Zero)
            const indexLton = await deployed.seigManagerV2.indexLton();
            const receipt = await (await deployed.seigManagerV2.connect(addr1).updateSeigniorage()).wait();
            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = deployed.seigManagerV2.interface.parseLog(log);

            expect(await deployed.seigManagerV2.indexLton()).to.gt(indexLton)
            expect(await deployed.ton.balanceOf(deployed.dao.address)).to.eq(balanceOfDao.add(deployedEvent.args.amount_[2]))
            expect(await deployed.ton.balanceOf(deployed.stosDistribute.address)).to.eq(balanceOfStosDistribute.add(deployedEvent.args.amount_[3]))

            expect(deployedEvent.args.increaseSeig_).to.gte(
                deployedEvent.args.amount_[0]
                .add(deployedEvent.args.amount_[1])
                .add(deployedEvent.args.amount_[2])
                .add(deployedEvent.args.amount_[3])
            )

            expect(await deployed.stakingLayer2.balanceOfLton(layerKey, addr1.address)).to.eq(prevBalanceLtonOf)
            expect(await deployed.stakingLayer2.balanceOf(layerKey, addr1.address)).to.gt(prevBalanceOf)
        });
    });

    /*
    describe('# unstake', () => {
        it('You can unstake when you have the staked amount.', async () => {
            let amount = ethers.utils.parseEther("5000");

            let layerOne = {
                addressManager: deployed.addressManager.address,
                l1Messenger: deployed.l1Messenger.address,
                l2Messenger: deployed.l2Messenger.address,
                l1Bridge: deployed.l1Bridge.address,
                l2Bridge:deployed.l2Bridge.address,
                l2ton: deployed.l2ton.address
            }

            let layerKey = await getLayerKey(layerOne);

            // let totalStakedPrincipal = await deployed.stakingLayer2.totalStakedPrincipal()
            let totalStakedLton = await deployed.stakingLayer2.totalStakedLton()
            let totalStakeAccountList = await deployed.stakingLayer2.totalStakeAccountList()

            await (await deployed.stakingLayer2.connect(addr1).unstake(
                    layerKey,
                    amount
                )).wait();

            // expect(await deployed.stakingLayer2.totalStakedPrincipal()).to.eq(totalStakedPrincipal.add(amount))
            expect(await deployed.stakingLayer2.totalStakedLton()).to.gt(totalStakedLton)
            expect(await deployed.stakingLayer2.totalStakeAccountList()).to.eq(totalStakeAccountList.add(1))
            expect(await deployed.stakingLayer2.stakeAccountList(totalStakeAccountList)).to.eq(addr1.address)

            let lton = await deployed.seigManagerV2.getTonToLton(amount);
            expect(await deployed.stakingLayer2.balanceOfLton(layerKey, addr1.address)).to.eq(lton)
            expect(await deployed.stakingLayer2.balanceOf(layerKey, addr1.address)).to.eq(amount)
        })
    });
    */
});

