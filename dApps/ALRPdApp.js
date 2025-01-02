const { ethers } = require("ethers");
require("dotenv").config();

// Configuration
const ABI = [];
const SKALE_RPC_URL = process.env.SKALE_RPC_URL; 
const PRIVATE_KEY = process.env.PRIVATE_KEY; 
const CONTRACT_ADDRESS = "0xA867cDA4A0BCee5C79599bf867903Cc75Fa10DFE";

// Set up provider and signer
const provider = new ethers.JsonRpcProvider(SKALE_RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Connect to the contract
const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, wallet);

// Reward Functionality Test
async function testReward() {
  try {
    const recipient = "0xdF1f9f0634247d05cbcbE8659179fd7Da6655416"; // Replace with the recipient's address
    const amount = ethers.parseEther("1"); // 1 tokens
    const description = "daily platform login";

    console.log("Sending reward...");

    const tx = await contract.reward(recipient, amount, description);
    console.log("Transaction sent: ", tx.hash);

    const receipt = await tx.wait();
    console.log("Transaction confirmed: ", receipt.hash); // Correct property for hash
    console.log("Block Number: ", receipt.blockNumber); // Optional log for debugging
    console.log("Gas Used: ", receipt.gasUsed.toString()); // Optional log for gas used

    } catch (error) {
    console.error("Error while testing reward: ", error);
  }
}

testReward();
