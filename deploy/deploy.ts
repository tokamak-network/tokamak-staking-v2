import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

import { SeigManagerV2Proxy } from '../../typechain-types/contracts/SeigManagerV2Proxy'
import { SeigManagerV2 } from '../../typechain-types/contracts/SeigManagerV2.sol'
import { Layer2ManagerProxy } from '../../typechain-types/contracts/Layer2ManagerProxy'
import { Layer2Manager } from '../../typechain-types/contracts/Layer2Manager.sol'
import { StakingLayer2Proxy } from '../../typechain-types/contracts/StakingLayer2Proxy'
import { StakingLayer2 } from '../../typechain-types/contracts/StakingLayer2.sol'

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;

    const deploySigner = await hre.ethers.getSigner(deployer);

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
        SeigManagerV2LogicDeployment.address
    )) as SeigManagerV2;

    const upgradeToTx_seigManagerV2Proxy = await seigManagerV2Proxy.connect(deploySigner).upgradeTo(SeigManagerV2LogicDeployment.address);
    await upgradeToTx_seigManagerV2Proxy.wait();

    //==== Layer2Manager =================================

    const Layer2ManagerLogicDeployment = await deploy("Layer2Manager", {
        from: deployer,
        args: [],
        log: true,
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
        Layer2ManagerLogicDeployment.address
    )) as Layer2Manager;

    const upgradeToTx_layer2Manager = await layer2ManagerProxy.connect(deploySigner).upgradeTo(Layer2ManagerLogicDeployment.address);
    await upgradeToTx_layer2Manager.wait();

    //==== StakingLayer2 =================================

    const StakingLayer2LogicDeployment = await deploy("StakingLayer2", {
        from: deployer,
        args: [],
        log: true,
    });

    const StakingLayer2ProxyDeployment = await deploy("StakingLayer2Proxy", {
        from: deployer,
        args: [],
        log: true,
    });

    const stakingLayer2Proxy = (await hre.ethers.getContractAt(
        StakingLayer2ProxyDeployment.abi,
        StakingLayer2ProxyDeployment.address
    )) as StakingLayer2Proxy;

    const stakingLayer2  = (await hre.ethers.getContractAt(
        StakingLayer2LogicDeployment.abi,
        StakingLayer2LogicDeployment.address
    )) as StakingLayer2;

    const upgradeToTx_stakingLayer2 = await stakingLayer2Proxy.connect(deploySigner).upgradeTo(StakingLayer2LogicDeployment.address);
    await upgradeToTx_stakingLayer2.wait();

    // initialize
    // ...

    if (hre.network.name != "hardhat") {
        await hre.run("etherscan-verify", {
        network: hre.network.name,
        });
    }
};

export default deploy;