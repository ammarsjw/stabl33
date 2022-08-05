// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.15;

import "./IERC20.sol";

interface IStabl33BuyAndBond {
    function getTotalTokenAmounts(IERC20 token) external view returns (uint256);
}