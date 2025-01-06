import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  networks: {
    base: {
      url: `https://base-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`${process.env.PRIVATE_KEY}`], 
    },
  }
};

export default config;
