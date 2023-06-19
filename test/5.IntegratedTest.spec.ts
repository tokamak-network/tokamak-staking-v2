import { expect } from './shared/expect'
import { ethers, network } from 'hardhat'
import { Signer, BigNumber } from 'ethers'
import {
    FW_STATUS,
    stakingV2Fixtures, getLayerKey, getCandidateKey,
    getCandidateLayerKey,
    bytesFastWithdrawMessage1
    } from './shared/fixtures'
import {
    StakeSnapshotFixture,
    Layer2Fixture, ParseMessageFixture,
    TonStakingV2Fixture, FastWithdrawMessageFixture, DomainMessageFixture} from './shared/fixtureInterfaces'
import snapshotGasCost from './shared/snapshotGasCost'

import Web3EthAbi from 'web3-eth-abi';

describe('Integrated Test', () => {
    let deployer: Signer, addr1: Signer, addr2: Signer, sequencer1:Signer

    let deployed: TonStakingV2Fixture
    let messageNonce: BigNumber

    let xDomainCalldataList:Array<DomainMessageFixture>   // calldata bytes, calldata bytes

    // mainnet
    let seigManagerInfo = {
        ton: "0x2be5e8c109e2197D077D13A82dAead6a9b3433C5",
        wton: "0xc4A11aaf6ea915Ed7Ac194161d2fC9384F15bff2",
        tot: "0x6FC20Ca22E67aAb397Adb977F092245525f7AeEf",
        seigManagerV1: "0x710936500aC59e8551331871Cbad3D33d5e0D909",
        layer2Manager: "",
        seigPerBlock: ethers.BigNumber.from("3920000000000000000"),
        minimumBlocksForUpdateSeig: 300,
        ratesTonStakers: 10000,
        ratesDao: 0,
        ratesStosHolders: 0,
        ratesUnits: 10000
    }

    let layer2ManagerInfo = {
        minimumDepositForSequencer: ethers.utils.parseEther("100"),
        minimumDepositForCandidate: ethers.utils.parseEther("200"),
        delayBlocksForWithdraw: 300,
    }

    let messageInfo: FastWithdrawMessageFixture =  {
        version:0,
        requestor: "",
        amount: ethers.utils.parseEther("1"),
        feeRates: 1000,
        deadline: 0,
        layerIndex: 0,
        messageNonce: ethers.BigNumber.from("1000")
    }

    let layerInfo: Layer2Fixture = {
        addressManager: "",
        l1Messenger: "",
        l2Messenger: "",
        l1Bridge: "",
        l2Bridge: "",
        l2ton: ""
    }

    let snapshotListSequencer: Array<StakeSnapshotFixture> = [];
    let snapshotListCandidate: Array<StakeSnapshotFixture> = [];

    before('create fixture loader', async () => {
        // deployed = await loadFixture(stakingV2Fixtures)

        deployed = await stakingV2Fixtures()
        deployer = deployed.deployer;
        addr1 = deployed.addr1;
        addr2 = deployed.addr2;
        sequencer1 = deployed.sequencer1;
        layerInfo.addressManager = deployed.addressManager.address;
        layerInfo.l1Messenger = deployed.l1Messenger.address
        layerInfo.l2Messenger = deployed.l2Messenger.address
        layerInfo.l1Bridge= deployed.l1Bridge.address
        layerInfo.l2Bridge= deployed.l2Bridge.address
        layerInfo.l2ton= deployed.l2ton.address
        messageNonce = ethers.BigNumber.from("1000");
    })

    describe('# initialize', () => {

        it('SeigManagerV2 : initialize can be executed by only owner', async () => {
            await snapshotGasCost(
                deployed.seigManagerV2Proxy.connect(deployer).initialize(
                    seigManagerInfo.ton,
                    seigManagerInfo.wton,
                    seigManagerInfo.tot,
                    [
                        seigManagerInfo.seigManagerV1,
                        deployed.layer2ManagerProxy.address,
                        deployed.optimismSequencerProxy.address,
                        deployed.candidateProxy.address
                    ],
                    seigManagerInfo.seigPerBlock,
                    seigManagerInfo.minimumBlocksForUpdateSeig,
                    [
                        seigManagerInfo.ratesTonStakers,
                        seigManagerInfo.ratesDao,
                        seigManagerInfo.ratesStosHolders,
                        seigManagerInfo.ratesUnits,
                    ]
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
                deployed.layer2ManagerProxy.address,
                deployed.fwReceiptProxy.address
                ))

            expect(await deployed.optimismSequencerProxy.ton()).to.eq(seigManagerInfo.ton)
            expect(await deployed.optimismSequencerProxy.seigManagerV2()).to.eq(deployed.seigManagerV2Proxy.address)
            expect(await deployed.optimismSequencerProxy.layer2Manager()).to.eq(deployed.layer2ManagerProxy.address)
            expect(await deployed.optimismSequencerProxy.fwReceipt()).to.eq(deployed.fwReceiptProxy.address)

        })

        it('Candidate : initialize can be executed by only owner', async () => {
            await snapshotGasCost(deployed.candidateProxy.connect(deployer).initialize(
                seigManagerInfo.ton,
                deployed.seigManagerV2Proxy.address,
                deployed.layer2ManagerProxy.address,
                deployed.fwReceiptProxy.address
                ))

            expect(await deployed.candidateProxy.ton()).to.eq(seigManagerInfo.ton)
            expect(await deployed.candidateProxy.seigManagerV2()).to.eq(deployed.seigManagerV2Proxy.address)
            expect(await deployed.candidateProxy.layer2Manager()).to.eq(deployed.layer2ManagerProxy.address)
            expect(await deployed.candidateProxy.fwReceipt()).to.eq(deployed.fwReceiptProxy.address)
        })

        it('FwReceipt : initialize can be executed by only owner', async () => {
            await snapshotGasCost(deployed.fwReceiptProxy.connect(deployer).initialize(
                seigManagerInfo.ton,
                deployed.seigManagerV2.address,
                deployed.optimismSequencerProxy.address,
                deployed.candidateProxy.address
                ))

            expect(await deployed.fwReceiptProxy.ton()).to.eq(seigManagerInfo.ton)
            expect(await deployed.fwReceiptProxy.optimismSequencer()).to.eq(deployed.optimismSequencerProxy.address)
            expect(await deployed.fwReceiptProxy.candidate()).to.eq(deployed.candidateProxy.address)

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
        /*
        it('Cannot be created unless the caller is the layer\'s sequencer.', async () => {
            expect(await deployed.addressManager.getAddress("OVM_Sequencer")).to.not.eq(addr1.address)
            let name = "Tokamak Optimism";
            let amount = ethers.utils.parseEther("100");

            await expect(
                deployed.layer2Manager.connect(addr1).createOptimismSequencer(
                    ethers.utils.formatBytes32String(name),
                    deployed.addressManager.address,
                    deployed.l1Bridge.address,
                    deployed.l2Bridge.address,
                    deployed.l2ton.address,
                    amount
                )
                ).to.be.revertedWith("NOT Sequencer")
        })
        */
        it('If the minimum security deposit is not provided, it cannot be created.', async () => {
            let name = "Tokamak Optimism";
            let amount = ethers.utils.parseEther("100");

            expect(await deployed.addressManager.getAddress("OVM_Sequencer")).to.eq(sequencer1.address)
            await expect(
                deployed.layer2Manager.connect(sequencer1).createOptimismSequencer(
                    ethers.utils.formatBytes32String(name),
                    deployed.addressManager.address,
                    deployed.l1Bridge.address,
                    deployed.l2Bridge.address,
                    deployed.l2ton.address,
                    amount
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
                    deployed.l1Bridge.address,
                    deployed.l2Bridge.address,
                    deployed.l2ton.address,
                    amount
                ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = deployed.layer2Manager.interface.parseLog(log);

            let sequencerIndex = deployedEvent.args._index;

            expect(deployedEvent.args._sequencer).to.eq(sequencer1.address);
            expect(deployedEvent.args._name).to.eq(ethers.utils.formatBytes32String(name));
            expect(deployedEvent.args.addressManager).to.eq(deployed.addressManager.address);
            expect(deployedEvent.args.l1Bridge).to.eq(deployed.l1Bridge.address);
            expect(deployedEvent.args.l2Bridge).to.eq(deployed.l2Bridge.address);

            expect(deployedEvent.args.l2ton).to.eq(deployed.l2ton.address);

            expect(await deployed.layer2Manager.totalLayers()).to.eq(totalLayers.add(1))
            expect(await deployed.layer2Manager.totalSecurityDeposit()).to.eq(totalSecurityDeposit.add(amount))

            let layerKey = await getLayerKey({
                    addressManager: deployed.addressManager.address,
                    l1Messenger: ethers.constants.AddressZero,
                    l2Messenger: ethers.constants.AddressZero,
                    l1Bridge: deployed.l1Bridge.address,
                    l2Bridge: deployed.l2Bridge.address,
                    l2ton: deployed.l2ton.address
                }
            );

            expect(await deployed.optimismSequencer.getLayerKey(sequencerIndex)).to.eq(layerKey)

            let layer = await deployed.optimismSequencer.getLayerInfo(sequencerIndex);

            expect(layer.addressManager).to.eq(deployed.addressManager.address)
            expect(layer.l1Bridge).to.eq(deployed.l1Bridge.address)
            expect(layer.l2Bridge).to.eq(deployed.l2Bridge.address)
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

            let sequencerIndex = await deployed.layer2Manager.optimismSequencerIndexes(totalLayers.sub(ethers.constants.One))

            let amount = await deployed.layer2Manager.minimumDepositForCandidate();

            if (amount.gt(await deployed.ton.balanceOf(addr1.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(addr1.address, amount)).wait();

            if (amount.gte(await deployed.ton.allowance(addr1.address, deployed.layer2Manager.address)))
                await (await deployed.ton.connect(addr1).approve(deployed.layer2Manager.address, amount)).wait();

            const topic = deployed.layer2Manager.interface.getEventTopic('CreatedCandidate');
            const commission = 500;
            const receipt = await(await snapshotGasCost(deployed.layer2Manager.connect(addr1).createCandidate(
                sequencerIndex,
                ethers.utils.formatBytes32String(name),
                commission,
                amount
            ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = deployed.layer2Manager.interface.parseLog(log);

            let candidateIndex = deployedEvent.args._index;
            expect(deployedEvent.args._operator).to.eq(addr1.address);
            expect(deployedEvent.args._name).to.eq(ethers.utils.formatBytes32String(name));
            expect(deployedEvent.args._sequencerIndex).to.eq(sequencerIndex);
            expect(deployedEvent.args._commission).to.eq(commission);

            expect(await deployed.layer2Manager.totalCandidates()).to.eq(totalCandidates.add(1))
            expect(await deployed.candidate["balanceOfLton(uint32)"](candidateIndex)).to.eq(amount)
            expect(await deployed.candidate["balanceOfLton(uint32,address)"](candidateIndex, addr1.address)).to.eq(amount)
            expect(await deployed.candidate["balanceOf(uint32,address)"](candidateIndex, addr1.address)).to.eq(amount)

            let candidateKey = await getCandidateKey({
                    operator: addr1.address,
                    sequencerIndex: sequencerIndex,
                    commission: ethers.constants.Zero
                }
            );

            expect(await deployed.candidate.getCandidateKey(candidateIndex)).to.eq(candidateKey)

            let candidateInfo_ = await deployed.candidate.getCandidateInfo(candidateIndex);
            expect(candidateInfo_.operator).to.eq(addr1.address)
            expect(candidateInfo_.sequencerIndex).to.eq(sequencerIndex)
            expect(candidateInfo_.commission).to.eq(commission)

            let candidateLayerKey = await getCandidateLayerKey({
                operator: addr1.address,
                sequencerIndex: sequencerIndex,
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

    describe('# increase Security Deposit ', () => {
        it('After approval of the use of TON in advance, the deposit can be increased.', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let amount = ethers.utils.parseEther("100");
            await expect(
                deployed.layer2Manager.connect(addr1).increaseSecurityDeposit(
                    layerIndex, amount
                )).to.be.reverted;
        })

        it('Approve the deposit and increase the security deposit.', async () => {
            let amount = ethers.utils.parseEther("100");
            let layerIndex = await deployed.layer2Manager.indexSequencers();

            if (amount.gt(await deployed.ton.balanceOf(addr1.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(addr1.address, amount)).wait();

            if (amount.gte(await deployed.ton.allowance(addr1.address, deployed.layer2Manager.address)))
                await (await deployed.ton.connect(addr1).approve(deployed.layer2Manager.address, amount)).wait();

            let balanceOfAccountBefore = await deployed.ton.balanceOf(addr1.address)
            let balanceOfLayer2ManagerBefore = await deployed.ton.balanceOf(deployed.layer2Manager.address)
            let totalSecurityDepositBefore = await deployed.layer2Manager.totalSecurityDeposit()
            let depositBefore = await deployed.layer2Manager.layerHoldings(layerIndex)
            await snapshotGasCost(deployed.layer2Manager.connect(addr1).increaseSecurityDeposit(
                    layerIndex,
                    amount
                ));

            let depositAfter = await deployed.layer2Manager.layerHoldings(layerIndex)

            expect(await deployed.ton.balanceOf(addr1.address)).to.eq(balanceOfAccountBefore.sub(amount))
            expect(await deployed.ton.balanceOf(deployed.layer2Manager.address)).to.eq(balanceOfLayer2ManagerBefore.add(amount))
            expect(depositAfter.securityDeposit).to.eq(depositBefore.securityDeposit.add(amount))
            expect(await  deployed.layer2Manager.totalSecurityDeposit()).to.eq(totalSecurityDepositBefore.add(amount))

        })
    });

    describe('# decrease Security Deposit ', () => {

        it('function can not be executed by not sequencer', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let amount = ethers.utils.parseEther("100");
            await expect(
                deployed.layer2Manager.connect(addr1).decreaseSecurityDeposit(
                    layerIndex, amount
                )
                ).to.be.revertedWith("sequencer is zero or not caller.")
        })


        it('Remained security deposit must is greater than more than the minimum security deposit.', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            // let minimumDepositForSequencer = await deployed.layer2Manager.minimumDepositForSequencer();
            let depositBefore = await deployed.layer2Manager.layerHoldings(layerIndex)
            let amount = depositBefore.securityDeposit;
            await expect(
                deployed.layer2Manager.connect(sequencer1).decreaseSecurityDeposit(
                    layerIndex, amount
                )).to.be.revertedWith("insufficient deposit");
        })

        it('Sequencer can decrease the security deposit.', async () => {

            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let minimumDepositForSequencer = await deployed.layer2Manager.minimumDepositForSequencer();
            let depositBefore = await deployed.layer2Manager.layerHoldings(layerIndex)
            let amount = depositBefore.securityDeposit.sub(minimumDepositForSequencer);

            let balanceOfAccountBefore = await deployed.ton.balanceOf(sequencer1.address)
            let balanceOfLayer2ManagerBefore = await deployed.ton.balanceOf(deployed.layer2Manager.address)
            let totalSecurityDepositBefore = await deployed.layer2Manager.totalSecurityDeposit()

            await snapshotGasCost(deployed.layer2Manager.connect(sequencer1).decreaseSecurityDeposit(
                    layerIndex,
                    amount
                ));

            let depositAfter = await deployed.layer2Manager.layerHoldings(layerIndex)

            expect(await deployed.ton.balanceOf(sequencer1.address)).to.eq(balanceOfAccountBefore.add(amount))
            expect(await deployed.ton.balanceOf(deployed.layer2Manager.address)).to.eq(balanceOfLayer2ManagerBefore.sub(amount))
            expect(depositAfter.securityDeposit).to.eq(depositBefore.securityDeposit.sub(amount))

            expect(await  deployed.layer2Manager.totalSecurityDeposit()).to.eq(totalSecurityDepositBefore.sub(amount))

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

        it('Anyone can take a snapshot.', async () => {

            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let account = addr1
            let block = await ethers.provider.getBlock('latest');
            const snapshotIdBefore = await deployed.seigManagerV2.getCurrentSnapshotId()

            const indexLton0 = await deployed.seigManagerV2.indexLton();
            const totalStakedLton0 = await deployed.optimismSequencer.totalStakedLton();
            const balanceOfLayer0 = await deployed.optimismSequencer["balanceOfLton(uint32)"](layerIndex);
            const balanceOfAccount0 = await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, account.address);

            const interface1 = deployed.seigManagerV2.interface ;
            const topic = interface1.getEventTopic('Snapshot');
            const receipt = await(await snapshotGasCost(deployed.seigManagerV2.connect(addr1).snapshot())).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = interface1.parseLog(log);
            let snapshotId  = deployedEvent.args.id;
            expect(snapshotId).to.be.eq(snapshotIdBefore.add(ethers.constants.One));
            // console.log('snapshotId',snapshotId)

            let snapshot:StakeSnapshotFixture = {
                id: snapshotId,
                layerIndex: layerIndex,
                account: account.address,
                totalStakedLton: totalStakedLton0,
                indexLton: indexLton0,
                balanceOfLayer: balanceOfLayer0,
                balanceOfAccount: balanceOfAccount0
            }
            snapshotListSequencer.push(snapshot)
            // console.log('snapshot',snapshot)

            expect(await deployed.seigManagerV2.indexLtonAt(snapshot.id)).to.be.eq(snapshot.indexLton);
            expect(await deployed.optimismSequencer.totalStakedLtonAt(snapshot.id)).to.be.eq(snapshot.totalStakedLton);
            expect(await deployed.optimismSequencer["balanceOfLtonAt(uint32,uint256)"](snapshot.layerIndex, snapshot.id))
                    .to.be.eq(snapshot.balanceOfLayer);
            expect(await deployed.optimismSequencer["balanceOfLtonAt(uint32,address,uint256)"](snapshot.layerIndex, account.address, snapshot.id))
                    .to.be.eq(snapshot.balanceOfAccount);

            let snapshotTimeAfter = await deployed.seigManagerV2.getSnapshotTime()
            expect(snapshotTimeAfter[snapshotId]).to.be.gt(block.timestamp);
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

    describe('# snapshot', () => {

        it('Anyone can take a snapshot.', async () => {
            // console.log('------------- 2 ---------------')
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let account = addr1

            let block = await ethers.provider.getBlock('latest');

            const snapshotIdBefore = await deployed.seigManagerV2.getCurrentSnapshotId()
            const indexLton0 = await deployed.seigManagerV2.indexLton();

            const interface1 = deployed.seigManagerV2.interface ;
            const topic = interface1.getEventTopic('Snapshot');
            const receipt = await(await snapshotGasCost(deployed.seigManagerV2.connect(addr1).snapshot())).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0 );
            const deployedEvent = interface1.parseLog(log);
            let snapshotId  = deployedEvent.args.id;
            expect(snapshotId).to.be.eq(snapshotIdBefore.add(ethers.constants.One));

            const indexLton1 = await deployed.seigManagerV2.indexLton();
            const totalStakedLton1 = await deployed.optimismSequencer.totalStakedLton();
            const balanceOfLayer1 = await deployed.optimismSequencer["balanceOfLton(uint32)"](layerIndex);
            const balanceOfAccount1 = await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, account.address);

            let snapshot:StakeSnapshotFixture = {
                id: snapshotId,
                layerIndex: layerIndex,
                account: account.address,
                indexLton: indexLton1,
                totalStakedLton: totalStakedLton1,
                balanceOfLayer: balanceOfLayer1,
                balanceOfAccount: balanceOfAccount1
            }
            snapshotListSequencer.push(snapshot)
            // console.log(snapshotListSequencer);

            expect(await deployed.seigManagerV2.indexLtonAt(snapshotIdBefore)).to.be.eq(indexLton0);
            let snapshotTimeAfter = await deployed.seigManagerV2.getSnapshotTime()
            expect(snapshotTimeAfter[snapshotId]).to.be.gt(block.timestamp);

            let i=0;
            for (i = 0; i < snapshotListSequencer.length; i++){
                expect(await deployed.seigManagerV2.indexLtonAt(snapshotListSequencer[i].id)).to.be.eq(snapshotListSequencer[i].indexLton);
                expect(await deployed.optimismSequencer.totalStakedLtonAt(snapshotListSequencer[i].id)).to.be.eq(snapshotListSequencer[i].totalStakedLton);
                expect(await deployed.optimismSequencer["balanceOfLtonAt(uint32,uint256)"](snapshotListSequencer[i].layerIndex, snapshotListSequencer[i].id))
                        .to.be.eq(snapshotListSequencer[i].balanceOfLayer);
                expect(await deployed.optimismSequencer["balanceOfLtonAt(uint32,address,uint256)"](snapshotListSequencer[i].layerIndex, account.address, snapshotListSequencer[i].id))
                        .to.be.eq(snapshotListSequencer[i].balanceOfAccount);
            }

        });

    });

    /// l2 fast withdraw
    describe('# fast withdraw', () => {

        it('L2 user request the fast withdraw ', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let block = await ethers.provider.getBlock('latest')

            messageInfo.amount = ethers.utils.parseEther("1")
            messageInfo.requestor = addr2.address
            messageInfo.deadline =  block.timestamp  + (60 * 60)
            messageInfo.deadline = parseInt(messageInfo.deadline)
            messageInfo.layerIndex = layerIndex
            messageInfo.messageNonce = ethers.BigNumber.from("11")

            let parseMessage : ParseMessageFixture = {
                xDomainCalldata: '',
                finalizeERC20WithdrawalData: '',
                fwReceiptData: '',
                fwRequestBytes: '',
                hashMessage: ''
            }

            let requestInfo: DomainMessageFixture = {
                messageNonce: messageNonce,
                fwReceipt: deployed.fwReceiptProxy.address,
                l1ton : seigManagerInfo.ton,
                layerInfo: layerInfo,
                messageInfo: messageInfo,
                parseMessage: parseMessage
            }

            const l2Messages = await bytesFastWithdrawMessage1(
                deployed.fwReceiptProxy.address,
                seigManagerInfo.ton,
                layerInfo,
                messageInfo,
                );
            // console.log('bytesFastWithdrawMessage', l2Messages)

            requestInfo.parseMessage.xDomainCalldata = l2Messages.xDomainCalldata;
            requestInfo.parseMessage.finalizeERC20WithdrawalData = l2Messages.finalizeERC20WithdrawalData;
            requestInfo.parseMessage.fwReceiptData = l2Messages.fwReceiptData;
            requestInfo.parseMessage.fwRequestBytes = l2Messages.fwRequestBytes;
            requestInfo.parseMessage.hashMessage = l2Messages.hashMessage;

            xDomainCalldataList = [];
            xDomainCalldataList.push(requestInfo);
        });
        it('The requester and provider cannot be the same.', async () => {
            let info: DomainMessageFixture = xDomainCalldataList[0];

            await expect(
                deployed.fwReceipt.connect(addr2).provideLiquidity(
                    info.messageInfo.requestor,
                    info.messageInfo.amount,
                    info.messageInfo.amount,
                    info.messageInfo.deadline,
                    false,
                    info.messageInfo.layerIndex,
                    info.messageInfo.feeRates,
                    info.messageInfo.layerIndex,
                    info.messageInfo.messageNonce,
                    info.parseMessage.hashMessage
                )
                ).to.be.revertedWith("The requester and provider cannot be the same.")

        });

        it('If it is an unsuccessful L1 message, it cannot be executed.', async () => {
            let info = xDomainCalldataList[0];
            await expect(
                deployed.fwReceipt.connect(addr1).finalizeFastWithdraw(
                    info.messageInfo.requestor,
                    info.messageInfo.amount,
                    0,
                    info.messageInfo.feeRates,
                    info.messageInfo.layerIndex,
                    info.messageInfo.messageNonce,
                    info.parseMessage.hashMessage
                )
                ).to.be.revertedWith("fail validateHashMessage")
        });

        it('If anyone don\'t provide liquidity to l2\'s request fw, L2 user withdraw the request amount by L1Bridge', async () => {

            let info: DomainMessageFixture = xDomainCalldataList[0];
            let balanceBefore = await deployed.ton.balanceOf(info.messageInfo.requestor)
            if (info.messageInfo.amount.gt(await deployed.ton.balanceOf(deployed.l1Bridge.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(deployed.l1Bridge.address, info.messageInfo.amount)).wait();

            let key = info.parseMessage.hashMessage;

            // (1)  DTD 이후 브릿지에서 실행이 된다.
            const receipt1 = await(
                await snapshotGasCost(deployed.l1Bridge.connect(addr1).finalizeERC20Withdrawal(
                    info.l1ton,
                    info.layerInfo.l2ton,
                    info.messageInfo.requestor,
                    info.fwReceipt,
                    info.messageInfo.amount,
                    info.parseMessage.fwRequestBytes,
                    info.messageInfo.messageNonce
            ))).wait();
            // console.log('receipt',receipt)

            // (2)  l1Messenger 의 successfulMessages 가 true 가 된다.
            let successfulMessages = await deployed.l1Messenger.successfulMessages(key);
            expect(successfulMessages).to.be.eq(true);

            // (3)  누군가가 FwContract에서 별도로 실행을 해야 한다. 실행을 해주지 않으면 시뇨리지를 계속 받게 된다.
            const interface1 = deployed.fwReceipt.interface ;
            const topic = interface1.getEventTopic('NormalWithdrawal');
            const receipt = await(
                await snapshotGasCost(deployed.fwReceipt.connect(addr1).finalizeFastWithdraw(
                    info.messageInfo.requestor,
                    info.messageInfo.amount,
                    info.messageInfo.deadline,
                    info.messageInfo.feeRates,
                    info.messageInfo.layerIndex,
                    info.messageInfo.messageNonce,
                    info.parseMessage.hashMessage
            ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0 );
            const deployedEvent = interface1.parseLog(log);
            expect(deployedEvent.args.key).to.be.eq(key);
            expect(deployedEvent.args.from).to.be.eq(info.messageInfo.requestor);
            expect(deployedEvent.args.to).to.be.eq(info.messageInfo.requestor);
            expect(deployedEvent.args.amount).to.be.eq(info.messageInfo.amount);
            expect(deployedEvent.args.status).to.be.eq(FW_STATUS.NORMAL_WITHDRAWAL);

            expect(await deployed.ton.balanceOf(info.messageInfo.requestor)).to.be.eq(balanceBefore.add(info.messageInfo.amount));

        });

        it('Liquidity cannot be provided for requests that have already been withdrawn.', async () => {

            let info: DomainMessageFixture = xDomainCalldataList[0];
            let key = info.parseMessage.hashMessage;
            await expect(
                deployed.fwReceipt.connect(addr1).provideLiquidity(
                    info.messageInfo.requestor,
                    info.messageInfo.amount,
                    info.messageInfo.amount,
                    info.messageInfo.deadline,
                    false,
                    info.messageInfo.layerIndex,
                    info.messageInfo.feeRates,
                    info.messageInfo.layerIndex,
                    info.messageInfo.messageNonce,
                    info.parseMessage.hashMessage
                )
                ).to.be.revertedWith("already processed")
        });

        it('L2 user request the fast withdraw ', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let block = await ethers.provider.getBlock('latest')

            messageInfo.requestor = addr1.address
            messageInfo.deadline =  block.timestamp - 100;
            messageInfo.deadline = parseInt(messageInfo.deadline)
            messageInfo.layerIndex = layerIndex
            messageInfo.messageNonce = ethers.BigNumber.from("2")

            let parseMessage : ParseMessageFixture = {
                xDomainCalldata: '',
                finalizeERC20WithdrawalData: '',
                fwReceiptData: '',
                fwRequestBytes: '',
                hashMessage: ''
            }

            let requestInfo: DomainMessageFixture = {
                messageNonce: messageNonce,
                fwReceipt: deployed.fwReceiptProxy.address,
                l1ton : seigManagerInfo.ton,
                layerInfo: layerInfo,
                messageInfo: messageInfo,
                provider: '',
                parseMessage: parseMessage
            }

            const l2Messages = await bytesFastWithdrawMessage1(
                deployed.fwReceiptProxy.address,
                seigManagerInfo.ton,
                layerInfo,
                messageInfo,
                );

            requestInfo.parseMessage.xDomainCalldata = l2Messages.xDomainCalldata;
            requestInfo.parseMessage.finalizeERC20WithdrawalData = l2Messages.finalizeERC20WithdrawalData;
            requestInfo.parseMessage.fwReceiptData = l2Messages.fwReceiptData;
            requestInfo.parseMessage.fwRequestBytes = l2Messages.fwRequestBytes;
            requestInfo.parseMessage.hashMessage = l2Messages.hashMessage;

            // xDomainCalldataList = [];
            xDomainCalldataList.push(requestInfo);
        });

        it('L1 users cannot provide liquidity after the fw deadline has passed.', async () => {
            let info: DomainMessageFixture = xDomainCalldataList[1];
            await expect(
                deployed.fwReceipt.connect(addr1).provideLiquidity(
                    info.messageInfo.requestor,
                    info.messageInfo.amount,
                    info.messageInfo.amount,
                    info.messageInfo.deadline,
                    false,
                    info.messageInfo.layerIndex,
                    info.messageInfo.feeRates,
                    info.messageInfo.layerIndex,
                    info.messageInfo.messageNonce,
                    info.parseMessage.hashMessage
                )
                ).to.be.revertedWith("past deadline")

        });

        it('L2 user request the fast withdraw ', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let block = await ethers.provider.getBlock('latest')

            messageInfo.requestor = addr2.address
            messageInfo.deadline =  block.timestamp + (60*60);
            messageInfo.deadline = parseInt(messageInfo.deadline)
            messageInfo.layerIndex = layerIndex
            messageInfo.messageNonce = ethers.BigNumber.from("3")

            let availableLiquidity = await deployed.fwReceipt.availableLiquidity(
                false, messageInfo.layerIndex,  addr1.address);

            messageInfo.amount = availableLiquidity.add(
                availableLiquidity.mul(ethers.BigNumber.from("4")).div(ethers.BigNumber.from("10")))


            let parseMessage : ParseMessageFixture = {
                xDomainCalldata: '',
                finalizeERC20WithdrawalData: '',
                fwReceiptData: '',
                fwRequestBytes: '',
                hashMessage: ''
            }

            let requestInfo: DomainMessageFixture = {
                messageNonce: messageNonce,
                fwReceipt: deployed.fwReceiptProxy.address,
                l1ton : seigManagerInfo.ton,
                layerInfo: layerInfo,
                messageInfo: messageInfo,
                provider: '',
                parseMessage: parseMessage
            }

            const l2Messages = await bytesFastWithdrawMessage1(
                deployed.fwReceiptProxy.address,
                seigManagerInfo.ton,
                layerInfo,
                messageInfo,
                );

            requestInfo.parseMessage.xDomainCalldata = l2Messages.xDomainCalldata;
            requestInfo.parseMessage.finalizeERC20WithdrawalData = l2Messages.finalizeERC20WithdrawalData;
            requestInfo.parseMessage.fwReceiptData = l2Messages.fwReceiptData;
            requestInfo.parseMessage.fwRequestBytes = l2Messages.fwRequestBytes;
            requestInfo.parseMessage.hashMessage = l2Messages.hashMessage;


            // xDomainCalldataList = [];
            xDomainCalldataList.push(requestInfo);

        });

        it('If there is not enough money to provide liquidity, it cannot provide liquidity.', async () => {
            let info: DomainMessageFixture = xDomainCalldataList[2];

            await expect(
                deployed.fwReceipt.connect(addr1).provideLiquidity(
                    info.messageInfo.requestor,
                    info.messageInfo.amount,
                    info.messageInfo.amount,
                    info.messageInfo.deadline,
                    false,
                    info.messageInfo.layerIndex,
                    info.messageInfo.feeRates,
                    info.messageInfo.layerIndex,
                    info.messageInfo.messageNonce,
                    info.parseMessage.hashMessage
                )
                ).to.be.revertedWith("liquidity is insufficient.")
        });

        it('The L1 provider cannot provide liquidity for cases canceled by the L2 requester.', async () => {
            let info: DomainMessageFixture = xDomainCalldataList[2];
            await (await deployed.fwReceipt.connect(addr2).cancelRequest(
                    info.messageInfo.requestor,
                    info.messageInfo.amount,
                    info.messageInfo.deadline,
                    info.messageInfo.feeRates,
                    info.messageInfo.layerIndex,
                    info.messageInfo.messageNonce,
                    info.parseMessage.hashMessage
                )).wait();

            await expect(deployed.fwReceipt.connect(addr1).provideLiquidity(
                info.messageInfo.requestor,
                info.messageInfo.amount,
                info.messageInfo.amount,
                info.messageInfo.deadline,
                false,
                info.messageInfo.layerIndex,
                info.messageInfo.feeRates,
                info.messageInfo.layerIndex,
                info.messageInfo.messageNonce,
                info.parseMessage.hashMessage
                )
                ).to.be.revertedWith("already processed")
        });

        it('The L2 request withdraw the fw amount for cases canceled by the L2 requester.', async () => {

            let info: DomainMessageFixture = xDomainCalldataList[2];
            let balanceBefore = await deployed.ton.balanceOf(addr2.address)
            if (info.messageInfo.amount.gt(await deployed.ton.balanceOf(deployed.l1Bridge.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(deployed.l1Bridge.address, info.messageInfo.amount)).wait();

            let key = info.parseMessage.hashMessage;

            // (1)  DTD 이후 브릿지에서 실행이 된다.
            const receipt1 = await(
                await snapshotGasCost(deployed.l1Bridge.connect(addr1).finalizeERC20Withdrawal(
                    info.l1ton,
                    info.layerInfo.l2ton,
                    info.messageInfo.requestor,
                    info.fwReceipt,
                    info.messageInfo.amount,
                    info.parseMessage.fwRequestBytes,
                    info.messageInfo.messageNonce
            ))).wait();

            // (2)  l1Messenger 의 successfulMessages 가 true 가 된다.
            let successfulMessages = await deployed.l1Messenger.successfulMessages(key);
            expect(successfulMessages).to.be.eq(true);

            // (3)  누군가가 FwContract에서 별도로 실행을 해야 한다. 실행을 해주지 않으면 시뇨리지를 계속 받게 된다.
            const interface1 = deployed.fwReceipt.interface ;
            const topic = interface1.getEventTopic('NormalWithdrawal');
            const receipt = await(
                await snapshotGasCost(deployed.fwReceipt.connect(addr1).finalizeFastWithdraw(
                    info.messageInfo.requestor,
                    info.messageInfo.amount,
                    info.messageInfo.deadline,
                    info.messageInfo.feeRates,
                    info.messageInfo.layerIndex,
                    info.messageInfo.messageNonce,
                    info.parseMessage.hashMessage
            ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = interface1.parseLog(log);

            expect(deployedEvent.args.key).to.be.eq(key);
            expect(deployedEvent.args.from).to.be.eq(info.messageInfo.requestor);
            expect(deployedEvent.args.to).to.be.eq(info.messageInfo.requestor);
            expect(deployedEvent.args.amount).to.be.eq(info.messageInfo.amount);
            expect(deployedEvent.args.status).to.be.eq(FW_STATUS.CANCEL_WITHDRAWAL);

            expect(await deployed.ton.balanceOf(addr2.address)).to.be.eq(balanceBefore.add(info.messageInfo.amount));

        });

        it('L2 user request the fast withdraw ', async () => {
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let block = await ethers.provider.getBlock('latest')

            messageInfo.requestor = addr2.address
            messageInfo.deadline =  block.timestamp + (60*60);
            messageInfo.deadline = parseInt(messageInfo.deadline)
            messageInfo.layerIndex = layerIndex
            messageInfo.messageNonce = ethers.BigNumber.from("4")

            let availableLiquidity = await deployed.fwReceipt.availableLiquidity(
                false, messageInfo.layerIndex,  addr1.address);

            messageInfo.amount = availableLiquidity.div(ethers.BigNumber.from("10000").sub(ethers.BigNumber.from(messageInfo.feeRates))).mul(ethers.BigNumber.from("10000"));

            let parseMessage : ParseMessageFixture = {
                xDomainCalldata: '',
                finalizeERC20WithdrawalData: '',
                fwReceiptData: '',
                fwRequestBytes: '',
                hashMessage: ''
            }
            let requestInfo: DomainMessageFixture = {
                messageNonce: messageNonce,
                fwReceipt: deployed.fwReceiptProxy.address,
                l1ton : seigManagerInfo.ton,
                layerInfo: layerInfo,
                messageInfo: messageInfo,
                parseMessage: parseMessage
            }

            const l2Messages = await bytesFastWithdrawMessage1(
                deployed.fwReceiptProxy.address,
                seigManagerInfo.ton,
                layerInfo,
                messageInfo,
                );

            requestInfo.parseMessage.xDomainCalldata = l2Messages.xDomainCalldata;
            requestInfo.parseMessage.finalizeERC20WithdrawalData = l2Messages.finalizeERC20WithdrawalData;
            requestInfo.parseMessage.fwReceiptData = l2Messages.fwReceiptData;
            requestInfo.parseMessage.fwRequestBytes = l2Messages.fwRequestBytes;
            requestInfo.parseMessage.hashMessage = l2Messages.hashMessage;

            // xDomainCalldataList = [];
            xDomainCalldataList.push(requestInfo);
        });

        it('If someone provide liquidity to l2\'s request fw, L2 user withdraw at providing.', async () => {
            xDomainCalldataList[3].provider  = addr1.address;
            xDomainCalldataList[3].isCandidate  = false;
            xDomainCalldataList[3].indexNo  = xDomainCalldataList[3].messageInfo.layerIndex;
            let info: DomainMessageFixture = xDomainCalldataList[3];

            let balanceAddr1Before = await deployed.ton.balanceOf(addr1.address)
            let balanceAddr2Before = await deployed.ton.balanceOf(addr2.address)
            let stakedAddr1Before = await deployed.optimismSequencer["balanceOfLton(uint32,address)"](
                info.messageInfo.layerIndex, addr1.address);
            let debtInStakedAddr1Before = await deployed.fwReceipt.debtInStaked(
                false, info.messageInfo.layerIndex, addr1.address);

            if (info.messageInfo.amount.gt(await deployed.ton.balanceOf(deployed.l1Bridge.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(deployed.l1Bridge.address, info.messageInfo.amount)).wait();

            let balancel1BridgeBefore = await deployed.ton.balanceOf(deployed.l1Bridge.address)

            let key = info.parseMessage.hashMessage;

            const interface0 = deployed.fwReceipt.interface ;
            const topic0 = interface0.getEventTopic('ProvidedLiquidity');
            const receipt = await(
                await snapshotGasCost(deployed.fwReceipt.connect(addr1).provideLiquidity(
                    info.messageInfo.requestor,
                    info.messageInfo.amount,
                    info.messageInfo.amount,
                    info.messageInfo.deadline,
                    false,
                    info.messageInfo.layerIndex,
                    info.messageInfo.feeRates,
                    info.messageInfo.layerIndex,
                    info.messageInfo.messageNonce,
                    info.parseMessage.hashMessage
                ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic0) >= 0);
            const deployedEvent = interface0.parseLog(log);

            let fee = info.messageInfo.amount.mul(ethers.BigNumber.from(messageInfo.feeRates)).div(ethers.BigNumber.from("10000"));
            let provideAmount = info.messageInfo.amount.sub(fee);
            expect(deployedEvent.args.key).to.be.eq(key);
            expect(deployedEvent.args.provider).to.be.eq(addr1.address);
            expect(deployedEvent.args.provideAmount).to.be.eq(provideAmount);
            expect(deployedEvent.args.feeAmount).to.be.eq(fee);

            expect(await deployed.ton.balanceOf(addr2.address)).to.be.eq(balanceAddr2Before.add(provideAmount));
            expect(await deployed.ton.balanceOf(deployed.l1Bridge.address)).to.be.eq(balancel1BridgeBefore);

            // 업데이트 시뇨리지시 이미 제공된 유동성에 대해서도 이자를 받을 수 있다.
            expect(await deployed.optimismSequencer["balanceOfLton(uint32,address)"](
                info.messageInfo.layerIndex, addr1.address
            )).to.be.eq(stakedAddr1Before);

            expect(await deployed.fwReceipt.debtInStaked(
                false, info.messageInfo.layerIndex, addr1.address
            )).to.be.eq(debtInStakedAddr1Before.add(provideAmount));

        });

        it('Fast withdrawals, normally provided with liquidity, are settled after DTD.', async () => {
            let info: DomainMessageFixture = xDomainCalldataList[3];
            let balanceBeforeAddr1 = await deployed.ton.balanceOf(addr1.address)
            let stakedAddr1Before = await deployed.optimismSequencer["balanceOfLton(uint32,address)"](
                info.messageInfo.layerIndex, addr1.address);
            let debtInStakedAddr1Before = await deployed.fwReceipt.debtInStaked(
                false, info.messageInfo.layerIndex, addr1.address);

            if (info.messageInfo.amount.gt(await deployed.ton.balanceOf(deployed.l1Bridge.address)))
                await (await deployed.ton.connect(deployed.tonAdmin).mint(deployed.l1Bridge.address, info.messageInfo.amount)).wait();

            let key = info.parseMessage.hashMessage;

            // (1)  DTD 이후 브릿지에서 실행이 된다.
            const receipt1 = await(
                await snapshotGasCost(deployed.l1Bridge.connect(addr1).finalizeERC20Withdrawal(
                    info.l1ton,
                    info.layerInfo.l2ton,
                    info.messageInfo.requestor,
                    info.fwReceipt,
                    info.messageInfo.amount,
                    info.parseMessage.fwRequestBytes,
                    info.messageInfo.messageNonce
            ))).wait();
            // console.log('receipt',receipt)

            // (2)  l1Messenger 의 successfulMessages 가 true 가 된다.
            let successfulMessages = await deployed.l1Messenger.successfulMessages(key);
            expect(successfulMessages).to.be.eq(true);

            // (3)  누군가가 FwContract에서 별도로 실행을 해야 한다. 실행을 해주지 않으면 시뇨리지를 계속 받게 된다.
            const interface1 = deployed.fwReceipt.interface ;
            const topic = interface1.getEventTopic('FinalizedFastWithdrawal');
            const receipt = await(
                await snapshotGasCost(deployed.fwReceipt.connect(addr1).finalizeFastWithdraw(
                    info.messageInfo.requestor,
                    info.messageInfo.amount,
                    info.messageInfo.deadline,
                    info.messageInfo.feeRates,
                    info.messageInfo.layerIndex,
                    info.messageInfo.messageNonce,
                    info.parseMessage.hashMessage
            ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);

            const deployedEvent = interface1.parseLog(log);

            let fee = info.messageInfo.amount.mul(ethers.BigNumber.from(messageInfo.feeRates)).div(ethers.BigNumber.from("10000"));
            let provideAmount = info.messageInfo.amount.sub(fee);

            expect(deployedEvent.args.key).to.be.eq(key);
            expect(deployedEvent.args.from).to.be.eq(info.provider);
            expect(deployedEvent.args.to).to.be.eq(info.messageInfo.requestor);
            expect(deployedEvent.args.providedAmount).to.be.eq(provideAmount);
            expect(deployedEvent.args.feeAmount).to.be.eq(fee);
            expect(deployedEvent.args.isCandidate).to.be.eq(info.isCandidate);
            expect(deployedEvent.args.indexNo).to.be.eq(info.indexNo);

            let feeLton = await deployed.seigManagerV2.getTonToLton(fee);
            expect(await deployed.optimismSequencer["balanceOfLton(uint32,address)"](
                info.messageInfo.layerIndex, addr1.address
            )).to.be.eq(stakedAddr1Before.add(feeLton));

            // 정산된다.
            expect(await deployed.fwReceipt.debtInStaked(
                false, info.messageInfo.layerIndex, addr1.address
            )).to.be.eq(debtInStakedAddr1Before.sub(provideAmount));
        });

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

            expect(await deployed.seigManagerV2.ratesDao()).to.eq(seigManagerInfo.ratesDao)
            expect(await deployed.seigManagerV2.ratesStosHolders()).to.eq(seigManagerInfo.ratesStosHolders)

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

        it('Anyone can take a snapshot.', async () => {
            // console.log('------------- 3 ---------------')
            let layerIndex = await deployed.layer2Manager.indexSequencers();
            let account = addr1

            let block = await ethers.provider.getBlock('latest');

            const snapshotIdBefore = await deployed.seigManagerV2.getCurrentSnapshotId()

            const interface1 = deployed.seigManagerV2.interface ;
            const topic = interface1.getEventTopic('Snapshot');
            const receipt = await(await snapshotGasCost(deployed.seigManagerV2.connect(addr1).snapshot())).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0 );
            const deployedEvent = interface1.parseLog(log);
            let snapshotId  = deployedEvent.args.id;
            expect(snapshotId).to.be.eq(snapshotIdBefore.add(ethers.constants.One));

            const indexLton1 = await deployed.seigManagerV2.indexLton();
            const totalStakedLton1 = await deployed.optimismSequencer.totalStakedLton();
            const balanceOfLayer1 = await deployed.optimismSequencer["balanceOfLton(uint32)"](layerIndex);
            const balanceOfAccount1 = await deployed.optimismSequencer["balanceOfLton(uint32,address)"](layerIndex, account.address);


            let snapshot:StakeSnapshotFixture = {
                id: snapshotId,
                layerIndex: layerIndex,
                account: account.address,
                indexLton: indexLton1,
                totalStakedLton: totalStakedLton1,
                balanceOfLayer: balanceOfLayer1,
                balanceOfAccount: balanceOfAccount1
            }
            snapshotListSequencer.push(snapshot)
            // console.log(snapshotListSequencer);
            let snapshotTimeAfter = await deployed.seigManagerV2.getSnapshotTime()
            expect(snapshotTimeAfter[snapshotId]).to.be.gt(block.timestamp);

            let i=0;
            for (i = 0; i < snapshotListSequencer.length; i++){
                expect(await deployed.seigManagerV2.indexLtonAt(snapshotListSequencer[i].id)).to.be.eq(snapshotListSequencer[i].indexLton);
                expect(await deployed.optimismSequencer.totalStakedLtonAt(snapshotListSequencer[i].id)).to.be.eq(snapshotListSequencer[i].totalStakedLton);
                expect(await deployed.optimismSequencer["balanceOfLtonAt(uint32,uint256)"](snapshotListSequencer[i].layerIndex, snapshotListSequencer[i].id))
                        .to.be.eq(snapshotListSequencer[i].balanceOfLayer);
                expect(await deployed.optimismSequencer["balanceOfLtonAt(uint32,address,uint256)"](snapshotListSequencer[i].layerIndex, account.address, snapshotListSequencer[i].id))
                        .to.be.eq(snapshotListSequencer[i].balanceOfAccount);
            }
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
            expect(await deployed.candidate.operator(candidateIndex)).to.eq(addr1.address)

            let amountLton = await deployed.candidate["balanceOfLton(uint32,address)"](candidateIndex, addr1.address)

            await expect(
                deployed.candidate.connect(addr1)["unstake(uint32,uint256)"](
                    candidateIndex,
                    amountLton
                )).to.be.revertedWith("unstake_err_1");
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

            await expect(deployed.optimismSequencer.connect(addr1).withdraw(layerIndex, false)).to.be.revertedWith("zero available withdrawal amount")

        })

        it('[at Candidate] You cannot withdraw if there is no amount available for withdrawal.', async () => {

            let _index = await deployed.layer2Manager.indexCandidates();

            const availableWithdrawOfStaker = await deployed.candidate.availableWithdraw(_index, addr1.address)

            expect(availableWithdrawOfStaker.amount).to.eq(ethers.constants.Zero)

            await expect(deployed.candidate.connect(addr1).withdraw(_index, true)).to.be.revertedWith("zero available withdrawal amount")

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

            const receipt = await (await snapshotGasCost(deployed.optimismSequencer.connect(addr1).withdraw(layerIndex, false))).wait();

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

            const receipt = await (await snapshotGasCost(deployed.candidate.connect(addr1).withdraw(_index, true))).wait();

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
            // console.log('balanceOfUser', ethers.utils.formatUnits(balanceOfUser), "TON")
            // console.log('curTotalLayer2Deposits', ethers.utils.formatUnits(curTotalLayer2Deposits), "TON")

            await (await snapshotGasCost(deployed.l1Bridge.connect(addr1).finalizeERC20Withdrawal(
                    deployed.ton.address,
                    deployed.l2ton.address,
                    addr1.address,
                    addr1.address,
                    amount,
                    '0x',
                    ethers.constants.Zero
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

