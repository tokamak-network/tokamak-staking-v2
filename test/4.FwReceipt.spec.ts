import { expect } from './shared/expect'
import { ethers, network } from 'hardhat'

import { Signer } from 'ethers'
import {
    FW_STATUS, stakingV2Fixtures, bytesFastWithdrawMessage, bytesInvalidFastWithdrawMessage
    } from './shared/fixtures'
import { TonStakingV2Fixture } from './shared/fixtureInterfaces'
import snapshotGasCost from './shared/snapshotGasCost'

import Web3EthAbi from 'web3-eth-abi';

describe('FwReceipt', () => {
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

    let messageInfo =  {
        requestor: "",
        amount: ethers.utils.parseEther("1"),
        feeRates: 1000,
        deadline: 0,
        layerIndex: 0
    }

    let layerInfo = {
        addressManager: "",
        l1Messenger: "",
        l2Messenger: "",
        l1Bridge: "",
        l2Bridge: "",
        l2ton: ""
    }

    before('create fixture loader', async () => {
        // deployed = await loadFixture(stakingV2Fixtures)

        deployed = await stakingV2Fixtures()
        deployer = deployed.deployer;
        addr1 = deployed.addr1;
        sequencer1 = deployed.sequencer1;

        layerInfo.addressManager = deployed.addressManager.address;
        layerInfo.l1Messenger = deployed.l1Messenger.address
        layerInfo.l2Messenger = deployed.l2Messenger.address
        layerInfo.l1Bridge= deployed.l1Bridge.address
        layerInfo.l2Bridge= deployed.l2Bridge.address
        layerInfo.l2ton= deployed.l2ton.address
    })

    describe('# initialize', () => {

        it('initialize can not be executed by not owner', async () => {
            await expect(
                deployed.fwReceiptProxy.connect(addr1).initialize(
                    seigManagerInfo.ton,
                    deployed.optimismSequencerProxy.address,
                    deployed.candidateProxy.address
                )
                ).to.be.revertedWith("Accessible: Caller is not an admin")
        })

        it('initialize can be executed by only owner', async () => {
            await snapshotGasCost(deployed.fwReceiptProxy.connect(deployer).initialize(
                    seigManagerInfo.ton,
                    deployed.optimismSequencerProxy.address,
                    deployed.candidateProxy.address
                ))

            expect(await deployed.fwReceiptProxy.ton()).to.eq(seigManagerInfo.ton)
            expect(await deployed.fwReceiptProxy.optimismSequencer()).to.eq(deployed.optimismSequencerProxy.address)

        })

        it('can execute only once.', async () => {
            await expect(
                deployed.fwReceiptProxy.connect(deployer).initialize(
                    seigManagerInfo.ton,
                    deployed.optimismSequencerProxy.address,
                    deployed.candidateProxy.address
                )
                ).to.be.revertedWith("already initialize")
        })
    });

    describe('# setOptimismSequencer', () => {

        it('setOptimismSequencer can not be executed by not owner', async () => {
            await expect(
                deployed.fwReceipt.connect(addr1).setOptimismSequencer(deployed.optimismSequencerProxy.address)
                ).to.be.revertedWith("Accessible: Caller is not an admin")
        })

        it('setOptimismSequencer can be executed by only owner ', async () => {
            await snapshotGasCost(
                    deployed.fwReceipt.connect(deployer).setOptimismSequencer(deployed.addr1.address)
            )
            expect(await deployed.fwReceipt.optimismSequencer()).to.eq(deployed.addr1.address)

            await snapshotGasCost(
                    deployed.fwReceipt.connect(deployer).setOptimismSequencer(deployed.optimismSequencerProxy.address)
            )
            expect(await deployed.fwReceipt.optimismSequencer()).to.eq(deployed.optimismSequencerProxy.address)
        })

        it('cannot be changed to the same value', async () => {
            await expect(
                deployed.fwReceipt.connect(deployer).setOptimismSequencer(deployed.optimismSequencerProxy.address)
                ).to.be.revertedWith("same")
        })
    });

    describe('# setCandidate', () => {

        it('setCandidate can not be executed by not owner', async () => {
            await expect(
                deployed.fwReceipt.connect(addr1).setCandidate(deployed.candidateProxy.address)
                ).to.be.revertedWith("Accessible: Caller is not an admin")
        })

        it('setCandidate can be executed by only owner ', async () => {
            await snapshotGasCost(
                    deployed.fwReceipt.connect(deployer).setCandidate(deployed.addr1.address)
            )
            expect(await deployed.fwReceipt.candidate()).to.eq(deployed.addr1.address)

            await snapshotGasCost(
                    deployed.fwReceipt.connect(deployer).setCandidate(deployed.candidateProxy.address)
            )
            expect(await deployed.fwReceipt.candidate()).to.eq(deployed.candidateProxy.address)
        })

        it('cannot be changed to the same value', async () => {
            await expect(
                deployed.fwReceipt.connect(deployer).setCandidate(deployed.candidateProxy.address)
                ).to.be.revertedWith("same")
        })
    });

    describe('# finalizeFastWithdraw', () => {

        it('Zero Layer Index is not allowed.', async () => {

            messageInfo.requestor = addr1.address
            messageInfo.deadline =  (Date.now()/1000)+(60*60)
            messageInfo.deadline = parseInt(messageInfo.deadline)
            messageInfo.layerIndex = 0

            let messageNonce = 0;

            const l2Messages = bytesFastWithdrawMessage(
                messageNonce,
                deployed.fwReceiptProxy.address,
                seigManagerInfo.ton,
                layerInfo,
                messageInfo,
                );

            const topic = deployed.fwReceipt.interface.getEventTopic('InvalidMessageFastWithdrawal');
            const receipt = await (await snapshotGasCost(deployed.fwReceipt.connect(addr1).finalizeFastWithdraw(
                l2Messages
            ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = deployed.fwReceipt.interface.parseLog(log);
            expect(deployedEvent.args.message).to.eq(l2Messages)
            expect(deployedEvent.args.status).to.eq(FW_STATUS.INVALID_LAYERINDEX)
        })

        it('Zero amount is not allowed.', async () => {

            messageInfo.requestor = addr1.address
            messageInfo.deadline =  (Date.now()/1000)+(60*60)
            messageInfo.deadline = parseInt(messageInfo.deadline)
            messageInfo.layerIndex = 1
            messageInfo.amount = ethers.constants.Zero
            let messageNonce = 0;
            const l2Messages = bytesFastWithdrawMessage(
                messageNonce,
                deployed.fwReceiptProxy.address,
                seigManagerInfo.ton,
                layerInfo,
                messageInfo,
                );

            const topic = deployed.fwReceipt.interface.getEventTopic('InvalidMessageFastWithdrawal');
            const receipt = await (await snapshotGasCost(deployed.fwReceipt.connect(addr1).finalizeFastWithdraw(
                l2Messages
            ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = deployed.fwReceipt.interface.parseLog(log);
            expect(deployedEvent.args.message).to.eq(l2Messages)
            expect(deployedEvent.args.status).to.eq(FW_STATUS.ZERO_AMOUNT)
        })

        it('It fails with a layer index that does not exist.', async () => {

            messageInfo.requestor = addr1.address
            messageInfo.deadline =  (Date.now()/1000)+(60*60)
            messageInfo.deadline = parseInt(messageInfo.deadline)
            messageInfo.layerIndex = 1
            messageInfo.amount = ethers.utils.parseEther("1");
            let messageNonce = 0;
            const l2Messages = bytesFastWithdrawMessage(
                messageNonce,
                deployed.fwReceiptProxy.address,
                seigManagerInfo.ton,
                layerInfo,
                messageInfo,
                );

            const topic = deployed.fwReceipt.interface.getEventTopic('InvalidMessageFastWithdrawal');
            const receipt = await (await snapshotGasCost(
                deployed.fwReceipt.connect(addr1).finalizeFastWithdraw(
                    l2Messages
            ))).wait();

            const log = receipt.logs.find(x => x.topics.indexOf(topic) >= 0);
            const deployedEvent = deployed.fwReceipt.interface.parseLog(log);
            expect(deployedEvent.args.message).to.eq(l2Messages)
            expect(deployedEvent.args.status).to.eq(FW_STATUS.ZERO_L1_BRIDGE)
        })
    });

    describe('# provideLiquidity', () => {

        it('Failed on invalid message', async () => {
            messageInfo.requestor = addr1.address
            messageInfo.deadline =  (Date.now()/1000)+(60*60)
            messageInfo.deadline = parseInt(messageInfo.deadline)
            messageInfo.layerIndex = 1
            messageInfo.amount = ethers.utils.parseEther("1");

            const l2Messages = bytesInvalidFastWithdrawMessage(messageInfo);

            await expect(
                deployed.fwReceipt.connect(addr1).provideLiquidity(
                    l2Messages
                )
            ).to.be.revertedWith("InvalidMessageFastWithdrawal")
        })

        it('Fails when layer index does not exist', async () => {
            messageInfo.requestor = addr1.address
            messageInfo.deadline =  (Date.now()/1000)+(60*60)
            messageInfo.deadline = parseInt(messageInfo.deadline)
            messageInfo.layerIndex = 0
            messageInfo.amount = ethers.utils.parseEther("1");
            let messageNonce = 0;
            const l2Messages = bytesFastWithdrawMessage(
                messageNonce,
                deployed.fwReceiptProxy.address,
                seigManagerInfo.ton,
                layerInfo,
                messageInfo,
                );

            await expect(
                deployed.fwReceipt.connect(addr1).provideLiquidity(
                    l2Messages
                )
            ).to.be.revertedWith("InvalidMessageFastWithdrawal")
        })

    });

    describe('# cancelRequest', () => {

        it('Failed on invalid message', async () => {
            messageInfo.requestor = addr1.address
            messageInfo.deadline =  (Date.now()/1000)+(60*60)
            messageInfo.deadline = parseInt(messageInfo.deadline)
            messageInfo.layerIndex = 1
            messageInfo.amount = ethers.utils.parseEther("1");

            const l2Messages = bytesInvalidFastWithdrawMessage(messageInfo);

            await expect(
                deployed.fwReceipt.connect(addr1).cancelRequest(
                    l2Messages
                )
            ).to.be.revertedWith("InvalidMessageFastWithdrawal")
        })


        it('Fails when layer index does not exist', async () => {
            messageInfo.requestor = addr1.address
            messageInfo.deadline =  (Date.now()/1000)+(60*60)
            messageInfo.deadline = parseInt(messageInfo.deadline)
            messageInfo.layerIndex = 0
            messageInfo.amount = ethers.utils.parseEther("1");
            let messageNonce = 0;
            const l2Messages = bytesFastWithdrawMessage(
                messageNonce,
                deployed.fwReceiptProxy.address,
                seigManagerInfo.ton,
                layerInfo,
                messageInfo,
                );

            await expect(
                deployed.fwReceipt.connect(addr1).cancelRequest(
                    l2Messages
                )
            ).to.be.revertedWith("InvalidMessageFastWithdrawal")
        })
    });

});

