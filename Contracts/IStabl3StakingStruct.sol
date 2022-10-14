// SPDX-License-Identifier: GNU GPLv3

pragma solidity ^0.8.0;

import "./IERC20.sol";

interface IStabl3StakingStruct {

    struct Staking {
        uint256 index;
        address user;
        bool status;
        uint8 stakingType;
        IERC20 token;
        uint256 amountTokenStaked;
        uint256 startTime;
        uint256 endTime;
        uint256 rewardWithdrawn;
        uint256 rewardWithdrawTimeLast;
        bool isLending;
        bool isClaimedStabl3Lending;
        uint256 amountTokenLending;
        uint256 amountStabl3Lending;
        bool isRealEstate;
    }

    struct Record {
        uint256 totalAmountTokenStaked;
        uint256 totalRewardWithdrawn;
        uint256 totalAmountStabl3Withdrawn;
    }
}