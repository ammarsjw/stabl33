// SPDX-License-Identifier: GNU GPLv3

pragma solidity ^0.8.0;

import "./IERC20.sol";

interface IROI {

    function permitted(address) external returns (bool);

    function updateTreasury(address _treasury) external;

    function initializeUCD(address _ucd) external;

    function updatePermission(address _contractAddress, bool _state) external;

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

    function delegateApprove(IERC20 _token, address _spender, bool _isApprove) external;

    function withdrawFunds(IERC20 _token, uint256 _amountToken) external;

    function withdrawAllFunds(IERC20 _token) external;
}