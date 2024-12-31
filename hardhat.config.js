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
    // If your .sol files are in a folder named .contracts/
    sources: "./.contracts",
  },
  networks: {
    baseSepolia: {
      url: process.env.BASE_SEPOLIA_RPC,
      accounts: [process.env.PRIVATE_KEY],

      // If you get "replacement transaction underpriced", consider setting:
      // gasPrice: 1500000000, // 1.5 Gwei
    },
    arbSepolia: {
      url: process.env.ARB_SEPOLIA_RPC,
      accounts: [process.env.PRIVATE_KEY],
      // Optional gas configuration
      // gasPrice: 1500000000, // 1.5 Gwei
    },
  },
  etherscan: {
    apiKey: process.env.BASESCAN_API_KEY,
  },
};
