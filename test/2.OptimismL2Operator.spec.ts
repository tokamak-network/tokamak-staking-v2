import { expect } from './shared/expect'
import { ethers, network } from 'hardhat'

import { Signer } from 'ethers'
import {stakingV2Fixtures, getLayerKey} from './shared/fixtures'
import { TonStakingV2Fixture } from './shared/fixtureInterfaces'
import snapshotGasCost from './shared/snapshotGasCost'

describe('OptimismSequencer', () => {
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
        sequencer1 = deployed.operator1;
    })

    describe('# initialize', () => {

        it('initialize can not be executed by not owner', async () => {
            await expect(
                deployed.optimismL2OperatorProxy.connect(addr1).initialize(
                    seigManagerInfo.ton,
                    deployed.seigManagerV2Proxy.address,
                    deployed.layer2ManagerProxy.address,
                    deployed.fwReceiptProxy.address
                )
                ).to.be.revertedWith("Accessible: Caller is not an admin")
        })

        it('initialize can be executed by only owner', async () => {
            await snapshotGasCost(deployed.optimismL2OperatorProxy.connect(deployer).initialize(
                seigManagerInfo.ton,
                deployed.seigManagerV2Proxy.address,
                deployed.layer2ManagerProxy.address,
                deployed.fwReceiptProxy.address
                ))

            expect(await deployed.optimismL2OperatorProxy.ton()).to.eq(seigManagerInfo.ton)
            expect(await deployed.optimismL2OperatorProxy.seigManagerV2()).to.eq(deployed.seigManagerV2Proxy.address)
            expect(await deployed.optimismL2OperatorProxy.layer2Manager()).to.eq(deployed.layer2ManagerProxy.address)

        })

        it('can execute only once.', async () => {
            await expect(
                deployed.optimismL2OperatorProxy.connect(deployer).initialize(
                    seigManagerInfo.ton,
                    deployed.seigManagerV2Proxy.address,
                    deployed.layer2ManagerProxy.address,
                    deployed.fwReceiptProxy.address
                )
                ).to.be.revertedWith("already initialize")
        })
    });

    describe('# stake', () => {

        it('You cannot stake on unregistered layers.', async () => {
            let amount = ethers.utils.parseEther("100");
            let addressOne ="0x0000000000000000000000000000000000000001";
            let _index = 1;

            await expect(
                deployed.optimismL2Operator.connect(addr1).stake(
                    _index,
                    amount
                )
                ).to.be.revertedWith("non-registered layer")

        })
    });

    describe('# fastWithdrawClaim', () => {

        it('fastWithdrawClaim can not be executed by not FwReceiptContract', async () => {
            let amount = ethers.utils.parseEther("100");
            let _index = 1;

            await expect(
                deployed.optimismL2Operator.connect(addr1).fastWithdrawClaim(
                    ethers.constants.HashZero,
                    _index,
                    addr1.address,
                    addr1.address,
                    amount
                )
                ).to.be.revertedWith("FW_CALLER_ERR")

        })
    });

    describe('# fastWithdrawStake', () => {

        it('fastWithdrawStake can not be executed by not FwReceiptContract', async () => {
            let amount = ethers.utils.parseEther("100");
            let _index = 1;

            await expect(
                deployed.optimismL2Operator.connect(addr1).fastWithdrawStake(
                    ethers.constants.HashZero,
                    _index,
                    addr1.address,
                    amount
                )
                ).to.be.revertedWith("FW_CALLER_ERR")

        })
    });
});
