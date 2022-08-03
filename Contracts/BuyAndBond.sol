// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.15;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";

contract BuyAndBond is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public treasuryPool = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;
    address public ROIPool = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

    IERC20 usdc = IERC20(0x8Af5a6599BD2406C44588FCf84FD6Eb1bB2e0243);
    IERC20 dai = IERC20(0xA83a21816ae63D3315c540396f887F53cfF274fA);

    IERC20 stabl3 = IERC20(0x20A91B0d2A5545BF05bcA96778e138E2E154e083);

    constructor() {
    }
}