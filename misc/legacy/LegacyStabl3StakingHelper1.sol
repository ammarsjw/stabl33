// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "../../Contracts/SafeMathUpgradeable.sol";

import "../../Contracts/IROI.sol";
import "../../Contracts/IStabl3Staking.sol";
import "../../Contracts/IStabl3StakingStruct.sol";

contract Stabl3StakingHelper is IStabl3StakingStruct {
    using SafeMathUpgradeable for uint256;

    IStabl3Staking public stabl3Staking;

    uint256 private oneDayTime;
    uint256 private oneYearTime;

    // constructor

    constructor() {
        stabl3Staking = IStabl3Staking(msg.sender);

        // TODO remove
        oneDayTime = 8 minutes;
        oneYearTime = 48 hours;
        // oneDayTime = 86400;
        // oneYearTime = 31104000;
    }

    //TODO remove
    function updateLockTimes(uint256[5] memory _lockTimes) external {
        oneDayTime = _lockTimes[1].div(90);
        oneYearTime = _lockTimes[4];
    }

    function allStakings(
        address _user,
        bool _isRealEstate
    ) public view returns (
        Staking[] memory unlockedLending,
        Staking[] memory lockedLending,
        Staking[] memory unlockedStaking,
        Staking[] memory lockedStaking
    ) {
        uint256 unlockedLendingLength;
        uint256 lockedLendingLength;
        uint256 unlockedStakingLength;
        uint256 lockedStakingLength;

        for (uint256 i = 0 ; i < stabl3Staking.allStakingsLength(_user) ; i++) {
            Staking memory staking = stabl3Staking.getStakings(_user, i);

            if (
                staking.status &&
                staking.isRealEstate == _isRealEstate
            ) {
                if (block.timestamp >= staking.startTime + stabl3Staking.lockTimes(staking.stakingType)) {
                    if (staking.isLending) {
                        unlockedLendingLength++;
                    }
                    else {
                        unlockedStakingLength++;
                    }
                }
                else {
                    if (staking.isLending) {
                        lockedLendingLength++;
                    }
                    else {
                        lockedStakingLength++;
                    }
                }
            }
        }

        unlockedLending = new Staking[](unlockedLendingLength);
        lockedLending = new Staking[](lockedLendingLength);
        unlockedStaking = new Staking[](unlockedStakingLength);
        lockedStaking = new Staking[](lockedStakingLength);

        unlockedLendingLength = 0;
        lockedLendingLength = 0;
        unlockedStakingLength = 0;
        lockedStakingLength = 0;

        for (uint256 i = 0 ; i < stabl3Staking.allStakingsLength(_user) ; i++) {
            Staking memory staking = stabl3Staking.getStakings(_user, i);

            if (
                staking.status &&
                staking.isRealEstate == _isRealEstate
            ) {
                if (block.timestamp >= staking.startTime + stabl3Staking.lockTimes(staking.stakingType)) {
                    if (staking.isLending) {
                        unlockedLending[unlockedLendingLength] = staking;
                        unlockedLendingLength++;
                    }
                    else {
                        unlockedStaking[unlockedStakingLength] = staking;
                        unlockedStakingLength++;
                    }
                }
                else {
                    if (staking.isLending) {
                        lockedLending[lockedLendingLength] = staking;
                        lockedLendingLength++;
                    }
                    else {
                        lockedStaking[lockedStakingLength] = staking;
                        lockedStakingLength++;
                    }
                }
            }
        }
    }

    function getAmountRewardSingle(
        address _user,
        uint256 _index,
        bool _isLending,
        bool _isRealEstate,
        uint256 _timestamp
    ) public view returns (uint256) {
        // uint256 amountReward;

        // Staking memory staking = stabl3Staking.getStakings(_user, _index);

        // uint256 endTime = staking.startTime + stabl3Staking.lockTimes(staking.stakingType);

        // if (
        //     staking.status &&
        //     staking.isLending == _isLending &&
        //     staking.isRealEstate == _isRealEstate &&
        //     staking.rewardWithdrawTimeLast < endTime
        // ) {
        //     uint256 timestampToConsider = _timestamp > endTime ? endTime : _timestamp;

        //     if (staking.stakingAPRIndexLast == stabl3Staking.ROI().allStakingAPRsLength() - 1) {
        //         uint256 numberOfDays = (timestampToConsider - staking.rewardWithdrawTimeLast) / oneDayTime;

        //         if (numberOfDays > 0) {
        //             uint256 ratio = stabl3Staking.ROI().allStakingAPRs(staking.stakingAPRIndexLast).APR;

        //             uint256 rewardTotal = _compoundSingle(staking.amountTokenStaked, ratio);

        //             amountReward += (rewardTotal * oneDayTime * numberOfDays) / oneYearTime;
        //         }
        //     }
        //     else {
        //         uint256 stakingAPRIndex = staking.stakingAPRIndexLast;

        //         StakingAPR memory stakingAPR = stabl3Staking.ROI().allStakingAPRs(stakingAPRIndex);
        //         StakingAPR memory stakingAPRNext = stabl3Staking.ROI().allStakingAPRs(stakingAPRIndex + 1);

        //         if (stakingAPRNext.timestamp < timestampToConsider) {
        //             uint256 numberOfDays = (stakingAPRNext.timestamp - staking.rewardWithdrawTimeLast) / oneDayTime;

        //             if (numberOfDays > 0) {
        //                 uint256 ratio = stakingAPR.APR;

        //                 uint256 rewardTotal = _compoundSingle(staking.amountTokenStaked, ratio);

        //                 amountReward += (rewardTotal * oneDayTime * numberOfDays) / oneYearTime;
        //             }

        //             stakingAPRIndex++;

        //             for ( ; stakingAPRIndex < stabl3Staking.ROI().allStakingAPRsLength() - 1 ; stakingAPRIndex++) {
        //                 stakingAPR = stabl3Staking.ROI().allStakingAPRs(stakingAPRIndex);
        //                 stakingAPRNext = stabl3Staking.ROI().allStakingAPRs(stakingAPRIndex + 1);

        //                 if (stakingAPRNext.timestamp < timestampToConsider) {
        //                     numberOfDays = (stakingAPRNext.timestamp - stakingAPR.timestamp) / oneDayTime;

        //                     if (numberOfDays > 0) {
        //                         uint256 ratio = stakingAPR.APR;

        //                         uint256 rewardTotal = _compoundSingle(staking.amountTokenStaked, ratio);

        //                         amountReward += (rewardTotal * oneDayTime * numberOfDays) / oneYearTime;
        //                     }
        //                 }
        //                 else {
        //                     break;
        //                 }
        //             }

        //             stakingAPR = stabl3Staking.ROI().allStakingAPRs(stakingAPRIndex);

        //             numberOfDays = (timestampToConsider - stakingAPR.timestamp) / oneDayTime;

        //             if (numberOfDays > 0) {
        //                 uint256 ratio = stakingAPR.APR;

        //                 uint256 rewardTotal = _compoundSingle(staking.amountTokenStaked, ratio);

        //                 amountReward += (rewardTotal * oneDayTime * numberOfDays) / oneYearTime;
        //             }
        //         }
        //         else {
        //             uint256 numberOfDays = (timestampToConsider - staking.rewardWithdrawTimeLast) / oneDayTime;

        //             if (numberOfDays > 0) {
        //                 uint256 ratio = stakingAPR.APR;

        //                 uint256 rewardTotal = _compoundSingle(staking.amountTokenStaked, ratio);

        //                 amountReward += (rewardTotal * oneDayTime * numberOfDays) / oneYearTime;
        //             }
        //         }
        //     }
        // }

        // return amountReward;
    }

    function getAmountRewardAll(address _user, bool _isLending, bool _isRealEstate) public view returns (uint256) {
        uint256 totalAmountReward;

        uint256 timestampToConsider = block.timestamp;

        for (uint256 i = 0 ; i < stabl3Staking.allStakingsLength(_user) ; i++) {
            Staking memory staking = stabl3Staking.getStakings(_user, i);

            if (
                staking.isLending == _isLending &&
                staking.isRealEstate == _isRealEstate
            ) {
                uint256 amountReward = getAmountRewardSingle(_user, i, _isLending,_isRealEstate, timestampToConsider);

                if (amountReward > 0) {
                    if (staking.token.decimals() < 18) {
                        amountReward *= 10 ** (18 - staking.token.decimals());
                    }

                    totalAmountReward += amountReward;
                }
            }
        }

        return totalAmountReward;
    }

    function getClaimableStabl3LendingSingle(
        address _user,
        uint256 _index,
        uint256 _timestamp
    ) public view returns (uint256) {
        uint256 claimableStabl3Lending;

        Staking memory staking = stabl3Staking.getStakings(_user, _index);

        if (
            staking.status &&
            staking.isLending &&
            staking.amountStabl3Lending > 0 &&
            _timestamp > staking.startTime + stabl3Staking.lendingStabl3ClaimTime()
        ) {
            claimableStabl3Lending = staking.amountStabl3Lending;
        }

        return claimableStabl3Lending;
    }

    function getClaimableStabl3LendingAll(address _user) public view returns (uint256) {
        uint256 totalClaimableStabl3Lending;

        uint256 timestampToConsider = block.timestamp;

        for (uint256 i = 0 ; i < stabl3Staking.allStakingsLength(_user) ; i++) {
            uint256 claimableStabl3Lending = getClaimableStabl3LendingSingle(_user, i, timestampToConsider);

            if (claimableStabl3Lending > 0) {
                totalClaimableStabl3Lending += claimableStabl3Lending;
            }
        }

        return totalClaimableStabl3Lending;
    }

    function getAmountStakedAll(
        address _user,
        bool _isLending,
        bool _isRealEstate
    ) external view returns (uint256 totalAmountStakedUnlocked, uint256 totalAmountStakedLocked) {
        Staking[] memory unlocked;
        Staking[] memory locked;

        if (_isLending) {
            (unlocked, locked, , ) = allStakings(_user, _isRealEstate);
        }
        else {
            (, , unlocked, locked) = allStakings(_user, _isRealEstate);
        }

        uint256 maxLength = unlocked.length.max(locked.length);

        for (uint256 i = 0 ; i < maxLength ; i++) {
            if (i < unlocked.length) {
                uint256 amountStakedUnlocked = unlocked[i].amountTokenStaked;

                if (unlocked[i].token.decimals() < 18) {
                    amountStakedUnlocked *= 10 ** (18 - unlocked[i].token.decimals());
                }

                totalAmountStakedUnlocked += amountStakedUnlocked;
            }

            if (i < locked.length) {
                uint256 amountStakedLocked = locked[i].amountTokenStaked;

                if (locked[i].token.decimals() < 18) {
                    amountStakedLocked *= 10 ** (18 - locked[i].token.decimals());
                }

                totalAmountStakedLocked += amountStakedLocked;
            }
        }
    }

    function _compoundSingle(uint256 _principal, uint256 _ratio) internal pure returns (uint256) {
        uint256 accruedAmount = _principal.mul(_ratio).div(10 ** 18);

        return accruedAmount;
    }
}