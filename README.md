# Addresses
## Arb Goerli


## Goerli
- GMX token: 0xCf95d9505aa6302C9505f4deE16dA26829255795
- ETH/GMX Pool: 0xb4fbf271143f4fbf7b91a5ded31805e42b2208d6
- NFT Position Manager: 0xC36442b4a4522E871399CD717aBDD847Ab11FE88
- WETH: 0xb4fbf271143f4fbf7b91a5ded31805e42b2208d6

# Notice important
The project currently only operates on the Goerli network. According to the Uniswapv3 documentation (https://docs.uniswap.org/contracts/v3/reference/deployments) and various explorer pages, it appears that the contracts have not been deployed on the **Arbitrum** network. 


# Run
## Deploy
- yarn install
- npx hardhat run scripts/deploy.ts --network goerli 

## Interact
- Copy & paste address
- npx hardhat run scripts/interact.ts --network goerli 


# Question?
- Why does the test provide the Balancer Vault? I don't understand its role in this case.





