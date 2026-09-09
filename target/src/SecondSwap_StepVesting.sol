// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interface/SecondSwap_Vesting.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; //  3.6. DOS caused by the use of transfer and transferFrom functions

/**
 * @title SecondSwap Step Vesting Contract
 * @notice Manages token vesting with linear steps over time
 * @dev Implements SecondSwap_Vesting interface for step-based token vesting
 */
contract SecondSwap_StepVesting is SecondSwap_Vesting {
    using SafeERC20 for IERC20;

    /**
     * @notice Emitted when a new vesting schedule is created
     * @param beneficiary Address receiving the vested tokens
     * @param totalAmount Total amount of tokens being vested
     */
    event VestingCreated(address indexed beneficiary, uint256 totalAmount);

    /**
     * @notice Emitted when vesting is transferred between addresses
     * @param grantor Address transferring the vesting
     * @param beneficiary Address receiving the vesting
     * @param amount Amount of tokens transferred
     */
    event VestingTransferred(address indexed grantor, address indexed beneficiary, uint256 amount);

    /**
     * @notice Emitted when tokens are claimed from vesting
     * @param beneficiary Address claiming the tokens
     * @param amount Amount of tokens claimed
     */
    event Claimed(address indexed beneficiary, uint256 amount);

    /**
     * @notice The ERC20 token being vested
     */
    IERC20 public immutable token;

    /**
     * @notice Structure containing vesting details for each beneficiary
     * @param stepsClaimed Number of vesting steps already claimed
     * @param amountClaimed Total amount of tokens claimed so far
     * @param releaseRate Number of tokens released per step
     * @param totalAmount Total amount of tokens in the vesting schedule
     */
    struct Vesting {
        uint256 stepsClaimed;
        uint256 amountClaimed;
        uint256 releaseRate;
        uint256 totalAmount;
    }

    /**
     * @notice Start time of the vesting schedule
     */
    uint256 public immutable startTime;

    /**
     * @notice End time of the vesting schedule
     */
    uint256 public immutable endTime;

    /**
     * @notice Total number of vesting steps
     */
    uint256 public immutable numOfSteps;

    /**
     * @notice Duration of each vesting step
     */
    uint256 public immutable stepDuration;

    /**
     * @notice Mapping of beneficiary addresses to their vesting details
     */
    mapping(address => Vesting) public _vestings;

    /**
     * @notice Address of the vesting deployer contract
     */
    address public vestingDeployer;

    /**
     * @notice Address of the manager contract
     */
    address public manager;

    /**
     * @notice Address of the token issuer
     */
    address public tokenIssuer;

    /**
     * @notice Restricts function access to manager only
     * @dev Throws if called by any account other than the manager
     */
    modifier onlyManager() {
        require(msg.sender == manager, "SS_StepVesting: caller is not the manager");
        _;
    }

    /**
     * @notice Initializes the vesting contract
     * @param _tokenIssuer Address authorized to issue tokens
     * @param _manager Address of the manager contract
     * @param _token Address of the ERC20 token
     * @param _startTime Start time of vesting schedule
     * @param _endTime End time of vesting schedule
     * @param _numOfSteps Number of vesting steps
     * @param _vestingDeployer Address of vesting deployer contract
     */
    constructor(
        address _tokenIssuer,
        address _manager,
        IERC20 _token,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _numOfSteps,
        address _vestingDeployer
    ) {
        vestingDeployer = _vestingDeployer;
        tokenIssuer = _tokenIssuer;
        manager = _manager;
        token = _token;
        startTime = _startTime;
        endTime = _endTime;
        numOfSteps = _numOfSteps;
        stepDuration = (_endTime - _startTime) / _numOfSteps;
    }

    /**
     * @notice Returns available (unclaimed) tokens for a beneficiary
     * @param _beneficiary Address to check
     * @return Amount of tokens available to claim
     */
    function available(address _beneficiary) external view returns (uint256) {
        return _vestings[_beneficiary].totalAmount - _vestings[_beneficiary].amountClaimed;
    }

    /**
     * @notice Returns total vesting amount for a beneficiary
     * @param _beneficiary Address to check
     * @return Total amount of tokens in vesting schedule
     */
    function total(address _beneficiary) external view returns (uint256) {
        return _vestings[_beneficiary].totalAmount;
    }

    /**
     * @notice Calculates claimable tokens for a beneficiary
     * @dev Returns both claimable amount and number of steps that can be claimed
     * @param _beneficiary Address to calculate for
     * @return Amount of tokens claimable
     * @return Number of steps claimable
     */
    function claimable(address _beneficiary) public view returns (uint256, uint256) {
        Vesting memory vesting = _vestings[_beneficiary];
        if (vesting.totalAmount == 0) {
            return (0, 0);
        }

        uint256 currentTime = Math.min(block.timestamp, endTime);
        if (currentTime < startTime) {
            return (0, 0);
        }

        uint256 elapsedTime = currentTime - startTime;
        uint256 currentStep = elapsedTime / stepDuration;
        uint256 claimableSteps = currentStep - vesting.stepsClaimed;

        uint256 claimableAmount;

        if (vesting.stepsClaimed + claimableSteps >= numOfSteps) {
            //[BUG FIX] user can buy more than they are allocated
            claimableAmount = vesting.totalAmount - vesting.amountClaimed;
            return (claimableAmount, claimableSteps);
        }

        claimableAmount = vesting.releaseRate * claimableSteps;
        return (claimableAmount, claimableSteps);
    }

    /**
     * @notice Claims available tokens
     * @dev Transfers claimable tokens to msg.sender
     * @custom:throws SS_StepVesting: nothing to claim
     */
    function claim() external {
        (uint256 claimableAmount, uint256 claimableSteps) = claimable(msg.sender);
        require(claimableAmount > 0, "SS_StepVesting: nothing to claim");

        Vesting storage vesting = _vestings[msg.sender];
        vesting.stepsClaimed += claimableSteps;
        vesting.amountClaimed += claimableAmount;

        token.safeTransfer(msg.sender, claimableAmount); //  3.6. DOS caused by the use of transfer and transferFrom functions
        emit Claimed(msg.sender, claimableAmount);
    }

    /**
     * @notice Transfers vesting from one address to another
     * @dev Can only be called by authorized addresses
     * @param _grantor Address transferring the vesting
     * @param _beneficiary Address receiving the vesting
     * @param _amount Amount of tokens to transfer
     * @custom:throws SS_StepVesting: unauthorized
     * @custom:throws SS_StepVesting: beneficiary is zero
     * @custom:throws SS_StepVesting: amount is zero
     * @custom:throws SS_StepVesting: insufficient balance
     */
    function transferVesting(address _grantor, address _beneficiary, uint256 _amount) external {
        require(
            msg.sender == tokenIssuer || msg.sender == manager || msg.sender == vestingDeployer,
            "SS_StepVesting: unauthorized"
        );
        require(_beneficiary != address(0), "SS_StepVesting: beneficiary is zero");
        require(_amount > 0, "SS_StepVesting: amount is zero");
        Vesting storage grantorVesting = _vestings[_grantor];
        require(
            grantorVesting.totalAmount - grantorVesting.amountClaimed >= _amount,
            "SS_StepVesting: insufficient balance"
        ); // 3.8. Claimed amount not checked in transferVesting function

        grantorVesting.totalAmount -= _amount;
        grantorVesting.releaseRate = grantorVesting.totalAmount / numOfSteps;

        _createVesting(_beneficiary, _amount, grantorVesting.stepsClaimed, true);

        emit VestingTransferred(_grantor, _beneficiary, _amount);
    }

    /**
     * @notice Creates a new vesting schedule for a beneficiary
     * @dev Can only be called by authorized addresses
     * @param _beneficiary Address to receive the vesting
     * @param _totalAmount Total amount of tokens to vest
     * @custom:throws SS_StepVesting: unauthorized
     */
    function createVesting(address _beneficiary, uint256 _totalAmount) external {
        require(
            msg.sender == tokenIssuer || msg.sender == manager || msg.sender == vestingDeployer,
            "SS_StepVesting: unauthorized"
        );
        _createVesting(_beneficiary, _totalAmount, 0, false);
    }

    /**
     * @notice Creates multiple vesting schedules in batch
     * @dev Can only be called by authorized addresses
     * @param _beneficiaries Array of addresses to receive vesting
     * @param _totalAmounts Array of token amounts to vest
     * @custom:throws SS_StepVesting: unauthorized
     * @custom:throws SS_StepVesting: array length mismatch
     */
    function createVestings(address[] memory _beneficiaries, uint256[] memory _totalAmounts) external {
        require(msg.sender == tokenIssuer || msg.sender == manager || msg.sender == vestingDeployer, "unauthorized");
        require(_beneficiaries.length == _totalAmounts.length, "SS_StepVesting: array length mismatch");

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            _createVesting(_beneficiaries[i], _totalAmounts[i], 0, false);
        }
    }

    /**
     * @notice Internal function to create vesting schedule
     * @dev Handles both new vestings and additions to existing vestings
     * @param _beneficiary Address to receive vesting
     * @param _totalAmount Amount of tokens to vest
     * @param _stepsClaimed Number of steps already claimed (for transfers)
     * @param _isInternal Whether this is an internal transfer
     * @custom:throws SS_StepVesting: beneficiary is zero
     * @custom:throws SS_StepVesting: total amount is zero
     */
    function _createVesting(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _stepsClaimed,
        bool _isInternal
    ) internal {
        require(_beneficiary != address(0), "SS_StepVesting: beneficiary is zero");
        require(_totalAmount > 0, "SS_StepVesting: total amount is zero");

        if (_vestings[_beneficiary].totalAmount == 0) {
            _vestings[_beneficiary] = Vesting({
                stepsClaimed: _stepsClaimed,
                amountClaimed: 0,
                releaseRate: _totalAmount / (numOfSteps - _stepsClaimed),
                totalAmount: _totalAmount
            });
        } else {
            _vestings[_beneficiary].totalAmount += _totalAmount;
            if (numOfSteps - _vestings[_beneficiary].stepsClaimed != 0) {
                _vestings[_beneficiary].releaseRate =
                    (_vestings[_beneficiary].totalAmount - _vestings[_beneficiary].amountClaimed) /
                    (numOfSteps - _vestings[_beneficiary].stepsClaimed);
            } else {
                _vestings[_beneficiary].releaseRate = 0;
            }
        }

        if (!_isInternal) {
            token.safeTransferFrom(tokenIssuer, address(this), _totalAmount);
        }
        emit VestingCreated(_beneficiary, _totalAmount);
    }
}
