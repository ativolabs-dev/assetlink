// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing the ERC20 interface
interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title SKL Staking Contract
 * @dev This contract allows SKL holders to stake their tokens and earn ASET rewards at an APR of 30%.
 */
contract SKLStaking {
    // Address of the SKL token contract
    IERC20 public sklToken;

    // Address of the ASET token contract
    IERC20 public asetToken;

    // APR (Annual Percentage Rate) for staking (30% => 30 * 10^16)
    uint256 public constant APR = 30 * 10**16; // Represented as a fixed-point number with 2 decimal places

    // Staking period in seconds (default: 6 months)
    uint256 public constant STAKING_PERIOD = 180 days;

    // Data structure to track staking information
    struct StakeInfo {
        uint256 amount; // Amount of SKL tokens staked
        uint256 startTime; // Timestamp when the stake was made
        bool active; // Whether the stake is active
    }

    // Mapping from user address to their staking information
    mapping(address => StakeInfo) public stakes;

    // Owner of the contract
    address public owner;

    /**
     * @dev Constructor initializes the SKL and ASET token contract addresses.
     * @param _sklToken Address of the SKL token contract
     * @param _asetToken Address of the ASET token contract
     */
    constructor(address _sklToken, address _asetToken) {
        require(_sklToken != address(0), "Invalid SKL token address");
        require(_asetToken != address(0), "Invalid ASET token address");

        sklToken = IERC20(_sklToken);
        asetToken = IERC20(_asetToken);
        owner = msg.sender;
    }

    /**
     * @dev Modifier to restrict access to the contract owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    /**
     * @dev Stake SKL tokens into the contract.
     * @param amount The amount of SKL tokens to stake.
     */
    function stake(uint256 amount) external {
        require(amount > 0, "Stake amount must be greater than zero");
        require(
            sklToken.transferFrom(msg.sender, address(this), amount),
            "SKL transfer failed"
        );

        StakeInfo storage userStake = stakes[msg.sender];

        require(!userStake.active, "Already staked");

        userStake.amount = amount;
        userStake.startTime = block.timestamp;
        userStake.active = true;
    }

    /**
     * @dev Check the staking status of the caller.
     * @return amount Staked amount.
     * @return startTime Staking start timestamp.
     * @return active Whether the stake is active.
     */
    function getStakeInfo()
        external
        view
        returns (
            uint256 amount,
            uint256 startTime,
            bool active
        )
    {
        StakeInfo storage userStake = stakes[msg.sender];
        return (userStake.amount, userStake.startTime, userStake.active);
    }

    /**
     * @dev Calculate the reward accrued for the caller.
     * @return reward Amount of ASET tokens earned as rewards.
     */
    function calculateReward() external view returns (uint256 reward) {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.active, "No active stake");

        uint256 stakingDuration = block.timestamp - userStake.startTime;
        if (stakingDuration > STAKING_PERIOD) {
            stakingDuration = STAKING_PERIOD; // Cap rewards at the staking period
        }

        reward = (userStake.amount * APR * stakingDuration) / (365 days * 100 * 10**16);
    }

    /**
     * @dev Withdraw staked SKL tokens and claim rewards.
     */
    function withdraw() external {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.active, "No active stake");
        require(
            block.timestamp >= userStake.startTime + STAKING_PERIOD,
            "Staking period not yet complete"
        );

        uint256 reward = (userStake.amount * APR * STAKING_PERIOD) / (365 days * 100 * 10**16);

        require(
            asetToken.transfer(msg.sender, reward),
            "ASET transfer failed"
        );
        require(
            sklToken.transfer(msg.sender, userStake.amount),
            "SKL transfer failed"
        );

        delete stakes[msg.sender];
    }

    /**
     * @dev Emergency function to withdraw staked SKL tokens without rewards (penalty).
     */
    function emergencyWithdraw() external {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.active, "No active stake");

        require(
            sklToken.transfer(msg.sender, userStake.amount),
            "SKL transfer failed"
        );

        delete stakes[msg.sender];
    }

    /**
     * @dev Update the address of the ASET token contract.
     * @param _newAsetToken Address of the new ASET token contract.
     */
    function updateAsetToken(address _newAsetToken) external onlyOwner {
        require(_newAsetToken != address(0), "Invalid ASET token address");
        asetToken = IERC20(_newAsetToken);
    }
}
