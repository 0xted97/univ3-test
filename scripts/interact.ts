import { ethers } from "hardhat";
import hre from 'hardhat'


async function main() {
  const [signer] = await ethers.getSigners();
  const networkName = hre.network.name

  const depositAmount = ethers.parseEther("0.00000005");
  const lqAddresses = {
    goerli: "0x47c794210cF4DDF6Ea381faaf9c6924d3bE32f2A",
    arbGoerli: "0x9d34940295A8313a6Af7E2c3Ee9c76bf8fB39E0B",
  } as any;

  const liquidityProvider = await ethers.getContractAt("LiquidityProvider", lqAddresses[networkName]);

  console.log("🚀 ~ file: deploy.ts:31 ~ main ~ liquidityProvider.pool():", await liquidityProvider.uniswapPool())


  // const withdrawETH = await liquidityProvider.withdrawETH(signer.address);
  // console.log("🚀 ~ file: interact.ts:18 ~ main ~ withdrawETH:", withdrawETH.hash)

  // const tx = await liquidityProvider.deposit({
  //   value: depositAmount,
  // });
  // console.log("🚀 ~ file: interact.ts:23 ~ main ~ tx:", tx.hash)
  // await tx.wait();


  // Read of Position
  const tokenId = 89137;
  const position = await liquidityProvider.deposits(tokenId);
  console.log("🚀 ~ file: interact.ts:35 ~ main ~ position:", position)

  // const txWithdraw = await liquidityProvider.withdrawLP(tokenId);
  // console.log("🚀 ~ file: interact.ts:36 ~ main ~ txWithdraw:", txWithdraw.hash)
  // await txWithdraw.wait();
  
  const txWithdrawAll = await liquidityProvider.emergencyWithdraw();
  console.log("🚀 ~ file: interact.ts:38 ~ main ~ txWithdrawAll:", txWithdrawAll.hash)

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
