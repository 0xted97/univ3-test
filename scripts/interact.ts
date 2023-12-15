import { ethers } from "hardhat";
import hre from 'hardhat'


async function main() {
  const [signer] = await ethers.getSigners();
  const networkName = hre.network.name

  const depositAmount = ethers.parseEther("0.0004");
  const lqAddresses = {
    goerli: "0x7364319681c24b0D96e5fd6F5B41a614Bc555F4B",
    arbGoerli: "0x9d34940295A8313a6Af7E2c3Ee9c76bf8fB39E0B",
  } as any;

  const liquidityProvider = await ethers.getContractAt("LiquidityProvider", lqAddresses[networkName]);

  // const withdrawETH = await liquidityProvider.withdrawETH(signer.address);
  // console.log("🚀 ~ file: interact.ts:18 ~ main ~ withdrawETH:", withdrawETH.hash)

  const tx = await liquidityProvider.deposit({
    value: depositAmount,
    // gasLimit: 50000,
    // gasPrice: ethers.parseUnits("100", "gwei"),
  });
  console.log("🚀 ~ file: interact.ts:23 ~ main ~ tx:", tx.hash)


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
