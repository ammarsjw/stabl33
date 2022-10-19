// SPDX-License-Identifier: GNU GPLv3

pragma solidity ^0.8.0;

import "./IERC20.sol";

interface IROI {

    function permitted(address) external returns (bool);

    function getTotalRewardDistributed() external view returns (uint256);

    function getReserves() external view returns (uint256);

    function getAPR() external view returns (uint256);

    function validatePool(
        IERC20 _token,
        uint256 _amountToken,
        uint8 _stakingType,
        bool _isLending
    ) external view returns (uint256 maxPool, uint256 currentPool);

    function updateAPR() external;

    function returnFunds(IERC20 _token, uint256 _amountToken, uint8[] memory _pools) external;
}