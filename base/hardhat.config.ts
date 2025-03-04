import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const privateKey = process.env.PRIVATE_KEY?.trim();
if (!privateKey) {
  throw new Error("Invalid private key");
}

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  networks: {
    base: {
      url: `https://base-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [privateKey], 
    },
  }
};

export default config;
