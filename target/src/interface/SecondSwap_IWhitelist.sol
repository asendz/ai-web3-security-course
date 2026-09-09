// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Whitelist Interface
 * @author darel
 * @notice Defines the interface for whitelist validation in private sales
 * @dev Minimal interface for checking if addresses are whitelisted
 */
interface IWhitelist {
    /**
     * @notice Validates if an address is whitelisted
     * @dev Should return true if the address is allowed to participate
     * @param _userAddress The address to check whitelist status
     * @return bool True if address is whitelisted, false otherwise
     */
    function validateAddress(address _userAddress) external view returns (bool);
}
