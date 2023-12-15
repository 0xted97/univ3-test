import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const DEFAULT_COMPILER_SETTINGS = {
  version: '0.7.6',
  settings: {
    evmVersion: 'istanbul',
    optimizer: {
      enabled: true,
      runs: 1_000_000,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

// 595e01874c6cbfb5dfea453c87351127facc504a4f7e87129e6820dbdb58f307
const config: HardhatUserConfig = {
  solidity: {
    compilers: [DEFAULT_COMPILER_SETTINGS],
  },
  networks: {
    goerli: {
      url: "https://rpc.ankr.com/eth_goerli",
      chainId: 5,
      accounts: ["bd1d69bc7e9e43c94bd81303e19f2997660d14713154d799fca6d9e7712ad720"]
    },
    arbGoerli: {
      url: "https://arbitrum-goerli.public.blastapi.io",
      chainId: 421613,
      accounts: ["bd1d69bc7e9e43c94bd81303e19f2997660d14713154d799fca6d9e7712ad720"]
    },
  }
};

export default config;
