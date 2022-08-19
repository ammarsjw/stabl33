// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.16;

import "./IERC20.sol";

interface ITreasury {
    function provideInitialLiquidity(uint256 _amountStabl3) external;

    function updatePermission(address _contractAddress, bool _state) external;

    function isReservedToken(IERC20 _token) external view returns (bool);

    function updateReservedToken(IERC20 _token, uint256 _decimals, bool _state) external;

    function getDecimalsReservedToken(IERC20 _token) external view returns (uint256);

    function allReservedTokensLength() external view returns (uint256);

    function getRate() external view returns (uint256);

    function getAmountOut(IERC20 _token, uint256 _amountToken) external view returns (uint256);

    function getAmountIn(uint256 _amountStabl3, IERC20 _token) external view returns (uint256);

    function update() external;

    function approveTreasury(IERC20 token, address spender, bool isApprove) external;

    function withdrawFunds(IERC20 _token, uint256 _amountToken) external;

    function withdrawAllFunds(IERC20 _token) external;
}