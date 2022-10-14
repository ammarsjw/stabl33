// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";

contract Stabl3Borrowing is Ownable, ReentrancyGuard {
    using SafeMathUpgradeable for uint256;

    uint8 private constant BORROW_POOL = 4;
    uint8 private constant EXCHANGE_POOL = 5;

    uint8 private constant COLLATERAL_STABL3_POOL = 6;

    uint8 private constant UCD_BORROW_POOL = 7;
    uint8 private constant UCD_BURN_POOL = 8;
    uint8 private constant UCD_RETURN_POOL = 9;

    IERC20 public immutable ucd;

    IERC20 public immutable stabl3;

    constructor() {
        ucd = IERC20(address(0));

        // TODO change
        stabl3 = IERC20(0xDf9c4990a8973b6cC069738592F27Ea54b27D569);
    }
}