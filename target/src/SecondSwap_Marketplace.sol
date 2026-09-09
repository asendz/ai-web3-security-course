// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "./interface/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; //  3.6. DOS caused by the use of transfer and transferFrom functions
import "./interface/SecondSwap_IMarketplaceSetting.sol";
import "./interface/SecondSwap_IWhitelist.sol";
import "./interface/SecondSwap_IVestingManager.sol";
import "./SecondSwap_WhitelistDeployer.sol";
import "hardhat/console.sol";
/**
 * @title SecondSwap Marketplace Contract
 * @notice Handles the listing and trading of vested tokens
 * @dev This contract is upgradeable and manages the marketplace functionality for SecondSwap
 */
contract SecondSwap_Marketplace is Initializable {
    using SafeERC20 for IERC20; //  3.6. DOS caused by the use of transfer and transferFrom functions

    /**
     * @notice Enumeration of possible listing statuses
     * @dev Used to track the current state of a listing
     * @param LIST Active listing that can be purchased
     * @param SOLDOUT Listing where all tokens have been sold
     * @param DELIST Listing that has been cancelled by the seller
     */
    enum Status {
        LIST,
        SOLDOUT,
        DELIST
    }
    /**
     * @notice Enumeration of listing types
     * @dev Determines how tokens can be purchased from the listing
     * @param PARTIAL Allows partial purchases of the listed amount
     * @param SINGLE Requires the entire listed amount to be purchased at once
     */
    enum ListingType {
        PARTIAL,
        SINGLE
    }
    /**
     * @notice Enumeration of discount types
     * @dev Defines how price discounts are calculated
     * @param NO No discount applied
     * @param LINEAR Discount increases linearly with purchase amount
     * @param FIX Fixed percentage discount regardless of amount
     */
    enum DiscountType {
        NO,
        LINEAR,
        FIX
    }
    /**
     * @notice Structure containing all listing information
     * @dev Used to store and manage listing details
     * @param seller Address of the token seller
     * @param total Total amount of tokens initially listed
     * @param balance Current remaining amount of tokens
     * @param pricePerUnit Price per token unit
     * @param listingType Type of listing (PARTIAL or SINGLE)
     * @param discountType Type of discount applied
     * @param discountPct Discount percentage (0-10000)
     * @param listTime Timestamp when listing was created
     * @param whitelist Address of whitelist contract if private listing
     * @param minPurchaseAmt Minimum amount that can be purchased
     * @param status Current status of the listing
     * @param currency Address of token used for payment
     */
    struct Listing {
        address seller;
        uint256 total;
        uint256 balance;
        uint256 pricePerUnit;
        ListingType listingType;
        DiscountType discountType;
        uint256 discountPct;
        uint256 listTime;
        address whitelist;
        uint256 minPurchaseAmt;
        Status status;
        address currency;
        address vestingPlan;
    }
    /**
     * @notice Address of the marketplace settings contract
     * @dev Used to access marketplace configuration and parameters
     */
    address public marketplaceSetting;

    /**
     * @notice Mapping of vesting plan addresses to their listing IDs and details
     * @dev First key is vesting plan address, second key is listing ID
     */
    mapping(address => mapping(uint256 => Listing)) public listings;

    /**
     * @notice Mapping of vesting plan addresses to their next available listing ID
     * @dev Used to generate unique listing IDs for each vesting plan
     */
    mapping(address => uint256) public nextListingId;

    /**
     * @notice Mapping of token addresses to their support status
     * @dev Tracks which tokens are accepted as payment currency
     */
    mapping(address => bool) public isTokenSupport;

    /**
     * @notice Base unit for percentage calculations
     * @dev 10000 represents 100%, used for fee and discount calculations
     */
    uint256 public constant BASE = 10000;

    /**
     * @notice Emitted when a new listing is created
     * @param vestingPlan Address of the vesting plan contract
     * @param listingId Unique identifier of the listing
     */
    event Listed(address indexed vestingPlan, uint256 indexed listingId);

    /**
     * @notice Emitted when a listing is delisted
     * @param vestingPlan Address of the vesting plan contract
     * @param listingId Unique identifier of the listing
     * @param penaltyFee Amount of penalty fee charged for early delisting
     * @param seller Address of the seller who delisted
     */
    event Delisted(address indexed vestingPlan, uint256 indexed listingId, uint256 penaltyFee, address seller);

    /**
     * @notice Emitted when a purchase is completed
     * @param vestingPlan Address of the vesting plan contract
     * @param listingId Unique identifier of the listing
     * @param buyer Address of the buyer
     * @param amount Amount of tokens purchased
     * @param referral Address of the referrer
     * @param buyerFee Amount of fees paid by buyer
     * @param sellerFee Amount of fees paid by seller
     * @param referralReward Amount of reward paid to referrer
     */
    event Purchased(
        address indexed vestingPlan,
        uint256 indexed listingId,
        address buyer,
        uint256 amount,
        address referral,
        uint256 buyerFee,
        uint256 sellerFee,
        uint256 referralReward
    );

    /**
     * @notice Emitted when a whitelist is created for a private listing
     * @param vestingPlan Address of the vesting plan contract
     * @param listingId Unique identifier of the listing
     * @param whitelistAddress Address of the deployed whitelist contract
     * @param seller Address of the seller
     * @param maxWhitelist Maximum number of addresses that can be whitelisted
     */
    event WhitelistCreated(
        address indexed vestingPlan,
        uint256 indexed listingId,
        address whitelistAddress,
        address seller,
        uint256 maxWhitelist
    );

    /**
     * @notice Emitted when a new token is added
     * @param token address ot the new token
     */
    event CoinAdded(address indexed token);

    /**
     * @notice Initializes the marketplace contract
     * @dev Implementation of initializer for upgradeable contract pattern
     * @param _token Initial supported token address for payments
     * @param _marketplaceSetting Address of the marketplace settings contract
     */
    function initialize(address _token, address _marketplaceSetting) public initializer {
        isTokenSupport[_token] = true;
        marketplaceSetting = _marketplaceSetting;
    }

    /**
     * @notice Modifier to prevent actions when marketplace is frozen
     * @dev Checks marketplace freeze status through settings contract
     * @custom:throws SS_Marketplace: Marketplace is currently frozen
     */
    modifier isFreeze() {
        require(
            !IMarketplaceSetting(marketplaceSetting).isMarketplaceFreeze(),
            "SS_Marketplace: Marketplace is currently frozen"
        );
        _;
    }

    /**
     * @notice Adds a new token as supported payment currency
     * @dev Only callable by marketplace admin
     * @param _token Address of the token to add as supported currency
     * @custom:throws SS_Marketplace: Unauthorized user - If caller is not admin
     * @custom:throws SS_Marketplace: Token is currently supported - If token already supported
     */
    function addCoin(address _token) external {
        require(msg.sender == IMarketplaceSetting(marketplaceSetting).s2Admin(), "SS_Marketplace: Unauthorized user");
        require(!isTokenSupport[_token], "SS_Marketplace: Token is currently supported");
        // try IERC20Extended(_token).decimals() returns (uint8 decimals) {
        //     require(decimals <= 18, "SS_Marketplace: Token decimals too high");
        //     require(decimals > 0, "SS_Marketplace: Token decimals must be greater than 0");

        //     isTokenSupport[_token] = true;
        //     emit CoinAdded(_token); // Emit event when coin is added
        // } catch {
        //     revert("SS_Marketplace: Token must implement decimals function");
        // }
        isTokenSupport[_token] = true;
    }

    /**
     * @notice Creates a new listing for vested tokens
     * @dev Transfers tokens to marketplace and creates listing record
     * @param _vestingPlan Address of the vesting plan contract
     * @param _amount Total amount of tokens to list
     * @param _price Price per token unit
     * @param _discountPct Discount percentage (0-10000)
     * @param _listingType PARTIAL allows partial fills, SINGLE requires complete fill
     * @param _discountType NO = no discount, LINEAR = progressive, FIX = fixed percentage
     * @param _maxWhitelist Maximum number of addresses for whitelist (if private)
     * @param _currency Address of token used for payment
     * @param _minPurchaseAmt Minimum purchase amount allowed
     * @param _isPrivate If true, creates whitelist for private sale
     * @custom:throws SS_Marketplace: Minimum Purchase Amount cannot be more than listing amount
     * @custom:throws SS_Marketplace: Price must be greater than 0
     * @custom:throws SS_Marketplace: Invalid discount amount
     * @custom:throws SS_Marketplace: Invalid listing amount
     * @custom:throws SS_Marketplace: Payment token is not supported
     * @custom:throws SS_Marketplace: Minimum whitelist user cannot be 0
     */
    function listVesting(
        address _vestingPlan,
        uint256 _amount,
        uint256 _price,
        uint256 _discountPct,
        ListingType _listingType,
        DiscountType _discountType,
        uint256 _maxWhitelist,
        address _currency,
        uint256 _minPurchaseAmt,
        bool _isPrivate
    ) external isFreeze {
        require(
            _listingType != ListingType.SINGLE || (_minPurchaseAmt > 0 && _minPurchaseAmt <= _amount),
            "SS_Marketplace: Minimum Purchase Amount cannot be more than listing amount"
        );
        require(_price > 0, "SS_Marketplace: Price must be greater than 0");
        require(
            (_discountType != DiscountType.NO && _discountPct > 0) || (_discountType == DiscountType.NO),
            "SS_Marketplace: Invalid discount amount"
        );
        require(_amount > 0, "SS_Marketplace: Invalid listing amount"); // 3.10. Inefficient _listingType check
        require(isTokenSupport[_currency], "SS_Marketplace: Payment token is not supported");

        require(
            doesFunctionExist(
                address(
                    IVestingManager(IMarketplaceSetting(marketplaceSetting).vestingManager()).getVestingTokenAddress(
                        _vestingPlan
                    )
                ),
                "decimals()"
            ),
            "SS_Marketplace: No decimals function"
        ); // 3.1. Rounding issue leads to total drain of vesting entries

        uint256 baseAmount = (_amount * _price) /
            uint256(
                10 **
                    (
                        IERC20Extended(
                            address(
                                IVestingManager(IMarketplaceSetting(marketplaceSetting).vestingManager())
                                    .getVestingTokenAddress(_vestingPlan)
                            )
                        ).decimals()
                    )
            ); // 3.1. Rounding issue leads to total drain of vesting entries
        require(baseAmount > 0, "SS_Marketplace: Cannot list amount it is too little"); // 3.1. Rounding issue leads to total drain of vesting entries

        IVestingManager(IMarketplaceSetting(marketplaceSetting).vestingManager()).listVesting(
            msg.sender,
            _vestingPlan,
            _amount
        );

        uint256 listingId = nextListingId[_vestingPlan]++;
        address whitelistAddress;

        if (_isPrivate) {
            require(_maxWhitelist > 0, "SS_Marketplace: Minimum whitelist user cannot be 0");
            whitelistAddress = SecondSwap_WhitelistDeployer(IMarketplaceSetting(marketplaceSetting).whitelistDeployer())
                .deployWhitelist(_maxWhitelist, msg.sender);
            emit WhitelistCreated(_vestingPlan, listingId, whitelistAddress, msg.sender, _maxWhitelist);
        }

        listings[_vestingPlan][listingId] = Listing({
            seller: msg.sender,
            total: _amount,
            balance: _amount,
            pricePerUnit: _price,
            listingType: _listingType,
            discountType: _discountType,
            discountPct: _discountPct,
            listTime: block.timestamp,
            whitelist: whitelistAddress,
            currency: _currency,
            minPurchaseAmt: _minPurchaseAmt,
            status: Status.LIST,
            vestingPlan: _vestingPlan
        });
        emit Listed(_vestingPlan, listingId);
    }

    function doesFunctionExist(address target, string memory functionSignature) public view returns (bool) {
        bytes4 selector = bytes4(keccak256(bytes(functionSignature)));
        (bool success, ) = target.staticcall(abi.encodeWithSelector(selector));
        return success;
    }

    /**
     * @notice Removes a listing from the marketplace
     * @dev Handles early unlisting penalties and token returns
     * @param _vestingPlan Address of the vesting plan contract
     * @param _listingId ID of the listing to remove
     * @custom:throws SS_Marketplace: Listing not active
     * @custom:throws SS_Marketplace: Not the seller
     * @custom:throws SS_Marketplace: Penalty fee required for early unlisting
     */
    function unlistVesting(address _vestingPlan, uint256 _listingId) external isFreeze {
        Listing storage listing = listings[_vestingPlan][_listingId];
        require(listing.status == Status.LIST, "SS_Marketplace: Listing not active");
        require(
            listing.seller == msg.sender || msg.sender == IMarketplaceSetting(marketplaceSetting).s2Admin(),
            "SS_Marketplace: Not the seller"
        );
        uint256 _penaltyFee = 0;
        if (msg.sender != IMarketplaceSetting(marketplaceSetting).s2Admin()) {
            //  3.4. The s2Admin is unable to unlist vesting
            if ((listing.listTime + IMarketplaceSetting(marketplaceSetting).minListingDuration()) > block.timestamp) {
                require(
                    (IMarketplaceSetting(marketplaceSetting).usdt()).balanceOf(msg.sender) >=
                        IMarketplaceSetting(marketplaceSetting).penaltyFee(),
                    "SS_Marketplace: Penalty fee required for early unlisting"
                ); // 3.7. Value difference caused by the same penalty fee
                (IMarketplaceSetting(marketplaceSetting).usdt()).safeTransferFrom(
                    msg.sender,
                    IMarketplaceSetting(marketplaceSetting).feeCollector(), // 3.7. Value difference caused by the same penalty fee
                    IMarketplaceSetting(marketplaceSetting).penaltyFee()
                ); //  3.6. DOS caused by the use of transfer and transferFrom functions
                _penaltyFee = IMarketplaceSetting(marketplaceSetting).penaltyFee();
            }
        }
        IVestingManager(IMarketplaceSetting(marketplaceSetting).vestingManager()).unlistVesting(
            listing.seller,
            _vestingPlan,
            listing.balance
        ); //  3.4. The s2Admin is unable to unlist vesting

        listing.status = Status.DELIST; // 3.3. Buyer can choose listing price
        listing.balance = 0; // 3.3. Buyer can choose listing price

        emit Delisted(_vestingPlan, _listingId, _penaltyFee, msg.sender);
    }

    /**
     * @notice Validates a purchase attempt
     * @dev Checks various conditions that must be met for a valid purchase
     * @param listing The listing to validate against
     * @param _amount Amount of tokens to purchase
     * @param _referral Address of the referrer
     * @custom:throws SS_Marketplace: Invalid referral
     * @custom:throws SS_Marketplace: Not whitelisted
     * @custom:throws SS_Marketplace: Invalid Purchase amount
     * @custom:throws SS_Marketplace: Invalid amount
     * @custom:throws SS_Marketplace: Insufficient
     */
    function _validatePurchase(Listing storage listing, uint256 _amount, address _referral) private view {
        require(listing.status == Status.LIST, "SS_Marketplace: Listing not active"); // 3.3. Buyer can choose listing price
        require(msg.sender != _referral, "SS_Marketplace: Invalid referral");
        require(
            listing.whitelist == address(0) || IWhitelist(listing.whitelist).validateAddress(msg.sender),
            "SS_Marketplace: Not whitelisted"
        );
        require(
            listing.listingType == ListingType.SINGLE ||
                (_amount >= listing.minPurchaseAmt || _amount == listing.balance),
            "SS_Marketplace: Invalid Purchase amount"
        );
        require(
            listing.listingType != ListingType.SINGLE || _amount == listing.total,
            "SS_Marketplace: Invalid amount"
        );
        require(_amount <= listing.balance, "SS_Marketplace: Insufficient");
    }

    /**
     * @notice Calculates the final price per token including discounts
     * @dev Applies linear or fixed discounts based on listing configuration
     * @param listing The listing to calculate price for
     * @param _amount Amount of tokens being purchased
     * @return Final price per token after discounts
     */
    function _getDiscountedPrice(Listing storage listing, uint256 _amount) private view returns (uint256) {
        uint256 discountedPrice = listing.pricePerUnit;

        if (listing.discountType == DiscountType.LINEAR) {
            discountedPrice = (discountedPrice * (BASE - ((_amount * listing.discountPct) / listing.total))) / BASE;
        } else if (listing.discountType == DiscountType.FIX) {
            discountedPrice = (discountedPrice * (BASE - listing.discountPct)) / BASE;
        }
        return discountedPrice;
    }

    /**
     *
     * @notice Retrieves buyer and seller fee rates for a vesting plan
     * @dev Checks for plan-specific fees, falls back to global fees if not set
     * @param _vestingPlan Address of the vesting plan
     * @return bfee Buyer fee percentage
     * @return sfee Seller fee percentage
     */
    function _getFees(address _vestingPlan) private view returns (uint256 bfee, uint256 sfee) {
        (int256 vpbf, int256 vpsf) = IMarketplaceSetting(marketplaceSetting).getVestingFees(_vestingPlan);
        bfee = vpbf > -1 ? uint256(vpbf) : IMarketplaceSetting(marketplaceSetting).buyerFee();
        sfee = vpsf > -1 ? uint256(vpsf) : IMarketplaceSetting(marketplaceSetting).sellerFee();
    }

    /**
     * @notice Handles all token transfers during a purchase
     * @dev Transfers payment tokens between buyer, seller, referrer, and fee collector
     * @param listing The listing being purchased from
     * @param _amount Amount of tokens being purchased
     * @param discountedPrice Price per token after discounts
     * @param bfee Buyer fee percentage
     * @param sfee Seller fee percentage
     * @param _referral Address of the referrer
     * @return buyerFeeTotal Total fees paid by buyer
     * @return sellerFeeTotal Total fees paid by seller
     * @return referralFeeCost Amount paid to referrer
     */
    function _handleTransfers(
        Listing storage listing,
        uint256 _amount,
        uint256 discountedPrice,
        uint256 bfee,
        uint256 sfee,
        address _referral
    ) private returns (uint256 buyerFeeTotal, uint256 sellerFeeTotal, uint256 referralFeeCost) {
        uint256 baseAmount = (_amount * discountedPrice) /
            uint256(
                10 **
                    (
                        IERC20Extended(
                            address(
                                IVestingManager(IMarketplaceSetting(marketplaceSetting).vestingManager())
                                    .getVestingTokenAddress(listing.vestingPlan)
                            )
                        ).decimals()
                    )
            ); // 3.1. Rounding issue leads to total drain of vesting entries
        require(baseAmount > 0, "SS_Marketplace: Amount too little"); // 3.1. Rounding issue leads to total drain of vesting entries

        buyerFeeTotal = (baseAmount * bfee) / BASE;
        sellerFeeTotal = (baseAmount * sfee) / BASE;

        IERC20(listing.currency).safeTransferFrom(msg.sender, address(this), (baseAmount + buyerFeeTotal)); //  3.6. DOS caused by the use of transfer and transferFrom functions

        referralFeeCost = 0;
        if (_referral != address(0) && listing.whitelist == address(0)) {
            referralFeeCost =
                buyerFeeTotal -
                (baseAmount * bfee * IMarketplaceSetting(marketplaceSetting).referralFee()) /
                (BASE * BASE);
        }

        IERC20(listing.currency).safeTransfer(listing.seller, (baseAmount - sellerFeeTotal)); //  3.6. DOS caused by the use of transfer and transferFrom functions

        uint256 feeCollectorTotal = (buyerFeeTotal + sellerFeeTotal);
        IERC20(listing.currency).safeTransfer(
            IMarketplaceSetting(marketplaceSetting).feeCollector(),
            feeCollectorTotal
        ); //  3.6. DOS caused by the use of transfer and transferFrom functions
    }

    /**
     * @notice Executes a purchase of listed tokens
     * @dev Handles the complete purchase flow including validation, pricing, and transfers
     * @param _vestingPlan Address of the vesting plan contract
     * @param _listingId ID of the listing to purchase from
     * @param _amount Amount of tokens to purchase
     * @param _referral Address of the referrer (if any)
     * @custom:throws Various errors from _validatePurchase
     * @custom:emits Purchased
     */
    function spotPurchase(
        address _vestingPlan,
        uint256 _listingId,
        uint256 _amount,
        address _referral
    ) external isFreeze {
        // Get listing and validate purchase parameters
        Listing storage listing = listings[_vestingPlan][_listingId];
        _validatePurchase(listing, _amount, _referral);

        // Calculate fees and final price
        (uint256 bfee, uint256 sfee) = _getFees(_vestingPlan);
        uint256 discountedPrice = _getDiscountedPrice(listing, _amount);

        // Process all transfers
        (uint256 buyerFeeTotal, uint256 sellerFeeTotal, uint256 referralFeeCost) = _handleTransfers(
            listing,
            _amount,
            discountedPrice,
            bfee,
            sfee,
            _referral
        );

        // Update listing status
        listing.balance -= _amount;
        listing.status = listing.balance == 0 ? Status.SOLDOUT : Status.LIST;

        // Complete the purchase through vesting manager
        IVestingManager(IMarketplaceSetting(marketplaceSetting).vestingManager()).completePurchase(
            msg.sender,
            _vestingPlan,
            _amount
        );

        // Emit purchase event
        emit Purchased(
            _vestingPlan,
            _listingId,
            msg.sender,
            _amount,
            _referral,
            buyerFeeTotal,
            sellerFeeTotal,
            referralFeeCost
        );
    }

    /**
     * @notice Updates the marketplace settings contract address
     * @dev Only callable by marketplace admin
     * @param _marketplaceSetting New address of the marketplace settings contract
     * @custom:throws SS_Marketplace: Unauthorized user
     * @custom:throws SS_Marketplace: Address cannot be null
     */
    function setMarketplaceSettingAddress(address _marketplaceSetting) external {
        require(msg.sender == IMarketplaceSetting(marketplaceSetting).s2Admin(), "SS_Marketplace: Unauthorized user");
        require(_marketplaceSetting != address(0), "SS_Marketplace: Address cannot be null");
        marketplaceSetting = _marketplaceSetting;
    }

    /**
     * @notice Returns the current version of the marketplace contract
     * @dev Used for version tracking in upgradeable contract pattern
     * @return String representing the contract version
     */
    function version() public pure returns (string memory) {
        return "1.0.0";
    }
}
