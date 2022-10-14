// SPDX-License-Identifier: GNU GPLv3

pragma solidity ^0.8.0;

import "./IStabl3StakingStruct.sol";

interface IStabl3Staking is IStabl3StakingStruct {

    function lendingStabl3Percentage() external view returns (uint256);

    function getStakings(address) external view returns (Staking[] memory);

    function getStakers(address) external view returns (bool);
    function allStakers(uint256) external view returns (address);

    function getRecords(address, bool) external view returns (Record memory);

    function getAmountStakedPerStakingType(uint8) external view returns (uint256);

    function updateTreasury(address _treasury) external;

    function updateROI(address _ROI) external;

    function updateHQ(address _HQ) external;

    function updateDistributionPercentages(
        uint256 _treasuryPercentage,
        uint256 _ROIPercentage,
        uint256 _HQPercentage,
        uint256 _lendingStabl3Percentage,
        bool _isLending
    ) external;

    function updateUnstakeFeePercentage(uint256 _unstakeFeePercentage) external;

    function updateLockTimes(uint256[4] memory _lockTimes) external;

    function updateLendingStabl3ClaimTime(uint256 _lendingStabl3ClaimTime) external;

    function updateStabl3RealEstate(address _stabl3RealEstate) external;

    function updateStakeState(bool _state) external;

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

    function restakeSingle(uint256 _index, uint256 _amountToWithdraw, uint8 _stakingType) external;

    function unstakeSingle(uint256 _index) external;

    function unstakeMultiple(uint256[] memory _indexes) external;
}