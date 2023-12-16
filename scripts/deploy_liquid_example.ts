// import { ethers } from "hardhat";
// import hre from 'hardhat'

// async function main() {
//   const networkName = hre.network.name
//   const SHIB = "0x6b72D5759D1A15C6A38ce62d52020d725Dd6Ccf5"
//   const GMX = "0x710c00D9955e4E6016541B3BA669E4701468C4f1"
//   const shib = await ethers.getContractAt("IERC20", SHIB)
//   const gmx = await ethers.getContractAt("IERC20", GMX)

//   const liquidityProvider = await ethers.deployContract("LiquidityExamples");
//   await liquidityProvider.waitForDeployment();

//   // const liquidityProvider = await ethers.getContractAt("LiquidityExamples", "0x6De9319860155643Fc2DAa0d5234EB956582bd6c");
//   console.log("🚀 ~ file: deploy_liquid_example.ts:15 ~ main ~ liquidityProvider:",  await liquidityProvider.pool())


//   const liquidAddress = await liquidityProvider.getAddress()
//   console.log("🚀 ~ file: deploy_liquid_example.ts:15 ~ main ~ liquidAddress:", liquidAddress)


//   const txT1 = await shib.approve(liquidAddress, ethers.parseEther("10000"));
//   await txT1.wait()
//   console.log("🚀 ~ file: deploy_liquid_example.ts:25 ~ main ~ txT1:", txT1.hash)

//   const txT2 = await gmx.approve(liquidAddress, ethers.parseEther("10000"));
//   await txT2.wait()
//   console.log("🚀 ~ file: deploy_liquid_example.ts:27 ~ main ~ txT2:", txT2.hash)

//   const tx = await liquidityProvider.mintNewPosition( ethers.parseEther("5"),  ethers.parseEther("5"))
//   console.log("🚀 ~ file: deploy_liquid_example.ts:24 ~ main ~ tx:", tx.hash)


// }

// // We recommend this pattern to be able to use async/await everywhere
// // and properly handle errors.
// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });
