// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interface/SecondSwap_IWhitelist.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
 * @title SecondSwap Whitelist Contract
 * @notice Manages whitelist functionality for private sales
 * @dev Implements IWhitelist interface for address validation
 */
contract SecondSwap_Whitelist is IWhitelist {
    /// @notice Maximum number of addresses that can be whitelisted
    uint256 public maxWhitelist;

    /// @notice Current number of whitelisted addresses
    uint256 public totalWhitelist;

    /// @notice Address of the lot owner who can modify whitelist settings
    /// @dev Immutable value set at contract creation
    address public immutable lotOwner;

    /// @notice Mapping of addresses to their whitelist status
    /// @dev Maps user address to boolean indicating if they are whitelisted
    mapping(address => bool) public userSettings;

    /**
     * @notice Emitted when an address is whitelisted
     * @param _balanceWhitelist Current total number of whitelisted addresses
     * @param userAddress Address that was whitelisted
     */
    event WhitelistedAddress(uint256 _balanceWhitelist, address userAddress);

    /**
     * @notice Emitted when maximum whitelist capacity is changed
     * @param balanceWhitelist Current total number of whitelisted addresses
     * @param maxWhitelist New maximum whitelist capacity
     */
    event ChangeMaxWhitelist(uint256 balanceWhitelist, uint256 maxWhitelist);

    /**
     * @notice Initializes the whitelist contract
     * @dev Sets initial maximum capacity and lot owner
     * @param _maxWhitelist Maximum number of addresses that can be whitelisted
     * @param _lotOwner Address that can modify whitelist settings
     */
    constructor(uint256 _maxWhitelist, address _lotOwner) {
        maxWhitelist = _maxWhitelist;
        lotOwner = _lotOwner;
    }

    /**
     * @notice Adds caller's address to the whitelist
     * @dev Increments total whitelist count and sets user status
     * @custom:throws SS_Whitelist: Reached whitelist limit
     */
    function whitelistAddress() external {
        require(totalWhitelist < maxWhitelist, "SS_Whitelist: Reached whitelist limit"); //3.9. Improper comparison in whitelistAddress function
        require(userSettings[msg.sender] == false, "SS_Whitelist: User is whitelisted"); //3.9. Improper comparison in whitelistAddress function

        userSettings[msg.sender] = true;
        totalWhitelist++;
        emit WhitelistedAddress(totalWhitelist, msg.sender);
    }

    /**
     * @notice Checks if an address is whitelisted
     * @dev View function to validate whitelist status
     * @param _userAddress Address to check
     * @return bool True if address is whitelisted, false otherwise
     */
    function validateAddress(address _userAddress) external view returns (bool) {
        return userSettings[_userAddress];
    }

    /**
     * @notice Updates the maximum whitelist capacity
     * @dev Can only be called by lot owner
     * @param _maxWhitelist New maximum whitelist capacity
     * @custom:throws SS_Whitelist: not lot owner
     * @custom:throws SS_Whitelist: amount cannot be lesser that the current whitelist amount
     */
    function setMaxWhitelist(uint256 _maxWhitelist) external {
        require(msg.sender == lotOwner, "SS_Whitelist: not lot owner");
        require(
            _maxWhitelist > maxWhitelist,
            "SS_Whitelist: amount cannot be lesser that the current whitelist amount"
        );
        require(
            _maxWhitelist > totalWhitelist,
            "SS_Whitelist: amount cannot be lesser that the current whitelist amount"
        );

        maxWhitelist = _maxWhitelist;
        emit ChangeMaxWhitelist(totalWhitelist, maxWhitelist);
    }
}
