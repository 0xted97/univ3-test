import { ethers } from "hardhat";
import hre from 'hardhat'


async function main() {
  const [signer] = await ethers.getSigners();
  const networkName = hre.network.name

  const depositAmount = ethers.parseEther("0.00000005");
  const lqAddresses = {
    goerli: "0x1bd3E7C01D16d1C7C0019Cf015BD59cAf02D7A3E",
    arbGoerli: "0x9d34940295A8313a6Af7E2c3Ee9c76bf8fB39E0B",
  } as any;

  const liquidityProvider = await ethers.getContractAt("LiquidityProvider", lqAddresses[networkName]);

  const txDeposit = await liquidityProvider.deposit({
    value: depositAmount,
  });
  console.log("🚀 ~ Deposit hash", txDeposit.hash);
  await txDeposit.wait();

  const txWithdrawAll = await liquidityProvider.emergencyWithdraw();
  console.log("🚀 ~ Withdraw all hash", txWithdrawAll.hash);
  await txWithdrawAll.wait();

  
  // const tokenId = 10000;
  // const txWithdraw = await liquidityProvider.withdrawLP(tokenId);
  // console.log("🚀 ~ Withdraw hash", txWithdraw.hash)
  // await txWithdraw.wait();

  // Read of Position
  // const position = await liquidityProvider.deposits(tokenId);




}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
