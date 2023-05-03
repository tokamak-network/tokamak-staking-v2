const { ethers, network } = require("hardhat");
const { Signer, BigNumber } = require("ethers");
const { expect, use } = require('chai');
const {SimpleStakeV1Contracts, getSimpleStakeV1Contracts, level19Address} = require("../shared/simple-stake-v1");
async function mineBlocks(blockNumber) {
    while (blockNumber > 0) {
      blockNumber--;
      await hre.network.provider.request({
        method: "evm_mine",
        params: [],
      });
    }
  }
describe('SeigManagerV2', () => {
    let deployer;
    let simpleStakeV1;
    let totalStakedAmount, userLevel19StakedAmount ;

    before('get simple stake contracts', async () => {
        simpleStakeV1 = await getSimpleStakeV1Contracts()

        console.log("ton admin", simpleStakeV1.tonAdmin.address)
        console.log("user1", simpleStakeV1.user1.address)

    })

    describe('# stakeOf', () => {

        it('user1\'s stakeOf', async () => {

            userLevel19StakedAmount = await simpleStakeV1.seigManager.stakeOf(
                level19Address,
                simpleStakeV1.user1.address
            )
            console.log('user1\'s stakeOf', ethers.utils.formatUnits(userLevel19StakedAmount, 27), 'WTON')
        });

        it('totalStakedAmount', async () => {
            totalStakedAmount  = await simpleStakeV1.tot["totalSupply()"]();
            console.log('totalStakedAmount', ethers.utils.formatUnits(totalStakedAmount, 27), 'WTON')
        });

        it('paused', async () => {
            let tx = await simpleStakeV1.seigManager.connect(simpleStakeV1.tonAdmin).pause();
        });

        it('update Seigniroage : don\'t change total staked amount after pause.', async () => {
            await simpleStakeV1.level19.updateSeigniorage();
            let totalStakedAmount = await simpleStakeV1.tot.totalSupply();
            console.log('totalStakedAmount', ethers.utils.formatUnits(totalStakedAmount, 27), 'WTON')
        });

        it('stake', async () => {

            let amount = ethers.utils.parseEther("100000000000");
            let balance = await simpleStakeV1.wton.balanceOf(simpleStakeV1.user1.address);

            if (balance.lt(amount)) {
                await simpleStakeV1.wton.connect(simpleStakeV1.tonAdmin).mint(
                    simpleStakeV1.user1.address,
                    amount
                );
            }

            let allowance = await simpleStakeV1.wton.allowance(simpleStakeV1.user1.address, simpleStakeV1.depositManager.address);
            if (allowance.lt(amount)) {
                await simpleStakeV1.wton.connect(simpleStakeV1.user1).approve(
                    simpleStakeV1.depositManager.address,
                    amount
                );
            }

            (await simpleStakeV1.depositManager.connect(simpleStakeV1.user1).deposit(
                simpleStakeV1.level19.address,
                amount
            )).wait();

            let stakeOf = await simpleStakeV1.seigManager.stakeOf(
                level19Address,
                simpleStakeV1.user1.address
            )
            console.log('previously staked amount', ethers.utils.formatUnits(userLevel19StakedAmount, 27), 'WTON')
            console.log('add staked amount', ethers.utils.formatUnits(amount, 27), 'WTON')
            console.log('user1\'s stakeOf', ethers.utils.formatUnits(stakeOf, 27), 'WTON')

            // expect(stakeOf).to.be.eq(userLevel19StakedAmount.add(amount));

            userLevel19StakedAmount = stakeOf;
        });

        it('unstake', async () => {
            let amount = ethers.utils.parseEther("200000000000");
            (await simpleStakeV1.depositManager.connect(simpleStakeV1.user1).requestWithdrawal(
                simpleStakeV1.level19.address,
                amount
            )).wait();

            let stakeOf = await simpleStakeV1.seigManager.stakeOf(
                level19Address,
                simpleStakeV1.user1.address
            )

            console.log('previously staked amount', ethers.utils.formatUnits(userLevel19StakedAmount, 27), 'WTON')
            console.log('unstaked amount', ethers.utils.formatUnits(amount, 27), 'WTON')
            console.log('user1\'s stakeOf', ethers.utils.formatUnits(stakeOf, 27), 'WTON')

        });

        it('pass blocks of withdrawal delay', async () => {
            await network.provider.send("hardhat_mine", ["0x16B77"]); // 93046 block
        });

        it('withdraw', async () => {
            let receiveTON = true;
            let balancePrev = await simpleStakeV1.ton.balanceOf(simpleStakeV1.user1.address);

            (await simpleStakeV1.depositManager.connect(simpleStakeV1.user1).processRequest(
                simpleStakeV1.level19.address,
                receiveTON
            )).wait();

            let balanceAfter = await simpleStakeV1.ton.balanceOf(simpleStakeV1.user1.address);

            console.log('user1\'s TON balance before', ethers.utils.formatUnits(balancePrev, 18), 'TON')
            console.log('user1\'s TON balance now', ethers.utils.formatUnits(balanceAfter, 18), 'TON')
        });

        it('totalStakedAmount', async () => {
            totalStakedAmount  = await simpleStakeV1.tot["totalSupply()"]();
            console.log('totalStakedAmount', ethers.utils.formatUnits(totalStakedAmount, 27), 'WTON')
        });

        it('update Seigniroage : don\'t change total staked amount after pause.', async () => {
            await simpleStakeV1.level19.updateSeigniorage();
            let totalStakedAmount = await simpleStakeV1.tot.totalSupply();
            console.log('totalStakedAmount', ethers.utils.formatUnits(totalStakedAmount, 27), 'WTON')
        });

        it('unpaused', async () => {
            let tx = await simpleStakeV1.seigManager.connect(simpleStakeV1.tonAdmin).unpause();
        });

        it('update Seigniroage : change total staked amount after pause.', async () => {
            await simpleStakeV1.level19.updateSeigniorage();
            let totalStakedAmount = await simpleStakeV1.tot.totalSupply();
            console.log('totalStakedAmount', ethers.utils.formatUnits(totalStakedAmount, 27), 'WTON')
        });

    })
})
