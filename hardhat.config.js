require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.20", // For OpenZeppelin & Chainlink
      },
      {
        version: "0.8.24", // For your custom contracts
      },
      {
        version: "0.8.21", // If needed
      },
    ],
  },
  paths: {
    sources: "./.contracts", // 
    sources: "./contracts", // 
  },
  networks: {
    baseSepolia: {
      url: process.env.BASE_SEPOLIA_RPC,
      accounts: [process.env.PRIVATE_KEY],
    },
    arbSepolia: {
      url: process.env.ARB_SEPOLIA_RPC,
      accounts: [process.env.PRIVATE_KEY],
    },
    skaleTestnet: {
      url: process.env.SKALE_RPC_URL, // Skale testnet RPC URL
      accounts: [process.env.PRIVATE_KEY],
      chainId: parseInt(process.env.SKALE_CHAIN_ID, 10), // Chain ID for Skale
    },
  },
  etherscan: {
    apiKeyETH: process.env.ETHERSCAN_API_KEY, 
    apiKeyBASE: process.env.BASESCAN_API_KEY, 
    apiKeyARB: process.env.ARBISCAN_API_KEY, 
  },
};
