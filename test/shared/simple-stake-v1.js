const { ethers, network } = require("hardhat");
const { Signer, BigNumber } = require("ethers");

const DepositManager = require('../abi/DepositManager.json')
const SeigManager = require('../abi/SeigManager.json')
const TON_TOKEN = require('../abi/TON.json')
const WTON_TOKEN = require('../abi/WTON.json')
const AutoRefactorCoinage = require('../abi/AutoRefactorCoinage.json')
const Candidate = require('../abi/Candidate.json')

// mainnet
let wtonAddress = "0xc4A11aaf6ea915Ed7Ac194161d2fC9384F15bff2";
let tonAddress = "0x2be5e8c109e2197D077D13A82dAead6a9b3433C5";
let tonAdminAddress = "0xDD9f0cCc044B0781289Ee318e5971b0139602C26";
let seigManagerAddress = "0x710936500aC59e8551331871Cbad3D33d5e0D909";
let depositManagerAddress = "0x56E465f654393fa48f007Ed7346105c7195CEe43";

let user1Address = "0xbe1737365C1bB0b7F635daaA5FFc2f489c4E0123"
let level19Address = "0x42ccf0769e87cb2952634f607df1c7d62e0bbc52"
let totAddress = "0x6FC20Ca22E67aAb397Adb977F092245525f7AeEf"

class SimpleStakeV1Contracts {
    ton = null;
    wton = null;
    seigManager = null;
    depositManager = null;
    tonAdmin = null;
    user1 = null;
    tot = null;
    level19 = null;

    constructor() {
        this.ton = null;
        this.wton = null;
        this.seigManager = null;
        this.depositManager = null;
        this.tonAdmin = null;
        this.user1 = null;
        this.tot = null;
        this.level19 = null;
    }

    getTON() {
        return this.ton;
    }
    getWTON() {
        return this.wton;
    }
    getDepositManager() {
        return this.seigManager;
    }
    getSeigManager() {
        return this.depositManager;
    }

    getTot() {
        return this.tot;
    }
}

const getSimpleStakeV1Contracts = async function () {
    const [deployer, ] = await ethers.getSigners();
    console.log('deployer', deployer.address);
    let simpleStakeV1Contracts = new SimpleStakeV1Contracts();

    simpleStakeV1Contracts.ton = await ethers.getContractAt(TON_TOKEN.abi, tonAddress, deployer);
    simpleStakeV1Contracts.wton = await ethers.getContractAt(WTON_TOKEN.abi, wtonAddress, deployer);
    simpleStakeV1Contracts.seigManager = await ethers.getContractAt(SeigManager.abi, seigManagerAddress, deployer);
    simpleStakeV1Contracts.depositManager = await ethers.getContractAt(DepositManager.abi, depositManagerAddress, deployer);
    simpleStakeV1Contracts.tot = await ethers.getContractAt(AutoRefactorCoinage.abi, totAddress, deployer);
    simpleStakeV1Contracts.level19 = await ethers.getContractAt(Candidate.abi, level19Address, deployer);

    await ethers.provider.send("hardhat_impersonateAccount",[tonAdminAddress]);
    simpleStakeV1Contracts.tonAdmin = await ethers.getSigner(tonAdminAddress);

    await hre.ethers.provider.send("hardhat_setBalance", [
        tonAdminAddress,
        "0x8ac7230489e80000",
      ]);

    await ethers.provider.send("hardhat_impersonateAccount",[user1Address]);
    simpleStakeV1Contracts.user1 = await ethers.getSigner(user1Address);

    await hre.ethers.provider.send("hardhat_setBalance", [
        user1Address,
        "0x8ac7230489e80000",
      ]);

    return simpleStakeV1Contracts;
}

module.exports = { SimpleStakeV1Contracts, getSimpleStakeV1Contracts, level19Address }
