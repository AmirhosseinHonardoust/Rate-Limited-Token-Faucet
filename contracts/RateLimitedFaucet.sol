// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Rate-Limited Token Faucet
/// @author amir
/// @notice Simple ERC20 faucet with per-address cooldown.
/// @dev Designed to be easy to read and audit – no external dependencies.
contract RateLimitedFaucet {
    /// @dev Minimal ERC20 interface.
    interface IERC20 {
        function transfer(address to, uint256 amount) external returns (bool);
        function balanceOf(address account) external view returns (uint256);
        function decimals() external view returns (uint8);
    }

    /// @notice ERC20 token distributed by the faucet.
    IERC20 public immutable token;

    /// @notice Owner/admin address.
    address public owner;

    /// @notice Amount of tokens given per claim.
    uint256 public dripAmount;

    /// @notice Cooldown time in seconds between claims per address.
    uint256 public cooldown;

    /// @notice Timestamp of last claim per user.
    mapping(address => uint256) public lastClaimAt;

    /// @notice Emitted when someone successfully claims from the faucet.
    event Claimed(address indexed user, uint256 amount);

    /// @notice Emitted when drip amount is updated.
    event DripAmountUpdated(uint256 oldAmount, uint256 newAmount);

    /// @notice Emitted when cooldown is updated.
    event CooldownUpdated(uint256 oldCooldown, uint256 newCooldown);

    /// @notice Emitted when ownership is transferred.
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when tokens are withdrawn by owner.
    event TokensWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /// @param _token Address of the ERC20 token to distribute.
    /// @param _dripAmount Amount of tokens to send per claim.
    /// @param _cooldown Cooldown time in seconds between claims.
    constructor(
        address _token,
        uint256 _dripAmount,
        uint256 _cooldown
    ) {
        require(_token != address(0), "Token is zero");
        require(_dripAmount > 0, "Drip amount must be > 0");

        token = IERC20(_token);
        owner = msg.sender;
        dripAmount = _dripAmount;
        cooldown = _cooldown;
    }

    // ------------------------------------------------------------------------
    // User-facing logic
    // ------------------------------------------------------------------------

    /// @notice Claim faucet tokens if cooldown has passed.
    function claim() external {
        uint256 last = lastClaimAt[msg.sender];
        uint256 nowTs = block.timestamp;

        // Enforce cooldown if set (0 means no cooldown)
        if (cooldown > 0) {
            require(nowTs >= last + cooldown, "Cooldown not passed");
        }

        require(token.balanceOf(address(this)) >= dripAmount, "Faucet empty");

        lastClaimAt[msg.sender] = nowTs;

        bool ok = token.transfer(msg.sender, dripAmount);
        require(ok, "Token transfer failed");

        emit Claimed(msg.sender, dripAmount);
    }

    /// @notice View if an address can currently claim.
    function canClaim(address user) external view returns (bool) {
        if (cooldown == 0) {
            return token.balanceOf(address(this)) >= dripAmount;
        }
        uint256 last = lastClaimAt[user];
        return
            block.timestamp >= last + cooldown &&
            token.balanceOf(address(this)) >= dripAmount;
    }

    // ------------------------------------------------------------------------
    // Owner / admin logic
    // ------------------------------------------------------------------------

    /// @notice Update the drip amount.
    /// @param _newDripAmount New amount of tokens per claim.
    function setDripAmount(uint256 _newDripAmount) external onlyOwner {
        require(_newDripAmount > 0, "Drip amount must be > 0");
        uint256 old = dripAmount;
        dripAmount = _newDripAmount;
        emit DripAmountUpdated(old, _newDripAmount);
    }

    /// @notice Update the cooldown time.
    /// @param _newCooldown New cooldown in seconds (0 disables cooldown).
    function setCooldown(uint256 _newCooldown) external onlyOwner {
        uint256 old = cooldown;
        cooldown = _newCooldown;
        emit CooldownUpdated(old, _newCooldown);
    }

    /// @notice Transfer ownership of the faucet.
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner is zero");
        address old = owner;
        owner = _newOwner;
        emit OwnershipTransferred(old, _newOwner);
    }

    /// @notice Withdraw tokens from the faucet (e.g. when shutting down).
    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Recipient is zero");
        bool ok = token.transfer(to, amount);
        require(ok, "Token transfer failed");
        emit TokensWithdrawn(to, amount);
    }

    // ------------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------------

    /// @notice Return faucet's current token balance.
    function faucetBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
