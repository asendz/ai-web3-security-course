// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SecondSwap Vesting Interface
 * @notice Defines core functionality for token vesting operations
 * @dev Interface for implementing token vesting with transfer and claiming capabilities
 */
interface SecondSwap_Vesting {
    /**
     * @notice Gets the total amount of tokens allocated to a beneficiary
     * @dev Returns full allocation regardless of claimed amount
     * @param _beneficiary Address of the vesting beneficiary
     * @return Total amount of tokens allocated
     */
    function total(address _beneficiary) external view returns (uint256);

    /**
     * @notice Gets the amount of tokens still available to a beneficiary
     * @dev Returns total allocation minus claimed amount
     * @param _beneficiary Address of the vesting beneficiary
     * @return Amount of tokens still available to claim
     */
    function available(address _beneficiary) external view returns (uint256);

    /**
     * @notice Calculates the amount of tokens currently claimable by a beneficiary
     * @dev Returns both claimable amount and number of steps claimable
     * @param _beneficiary Address of the vesting beneficiary
     * @return Amount of tokens currently claimable
     * @return Number of vesting steps that can be claimed
     */
    function claimable(address _beneficiary) external view returns (uint256, uint256);

    /**
     * @notice Claims available tokens for the caller
     * @dev Transfers claimable tokens to msg.sender
     */
    function claim() external;

    /**
     * @notice Transfers vested tokens between addresses
     * @dev Allows transfer of vesting allocation between users
     * @param grantor Address transferring the vesting
     * @param beneficiary Address receiving the vesting
     * @param _amount Amount of tokens to transfer
     */
    function transferVesting(address grantor, address beneficiary, uint256 _amount) external;

    /**
     * @notice Creates a new vesting schedule for a beneficiary
     * @dev Sets up vesting allocation for a single address
     * @param beneficiary Address to receive the vesting
     * @param totalAmount Total amount of tokens to vest
     */
    function createVesting(address beneficiary, uint256 totalAmount) external;

    /**
     * @notice Creates multiple vesting schedules in batch
     * @dev Sets up vesting allocations for multiple addresses
     * @param beneficiaries Array of addresses to receive vesting
     * @param totalAmounts Array of token amounts corresponding to each beneficiary
     */
    function createVestings(address[] memory beneficiaries, uint256[] memory totalAmounts) external;
}
