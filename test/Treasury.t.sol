// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "../lib/forge-std/src/Test.sol";

import "../contracts/Treasury.sol";
import "../contracts/ROI.sol";
import "../contracts/Stabl3PublicSale.sol";

contract TreasuryTest is Test {

    Treasury treasury;
    ROI roi;
    address hq;

    Stabl3PublicSale publicSale;

    /// @dev Invoked before each test.
    function setUp() public {
    }
}