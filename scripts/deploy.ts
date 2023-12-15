import { ethers } from "hardhat";
import hre from 'hardhat'

async function main() {
  const networkName = hre.network.name
  const addresses = {
    goerli: [
      "0xBA12222222228d8Ba445958a75a0704d566BF2C8", // vault
      "0x83ced15eaf7254474cc21f68dd095e82ee9f4f0d", // Pool ETH-LINK
      "0xE592427A0AEce92De3Edee1F18E0157C05861564", // Router
      "0xC36442b4a4522E871399CD717aBDD847Ab11FE88", // Position Manager
      "0xb4fbf271143f4fbf7b91a5ded31805e42b2208d6", // WETH
      "0x326c977e6efc84e512bb9c30f76e30c160ed06fb", // LINK
    ],
    arbGoerli: [
      "0xBA12222222228d8Ba445958a75a0704d566BF2C8", // vault
      "0xCfb56243DD0d7401d67Aad0Cd84Ea99400de355c", // Pool
      "0xE592427A0AEce92De3Edee1F18E0157C05861564", // Router
      "0x622e4726a167799826d1e1d150b076a7725f5d81", // Position Manager
      "0xe39ab88f8a4777030a534146a9ca3b52bd5d43a3", // WETH
      "0xE19CCb48bcE8dBb8e9deD51D90FaF409314278E8", // GMX
    ],
  } as any;

  const  liquidityProvider = await ethers.deployContract("LiquidityProvider", addresses[networkName]);

  await liquidityProvider.waitForDeployment();
  console.log("🚀 ~ file: deploy.ts:18 ~ main ~ liquidityProvider:", await liquidityProvider.getAddress())

  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
