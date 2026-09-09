// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interface/SecondSwap_IMarketplaceSetting.sol";
import "./interface/SecondSwap_IVestingManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SecondSwap Marketplace Settings Contract
 * @notice Manages configuration and settings for the SecondSwap marketplace
 * @dev Implements IMarketplaceSetting interface and handles all marketplace parameters
 */
contract SecondSwap_MarketplaceSetting is IMarketplaceSetting {
    /**
     * @notice Fee percentage charged to buyers (in basis points)
     * @dev 100 = 1%, 10000 = 100%
     */
    uint256 public buyerFee;

    /**
     * @notice Fee percentage charged to sellers (in basis points)
     * @dev 100 = 1%, 10000 = 100%
     */
    uint256 public sellerFee;

    /**
     * @notice Fee charged for early unlisting (in wei)
     */
    uint256 public penaltyFee;

    /**
     * @notice Minimum duration a listing must remain active (in seconds)
     */
    uint256 public minListingDuration;

    /**
     * @notice Percentage of fees allocated to referrals (in basis points)
     */
    uint256 public referralFee;

    /**
     * @notice Flag indicating if marketplace is frozen
     */
    bool public isMarketplaceFreeze;

    /**
     * @notice Address that collects marketplace fees
     */
    address public feeCollector;

    /**
     * @notice Address of the marketplace admin
     */
    address public s2Admin;

    /**
     * @notice Address of the whitelist deployer contract
     */
    address public whitelistDeployer;

    /**
     * @notice Address of the vesting manager contract
     */
    address public vestingManager;

    /**
     * @notice Address that collects referral fees
     */
    address public referralFeeCollector;

    /**
     * @notice USDT address in IERC20 format
     */
    IERC20 public usdt;

    /**
     * @notice Emitted when default buyer fee is updated
     */
    event DefaultBuyerFeeUpdated(uint256 buyerFee);

    /**
     * @notice Emitted when default seller fee is updated
     */
    event DefaultSellerFeeUpdated(uint256 sellerFee);

    /**
     * @notice Emitted when penalty fee is updated
     */
    event DefaultPenaltyFeeUpdated(uint256 penaltyFee);

    /**
     * @notice Emitted when minimum listing duration is updated
     */
    event PenaltyDurationUpdated(uint256 penaltyTime);

    /**
     * @notice Emitted when marketplace freeze status is updated
     */
    event MarketplaceStatusUpdated(bool status);

    /**
     * @notice Emitted when fee collector address is updated
     */
    event FeeCollectorUpdated(address newCollector);

    /**
     * @notice Emitted when admin address is updated
     */
    event AdminUpdated(address newAdmin);

    /**
     * @notice Emitted when dev address is updated
     */
    event DevUpdated(address newDev);

    /**
     * @notice Emitted when referral percentage is updated
     */
    event ReferralUpdated(uint256 _percentage);

    /**
     * @notice Initializes the marketplace settings contract
     * @dev Sets initial values for all marketplace parameters
     * @param _feeCollector Address to collect marketplace fees
     * @param _s2Admin Address of the marketplace admin
     * @param _whitelistDeployer Address of whitelist deployer contract
     * @param _vestingManager Address of vesting manager contract
     * @custom:throws SS_Marketplace_Settings: Invalid fee collector address
     * @custom:throws SS_Marketplace_Settings: Invalid admin address
     */
    constructor(
        address _feeCollector,
        address _s2Admin,
        address _whitelistDeployer,
        address _vestingManager,
        address _usdt
    ) {
        require(_feeCollector != address(0), "SS_Marketplace_Settings: Invalid fee collector address");
        require(_s2Admin != address(0), "SS_Marketplace_Settings: Invalid admin address");
        feeCollector = _feeCollector;
        s2Admin = _s2Admin;
        buyerFee = 250; // 2.5% fee
        sellerFee = 250; // 2.5% fee
        penaltyFee = 10 ether;
        minListingDuration = 120;
        referralFee = 1000;
        isMarketplaceFreeze = false;
        whitelistDeployer = _whitelistDeployer;
        vestingManager = _vestingManager;
        usdt = IERC20(_usdt);
    }

    /**
     * @notice Restricts function access to admin only
     * @dev Throws if called by any account other than the admin
     */
    modifier onlyAdmin() {
        require(msg.sender == s2Admin, "SS_Marketplace_Settings: Unauthorized user");
        _;
    }

    /**
     * @notice Sets the buyer fee percentage
     * @dev Fee is in basis points (100 = 1%)
     * @param _amount New buyer fee percentage
     * @custom:throws SS_Marketplace_Settings: Buyer fee cannot be more than 50%
     */
    function setBuyerFee(uint256 _amount) external onlyAdmin {
        require(_amount <= 5000, "SS_Marketplace_Settings: Buyer fee cannot be more than 50%");
        buyerFee = _amount;
        emit DefaultBuyerFeeUpdated(_amount);
    }

    /**
     * @notice Sets the seller fee percentage
     * @dev Fee is in basis points (100 = 1%)
     * @param _amount New seller fee percentage
     * @custom:throws SS_Marketplace_Settings: Seller fee cannot be more than 50%
     */
    function setSellerFee(uint256 _amount) external onlyAdmin {
        require(_amount <= 5000, "SS_Marketplace_Settings: Seller fee cannot be more than 50%");
        sellerFee = _amount;
        emit DefaultSellerFeeUpdated(_amount);
    }

    /**
     * @notice Updates the fee collector address
     * @dev The fee collector receives all marketplace fees
     * @param _address New fee collector address
     * @custom:throws SS_Marketplace_Settings: Cannot be zero address
     * @custom:throws SS_Marketplace_Settings: Cannot be the same address
     */
    function setFeeAccount(address _address) external onlyAdmin {
        require(_address != address(0), "SS_Marketplace_Settings: Cannot be zero address");
        require(_address != feeCollector, "SS_Marketplace_Settings: Cannot be the same address");
        feeCollector = _address;
        emit FeeCollectorUpdated(_address);
    }

    /**
     * @notice Sets the penalty fee for early unlisting
     * @dev Fee is in wei
     * @param _amount New penalty fee amount
     * @custom:throws SS_Marketplace_Settings: Penalty fee cannot be less than 0
     */
    function setPenaltyFee(uint256 _amount) external onlyAdmin {
        require(_amount > 0, "SS_Marketplace_Settings: Penalty fee cannot be less than 0");
        penaltyFee = _amount;
        emit DefaultPenaltyFeeUpdated(_amount);
    }
    /**
     * @notice Sets minimum duration for listings
     * @dev Duration is in seconds
     * @param _seconds New minimum listing duration
     * @custom:throws SS_Marketplace_Settings: Duration must be greater than 0
     */
    function setMinListingDuration(uint256 _seconds) external onlyAdmin {
        require(_seconds > 0, "SS_Marketplace_Settings: Duration must be greater than 0");
        minListingDuration = _seconds;
        emit PenaltyDurationUpdated(_seconds);
    }

    /**
     * @notice Updates the admin address
     * @dev Can only be called by current admin
     * @param _user New admin address
     * @custom:throws SS_Marketplace_Settings: Unauthorized Access
     * @custom:throws SS_Marketplace_Settings: Cannot be zero address
     * @custom:throws SS_Marketplace_Settings: Cannot be the same address
     */
    function setS2Admin(address _user) external {
        require(msg.sender == s2Admin, "SS_Marketplace_Settings: Unauthorized Access");
        require(_user != address(0), "SS_Marketplace_Settings: Cannot be zero address");
        require(_user != s2Admin, "SS_Marketplace_Settings: Cannot be the same address");
        s2Admin = _user;
        emit AdminUpdated(_user);
    }

    /**
     * @notice Updates marketplace freeze status
     * @dev When frozen, most marketplace operations are disabled
     * @param _status New freeze status
     */
    function setMarketplaceStatus(bool _status) external onlyAdmin {
        isMarketplaceFreeze = _status;
        emit MarketplaceStatusUpdated(_status);
    }

    /**
     * @notice Sets the referral reward percentage
     * @dev Percentage is in basis points (100 = 1%)
     * @param _percentage New referral percentage
     * @custom:throws SS_Marketplace_Settings: Percentage value cannot be 0
     * @custom:throws SS_Marketplace_Settings: Percentage cannot be more than 100%
     */
    function setReferral(uint256 _percentage) external onlyAdmin {
        require(_percentage > 0, "SS_Marketplace_Settings: Percentage value cannot be 0");
        require(_percentage <= 10000, "SS_Marketplace_Settings: Percentage cannot be more than 100%");
        referralFee = _percentage;
        emit ReferralUpdated(_percentage);
    }
    /**
     * @notice Updates the whitelist deployer address
     * @dev The whitelist deployer creates whitelist contracts for private sales
     * @param _whitelistDeployer New whitelist deployer address
     * @custom:throws SS_Marketplace_Settings: Cannot be zero address
     * @custom:throws SS_Marketplace_Settings: Cannot be the same whitelist address
     */
    function setWhitelistDeployer(address _whitelistDeployer) external onlyAdmin {
        require(_whitelistDeployer != address(0), "SS_Marketplace_Settings: Cannot be zero address");
        require(
            _whitelistDeployer != address(whitelistDeployer),
            "SS_Marketplace_Settings: Cannot be the same whitelist address"
        );
        whitelistDeployer = _whitelistDeployer;
    }

    /**
     * @notice Updates the vesting manager address
     * @dev The vesting manager handles token vesting logic
     * @param _vestingManager New vesting manager address
     * @custom:throws SS_Marketplace_Settings: Cannot be zero address
     * @custom:throws SS_Marketplace_Settings: Cannot be the same vestingManager address
     */
    function setManager(address _vestingManager) external onlyAdmin {
        require(_vestingManager != address(0), "SS_Marketplace_Settings: Cannot be zero address");
        require(
            _vestingManager != address(vestingManager),
            "SS_Marketplace_Settings: Cannot be the same vestingManager address"
        );
        vestingManager = _vestingManager;
    }

    /**
     * @notice Retrieves buyer and seller fees for a specific vesting plan
     * @dev Returns -1 if no specific fees are set for the plan
     * @param _vesting Address of the vesting plan
     * @return VPbuyerFee Buyer fee for the vesting plan
     * @return VPsellerFee Seller fee for the vesting plan
     */
    function getVestingFees(address _vesting) public view returns (int256 VPbuyerFee, int256 VPsellerFee) {
        (VPbuyerFee, VPsellerFee) = IVestingManager(vestingManager).getVestingFees(_vesting);
        return (VPbuyerFee, VPsellerFee);
    }
}
