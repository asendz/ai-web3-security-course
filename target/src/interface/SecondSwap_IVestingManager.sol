// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Vesting Manager Interface
 * @author darel
 * @notice Defines core functionality for managing vesting operations in the marketplace
 * @dev Interface for marketplace interaction with vesting operations and settings
 */
interface IVestingManager {
    /**
     * @notice Settings structure for vesting contracts
     * @dev Stores configuration for each vesting contract
     * @param sellable Whether tokens from this vesting can be sold
     * @param maxSellPercent Maximum percentage of tokens that can be sold (in basis points)
     * @param buyerFee Fee charged to buyers (-1 for default fee)
     * @param sellerFee Fee charged to sellers (-1 for default fee)
     */
    struct VestingSettings {
        bool sellable;
        uint256 maxSellPercent;
        int256 buyerFee;
        int256 sellerFee;
    }

    /**
     * @notice Lists vested tokens for sale in the marketplace
     * @dev Can only be called by the marketplace contract
     * @param seller Address of the token seller
     * @param plan Address of the vesting plan
     * @param amount Amount of tokens to list
     */
    function listVesting(address seller, address plan, uint256 amount) external;

    /**
     * @notice Removes tokens from marketplace listing
     * @dev Can only be called by the marketplace contract
     * @param seller Address of the token seller
     * @param plan Address of the vesting plan
     * @param amount Amount of tokens to unlist
     */
    function unlistVesting(address seller, address plan, uint256 amount) external;

    /**
     * @notice Completes a purchase transaction
     * @dev Can only be called by the marketplace contract
     * @param buyer Address of the token buyer
     * @param vesting Address of the vesting contract
     * @param amount Amount of tokens purchased
     */
    function completePurchase(address buyer, address vesting, uint256 amount) external;

    /**
     * @notice Sets whether tokens can be sold from a vesting contract
     * @dev Controls ability to list tokens from this vesting
     * @param vesting Address of the vesting contract
     * @param sellable Whether tokens should be sellable
     */
    function setSellable(address vesting, bool sellable) external;

    /**
     * @notice Sets maximum percentage of tokens that can be sold
     * @dev Percentage is in basis points (100 = 1%)
     * @param vesting Address of the vesting contract
     * @param maxSellPercent Maximum sell percentage in basis points
     */
    function setMaxSellPercent(address vesting, uint256 maxSellPercent) external;

    /**
     * @notice Sets the buyer fee for a specific vesting contract
     * @dev Fee can be -1 to use default marketplace fee
     * @param vesting Address of the vesting contract
     * @param fee Buyer fee in basis points, -1 for default
     */
    function setBuyerFee(address vesting, int256 fee) external;

    /**
     * @notice Sets the seller fee for a specific vesting contract
     * @dev Fee can be -1 to use default marketplace fee
     * @param vesting Address of the vesting contract
     * @param fee Seller fee in basis points, -1 for default
     */
    function setSellerFee(address vesting, int256 fee) external;

    /**
     * @notice Gets the current buyer and seller fees for a vesting plan
     * @dev Returns -1 for fees if using default marketplace fees
     * @param _vestingPlan Address of the vesting plan to check
     * @return buyerFee Current buyer fee (-1 for default)
     * @return sellerFee Current seller fee (-1 for default)
     */
    function getVestingFees(address _vestingPlan) external view returns (int256 buyerFee, int256 sellerFee);

    function getVestingTokenAddress(address _vestingPlan) external view returns (address _token);
}
