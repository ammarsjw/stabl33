// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.16;

import "./IERC20.sol";

interface IStabl3PublicSale {
    function getAmountReservedTokenPooled(IERC20 token) external view returns (uint256);
}