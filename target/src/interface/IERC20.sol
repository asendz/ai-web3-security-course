// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Extended interface of the ERC20 standard.
 * Adds decimals() function on top of standard IERC20 interface.
 */
interface IERC20Extended is IERC20 {
    /**
     * @dev Returns the decimals places of the token.
     * For example, if decimals equals 2, a balance of 505 tokens should be displayed as 5.05
     * Tokens usually opt for a value of 18, imitating the relationship between Ether and Wei.
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() external view returns (uint8);
}
