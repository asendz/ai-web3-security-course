// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SecondSwap_StepVesting.sol";
import "./interface/SecondSwap_IVestingManager.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SecondSwap Vesting Deployer Contract
 * @notice Manages the deployment and configuration of vesting contracts
 * @dev Upgradeable contract that handles vesting contract deployment and management
 */
contract SecondSwap_VestingDeployer is Initializable {
    /**
     * @notice Emitted when a new vesting contract is deployed
     * @param token Address of the token being vested
     * @param vesting Address of the deployed vesting contract
     * @param vestingId Unique identifier for the vesting contract
     */
    event VestingDeployed(address indexed token, address vesting, string vestingId);

    /**
     * @notice Emitted when a new vesting schedule is created
     * @param beneficiary Address receiving the vested tokens
     * @param totalAmount Amount of tokens being vested
     * @param stepVesting Address of the step vesting contract
     */
    event VestingCreated(address indexed beneficiary, uint256 totalAmount, address stepVesting);

    /**
     * @notice Emitted when vesting is transferred between addresses
     * @param grantor Address transferring the vesting
     * @param beneficiary Address receiving the vesting
     * @param amount Amount of tokens transferred
     * @param stepVesting Address of the step vesting contract
     * @param transactionId Unique identifier for the transfer
     */
    event VestingTransferred(
        address indexed grantor,
        address indexed beneficiary,
        uint256 amount,
        address stepVesting,
        string transactionId
    );

    /**
     * @notice Emitted when tokens are claimed from vesting
     * @param beneficiary Address claiming the tokens
     * @param stepVesting Address of the step vesting contract
     * @param amount Amount of tokens claimed
     */
    event VestingClaimed(address indexed beneficiary, address stepVesting, uint256 amount);

    /**
     * @notice Address of the vesting manager contract
     */
    address public manager;

    /**
     * @notice Mapping of addresses to their owned tokens
     * @dev Maps token owner address to token address
     */
    mapping(address => address) public _tokenOwner;

    /**
     * @notice Address of the admin
     */
    address public s2Admin;

    /**
     * @notice Initializes the vesting deployer contract
     * @dev Implementation of initializer for upgradeable pattern
     * @param _s2Admin Address of the admin
     * @param _manager Address of the manager contract
     */
    function initialize(address _s2Admin, address _manager) public initializer {
        s2Admin = _s2Admin;
        manager = _manager;
    }

    /**
     * @notice Restricts function access to admin only
     * @custom:throws SS_VestingDeployer: Unauthorized user
     */
    modifier onlyAdmin() {
        require(msg.sender == s2Admin, "SS_VestingDeployer: Unauthorized user");
        _;
    }

    /**
     * @notice Deploys a new vesting contract
     * @dev Creates a new StepVesting contract instance and makes it sellable
     * @param tokenAddress Address of the token to be vested
     * @param startTime Start time of the vesting schedule
     * @param endTime End time of the vesting schedule
     * @param steps Number of vesting steps
     * @param vestingId Unique identifier for the vesting contract
     * @custom:throws SS_VestingDeployer: caller is not the token owner
     * @custom:throws SS_VestingDeployer: start time must be before end time
     * @custom:throws SS_VestingDeployer: steps must be greater than 0
     * @custom:throws SS_VestingDeployer: manager not set
     */
    function deployVesting(
        address tokenAddress,
        uint256 startTime,
        uint256 endTime,
        uint256 steps,
        string memory vestingId
    ) external {
        require(_tokenOwner[msg.sender] == tokenAddress, "SS_VestingDeployer: caller is not the token owner");
        //require(_tokenOwner[msg.sender] == address(SecondSwap_StepVesting(_stepVesting).token()), "SS_VestingDeployer: caller is not the token owner"); Can't implement this as the stepVesting Contract is not deployed
        require(tokenAddress != address(0), "SS_VestingDeployer: token address is zero"); // 3.2. Arbitrary transfer of vesting

        require(startTime < endTime, "SS_VestingDeployer: start time must be before end time");
        require(steps > 0, "SS_VestingDeployer: steps must be greater than 0");
        require(manager != address(0), "SS_VestingDeployer: manager not set");

        address newVesting = address(
            new SecondSwap_StepVesting(
                msg.sender,
                manager,
                IERC20(tokenAddress),
                startTime,
                endTime,
                steps,
                address(this)
            )
        );
        IVestingManager(manager).setSellable(newVesting, true);
        emit VestingDeployed(tokenAddress, newVesting, vestingId);
    }

    /**
     * @notice Sets the owner for a token
     * @dev Maps token address to owner address
     * @param token Address of the token
     * @param _owner Address to be set as owner
     * @custom:throws Existing token have owner
     */
    function setTokenOwner(address token, address _owner) external onlyAdmin {
        require(_tokenOwner[_owner] == address(0), "SS_VestingDeployer: Existing token have owner");
        _tokenOwner[_owner] = token;
    }

    /**
     * @notice Updates the manager address
     * @dev Sets new manager address for vesting management
     * @param _manager New manager address
     * @custom:throws Cannot assign the same address
     */
    function setManager(address _manager) external onlyAdmin {
        require(manager != _manager, "SS_VestingDeployer: Cannot assign the same address");
        manager = _manager;
    }

    /**
     * @notice Updates the admin address
     * @dev Sets new admin address for vesting management
     * @param _admin New admin address
     * @custom:throws Cannot assign the same address
     */
    function setAdmin(address _admin) external onlyAdmin {
        require(s2Admin != _admin, "SS_VestingDeployer: Cannot assign the same address");
        s2Admin = _admin;
    }

    /**
     * @notice Creates a new vesting schedule
     * @dev Creates vesting for a single beneficiary
     * @param _beneficiary Address receiving the vesting
     * @param _totalAmount Amount of tokens to vest
     * @param _stepVesting Address of the step vesting contract
     * @custom:throws SS_VestingDeployer: caller is not the token owner
     */
    function createVesting(address _beneficiary, uint256 _totalAmount, address _stepVesting) external {
        require(
            _tokenOwner[msg.sender] == address(SecondSwap_StepVesting(_stepVesting).token()),
            "SS_VestingDeployer: caller is not the token owner"
        ); // 3.2. Arbitrary transfer of vesting
        SecondSwap_StepVesting(_stepVesting).createVesting(_beneficiary, _totalAmount);
        emit VestingCreated(_beneficiary, _totalAmount, _stepVesting);
    }

    /**
     * @notice Creates multiple vesting schedules in batch
     * @dev Creates vestings for multiple beneficiaries
     * @param _beneficiaries Array of beneficiary addresses
     * @param _totalAmounts Array of vesting amounts
     * @param _stepVesting Address of the step vesting contract
     * @custom:throws SS_VestingDeployer: caller is not the token owner
     */
    function createVestings(
        address[] memory _beneficiaries,
        uint256[] memory _totalAmounts,
        address _stepVesting
    ) external {
        require(
            _tokenOwner[msg.sender] == address(SecondSwap_StepVesting(_stepVesting).token()),
            "SS_VestingDeployer: caller is not the token owner"
        ); // 3.2. Arbitrary transfer of vesting
        SecondSwap_StepVesting(_stepVesting).createVestings(_beneficiaries, _totalAmounts);
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            emit VestingCreated(_beneficiaries[i], _totalAmounts[i], _stepVesting);
        }
    }

    /**
     * @notice Transfers vesting between addresses
     * @dev Transfers vesting tokens from grantor to beneficiary
     * @param _grantor Address transferring the vesting
     * @param _beneficiary Address receiving the vesting
     * @param _amount Amount of tokens to transfer
     * @param _stepVesting Address of the step vesting contract
     * @param _transactionId Unique identifier for the transfer
     * @custom:throws SS_VestingDeployer: caller is not the token owner
     */
    function transferVesting(
        address _grantor,
        address _beneficiary,
        uint256 _amount,
        address _stepVesting,
        string memory _transactionId
    ) external {
        require(
            _tokenOwner[msg.sender] == address(SecondSwap_StepVesting(_stepVesting).token()),
            "SS_VestingDeployer: caller is not the token owner"
        ); // 3.2. Arbitrary transfer of vesting
        SecondSwap_StepVesting(_stepVesting).transferVesting(_grantor, _beneficiary, _amount);
        emit VestingTransferred(_grantor, _beneficiary, _amount, _stepVesting, _transactionId);
    }

    /**
     * @notice Returns the current version of the contract
     * @return String representing the contract version
     */
    function version() public pure returns (string memory) {
        return "1.0.0";
    }
}
