// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interface/SecondSwap_Vesting.sol";
import "./SecondSwap_StepVesting.sol";
import "./interface/SecondSwap_IVestingManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

/**
 * @title SecondSwap Vesting Manager Contract
 * @notice Manages vesting settings, allocations, and marketplace interactions
 * @dev Implements IVestingManager interface to handle vesting operations
 */
contract SecondSwap_VestingManager is IVestingManager, Initializable {
    /**
     * @notice Tracks bought and sold amounts for each user's vesting allocation
     * @param bought Amount of tokens bought by the user
     * @param sold Amount of tokens sold by the user
     */
    struct Allocation {
        uint256 bought;
        uint256 sold;
    }

    /**
     * @notice Emitted when a vesting plan's sellable status is updated
     * @param vesting Address of the vesting contract
     * @param sellable New sellable status
     */
    event VestingSellableUpdated(address vesting, bool sellable);

    /**
     * @notice Emitted when maximum sell percentage is updated
     * @param vesting Address of the vesting contract
     * @param maxSellPercent New maximum sell percentage
     */
    event MaxSellPercentUpdated(address vesting, uint256 maxSellPercent);

    /**
     * @notice Emitted when buyer fee is updated
     * @param vesting Address of the vesting contract
     * @param fee New buyer fee
     */
    event BuyerFeeUpdated(address vesting, int256 fee);

    /**
     * @notice Emitted when seller fee is updated
     * @param vesting Address of the vesting contract
     * @param fee New seller fee
     */
    event SellerFeeUpdated(address vesting, int256 fee);

    /**
     * @notice Maps vesting contract addresses to their settings
     */
    mapping(address => VestingSettings) public vestingSettings;

    /**
     * @notice Maps user addresses to their vesting allocations
     * @dev First key is user address, second key is vesting plan address
     */
    mapping(address => mapping(address => Allocation)) public allocations;

    /**
     * @notice Address of the marketplace contract
     */
    address public marketplace;

    /**
     * @notice Address of the admin
     */
    address public s2Admin;

    /**
     * @notice Address of the vesting deployer
     */
    address public vestingDeployer;

    /**
     * @notice Base unit for percentage calculations (100% = 10000)
     */
    uint256 constant BASE = 10000;

    /**
     * @notice Restricts function access to marketplace only
     */
    modifier onlyMarketplace() {
        require(msg.sender == marketplace, "SS_VestingManager: caller is not marketplace");
        _;
    }

    /**
     * @notice Restricts function access to admin only
     */
    modifier onlyAdmin() {
        require(msg.sender == s2Admin, "SS_VestingManager: Unauthorized user");
        _;
    }

    /**
     * @notice Initializes the vesting manager contract
     * @dev Implementation of initializer for upgradeable pattern
     * @param _s2admin Address of the admin
     */
    function initialize(address _s2admin) public initializer {
        s2Admin = _s2admin;
    }

    /**
     * @notice Lists tokens for sale in the marketplace
     * @dev Validates selling limits and transfers tokens to contract
     * @param seller Address of the token seller
     * @param plan Address of the vesting plan
     * @param amount Amount of tokens to list
     * @custom:throws vesting not sellable
     * @custom:throws SS_VestingManager: insufficient availablility
     * @custom:throws SS_VestingManager: cannot list more than max sell percent
     */
    function listVesting(address seller, address plan, uint256 amount) external onlyMarketplace {
        require(vestingSettings[plan].sellable, "vesting not sellable");
        require(SecondSwap_Vesting(plan).available(seller) >= amount, "SS_VestingManager: insufficient availablility");

        Allocation storage userAllocation = allocations[seller][plan];

        uint256 sellLimit = userAllocation.bought;
        uint256 currentAlloc = SecondSwap_Vesting(plan).total(seller);

        if (currentAlloc + userAllocation.sold > userAllocation.bought) {
            sellLimit +=
                ((currentAlloc + userAllocation.sold - userAllocation.bought) * vestingSettings[plan].maxSellPercent) /
                BASE;
        }

        userAllocation.sold += amount;

        require(userAllocation.sold <= sellLimit, "SS_VestingManager: cannot list more than max sell percent");
        SecondSwap_Vesting(plan).transferVesting(seller, address(this), amount);
    }

    /**
     * @notice Removes tokens from marketplace listing
     * @dev Returns tokens to seller
     * @param seller Address of the token seller
     * @param plan Address of the vesting plan
     * @param amount Amount of tokens to unlist
     */
    function unlistVesting(address seller, address plan, uint256 amount) external onlyMarketplace {
        allocations[seller][plan].sold -= amount;
        SecondSwap_Vesting(plan).transferVesting(address(this), seller, amount);
    }

    /**
     * @notice Completes a purchase of vested tokens
     * @dev Updates buyer allocation and transfers tokens
     * @param buyer Address of the token buyer
     * @param vesting Address of the vesting contract
     * @param amount Amount of tokens purchased
     */
    function completePurchase(address buyer, address vesting, uint256 amount) external onlyMarketplace {
        allocations[buyer][vesting].bought += amount;
        SecondSwap_Vesting(vesting).transferVesting(address(this), buyer, amount);
    }

    /**
     * @notice Sets whether tokens can be sold from a vesting contract
     * @dev Also initializes default settings for new sellable vestings
     * @param vesting Address of the vesting contract
     * @param sellable Whether the tokens can be sold
     * @custom:throws SS_VestingManager: Unauthorised user
     */
    function setSellable(address vesting, bool sellable) external {
        require(s2Admin == msg.sender || vestingDeployer == msg.sender, "SS_VestingManager: Unauthorised user");

        VestingSettings storage vestingSetting = vestingSettings[vesting];

        vestingSetting.sellable = sellable;
        if (vestingSetting.maxSellPercent == 0 && vestingSetting.sellable) {
            vestingSetting.maxSellPercent = 2000;
            vestingSetting.buyerFee = -1;
            vestingSetting.sellerFee = -1;
            emit MaxSellPercentUpdated(vesting, 2000);
        }
        emit VestingSellableUpdated(vesting, sellable);
    }

    /**
     * @notice Sets maximum percentage of tokens that can be sold
     * @param vesting Address of the vesting contract
     * @param maxSellPercent Maximum percentage allowed to sell
     * @custom:throws SS_VestingManager: Invalid Token Issuer
     */
    function setMaxSellPercent(address vesting, uint256 maxSellPercent) external {
        require(SecondSwap_StepVesting(vesting).tokenIssuer() == msg.sender, "SS_VestingManager: Invalid Token Issuer");
        vestingSettings[vesting].maxSellPercent = maxSellPercent;
        emit MaxSellPercentUpdated(vesting, maxSellPercent);
    }

    /**
     * @notice Sets the marketplace address
     * @param _marketplace New marketplace address
     */
    function setMarketplace(address _marketplace) external onlyAdmin {
        marketplace = _marketplace;
    }

    /**
     * @notice Updates the admin address
     * @param _admin New admin address
     */
    function setAdmin(address _admin) external onlyAdmin {
        s2Admin = _admin;
    }

    /**
     * @notice Sets buyer fee for a vesting contract
     * @dev Fee can be -1 for default fee
     * @param _vesting Address of the vesting contract
     * @param _fee New buyer fee (-1 to 5000)
     * @custom:throws SS_VestingManager: Buyer Fee cannot be less than 0
     */
    function setBuyerFee(address _vesting, int256 _fee) external onlyAdmin {
        require(_fee >= -1 && _fee <= 5000, "SS_VestingManager: Buyer Fee cannot be less than 0");
        vestingSettings[_vesting].buyerFee = _fee;
        emit BuyerFeeUpdated(_vesting, _fee);
    }

    /**
     * @notice Sets seller fee for a vesting contract
     * @dev Fee can be -1 for default fee
     * @param _vesting Address of the vesting contract
     * @param _fee New seller fee (-1 to 5000)
     * @custom:throws SS_VestingManager: Seller fee cannot be less than 0
     */
    function setSellerFee(address _vesting, int256 _fee) external onlyAdmin {
        require(_fee >= -1 && _fee <= 5000, "SS_VestingManager: Seller fee cannot be less than 0");
        vestingSettings[_vesting].sellerFee = _fee;
        emit SellerFeeUpdated(_vesting, _fee);
    }

    /**
     * @notice Updates the vesting deployer address
     * @param _vestingDeployer New vesting deployer address
     * @custom:throws SS_VestingManager: VestingDeployer cannot be the same
     */
    function setVestingDeployer(address _vestingDeployer) external onlyAdmin {
        require(_vestingDeployer != vestingDeployer, "SS_VestingManager: VestingDeployer cannot be the same");
        vestingDeployer = _vestingDeployer;
    }

    /**
     * @notice Gets buyer and seller fees for a vesting plan
     * @param _vestingPlan Address of the vesting plan
     * @return buyerFee Current buyer fee
     * @return sellerFee Current seller fee
     */
    function getVestingFees(address _vestingPlan) external view returns (int256 buyerFee, int256 sellerFee) {
        return (vestingSettings[_vestingPlan].buyerFee, vestingSettings[_vestingPlan].sellerFee);
    }

    function getVestingTokenAddress(address _vestingPlan) external view onlyMarketplace returns (address _token) {
        return address(SecondSwap_StepVesting(_vestingPlan).token());
    }
}
