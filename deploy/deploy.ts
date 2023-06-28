import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

import { LibOperator } from '../typechain-types/contracts/libraries/LibOperator'
import { LibOptimism } from '../typechain-types/contracts/libraries/LibOptimism'
import { LibFastWithdraw } from '../typechain-types/contracts/libraries/LibFastWithdraw.sol'

import { SeigManagerV2Proxy } from '../typechain-types/contracts/proxy/SeigManagerV2Proxy'
import { SeigManagerV2 } from '../typechain-types/contracts/SeigManagerV2.sol'
import { Layer2ManagerProxy } from '../typechain-types/contracts/proxy/Layer2ManagerProxy'
import { Layer2Manager } from '../typechain-types/contracts/Layer2Manager.sol'

import { OptimismSequencerProxy } from '../typechain-types/contracts/proxy/OptimismSequencerProxy'
import { OptimismSequencer } from '../typechain-types/contracts/OptimismSequencer'
import { CandidateProxy } from '../typechain-types/contracts/proxy/CandidateProxy'
import { Candidate } from '../typechain-types/contracts/Candidate'
import { FwReceiptProxy } from '../typechain-types/contracts/proxy/FwReceiptProxy'
import { FwReceipt } from '../typechain-types/contracts/FwReceipt.sol'

const deployTonStakingV2: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;

    const deploySigner = await hre.ethers.getSigner(deployer);

    // mainnet
    let seigManagerInfo_mainnet = {
        ton: "0x2be5e8c109e2197D077D13A82dAead6a9b3433C5",
        wton: "0xc4A11aaf6ea915Ed7Ac194161d2fC9384F15bff2",
        tot: "0x6FC20Ca22E67aAb397Adb977F092245525f7AeEf",
        seigManagerV1: "0x710936500aC59e8551331871Cbad3D33d5e0D909",
        dao: "0x2520CD65BAa2cEEe9E6Ad6EBD3F45490C42dd303",
        powerTon: "0x970298189050aBd4dc4F119ccae14ee145ad9371",
        seigPerBlock: hre.ethers.BigNumber.from("3920000000000000000"),
        minimumBlocksForUpdateSeig: 2400,

    }

    let layer2ManagerInfo_mainnet  = {
        minimumDepositForSequencer: hre.ethers.utils.parseEther("100"),
        minimumDepositForCandidate: hre.ethers.utils.parseEther("200"),
        delayBlocksForWithdraw: 93046,
    }

    // goerli
    let seigManagerInfo_goerli = {
        ton: "0x68c1F9620aeC7F2913430aD6daC1bb16D8444F00",
        wton: "0xe86fCf5213C785AcF9a8BFfEeDEfA9a2199f7Da6",
        tot: "0x8526cF3F0b50A39c7F1320c5aa43dA45a14d1635",
        seigManagerV1: "0x446ece59ef429B774Ff116432bbB123f1915D9E3",
        dao: "0xb0B9c6076D46E333A8314ccC242992A625931C99",
        powerTon: "0x031B5b13Df847eB10c14451EB2a354EfEE23Cc94",
        seigPerBlock: hre.ethers.BigNumber.from("3920000000000000000"),
        minimumBlocksForUpdateSeig: 2400,

    }

    let layer2ManagerInfo_goerli  = {
        minimumDepositForSequencer: hre.ethers.utils.parseEther("100"),
        minimumDepositForCandidate: hre.ethers.utils.parseEther("200"),
        delayBlocksForWithdraw: 93046,
    }

    let seigManagerInfo = seigManagerInfo_mainnet;
    let layer2ManagerInfo = layer2ManagerInfo_mainnet;

    if (hre.network.name == 'goerli') {
        seigManagerInfo = seigManagerInfo_goerli;
        layer2ManagerInfo = layer2ManagerInfo_goerli;
    }

    //==== libraries =================================
    const LibOptimismDeployment = await deploy("LibOptimism", {
        from: deployer,
        contract: "contracts/libraries/LibOptimism.sol:LibOptimism",
        log: true
    })

    const LibOperatorDeployment = await deploy("LibOperator", {
        from: deployer,
        contract: "contracts/libraries/LibOperator.sol:LibOperator",
        log: true
    })

    const LibFastWithdrawDeployment = await deploy("LibFastWithdraw", {
        from: deployer,
        contract: "contracts/libraries/LibFastWithdraw.sol:LibFastWithdraw",
        log: true
    })

    //==== SeigManagerV2 =================================

    const SeigManagerV2LogicDeployment = await deploy("SeigManagerV2", {
        from: deployer,
        args: [],
        log: true,
    });

    const SeigManagerV2ProxyDeployment = await deploy("SeigManagerV2Proxy", {
        from: deployer,
        args: [],
        log: true,
    });

    const seigManagerV2Proxy = (await hre.ethers.getContractAt(
        SeigManagerV2ProxyDeployment.abi,
        SeigManagerV2ProxyDeployment.address
    )) as SeigManagerV2Proxy;

    const seigManagerV2  = (await hre.ethers.getContractAt(
        SeigManagerV2LogicDeployment.abi,
        SeigManagerV2ProxyDeployment.address
    )) as SeigManagerV2;


    //==== Layer2Manager =================================

    const Layer2ManagerLogicDeployment = await deploy("Layer2Manager", {
        from: deployer,
        args: [],
        log: true,
        libraries: {
            LibOptimism: LibOptimismDeployment.address,
            LibOperator: LibOperatorDeployment.address
        }
    });

    const Layer2ManagerProxyDeployment = await deploy("Layer2ManagerProxy", {
        from: deployer,
        args: [],
        log: true,
    });

    const layer2ManagerProxy = (await hre.ethers.getContractAt(
        Layer2ManagerProxyDeployment.abi,
        Layer2ManagerProxyDeployment.address
    )) as Layer2ManagerProxy;

    const layer2Manager  = (await hre.ethers.getContractAt(
        Layer2ManagerLogicDeployment.abi,
        Layer2ManagerProxyDeployment.address
    )) as Layer2Manager;


    //==== OptimismSequencer =================================

    const OptimismSequencerLogicDeployment = await deploy("OptimismSequencer", {
        from: deployer,
        args: [],
        log: true,
        libraries: {
            LibOptimism: LibOptimismDeployment.address
        }
    });

    const OptimismSequencerProxyDeployment = await deploy("OptimismSequencerProxy", {
        from: deployer,
        args: [],
        log: true,
    });

    const optimismSequencerProxy = (await hre.ethers.getContractAt(
        OptimismSequencerProxyDeployment.abi,
        OptimismSequencerProxyDeployment.address
    )) as OptimismSequencerProxy;

    const optimismSequencer  = (await hre.ethers.getContractAt(
        OptimismSequencerLogicDeployment.abi,
        OptimismSequencerProxyDeployment.address
    )) as OptimismSequencer;


    //==== Candidate =================================

    const CandidateLogicDeployment = await deploy("Candidate", {
        from: deployer,
        args: [],
        log: true,
        libraries: {
            LibOperator: LibOperatorDeployment.address
        }
    });

    const CandidateProxyDeployment = await deploy("CandidateProxy", {
        from: deployer,
        args: [],
        log: true,
    });

    const candidateProxy = (await hre.ethers.getContractAt(
        CandidateProxyDeployment.abi,
        CandidateProxyDeployment.address
    )) as CandidateProxy;

    const candidate  = (await hre.ethers.getContractAt(
        CandidateLogicDeployment.abi,
        CandidateProxyDeployment.address
    )) as Candidate;

    //==== FwReceipt =================================

    const FwReceiptLogicDeployment = await deploy("FwReceipt", {
        from: deployer,
        args: [],
        log: true,
        libraries: {
            LibFastWithdraw: LibFastWithdrawDeployment.address
        }
    });

    const FwReceiptProxyDeployment = await deploy("FwReceiptProxy", {
        from: deployer,
        args: [],
        log: true,
    });

    const fwReceiptProxy = (await hre.ethers.getContractAt(
        FwReceiptProxyDeployment.abi,
        FwReceiptProxyDeployment.address
    )) as FwReceiptProxy;

    const fwReceipt  = (await hre.ethers.getContractAt(
        FwReceiptLogicDeployment.abi,
        FwReceiptProxyDeployment.address
    )) as FwReceipt;

        /*
    //==== initialize =================================

    await (await seigManagerV2Proxy.connect(deploySigner).initialize(
        seigManagerInfo.ton,
        seigManagerInfo.wton,
        seigManagerInfo.tot,
        [
            seigManagerInfo.seigManagerV1,
            layer2ManagerProxy.address,
            optimismSequencerProxy.address,
            candidateProxy.address
        ],
        seigManagerInfo.seigPerBlock,
        seigManagerInfo.minimumBlocksForUpdateSeig
    )).wait();


    await (await layer2ManagerProxy.connect(deploySigner).initialize(
        seigManagerInfo.ton,
        seigManagerV2Proxy.address,
        optimismSequencerProxy.address,
        candidateProxy.address,
        layer2ManagerInfo.minimumDepositForSequencer,
        layer2ManagerInfo.minimumDepositForCandidate,
        layer2ManagerInfo.delayBlocksForWithdraw
    )).wait();

    await (await optimismSequencerProxy.connect(deploySigner).initialize(
        seigManagerInfo.ton,
        seigManagerV2Proxy.address,
        layer2ManagerProxy.address,
        fwReceiptProxy.address
    )).wait();

    await (await candidateProxy.connect(deploySigner).initialize(
        seigManagerInfo.ton,
        seigManagerV2Proxy.address,
        layer2ManagerProxy.address,
        fwReceiptProxy.address
    )).wait();


    await (await fwReceiptProxy.connect(deploySigner).initialize(
        seigManagerInfo.ton,
        seigManagerV2.address,
        optimismSequencerProxy.address,
        candidateProxy.address
    )).wait();

    //==== upgradeTo =================================
    const upgradeToTx_seigManagerV2Proxy = await seigManagerV2Proxy.connect(deploySigner).upgradeTo(SeigManagerV2LogicDeployment.address);
    await upgradeToTx_seigManagerV2Proxy.wait();

    const upgradeToTx_layer2Manager = await layer2ManagerProxy.connect(deploySigner).upgradeTo(Layer2ManagerLogicDeployment.address);
    await upgradeToTx_layer2Manager.wait();
        */
    const upgradeToTx_optimism = await optimismSequencerProxy.connect(deploySigner).upgradeTo(OptimismSequencerLogicDeployment.address);
    await upgradeToTx_optimism.wait();


    const upgradeToTx_candiate = await candidateProxy.connect(deploySigner).upgradeTo(CandidateLogicDeployment.address);
    await upgradeToTx_candiate.wait();
        /*
    const upgradeToTx_fwReceipt = await fwReceiptProxy.connect(deploySigner).upgradeTo(FwReceiptLogicDeployment.address);
    await upgradeToTx_fwReceipt.wait();


    //==== setLastSeigBlock =================================

    let block = await hre.ethers.provider.getBlock('latest')
    await (await seigManagerV2.connect(deploySigner).setLastSeigBlock(
        block.number + 2
        )).wait();

    //==== setAddress (DAO, sTosHolder(powerTON)) =================================

    await (await seigManagerV2.connect(deploySigner).setAddress(
        seigManagerInfo.dao,
        seigManagerInfo.powerTon
        )).wait();
        */

    //==== verify =================================

    if (hre.network.name != "hardhat") {

        await hre.run("etherscan-verify", {
            network: hre.network.name
        });
    }

};

export default deployTonStakingV2;