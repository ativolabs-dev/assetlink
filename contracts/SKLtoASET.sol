// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title SKL to ASET Staking Contract
 * @dev Enables SKL holders to stake tokens and earn ASET rewards at a fixed APR.
 */
contract SKLtoASET is ReentrancyGuard, Pausable, Initializable {
    // Immutable token addresses to save gas
    IERC20 public sklToken;
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
    mapping(address => StakeInfo[]) public stakes;

    // Owner of the contract
    address public owner;

    /**
     * @dev Events for transparency.
     */
    event Staked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event EmergencyWithdrawn(address indexed user, uint256 amount);
    event AsetTokenUpdated(address indexed oldAddress, address indexed newAddress);
    event ContractInitialized(address sklToken, address asetToken);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Constructor to initialize the contract.
     */
    function initialize(address _sklToken, address _asetToken) external initializer {
        require(_sklToken != address(0), "Invalid SKL token address");
        require(_asetToken != address(0), "Invalid ASET token address");

        sklToken = IERC20(_sklToken);
        asetToken = IERC20(_asetToken);
        owner = msg.sender;

        emit ContractInitialized(_sklToken, _asetToken);
    }

    /**
     * @dev Modifier to restrict access to the contract owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    /**
     * @dev Transfer ownership of the contract to a new address.
     * @param newOwner Address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Stake SKL tokens into the contract.
     * @param amount The amount of SKL tokens to stake.
     */
    function stake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Stake amount must be greater than zero");
        require(
            sklToken.transferFrom(msg.sender, address(this), amount),
            "SKL transfer failed"
        );

        stakes[msg.sender].push(StakeInfo({
            amount: amount,
            startTime: block.timestamp,
            active: true
        }));

        emit Staked(msg.sender, amount);
    }

    /**
     * @dev Check the staking status of the caller.
     */
    function getStakeInfo(uint256 index)
        external
        view
        returns (
            uint256 amount,
            uint256 startTime,
            bool active
        )
    {
        StakeInfo storage userStake = stakes[msg.sender][index];
        return (userStake.amount, userStake.startTime, userStake.active);
    }

    /**
     * @dev Calculate the reward accrued for a specific stake index.
     * @param index The index of the stake.
     * @return reward Amount of ASET tokens earned as rewards.
     */
    function calculateReward(uint256 index) external view returns (uint256 reward) {
        StakeInfo storage userStake = stakes[msg.sender][index];
        require(userStake.active, "No active stake");

        uint256 stakingDuration = block.timestamp - userStake.startTime;
        if (stakingDuration > STAKING_PERIOD) {
            stakingDuration = STAKING_PERIOD; // Cap rewards at the staking period
        }

        unchecked {
            reward = (userStake.amount * APR * stakingDuration) / (365 days * 100 * 10**16);
        }
    }

    /**
     * @dev Withdraw staked SKL tokens and claim rewards.
     * @param index The index of the stake to withdraw.
     */
    function withdraw(uint256 index) external nonReentrant whenNotPaused {
        StakeInfo storage userStake = stakes[msg.sender][index];
        require(userStake.active, "No active stake");
        require(
            block.timestamp >= userStake.startTime + STAKING_PERIOD,
            "Staking period not yet complete"
        );

        uint256 reward;
        unchecked {
            reward = (userStake.amount * APR * STAKING_PERIOD) / (365 days * 100 * 10**16);
        }

        require(
            asetToken.transfer(msg.sender, reward),
            "ASET reward transfer failed"
        );
        require(
            sklToken.transfer(msg.sender, userStake.amount),
            "SKL stake transfer failed"
        );

        userStake.active = false;
        removeInactiveStakes(msg.sender);

        emit Withdrawn(msg.sender, userStake.amount, reward);
    }

    /**
     * @dev Emergency function to withdraw staked SKL tokens without rewards (penalty).
     * Restricted to paused state.
     * @param index The index of the stake to withdraw.
     */
    function emergencyWithdraw(uint256 index) external nonReentrant whenPaused {
        StakeInfo storage userStake = stakes[msg.sender][index];
        require(userStake.active, "No active stake");

        require(
            sklToken.transfer(msg.sender, userStake.amount),
            "SKL transfer failed"
        );

        userStake.active = false;
        removeInactiveStakes(msg.sender);

        emit EmergencyWithdrawn(msg.sender, userStake.amount);
    }

    /**
     * @dev Update the address of the ASET token contract.
     * @param _newAsetToken Address of the new ASET token contract.
     */
    function updateAsetToken(address _newAsetToken) external onlyOwner {
        require(_newAsetToken != address(0), "Invalid ASET token address");

        address oldAddress = address(asetToken);
        asetToken = IERC20(_newAsetToken);

        emit AsetTokenUpdated(oldAddress, _newAsetToken);
    }

    /**
     * @dev Remove inactive stakes from the array.
     * @param user The address of the user.
     */
    function removeInactiveStakes(address user) internal {
        StakeInfo[] storage userStakes = stakes[user];
        for (uint256 i = 0; i < userStakes.length; ) {
            if (!userStakes[i].active) {
                userStakes[i] = userStakes[userStakes.length - 1];
                userStakes.pop();
            } else {
                i++;
            }
        }
    }

    /**
     * @dev Pause the contract in case of emergencies.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
