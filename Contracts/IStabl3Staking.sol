// SPDX-License-Identifier: GNU GPLv3

pragma solidity ^0.8.0;

import "./IROI.sol";
import "./IStabl3StakingStruct.sol";

interface IStabl3Staking is IStabl3StakingStruct {

    function ROI() external view returns (IROI);

    function lendingStabl3Percentage() external view returns (uint256);
    function lendingStabl3ClaimTime() external view returns (uint256);

    function lockTimes(uint256) external view returns (uint256);

    function excludedFromROIReserves() external view returns (uint256);

    function getStakings(address, uint256) external view returns (Staking memory);

    function getStakers(uint256) external view returns (address);

    function getRecords(address, bool) external view returns (Record memory);

    function allStakersLength() external view returns (uint256);

    function allStakingsLength(address _user) external view returns (uint256);

    function allStakings(
        address _user,
        bool _isRealEstate
    ) external view returns (
        Staking[] memory unlockedLending,
        Staking[] memory lockedLending,
        Staking[] memory unlockedStaking,
        Staking[] memory lockedStaking
    );

    function stake(IERC20 _token, uint256 _amountToken, uint8 _stakingType, bool _isLending) external;

    function accessWithPermit(address _user, Staking memory _staking, uint8 _identifier) external;

    function getAmountRewardSingle(
        address _user,
        uint256 _index,
        bool _isLending,
        bool _isRealEstate,
        uint256 _timestamp
    ) external view returns (uint256);

    function getAmountRewardAll(address _user, bool _isLending, bool _isRealEstate) external view returns (uint256);

    function withdrawAmountRewardAll(bool _isLending) external;

    function getClaimableStabl3LendingSingle(
        address _user,
        uint256 _index,
        uint256 _timestamp
    ) external view returns (uint256);

    function getClaimableStabl3LendingAll(address _user) external view returns (uint256);

    function claimStabl3LendingAll() external;

    function getAmountStakedAll(
        address _user,
        bool _isLending,
        bool _isRealEstate
    ) external view returns (uint256 totalAmountStakedUnlocked, uint256 totalAmountStakedLocked);

    function restakeSingle(uint256 _index, uint256 _amountToUnstake, uint8 _stakingType) external;

    function unstakeSingle(uint256 _index) external;

    function unstakeMultiple(uint256[] memory _indexes) external;
}