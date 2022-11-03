// SPDX-License-Identifier: GNU GPLv3

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./IStabl3StakingStruct.sol";

interface IROI is IStabl3StakingStruct {

    function timeWeightedAPR() external view returns (TimeWeightedAPR memory);
    function updateAPRLast() external view returns (uint256);
    function updateTimestampLast() external view returns (uint256);

    function contractCreationTime() external view returns (uint256);

    function getTimeWeightedAPRs(uint256) external view returns (TimeWeightedAPR memory);
    function getAPRs(uint256) external view returns (uint256);

    function permitted(address) external returns (bool);

    function searchTimeWeightedAPR(uint256 _startTimeWeight, uint256 _endTimeWeight) external view returns (TimeWeightedAPR memory);

    function getTotalRewardDistributed() external view returns (uint256);

    function getReserves() external view returns (uint256);

    function getAPR() external view returns (uint256);

    function validatePool(
        IERC20 _token,
        uint256 _amountToken,
        uint8 _stakingType,
        bool _isLending
    ) external view returns (uint256 maxPool, uint256 currentPool);

    function distributeReward(
        address _user,
        IERC20 _rewardToken,
        uint256 _amountRewardToken,
        uint8 _poolType
    ) external;

    function updateAPR() external;

    function returnFunds(IERC20 _token, uint256 _amountToken, uint8[] memory _pools) external;
}