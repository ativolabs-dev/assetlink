// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title AL Reward Token Token Contract (UUPS Upgradable)
 * @dev A gas-optimized, secure, and upgradable ERC-20 token for loyalty points, allowing minting, burning, and pausing functionality.
 */
contract ALRToken is
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable
{
    // Role for minting authority
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Maximum supply of AL Reward Token
    uint256 public maxSupply;

    // Maximum array length for batch operations
    uint256 public constant MAX_BATCH_LENGTH = 100;

    // Event for minting AL Reward Token
    event PointsMinted(address indexed user, uint256 amount);

    // Event for burning AL Reward Token
    event PointsBurned(address indexed user, uint256 amount);

    // Aggregate event for batch operations
    event BatchOperationSummary(uint256 totalMinted, uint256 totalBurned);

    // Event for activity-based rewards
    event RewardGranted(address indexed user, uint256 amount, string activity);

    /**
     * @dev Initializer to replace constructor for upgradable contracts.
     * @param _name Token name.
     * @param _symbol Token symbol.
     * @param _maxSupply Maximum supply of AL Reward Token.
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply
    ) external initializer {
        require(_maxSupply > 0, "Max supply must be greater than zero");
        maxSupply = _maxSupply;

        // Initialize ERC20
        __ERC20_init(_name, _symbol);
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        __AccessControl_init();

        // Grant owner the default admin role and minter role
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    /**
     * @dev Authorize contract upgrades. Restricted to the owner.
     * @param newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Mint AL Reward Token to a specific address.
     * @param to Address to receive the minted AL Reward Token.
     * @param amount Amount of AL Reward Token to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(totalSupply() + amount <= maxSupply, "Minting exceeds max supply");
        require(to != address(0), "Cannot mint to zero address");
        _mint(to, amount);
        emit PointsMinted(to, amount);
    }

    /**
     * @dev Burn AL Reward Token from a specific address.
     * @param amount Amount of AL Reward Token to burn.
     */
    function burn(uint256 amount) public override whenNotPaused nonReentrant {
        require(amount > 0, "Burn amount must be greater than zero");
        super.burn(amount); // Call the parent implementation
        emit PointsBurned(msg.sender, amount);
    }

    /**
     * @dev Mint AL Reward Token to multiple addresses in one transaction.
     * @param recipients Array of addresses to receive the minted AL Reward Token.
     * @param amounts Array of amounts to mint for each address.
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(recipients.length == amounts.length, "Recipients and amounts length mismatch");
        require(recipients.length <= MAX_BATCH_LENGTH, "Batch length exceeds limit");

        uint256 totalMinted = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Cannot mint to zero address");
            require(totalSupply() + amounts[i] <= maxSupply, "Minting exceeds max supply");

            _mint(recipients[i], amounts[i]);
            emit PointsMinted(recipients[i], amounts[i]);
            totalMinted += amounts[i];
        }

        emit BatchOperationSummary(totalMinted, 0);
    }

    /**
     * @dev Burn AL Reward Token from multiple addresses in one transaction.
     * @param amounts Array of amounts to burn for each address.
     */
    function batchBurn(uint256[] calldata amounts) external whenNotPaused nonReentrant {
        require(amounts.length <= MAX_BATCH_LENGTH, "Batch length exceeds limit");

        uint256 totalBurned = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(amounts[i] > 0, "Burn amount must be greater than zero");

            _burn(msg.sender, amounts[i]);
            emit PointsBurned(msg.sender, amounts[i]);
            totalBurned += amounts[i];
        }

        emit BatchOperationSummary(0, totalBurned);
    }

    /**
     * @dev Pause the contract to prevent minting and burning.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract to resume operations.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Override transfer functions to respect paused state.
     * @param sender Address sending the tokens.
     * @param recipient Address receiving the tokens.
     * @param amount Amount of tokens being transferred.
     */
    function _beforeTokenTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) whenNotPaused {
        super._beforeTokenTransfer(sender, recipient, amount);
    }

    /**
     * @dev Reward a user with AL Reward Token based on an activity.
     * @param user Address of the user to reward.
     * @param amount Amount of AL Reward Token to reward.
     * @param activity Description of the activity for which the reward is given.
     */
    function reward(
        address user,
        uint256 amount,
        string calldata activity
    ) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(user != address(0), "Cannot reward to zero address");
        require(amount > 0, "Reward amount must be greater than zero");
        require(totalSupply() + amount <= maxSupply, "Reward exceeds max supply");

        _mint(user, amount);

        emit PointsMinted(user, amount);
        emit RewardGranted(user, amount, activity);
    }

    /**
    * @dev Placeholder for future token locking or vesting mechanisms.
    * State mutability is not restricted to 'view' because this function is intended to modify state in the future.
    */
    function lockTokens(address account, uint256 amount) external onlyOwner {
        require(account != address(0), "Cannot lock tokens for zero address");
        require(amount > 0, "Lock amount must be greater than zero");
        // Future implementation for locking tokens.
    }
}
