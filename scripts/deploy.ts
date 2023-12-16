import { ethers } from "hardhat";
import hre from 'hardhat'

async function main() {
  const networkName = hre.network.name
  const addresses = {
    goerli: [
      "0xBA12222222228d8Ba445958a75a0704d566BF2C8", // vault
      // "", // Pool ETH-LINK
      "0xE592427A0AEce92De3Edee1F18E0157C05861564", // Router
      // "0xC36442b4a4522E871399CD717aBDD847Ab11FE88", // Position Manager
      "0xb4fbf271143f4fbf7b91a5ded31805e42b2208d6", // WETH
      "0xCf95d9505aa6302C9505f4deE16dA26829255795", // GMX
      "0x9Ce85ffE6DbBa9346db5cBB9b94980633CD07ed7", // Treasury
    ],
    arbGoerli: [
      "0xBA12222222228d8Ba445958a75a0704d566BF2C8", // vault
      "0xE592427A0AEce92De3Edee1F18E0157C05861564", // Router
      // "0xC36442b4a4522E871399CD717aBDD847Ab11FE88", // Position Manager
      "0xe39ab88f8a4777030a534146a9ca3b52bd5d43a3", // WETH
      "0xE19CCb48bcE8dBb8e9deD51D90FaF409314278E8", // GMX
      "0x9Ce85ffE6DbBa9346db5cBB9b94980633CD07ed7", // Treasury
    ],
  } as any;

  const  liquidityProvider = await ethers.deployContract("LiquidityProvider", addresses[networkName]);

  await liquidityProvider.waitForDeployment();
  console.log("🚀 ~ Contract Address:", await liquidityProvider.getAddress());
  console.log("🚀 ~  Liquidity Pool Address", await liquidityProvider.uniswapPool());

  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
