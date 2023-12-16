import { ethers } from "hardhat";
import hre from 'hardhat'


async function main() {
  const [signer] = await ethers.getSigners();
  const networkName = hre.network.name

  const depositAmount = ethers.parseEther("0.00002");
  const lqAddresses = {
    goerli: "0xCf2a9CB429A386F252861580E54217b53e0df66d",
    arbGoerli: "0x9d34940295A8313a6Af7E2c3Ee9c76bf8fB39E0B",
  } as any;

  const liquidityProvider = await ethers.getContractAt("LiquidityProvider", lqAddresses[networkName]);

  console.log("🚀 ~ file: deploy.ts:31 ~ main ~ liquidityProvider.pool():", await liquidityProvider.uniswapPool())


  // const withdrawETH = await liquidityProvider.withdrawETH(signer.address);
  // console.log("🚀 ~ file: interact.ts:18 ~ main ~ withdrawETH:", withdrawETH.hash)

  const tx = await liquidityProvider.deposit({
    value: depositAmount,
  });
  console.log("🚀 ~ file: interact.ts:23 ~ main ~ tx:", tx.hash)

  // const tx = await liquidityProvider.withdraw(89062);
  // console.log("🚀 ~ file: interact.ts:23 ~ main ~ tx:", tx.hash)


  // Read of Position
  const tokenId = 1000;
  const position = await liquidityProvider.deposits(tokenId);
  console.log("🚀 ~ file: interact.ts:35 ~ main ~ position:", position)

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
