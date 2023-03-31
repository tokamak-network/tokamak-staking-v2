import { expect } from './shared/expect'
import { ethers, network } from 'hardhat'

import { Signer } from 'ethers'
import { stakingV2Fixtures, getLayerKey, getCandidateKey, getCandidateLayerKey} from './shared/fixtures'
import { TonStakingV2Fixture } from './shared/fixtureInterfaces'
import snapshotGasCost from './shared/snapshotGasCost'

describe('Integrated Test', () => {
    let deployer: Signer, addr1: Signer, addr2: Signer, sequencer1:Signer

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
        minimumDepositForCandidate: ethers.utils.parseEther("200"),
        delayBlocksForWithdraw: 300,
    }

    before('create fixture loader', async () => {
        // deployed = await loadFixture(stakingV2Fixtures)

        deployed = await stakingV2Fixtures()
        deployer = deployed.deployer;
        addr1 = deployed.addr1;
        addr2 = deployed.addr2;
        sequencer1 = deployed.sequencer1;
    })

    describe('# initialize', () => {

        it('SeigManagerV2 : initialize can be executed by only owner', async () => {
            await snapshotGasCost(
                deployed.seigManagerV2Proxy.connect(deployer).initialize(
                        seigManagerInfo.ton,
                        seigManagerInfo.wton,
                        seigManagerInfo.tot,
                        seigManagerInfo.seigManagerV1,
                        deployed.layer2ManagerProxy.address,
                        deployed.optimismSequencerProxy.address,
                        deployed.candidateProxy.address,
                        seigManagerInfo.seigPerBlock,
                        seigManagerInfo.minimumBlocksForUpdateSeig
                    )
            );

            expect(await deployed.seigManagerV2Proxy.ton()).to.eq(seigManagerInfo.ton)
            expect(await deployed.seigManagerV2Proxy.wton()).to.eq(seigManagerInfo.wton)
            expect(await deployed.seigManagerV2Proxy.tot()).to.eq(seigManagerInfo.tot)
            expect(await deployed.seigManagerV2Proxy.seigManagerV1()).to.eq(seigManagerInfo.seigManagerV1)
            expect(await deployed.seigManagerV2Proxy.layer2Manager()).to.eq(deployed.layer2ManagerProxy.address)
            expect(await deployed.seigManagerV2Proxy.optimismSequencer()).to.eq(deployed.optimismSequencerProxy.address)
            expect(await deployed.seigManagerV2Proxy.candidate()).to.eq(deployed.candidateProxy.address)

            expect(await deployed.seigManagerV2Proxy.seigPerBlock()).to.eq(seigManagerInfo.seigPerBlock)
            expect(await deployed.seigManagerV2Proxy.minimumBlocksForUpdateSeig()).to.eq(seigManagerInfo.minimumBlocksForUpdateSeig)

        })


        it('Layer2Manager : initialize can be executed by only owner', async () => {
            await snapshotGasCost(deployed.layer2ManagerProxy.connect(deployer).initialize(
                    seigManagerInfo.ton,
                    deployed.seigManagerV2Proxy.address,
                    deployed.optimismSequencerProxy.address,
                    deployed.candidateProxy.address,
                    layer2ManagerInfo.minimumDepositForSequencer,
                    layer2ManagerInfo.minimumDepositForCandidate,
                    layer2ManagerInfo.delayBlocksForWithdraw
                ))

            expect(await deployed.layer2ManagerProxy.ton()).to.eq(seigManagerInfo.ton)
            expect(await deployed.layer2ManagerProxy.seigManagerV2()).to.eq(deployed.seigManagerV2Proxy.address)
            expect(await deployed.layer2ManagerProxy.optimismSequencer()).to.eq(deployed.optimismSequencerProxy.address)
            expect(await deployed.layer2ManagerProxy.candidate()).to.eq(deployed.candidateProxy.address)

            expect(await deployed.layer2ManagerProxy.minimumDepositForSequencer()).to.eq(layer2ManagerInfo.minimumDepositForSequencer)
            expect(await deployed.layer2ManagerProxy.minimumDepositForCandidate()).to.eq(layer2ManagerInfo.minimumDepositForCandidate)

            expect(await deployed.layer2ManagerProxy.delayBlocksForWithdraw()).to.eq(layer2ManagerInfo.delayBlocksForWithdraw)
        })

        it('OptimismSequencer : initialize can be executed by only owner', async () => {
            await snapshotGasCost(deployed.optimismSequencerProxy.connect(deployer).initialize(
                seigManagerInfo.ton,
                deployed.seigManagerV2Proxy.address,
                deployed.layer2ManagerProxy.address
                ))

            expect(await deployed.optimismSequencerProxy.ton()).to.eq(seigManagerInfo.ton)
            expect(await deployed.optimismSequencerProxy.seigManagerV2()).to.eq(deployed.seigManagerV2Proxy.address)
            expect(await deployed.optimismSequencerProxy.layer2Manager()).to.eq(deployed.layer2ManagerProxy.address)

        })

        it('Candidate : initialize can be executed by only owner', async () => {
            await snapshotGasCost(deployed.candidateProxy.connect(deployer).initialize(
                seigManagerInfo.ton,
                deployed.seigManagerV2Proxy.address,
                deployed.layer2ManagerProxy.address
                ))

            expect(await deployed.candidateProxy.ton()).to.eq(seigManagerInfo.ton)
            expect(await deployed.candidateProxy.seigManagerV2()).to.eq(deployed.seigManagerV2Proxy.address)
            expect(await deployed.candidateProxy.layer2Manager()).to.eq(deployed.layer2ManagerProxy.address)

        })


    });

    describe('# setLastSeigBlock', () => {

        it('LastSeigBlock can be executed by only owner ', async () => {
            const block = await ethers.provider.getBlock('latest')
            await snapshotGasCost(deployed.seigManagerV2.connect(deployer).setLastSeigBlock(block.number))
            expect(await deployed.seigManagerV2.lastSeigBlock()).to.eq(block.number)
        })

    });

    describe('# setMaxLayer2Count', () => {

        it('setMaxLayer2Count can be executed by only owner ', async () => {
            const maxLayer2Count = ethers.BigNumber.from("3");
            await snapshotGasCost(deployed.layer2Manager.connect(deployer).setMaxLayer2Count(maxLayer2Count))
            expect(await deployed.layer2Manager.maxLayer2Count()).to.eq(maxLayer2Count)

        })

    });

    describe('# create OptimismSequencer', () => {

        it('Cannot be created unless the caller is the layer\'s sequencer.', async () => {
            expect(await deployed.addressManager.getAddress("OVM_Sequencer")).to.not.eq(addr1.address)
            let name = "Tokamak Optimism";

            await expect(
                deployed.layer2Manager.connect(addr1).createOptimismSequencer(
                    ethers.utils.formatBytes32String(name),
                    deployed.addressManager.address,
                    deployed.l1Messenger.address,
                    deployed.l1Bridge.address,
                    deployed.l2ton.address
                )
                ).to.be.revertedWith("NOT Sequencer")
        })

        it('If the minimum security deposit is not provided, it cannot be created.', async () => {
            let name = "Tokamak Optimism";
            expect(await deployed.addressManager.getAddress("OVM_Sequencer")).to.eq(sequencer1.address)
            await expect(
                deployed.layer2Manager.connect(sequencer1).createOptimismSequencer(
                    ethers.utils.formatBytes32String(name),
                    deployed.addressManager.address,
                    deployed.l1Messenger.address,
                    deployed.l1Bridge.address,
                    deployed.l2ton.address
                )).to.be.reverted;
        })

        it('Approve the minimum security deposit and create.', async () => {
            let name = "Tokamak Optimism";
            let totalLayers = await deployed.layer2Manager.totalLayers()
            let getAllLayersBefore = await deployed.layer2Manager.getAllLayers();
            expect(await deployed.addressManager.getAddress("OVM_Sequencer")).to.eq(sequencer1.address)
            let totalSecurityDeposit = await deployed.layer2Manager.totalSecurityDeposit();
            let amount = await deployed.layer2Manager.minimumDepositForSequencer();

            if (amount.gt(await deployed.ton.balanceOf(sequencer1.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(sequencer1.address, amount)).wait();

            if (amount.gte(await deployed.ton.allowance(sequencer1.address, deployed.layer2Manager.address)))
                await (await deployed.ton.connect(sequencer1).approve(deployed.layer2Manager.address, amount)).wait();

            const topic = deployed.layer2Manager.interface.getEventTopic('CreatedOptimismSequencer');

            const receipt = await (await snapshotGasCost(deployed.layer2Manager.connect(sequencer1).createOptimismSequencer(
                    ethers.utils.formatBytes32String(name),
                    deployed.addressManager.address,
                    deployed.l1Messenger.address,
                    deployed.l1Bridge.address,
                    deployed.l2ton.address
                ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = deployed.layer2Manager.interface.parseLog(log);

            // console.log('deployedEvent.args', deployedEvent.args);
            // console.log('ethers.utils.formatBytes32String(name)', ethers.utils.formatBytes32String(name));
            // console.log('deployedEvent.args', ethers.utils.parseBytes32String(deployedEvent.args._name));

            let sequencerIndex = deployedEvent.args._index;

            expect(deployedEvent.args._sequencer).to.eq(sequencer1.address);
            expect(deployedEvent.args._name).to.eq(ethers.utils.formatBytes32String(name));
            expect(deployedEvent.args.addressManager).to.eq(deployed.addressManager.address);
            expect(deployedEvent.args.l1Messenger).to.eq(deployed.l1Messenger.address);
            expect(deployedEvent.args.l1Bridge).to.eq(deployed.l1Bridge.address);
            expect(deployedEvent.args.l2ton).to.eq(deployed.l2ton.address);

            expect(await deployed.layer2Manager.totalLayers()).to.eq(totalLayers.add(1))
            expect(await deployed.layer2Manager.totalSecurityDeposit()).to.eq(totalSecurityDeposit.add(amount))

            let layerKey = await getLayerKey({
                    addressManager: deployed.addressManager.address,
                    l1Messenger: deployed.l1Messenger.address,
                    l2Messenger: ethers.constants.AddressZero,
                    l1Bridge: deployed.l1Bridge.address,
                    l2Bridge: ethers.constants.AddressZero,
                    l2ton: deployed.l2ton.address
                }
            );
            expect(await deployed.optimismSequencer.getLayerKey(sequencerIndex)).to.eq(layerKey)

            let layer = await deployed.optimismSequencer.getLayerInfo(sequencerIndex);
            expect(layer.addressManager).to.eq(deployed.addressManager.address)
            expect(layer.l1Messenger).to.eq(deployed.l1Messenger.address)
            expect(layer.l1Bridge).to.eq(deployed.l1Bridge.address)
            expect(layer.l2ton).to.eq(deployed.l2ton.address)

            expect(await deployed.layer2Manager.layerKeys(layerKey)).to.eq(true)
            expect(await deployed.layer2Manager.indexSequencers()).to.eq(sequencerIndex)

            let getAllLayersAfter = await deployed.layer2Manager.getAllLayers();

            expect(getAllLayersBefore.optimismSequencerIndexes_.length).to.eq(
                getAllLayersAfter.optimismSequencerIndexes_.length-1
            )

        })

    });

    describe('# create Candidate', () => {

        it('Approve the minimum deposit and create.', async () => {
            let name = "Tokamak Candidate #1";
            let getAllCandidatesBefore = await deployed.layer2Manager.getAllCandidates();

            let totalLayers = await deployed.layer2Manager.totalLayers()
            let totalCandidates = await deployed.layer2Manager.totalCandidates()

            let sequenceIndex = await deployed.layer2Manager.optimismSequencerIndexes(totalLayers.sub(ethers.constants.One))

            let amount = await deployed.layer2Manager.minimumDepositForCandidate();

            if (amount.gt(await deployed.ton.balanceOf(addr1.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(addr1.address, amount)).wait();

            if (amount.gte(await deployed.ton.allowance(addr1.address, deployed.layer2Manager.address)))
                await (await deployed.ton.connect(addr1).approve(deployed.layer2Manager.address, amount)).wait();

            const topic = deployed.layer2Manager.interface.getEventTopic('CreatedCandidate');
            const commission = 500;
            const receipt = await(await snapshotGasCost(deployed.layer2Manager.connect(addr1).createCandidate(
                sequenceIndex,
                ethers.utils.formatBytes32String(name),
                commission
            ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = deployed.layer2Manager.interface.parseLog(log);

            let candidateIndex = deployedEvent.args._index;
            expect(deployedEvent.args._operator).to.eq(addr1.address);
            expect(deployedEvent.args._name).to.eq(ethers.utils.formatBytes32String(name));
            expect(deployedEvent.args._sequenceIndex).to.eq(sequenceIndex);
            expect(deployedEvent.args._commission).to.eq(commission);

            expect(await deployed.layer2Manager.totalCandidates()).to.eq(totalCandidates.add(1))
            expect(await deployed.candidate["balanceOfLton(uint32)"](candidateIndex)).to.eq(amount)
            expect(await deployed.candidate["balanceOfLton(uint32,address)"](candidateIndex, addr1.address)).to.eq(amount)
            expect(await deployed.candidate["balanceOf(uint32,address)"](candidateIndex, addr1.address)).to.eq(amount)
            expect(await deployed.candidate["commissions(uint32)"](candidateIndex)).to.eq(commission)


            let candidateKey = await getCandidateKey({
                    operator: addr1.address,
                    sequencerIndex: sequenceIndex,
                    commission: ethers.constants.Zero
                }
            );

            expect(await deployed.candidate.getCandidateKey(candidateIndex)).to.eq(candidateKey)

            let candidateInfo_ = await deployed.candidate.getCandidateInfo(candidateIndex);
            expect(candidateInfo_.operator).to.eq(addr1.address)
            expect(candidateInfo_.sequencerIndex).to.eq(sequenceIndex)
            expect(candidateInfo_.commission).to.eq(commission)


            let candidateLayerKey = await getCandidateLayerKey({
                operator: addr1.address,
                sequencerIndex: sequenceIndex,
                commission: ethers.constants.Zero
                }
            );

            expect(await deployed.layer2Manager.layerKeys(candidateLayerKey)).to.eq(true)
            expect(await deployed.layer2Manager.indexCandidates()).to.eq(candidateIndex)

            let getAllCandidatesAfter = await deployed.layer2Manager.getAllCandidates();
            expect(getAllCandidatesBefore.candidateNamesIndexes_.length).to.eq(
                getAllCandidatesAfter.candidateNamesIndexes_.length-1
            )

        })
    });


    describe('# stake at Sequencer', () => {

        it('You cannot stake on unregistered layers.', async () => {
            let amount = ethers.utils.parseEther("100");
            let layerIndex = 10;

            await expect(
                deployed.optimismSequencer.connect(addr1).stake(
                    layerIndex,
                    amount
                )
                ).to.be.revertedWith("non-registered layer")

        })

        it('If TON are not approved prior to staking, staking is not possible.', async () => {
            let amount = ethers.utils.parseEther("100");

            let layerIndex = await deployed.layer2Manager.indexSequencers();

            await expect(
                deployed.optimismSequencer.connect(addr1).stake(
                    layerIndex,
                    amount
                )).to.be.reverted;

        })

        it('If it is a registered layer, you can stake it.', async () => {
            let amount = ethers.utils.parseEther("5000");
            let layerIndex = await deployed.layer2Manager.indexSequencers();

            // let totalStakedPrincipal = await deployed.stakingLayer2.totalStakedPrincipal()
            let totalStakedLton = await deployed.optimismSequencer.totalStakedLton()
            let totalStakeAccountList = await deployed.optimismSequencer.totalStakeAccountList()

            if (amount.gt(await deployed.ton.balanceOf(addr1.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(addr1.address, amount)).wait();

            if (amount.gte(await deployed.ton.allowance(addr1.address, deployed.optimismSequencer.address)))
                await (await deployed.ton.connect(addr1).approve(deployed.optimismSequencer.address, amount)).wait();

            await snapshotGasCost(deployed.optimismSequencer.connect(addr1).stake(
                    layerIndex,
                    amount
                ));

            // expect(await deployed.stakingLayer2.totalStakedPrincipal()).to.eq(totalStakedPrincipal.add(amount))
            expect(await deployed.optimismSequencer.totalStakedLton()).to.gt(totalStakedLton)
            expect(await deployed.optimismSequencer.totalStakeAccountList()).to.eq(totalStakeAccountList.add(1))
            expect(await deployed.optimismSequencer.stakeAccountList(totalStakeAccountList)).to.eq(addr1.address)

            let lton = await deployed.seigManagerV2.getTonToLton(amount);
            expect(await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, addr1.address)).to.eq(lton)
            expect(await deployed.optimismSequencer.balanceOf(layerIndex, addr1.address)).to.eq(amount)
        })

    });

    describe('# stake at Candidate', () => {

        it('You cannot stake on unregistered layers.', async () => {
            let amount = ethers.utils.parseEther("100");
            let _index = 10;

            await expect(
                deployed.candidate.connect(addr1).stake(
                    _index,
                    amount
                )
                ).to.be.revertedWith("non-registered layer")

        })

        it('If TON are not approved prior to staking, staking is not possible.', async () => {
            let amount = ethers.utils.parseEther("100");

            let _index = 10;
            await expect(
                deployed.candidate.connect(addr1).stake(
                    _index,
                    amount
                )).to.be.reverted;

        })

        it('If it is a registered layer, you can stake it.', async () => {
            let amount = ethers.utils.parseEther("5000");

            let _index = await deployed.layer2Manager.indexCandidates();
            let balanceOf = await deployed.candidate.balanceOf(_index, addr1.address);
            let balanceOfLton = await deployed.candidate["balanceOfLton(uint32,address)"](_index, addr1.address);

            let totalStakedLton = await deployed.candidate.totalStakedLton()
            let totalStakeAccountList = await deployed.candidate.totalStakeAccountList()

            if (amount.gt(await deployed.ton.balanceOf(addr1.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(addr1.address, amount)).wait();

            if (amount.gte(await deployed.ton.allowance(addr1.address, deployed.candidate.address)))
                await (await deployed.ton.connect(addr1).approve(deployed.candidate.address, amount)).wait();

            await snapshotGasCost(deployed.candidate.connect(addr1).stake(
                    _index,
                    amount
                ));

            expect(await deployed.candidate.totalStakedLton()).to.gt(totalStakedLton)

            let getLayerStakes = await deployed.candidate.getLayerStakes(_index, addr1.address);

            if (!getLayerStakes.stake) {
                expect(await deployed.candidate.totalStakeAccountList()).to.eq(totalStakeAccountList.add(1))
                expect(await deployed.candidate.stakeAccountList(totalStakeAccountList)).to.eq(addr1.address)
            }

            let lton = await deployed.seigManagerV2.getTonToLton(amount);
            expect(await deployed.candidate["balanceOfLton(uint32,address)"](_index, addr1.address))
                .to.eq(balanceOfLton.add(lton))
            expect(await deployed.candidate.balanceOf(_index, addr1.address))
                .to.eq(balanceOf.add(amount))

        })
    });

    describe('# TON.approveAndCall -> stake at Sequencer', () => {

        it('You can stake without approval before staking.', async () => {
            let amount = ethers.utils.parseEther("5000");
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let balanceOf = await deployed.optimismSequencer.balanceOf(layerIndex, addr1.address);
            let balanceOfLton = await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, addr1.address);

            let totalStakedLton = await deployed.optimismSequencer.totalStakedLton()
            let totalStakeAccountList = await deployed.optimismSequencer.totalStakeAccountList()

            if (amount.gt(await deployed.ton.balanceOf(addr1.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(addr1.address, amount)).wait();

            const data = ethers.utils.solidityPack(
                ["uint32"],
                [layerIndex]
                );

            await snapshotGasCost(deployed.ton.connect(addr1).approveAndCall(
                deployed.optimismSequencer.address,
                amount,
                data
            ));

            expect(await deployed.optimismSequencer.totalStakedLton()).to.gt(totalStakedLton)

            let getLayerStakes = await deployed.optimismSequencer.getLayerStakes(layerIndex, addr1.address);

            if (!getLayerStakes.stake) {
                expect(await deployed.optimismSequencer.totalStakeAccountList()).to.eq(totalStakeAccountList.add(1))
                expect(await deployed.optimismSequencer.stakeAccountList(totalStakeAccountList)).to.eq(addr1.address)
            }

            let lton = await deployed.seigManagerV2.getTonToLton(amount);
            expect(await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, addr1.address))
                .to.eq(balanceOfLton.add(lton))
            expect(await deployed.optimismSequencer.balanceOf(layerIndex, addr1.address))
                .to.eq(balanceOf.add(amount))
        })

    });

    describe('# TON.approveAndCall -> stake at Candidate', () => {

        it('You can stake without approval before staking.', async () => {
            let amount = ethers.utils.parseEther("5000");
            let _index = await deployed.layer2Manager.indexCandidates();

            let balanceOf = await deployed.candidate.balanceOf(_index, addr1.address);
            let balanceOfLton = await deployed.candidate["balanceOfLton(uint32,address)"](_index, addr1.address);

            let totalStakedLton = await deployed.candidate.totalStakedLton()
            let totalStakeAccountList = await deployed.candidate.totalStakeAccountList()

            if (amount.gt(await deployed.ton.balanceOf(addr1.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(addr1.address, amount)).wait();

            const data = ethers.utils.solidityPack(
                ["uint32"],
                [_index]
                );

            await snapshotGasCost(deployed.ton.connect(addr1).approveAndCall(
                deployed.candidate.address,
                amount,
                data
            ));

            let getLayerStakes = await deployed.candidate.getLayerStakes(_index, addr1.address);

            if (!getLayerStakes.stake) {
                expect(await deployed.candidate.totalStakeAccountList()).to.eq(totalStakeAccountList.add(1))
                expect(await deployed.candidate.stakeAccountList(totalStakeAccountList)).to.eq(addr1.address)
            }

            expect(await deployed.candidate.totalStakedLton()).to.gt(totalStakedLton)

            let lton = await deployed.seigManagerV2.getTonToLton(amount);
            expect(await deployed.candidate["balanceOfLton(uint32,address)"](_index, addr1.address))
                .to.eq(balanceOfLton.add(lton))
            expect(await deployed.candidate.balanceOf(_index, addr1.address))
                .to.eq(balanceOf.add(amount))
        })

    });

    describe('# updateSeigniorage', () => {

        it('After the recent seignorage issuance, seignorage will not be issued unless the minimum block has passed.', async () => {
            const lastSeigBlock = await deployed.seigManagerV2.lastSeigBlock()
            const minimumBlocksForUpdateSeig = await deployed.seigManagerV2.minimumBlocksForUpdateSeig()
            const block = await ethers.provider.getBlock('latest')

            await snapshotGasCost(deployed.seigManagerV2.connect(addr1).updateSeigniorage())

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

        it('If the staked amount is greater than 0, indexLton increase.', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let candidateIndex = await deployed.layer2Manager.indexCandidates();

            let prevBalanceOfSequencer = await deployed.optimismSequencer.balanceOf(layerIndex, addr1.address);
            let prevBalanceLtonOfSequencer =await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, addr1.address)

            let prevBalanceOfCandidate = await deployed.candidate.balanceOf(candidateIndex, addr1.address);
            let prevBalanceLtonOfCandidate =await deployed.candidate["balanceOfLton(uint32,address)"](candidateIndex, addr1.address)

            expect(await deployed.seigManagerV2.ratesDao()).to.eq(0)
            expect(await deployed.seigManagerV2.ratesStosHolders()).to.eq(0)

            expect(await deployed.seigManagerV2.getTotalLton()).to.gt(ethers.constants.Zero)
            const indexLton = await deployed.seigManagerV2.indexLton();
            await snapshotGasCost(deployed.seigManagerV2.connect(addr1).updateSeigniorage())
            expect(await deployed.seigManagerV2.indexLton()).to.gt(indexLton)

            expect(await deployed.ton.balanceOf(deployed.dao.address)).to.eq(0)
            expect(await deployed.ton.balanceOf(deployed.stosDistribute.address)).to.eq(0)

            expect(await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, addr1.address)).to.eq(prevBalanceLtonOfSequencer)
            expect(await deployed.optimismSequencer.balanceOf(layerIndex, addr1.address)).to.gt(prevBalanceOfSequencer)

            expect(await deployed.candidate["balanceOfLton(uint32,address)"](candidateIndex, addr1.address)).to.eq(prevBalanceLtonOfCandidate)
            expect(await deployed.candidate.balanceOf(candidateIndex, addr1.address)).to.gt(prevBalanceOfCandidate)

        });

        it("      pass blocks", async function () {
            const minimumBlocksForUpdateSeig = await deployed.seigManagerV2.minimumBlocksForUpdateSeig()
            let i
            for (i = 0; i < minimumBlocksForUpdateSeig; i++){
                await ethers.provider.send('evm_mine');
            }
        });

        it('runUpdateSeigniorage : If the sum of the staking amount and the bonding liquidity amount is greater than 0, indexLton increase.', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let candidateIndex = await deployed.layer2Manager.indexCandidates();


            let prevBalanceOfSequencer = await deployed.optimismSequencer.balanceOf(layerIndex, addr1.address);
            let prevBalanceLtonOfSequencer =await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, addr1.address)

            let prevBalanceOfCandidate = await deployed.candidate.balanceOf(candidateIndex, addr1.address);
            let prevBalanceLtonOfCandidate =await deployed.candidate["balanceOfLton(uint32,address)"](candidateIndex, addr1.address)


            expect(await deployed.seigManagerV2.ratesDao()).to.eq(0)
            expect(await deployed.seigManagerV2.ratesStosHolders()).to.eq(0)

            expect(await deployed.seigManagerV2.getTotalLton()).to.gt(ethers.constants.Zero)
            const indexLton = await deployed.seigManagerV2.indexLton();
            await snapshotGasCost(deployed.seigManagerV2.connect(addr1).runUpdateSeigniorage())
            expect(await deployed.seigManagerV2.indexLton()).to.gt(indexLton)

            expect(await deployed.ton.balanceOf(deployed.dao.address)).to.eq(0)
            expect(await deployed.ton.balanceOf(deployed.stosDistribute.address)).to.eq(0)


            expect(await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, addr1.address)).to.eq(prevBalanceLtonOfSequencer)
            expect(await deployed.optimismSequencer.balanceOf(layerIndex, addr1.address)).to.gt(prevBalanceOfSequencer)

            expect(await deployed.candidate["balanceOfLton(uint32,address)"](candidateIndex, addr1.address)).to.eq(prevBalanceLtonOfCandidate)
            expect(await deployed.candidate.balanceOf(candidateIndex, addr1.address)).to.gt(prevBalanceOfCandidate)

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

            await snapshotGasCost(deployed.seigManagerV2.connect(deployer).setDividendRates(
                    rates.ratesDao,
                    rates.ratesStosHolders,
                    rates.ratesTonStakers,
                    rates.ratesUnits
                ))
            expect(await deployed.seigManagerV2.ratesDao()).to.eq(rates.ratesDao)
            expect(await deployed.seigManagerV2.ratesStosHolders()).to.eq(rates.ratesStosHolders)
            expect(await deployed.seigManagerV2.ratesTonStakers()).to.eq(rates.ratesTonStakers)
            expect(await deployed.seigManagerV2.ratesUnits()).to.eq(rates.ratesUnits)
        })

        it('setAddress can be executed by only owner ', async () => {
            await snapshotGasCost(deployed.seigManagerV2.connect(deployer).setAddress(
                    deployed.dao.address,
                    deployed.stosDistribute.address
                ))
            expect(await deployed.seigManagerV2.dao()).to.eq(deployed.dao.address)
            expect(await deployed.seigManagerV2.stosDistribute()).to.eq(deployed.stosDistribute.address)

        })

        it('If you set the DAO and dividend rate for seig, seig is granted to the DAO.', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let candidateIndex = await deployed.layer2Manager.indexCandidates();


            let prevBalanceOfSequencer = await deployed.optimismSequencer.balanceOf(layerIndex, addr1.address);
            let prevBalanceLtonOfSequencer =await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, addr1.address)

            let prevBalanceOfCandidate = await deployed.candidate.balanceOf(candidateIndex, addr1.address);
            let prevBalanceLtonOfCandidate =await deployed.candidate["balanceOfLton(uint32,address)"](candidateIndex, addr1.address)

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
            expect(await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, addr1.address)).to.eq(prevBalanceLtonOfSequencer)
            expect(await deployed.optimismSequencer.balanceOf(layerIndex, addr1.address)).to.gt(prevBalanceOfSequencer)

            expect(await deployed.candidate["balanceOfLton(uint32,address)"](candidateIndex, addr1.address)).to.eq(prevBalanceLtonOfCandidate)
            expect(await deployed.candidate.balanceOf(candidateIndex, addr1.address)).to.gt(prevBalanceOfCandidate)

        });
    });

    describe('# unstake at Sequencer', () => {
        let pendings ;
        let availableWithdraw;

        it('You can unstake when you have the staked amount.', async () => {

            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let candidateIndex = await deployed.layer2Manager.indexCandidates();

            const balanceOfStaker = await deployed.ton.balanceOf(addr1.address)
            const availableWithdrawOfStaker = await deployed.optimismSequencer.availableWithdraw(layerIndex, addr1.address)
            const amountOfPendings = await deployed.optimismSequencer.amountOfPendings(layerIndex, addr1.address)

            let amountLton = await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, addr1.address)
            let amount = await deployed.seigManagerV2.getLtonToTon(amountLton)

            let totalStakedLton = await deployed.optimismSequencer.totalStakedLton()

            const block = await ethers.provider.getBlock('latest')
            const delay = await deployed.layer2Manager.delayBlocksForWithdraw();

            const topic = deployed.optimismSequencer.interface.getEventTopic('Unstaked');

            const receipt = await (await snapshotGasCost(deployed.optimismSequencer.connect(addr1).unstake(
                    layerIndex,
                    amountLton
                ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = deployed.optimismSequencer.interface.parseLog(log);
            expect(deployedEvent.args.lton).to.eq(amountLton)
            expect(deployedEvent.args.amount).to.gte(amount)

            expect(await deployed.optimismSequencer.totalStakedLton()).to.eq(totalStakedLton.sub(amountLton))

            expect(await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, addr1.address)).to.eq(0)
            expect(await deployed.optimismSequencer.balanceOf(layerIndex, addr1.address)).to.eq(0)

            expect(await deployed.ton.balanceOf(addr1.address)).to.eq(balanceOfStaker)

            pendings = await deployed.optimismSequencer.amountOfPendings(layerIndex, addr1.address)
            availableWithdraw = await deployed.optimismSequencer.availableWithdraw(layerIndex, addr1.address)

            expect(availableWithdraw.amount).to.eq(availableWithdrawOfStaker.amount)
            expect(pendings.amount).to.eq(amountOfPendings.amount.add(deployedEvent.args.amount))
            expect(pendings.len).to.eq(amountOfPendings.len + 1)
            expect(pendings.nextWithdrawableBlockNumber).to.gte(block.number + delay.toNumber())
        })
    });

    describe('# unstake at Candidate', () => {
        let pendings ;
        let availableWithdraw;

        it('Operators must always staked amount greater than or equal to minimumDepositForCandidate.', async () => {

            let candidateIndex = await deployed.layer2Manager.indexCandidates();
            let amountLton = await deployed.candidate["balanceOfLton(uint32,address)"](candidateIndex, addr1.address)

            await expect(
                deployed.candidate.connect(addr1).unstake(
                    candidateIndex,
                    amountLton
                )).to.be.revertedWith("minimumDepositForCandidate E1");
        })

        it('You can unstake when you have the staked amount.', async () => {

            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let candidateIndex = await deployed.layer2Manager.indexCandidates();

            const balanceOfStaker = await deployed.ton.balanceOf(addr1.address)
            const availableWithdrawOfStaker = await deployed.candidate.availableWithdraw(candidateIndex, addr1.address)
            const amountOfPendings = await deployed.candidate.amountOfPendings(candidateIndex, addr1.address)

            let amountLton = await deployed.candidate["balanceOfLton(uint32,address)"](candidateIndex, addr1.address)

            let minimumDepositForCandidate = await deployed.layer2Manager.minimumDepositForCandidate();
            let minimumDepositForCandidateLton = await deployed.seigManagerV2.getTonToLton(minimumDepositForCandidate)

            let unstakeAmountLton = amountLton.sub(minimumDepositForCandidateLton).sub(ethers.constants.One);
            let remainedAmountLton = amountLton.sub(unstakeAmountLton);

            let amount = await deployed.seigManagerV2.getLtonToTon(unstakeAmountLton);

            let totalStakedLton = await deployed.candidate.totalStakedLton()

            const block = await ethers.provider.getBlock('latest')
            const delay = await deployed.layer2Manager.delayBlocksForWithdraw();

            const topic = deployed.candidate.interface.getEventTopic('Unstaked');

            const receipt = await (await snapshotGasCost(deployed.candidate.connect(addr1).unstake(
                    candidateIndex,
                    unstakeAmountLton
                ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = deployed.candidate.interface.parseLog(log);
            expect(deployedEvent.args.lton).to.eq(unstakeAmountLton)
            expect(deployedEvent.args.amount).to.gte(amount)

            expect(await deployed.candidate.totalStakedLton()).to.eq(totalStakedLton.sub(unstakeAmountLton))

            expect(await deployed.candidate["balanceOfLton(uint32,address)"](candidateIndex, addr1.address)).to.eq(remainedAmountLton)
            // expect(await deployed.candidate.balanceOf(candidateIndex, addr1.address)).to.eq(0)

            expect(await deployed.ton.balanceOf(addr1.address)).to.eq(balanceOfStaker)

            pendings = await deployed.candidate.amountOfPendings(candidateIndex, addr1.address)
            availableWithdraw = await deployed.candidate.availableWithdraw(candidateIndex, addr1.address)

            expect(availableWithdraw.amount).to.eq(availableWithdrawOfStaker.amount)
            expect(pendings.amount).to.eq(amountOfPendings.amount.add(deployedEvent.args.amount))
            expect(pendings.len).to.eq(amountOfPendings.len + 1)
            expect(pendings.nextWithdrawableBlockNumber).to.gte(block.number + delay.toNumber())
        })
    });

    describe('# withdraw ', () => {

        it('[at Sequencer] You cannot withdraw if there is no amount available for withdrawal.', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();

            const availableWithdrawOfStaker = await deployed.optimismSequencer.availableWithdraw(layerIndex, addr1.address)

            expect(availableWithdrawOfStaker.amount).to.eq(ethers.constants.Zero)

            await expect(deployed.optimismSequencer.connect(addr1).withdraw(layerIndex)).to.be.revertedWith("zero available withdrawal amount")

        })

        it('[at Candidate] You cannot withdraw if there is no amount available for withdrawal.', async () => {

            let _index = await deployed.layer2Manager.indexCandidates();

            const availableWithdrawOfStaker = await deployed.candidate.availableWithdraw(_index, addr1.address)

            expect(availableWithdrawOfStaker.amount).to.eq(ethers.constants.Zero)

            await expect(deployed.candidate.connect(addr1).withdraw(_index)).to.be.revertedWith("zero available withdrawal amount")

        })
        it("      pass blocks", async function () {
            const delay = await deployed.layer2Manager.delayBlocksForWithdraw();
            let i
            for (i = 0; i < delay.toNumber(); i++){
                await ethers.provider.send('evm_mine');
            }
        });

        it('[at Sequencer] You can withdraw if there is amount available for withdrawal.', async () => {

            let layerIndex = await deployed.layer2Manager.indexSequencers();

            const balanceOfStaker = await deployed.ton.balanceOf(addr1.address)
            const availableWithdrawOfStaker = await deployed.optimismSequencer.availableWithdraw(layerIndex, addr1.address)

            expect(availableWithdrawOfStaker.amount).to.gt(ethers.constants.Zero)

            const topic = deployed.optimismSequencer.interface.getEventTopic('Withdrawal');

            const receipt = await (await snapshotGasCost(deployed.optimismSequencer.connect(addr1).withdraw(layerIndex))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = deployed.optimismSequencer.interface.parseLog(log);
            expect(deployedEvent.args.amount).to.gte(availableWithdrawOfStaker.amount)

            const availableWithdraw = await deployed.optimismSequencer.availableWithdraw(layerIndex, addr1.address)
            expect(availableWithdraw.amount).to.eq(ethers.constants.Zero)
            expect(await deployed.ton.balanceOf(addr1.address)).to.eq(balanceOfStaker.add(availableWithdrawOfStaker.amount))
        })

        it('[at Candidate] You can withdraw if there is amount available for withdrawal.', async () => {

            let _index = await deployed.layer2Manager.indexCandidates();

            const balanceOfStaker = await deployed.ton.balanceOf(addr1.address)
            const availableWithdrawOfStaker = await deployed.candidate.availableWithdraw(_index, addr1.address)

            expect(availableWithdrawOfStaker.amount).to.gt(ethers.constants.Zero)

            const topic = deployed.candidate.interface.getEventTopic('Withdrawal');

            const receipt = await (await snapshotGasCost(deployed.candidate.connect(addr1).withdraw(_index))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = deployed.candidate.interface.parseLog(log);
            expect(deployedEvent.args.amount).to.gte(availableWithdrawOfStaker.amount)

            const availableWithdraw = await deployed.candidate.availableWithdraw(_index, addr1.address)
            expect(availableWithdraw.amount).to.eq(ethers.constants.Zero)
            expect(await deployed.ton.balanceOf(addr1.address)).to.eq(balanceOfStaker.add(availableWithdrawOfStaker.amount))
        })
    });


    describe('# curTotalLayer2Deposits', () => {

        it('Depositing in layer2 increases the total amount of deposit in the layer.', async () => {

            let amount = ethers.utils.parseEther("300");
            let curTotalLayer2Deposits = await deployed.layer2Manager.curTotalLayer2Deposits()

            if (amount.gt(await deployed.ton.balanceOf(addr1.address)))
            await (await deployed.ton.connect(deployed.tonAdmin).mint(addr1.address, amount)).wait();

            if (amount.gte(await deployed.ton.allowance(addr1.address, deployed.l1Bridge.address)))
                await (await deployed.ton.connect(addr1).approve(deployed.l1Bridge.address, amount)).wait();

            await (await deployed.l1Bridge.connect(addr1).depositERC20To(
                    deployed.ton.address,
                    deployed.l2ton.address,
                    addr1.address,
                    amount,
                    20000,
                    '0x'
                )).wait();

            expect(await deployed.layer2Manager.curTotalLayer2Deposits()).to.eq(curTotalLayer2Deposits.add(amount))

        })

        it('If you withdraw from layer 2, the deposit amount of the total layer will be reduced.', async () => {

            let amount = ethers.utils.parseEther("100");
            let curTotalLayer2Deposits = await deployed.layer2Manager.curTotalLayer2Deposits()
            let balanceOfUser = await deployed.ton.balanceOf(addr1.address)

            await (await snapshotGasCost(deployed.l1Bridge.connect(addr1).finalizeERC20Withdrawal(
                    deployed.ton.address,
                    deployed.l2ton.address,
                    addr1.address,
                    addr1.address,
                    amount,
                    '0x'
                ))).wait();

            expect(await deployed.layer2Manager.curTotalLayer2Deposits()).to.eq(curTotalLayer2Deposits.sub(amount))
            expect(await deployed.ton.balanceOf(addr1.address)).to.eq(balanceOfUser.add(amount))

        })

    });

    describe('# claim of sequencer', () => {

        it('Depositing in L2 will increase L2 holdings.', async () => {

            let amount = ethers.utils.parseEther("300");
            let curTotalLayer2Deposits = await deployed.layer2Manager.curTotalLayer2Deposits()

            if (amount.gt(await deployed.ton.balanceOf(addr1.address)))
            await (await deployed.ton.connect(deployed.tonAdmin).mint(addr1.address, amount)).wait();

            if (amount.gte(await deployed.ton.allowance(addr1.address, deployed.l1Bridge.address)))
                await (await deployed.ton.connect(addr1).approve(deployed.l1Bridge.address, amount)).wait();

            await (await snapshotGasCost(deployed.l1Bridge.connect(addr1).depositERC20To(
                    deployed.ton.address,
                    deployed.l2ton.address,
                    addr1.address,
                    amount,
                    20000,
                    '0x'
                ))).wait();

            expect(await deployed.layer2Manager.curTotalLayer2Deposits()).to.eq(curTotalLayer2Deposits.add(amount))
        })

        it("      pass blocks", async function () {
            const minimumBlocksForUpdateSeig = await deployed.seigManagerV2.minimumBlocksForUpdateSeig()
            let i
            for (i = 0; i < minimumBlocksForUpdateSeig; i++){
                await ethers.provider.send('evm_mine');
            }
        });

        it('When seignorage is updated, totalSeigs(the seignorage distributed to the sequencers) is increases.', async () => {

            let totalSeigs = await deployed.layer2Manager.totalSeigs()
            await snapshotGasCost(deployed.seigManagerV2.connect(addr1).updateSeigniorage())
            expect(await deployed.layer2Manager.totalSeigs()).to.gt(totalSeigs)

        })

        it('The sequencer cannot claim when there is no claimable amount.', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();

            let holdings = await deployed.layer2Manager.holdings(layerIndex)
            expect(holdings.seigs).to.eq(ethers.constants.Zero)

            await expect(
                deployed.layer2Manager.connect(addr1).claim(layerIndex)
                ).to.be.revertedWith("no amount to claim")
        });

        it('When totalSeigs is not 0, seigniorage can be distributed to the sequencer.', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();

            expect((await deployed.layer2Manager.holdings(layerIndex)).seigs).to.eq(ethers.constants.Zero)
            expect(await deployed.layer2Manager.totalSeigs()).to.gt(ethers.constants.Zero)

            await snapshotGasCost(deployed.layer2Manager.connect(addr1).distribute())
            let holdings = (await deployed.layer2Manager.holdings(layerIndex)) ;

            expect(await deployed.layer2Manager.totalSeigs()).to.lte(ethers.constants.One)
            expect((await deployed.layer2Manager.holdings(layerIndex)).seigs).to.gt(ethers.constants.Zero)
        });

        it('the sequencers can claim ', async () => {

            let layerIndex = await deployed.layer2Manager.indexSequencers();

            expect(await deployed.layer2Manager.sequencer(layerIndex)).to.eq(sequencer1.address);
            let balanceOfTon = await deployed.ton.balanceOf(sequencer1.address);
            let holdings = (await deployed.layer2Manager.holdings(layerIndex)) ;

            expect(holdings.seigs).to.gt(ethers.constants.Zero)

            await snapshotGasCost(deployed.layer2Manager.connect(addr1).claim(layerIndex))
            expect((await deployed.layer2Manager.holdings(layerIndex)).seigs).to.eq(ethers.constants.Zero)
            expect(await deployed.ton.balanceOf(sequencer1.address)).to.eq(balanceOfTon.add(holdings.seigs))
        })
    });

});
