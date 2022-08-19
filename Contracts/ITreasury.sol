// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.16;

import "./IERC20.sol";

interface ITreasury {
    function isReservedToken(IERC20 token) external view returns (bool);

    function getDecimalsReservedToken(IERC20 token) external view returns (uint256);
 
    function getAmountOut(IERC20 _token, uint256 _amountToken) external view returns (uint256);

    function update() external;
}