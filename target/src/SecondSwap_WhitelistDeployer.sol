// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SecondSwap_Whitelist.sol";
/**
 * @title SecondSwap Whitelist Deployer Contract
 * @notice Factory contract for deploying whitelist contracts
 * @dev Deploys new instances of SecondSwap_Whitelist contract for private sales
 */

contract SecondSwap_WhitelistDeployer {
    /**
     * @notice Emitted when a new whitelist contract is deployed
     * @param whitelistContract Address of the newly deployed whitelist contract
     * @param _lotOwner Address of the lot owner who will manage the whitelist
     */
    event WhitelistCreated(address indexed whitelistContract, address _lotOwner);

    /**
     * @notice Deploys a new whitelist contract
     * @dev Creates a new instance of SecondSwap_Whitelist with specified parameters
     * @param _maxWhitelist Maximum number of addresses that can be whitelisted
     * @param _lotOwner Address that will have owner rights to the whitelist
     * @return Address of the newly deployed whitelist contract
     */
    function deployWhitelist(uint256 _maxWhitelist, address _lotOwner) external returns (address) {
        address newWhitelist = address(new SecondSwap_Whitelist(_maxWhitelist, _lotOwner));
        emit WhitelistCreated(newWhitelist, _lotOwner);
        return newWhitelist;
    }
}
