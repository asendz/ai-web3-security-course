// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
 * @title Marketplace Settings Interface
 * @author darel
 * @notice Interface for accessing marketplace configuration and settings
 * @dev Defines required functions for marketplace setting implementations
 */
interface IMarketplaceSetting {
    /**
     * @notice Gets the current buyer fee percentage
     * @dev Fee is in basis points (100 = 1%)
     * @return Current buyer fee percentage
     */
    function buyerFee() external view returns (uint256);

    /**
     * @notice Gets the current seller fee percentage
     * @dev Fee is in basis points (100 = 1%)
     * @return Current seller fee percentage
     */
    function sellerFee() external view returns (uint256);

    /**
     * @notice Gets the current early unlisting penalty fee
     * @dev Fee is denominated in wei
     * @return Current penalty fee amount
     */
    function penaltyFee() external view returns (uint256);

    /**
     * @notice Gets the minimum duration a listing must remain active
     * @dev Duration is in seconds
     * @return Minimum listing duration
     */
    function minListingDuration() external view returns (uint256);

    /**
     * @notice Gets the referral reward percentage
     * @dev Percentage is in basis points (100 = 1%)
     * @return Current referral fee percentage
     */
    function referralFee() external view returns (uint256);

    /**
     * @notice Checks if the marketplace is currently frozen
     * @dev When true, most marketplace operations are disabled
     * @return Current freeze status
     */
    function isMarketplaceFreeze() external view returns (bool);

    /**
     * @notice Gets the address that collects marketplace fees
     * @dev This address receives all fees from marketplace operations
     * @return Address of the fee collector
     */
    function feeCollector() external view returns (address);

    /**
     * @notice Gets the marketplace admin address
     * @dev Admin has special privileges for marketplace management
     * @return Address of the marketplace admin
     */
    function s2Admin() external view returns (address);

    /**
     * @notice Gets the whitelist deployer contract address
     * @dev This contract handles creation of whitelist contracts for private sales
     * @return Address of the whitelist deployer contract
     */
    function whitelistDeployer() external view returns (address);

    /**
     * @notice Gets the vesting manager contract address
     * @dev This contract handles vesting operations and settings
     * @return Address of the vesting manager contract
     */
    function vestingManager() external view returns (address);

    /**
     * @notice Gets the USDT token contract address
     * @dev Returns the address of the USDT token contract used by the marketplace
     * @return Address of the USDT contract in IERC20 format
     */
    function usdt() external view returns (IERC20);

    /**
     * @notice Gets buyer and seller fees for a specific vesting plan
     * @dev Returns -1 for fees if using default marketplace fees
     * @param _vesting Address of the vesting contract to check
     * @return VPbuyerFee Buyer fee for the specific vesting plan (-1 for default)
     * @return VPsellerFee Seller fee for the specific vesting plan (-1 for default)
     */
    function getVestingFees(address _vesting) external view returns (int256 VPbuyerFee, int256 VPsellerFee);
}
