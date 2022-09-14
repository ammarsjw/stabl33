// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./ABDKMath64x64.sol";
import "./SafeERC20.sol";

import "./ITreasury.sol";
import "./IROI.sol";

contract Stabl3Staking is Ownable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20 for IERC20;

    uint8 private constant BUY_POOL = 0;
    uint8 private constant BOND_POOL = 1;
    uint8 private constant STAKE_POOL = 2;
    uint8 private constant LEND_POOL = 3;

    uint8 private constant STAKE_REWARD_DISTRIBUTED = 6;
    uint8 private constant LEND_REWARD_DISTRIBUTED = 7;

    ITreasury public treasury;
    IROI public ROI;
    address public HQ;

    IERC20 public stabl3;

    uint256[] public treasuryPercentages;
    uint256[] public ROIPercentages;
    uint256[] public HQPercentages;

    uint256 public unstakeFeePercentage;

    uint256 public maxPoolPercentage;

    uint256 oneMinuteTime;
    uint256 oneYearTime;
    uint256[4] public lockTimes;

    uint256 public lendingStabl3ClaimTime;

    bool public stakeState;

    // structs

    struct Staking {
        uint256 index;
        address user;
        bool status;
        uint8 stakingType;
        IERC20 token;
        uint256 amountTokenStaked;
        uint256 amountTokenStakedInitial;
        uint256 startTime;
        uint256 rewardWithdrawn;
        uint256 rewardWithdrawTimeLast;
        bool isLending;
        bool isClaimedStabl3Lending;
        uint256 amountTokenLending;
        uint256 amountStabl3Lending;
    }

    struct Values {
        uint256 totalAmountTokenStaked;
        uint256 totalRewardWithdrawn;
        uint256 totalAmountStabl3Lending;
    }

    // mappings

    // user staking
    mapping (address => Staking[]) public getStakings;

    mapping (address => Values) public getValues;

    // events

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedHQ(address newHQ, address oldHQ);

    event UpdatedUnstakeFeePercentage(uint256 newUnstakeFeePercentage, uint256 oldUnstakeFeePercentage);

    event UpdatedLockTime(uint256[4] newLockTimes, uint256[4] oldLockTimes);

    event UpdatedLendingStabl3Percentage(uint256 newLendingStabl3Percentage, uint256 oldLendingStabl3Percentage);

    event UpdatedLendingStabl3ClaimTime(uint256 newLendingStabl3ClaimTime, uint256 oldLendingStabl3ClaimTime);

    event Stake(
        address indexed user,
        uint256 index,
        uint8 stakingType,
        IERC20 token,
        uint256 amountToken,
        uint256 totalAmountToken,
        bool isLend,
        uint256 timestamp
    );

    event WithdrewReward(
        address indexed user,
        uint256 index,
        IERC20 token,
        uint256 rewardWithdrawn,
        uint256 totalRewardWithdrawn,
        bool isLend,
        uint256 timestamp
    );

    event ClaimedLendingStabl3(
        address indexed user,
        uint256 index,
        IERC20 token,
        uint256 amountTokenLending,
        uint256 amountStabl3Lending,
        uint256 totalAmountStabl3Lending,
        uint256 timestamp
    );

    event WithdrewAmountStaked(address indexed user, uint256 index, IERC20 token, uint256 amountWithdrawn, bool isLend);

    event Unstake(address indexed user, uint256 index, IERC20 token, uint256 amountToken, uint256 reward, uint8 stakingType, bool isLend);

    // constructor

    constructor(address _treasury, address _ROI) {
        treasury = ITreasury(_treasury);
        ROI = IROI(_ROI);
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        stabl3 = IERC20(0xDf9c4990a8973b6cC069738592F27Ea54b27D569);

        treasuryPercentages = [975, 800];
        ROIPercentages = [0, 175];
        HQPercentages = [25, 25];

        unstakeFeePercentage = 50;

        maxPoolPercentage = 700;

        oneMinuteTime = 60;
        oneYearTime = 31536000;
        lockTimes = [7776000, 15552000, 23328000, 31104000];   // 3, 6, 9 and 12 months time in seconds

        lendingStabl3ClaimTime = 2592000;
    }

    function updateTreasury(address _treasury) external onlyOwner {
        require(address(treasury) != _treasury, "Stabl3Staking: Treasury is already this address");
        emit UpdatedTreasury(_treasury, address(treasury));
        treasury = ITreasury(_treasury);
    }

    function updateROI(address _ROI) external onlyOwner {
        require(address(ROI) != _ROI, "Stabl3Staking: ROI is already this address");
        emit UpdatedROI(_ROI, address(ROI));
        ROI = IROI(_ROI);
    }

    function updateHQ(address _HQ) external onlyOwner {
        require(HQ != _HQ, "Stabl3Staking: HQ is already this address");
        emit UpdatedHQ(_HQ, HQ);
        HQ = _HQ;
    }

    function updateDistributionPercentages(
        uint256[2] memory _treasuryPercentages,
        uint256[2] memory _ROIPercentages,
        uint256[2] memory _HQPercentages
    ) external onlyOwner {
        require(_treasuryPercentages[0] + _ROIPercentages[0] + _HQPercentages[0] == 1000,
            "Stabl3Staking: Sum of magnified Stake percentages should equal 1000");
        require(_treasuryPercentages[1] + _ROIPercentages[1] + _HQPercentages[1] == 1000,
            "Stabl3Staking: Sum of magnified Lend percentages should equal 1000");

        treasuryPercentages = _treasuryPercentages;
        ROIPercentages = _ROIPercentages;
        HQPercentages = _HQPercentages;
    }

    function updateUnstakeFeePercentage(uint256 _unstakeFeePercentage) external onlyOwner {
        require(unstakeFeePercentage != _unstakeFeePercentage, "Stabl3Staking: Unstake Fee is already this value");
        emit UpdatedUnstakeFeePercentage(_unstakeFeePercentage, unstakeFeePercentage);
        unstakeFeePercentage = _unstakeFeePercentage;
    }

    function updateMaxPoolPercentage(uint256 _maxPoolPercentage) external onlyOwner {
        require(maxPoolPercentage != _maxPoolPercentage, "Stabl3Staking: Max Pool Percentage is already this value");
        maxPoolPercentage = _maxPoolPercentage;
    }

    function updateLockTimes(uint256[4] memory _lockTimes) external onlyOwner {
        emit UpdatedLockTime(_lockTimes, lockTimes);
        lockTimes = _lockTimes;
    }

    function updateLendingStabl3ClaimTime(uint256 _lendingStabl3ClaimTime) external onlyOwner {
        require(lendingStabl3ClaimTime != _lendingStabl3ClaimTime, "Stabl3Staking: Lending Stabl3 Claim Time is already this value");
        emit UpdatedLendingStabl3ClaimTime(_lendingStabl3ClaimTime, lendingStabl3ClaimTime);
        lendingStabl3ClaimTime = _lendingStabl3ClaimTime;
    }

    function updateStakeState(bool _state) external onlyOwner {
        require(stakeState != _state, "Stabl3Staking: Stake State is already of the value 'state'");
        stakeState = _state;
    }

    function allStakingsLength(address _user) external view returns (uint256) {
        return getStakings[_user].length;
    }

    function allStakings(
        address _user
    ) external view returns (
        Staking[] memory unlockedLending,
        Staking[] memory lockedLending,
        Staking[] memory unlockedStaking,
        Staking[] memory lockedStaking
    ) {
        for (uint256 i = 0 ; i < getStakings[_user].length ; i++) {
            Staking memory staking = getStakings[_user][i];

            if (staking.status && staking.amountTokenStaked > 0) {
                uint256 endTime = staking.startTime + lockTimes[staking.stakingType - 1];

                if (block.timestamp >= endTime) {
                    if (staking.isLending) {
                        unlockedLending[unlockedLending.length] = staking;
                    }
                    else {
                        unlockedStaking[unlockedStaking.length] = staking;
                    }
                }
                else {
                    if (staking.isLending) {
                        lockedLending[lockedLending.length] = staking;
                    }
                    else {
                        lockedStaking[lockedStaking.length] = staking;
                    }
                }
            }
        }
    }

    function validatePool(IERC20 _token, uint256 _amountToken) public view stakeActive reserved(_token) returns (bool) {
        uint256 maxPool;
        uint256 currentPool;

        for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
            IERC20 reservedToken = treasury.allReservedTokens(i);
            if (treasury.isReservedToken(reservedToken)) {
                uint256 boughtAmountReservedToken = treasury.getTreasuryPool(BUY_POOL, reservedToken);
                uint256 bondedAmountReservedToken = treasury.getTreasuryPool(BOND_POOL, reservedToken);

                uint256 stakedAmountReservedToken = treasury.sumOfAllPools(STAKE_POOL, reservedToken);
                uint256 lendedAmountReservedToken = treasury.sumOfAllPools(LEND_POOL, reservedToken);

                uint256 decimalsReservedToken = reservedToken.decimals();

                if (decimalsReservedToken < 18) {
                    boughtAmountReservedToken = boughtAmountReservedToken * (10 ** (18 - decimalsReservedToken));
                    bondedAmountReservedToken = bondedAmountReservedToken * (10 ** (18 - decimalsReservedToken));
                    stakedAmountReservedToken = stakedAmountReservedToken * (10 ** (18 - decimalsReservedToken));
                    lendedAmountReservedToken = lendedAmountReservedToken * (10 ** (18 - decimalsReservedToken));
                }

                maxPool += boughtAmountReservedToken + bondedAmountReservedToken;
                currentPool += stakedAmountReservedToken + lendedAmountReservedToken;
            }
        }

        maxPool = maxPool.mul(maxPoolPercentage).div(1000);

        if (_token.decimals() < 18) {
            _amountToken = _amountToken.mul(10 ** (18 - _token.decimals()));
        }

        bool isValid = (currentPool + _amountToken) <= maxPool;

        return isValid;
    }

    function stake(IERC20 _token, uint256 _amountToken, uint8 _stakingType, bool _isLending) external stakeActive reserved(_token) {
        require(_amountToken > 0, "Stabl3Staking: Amount should be greater than zero");
        require(1 <= _stakingType && _stakingType <= 4, "Stabl3Staking: Incorrect staking type");
        require(validatePool(_token, _amountToken), "Stabl3Staking: Staking pool limit reached");

        uint256 amountTokenLending;
        uint256 amountStabl3Lending;

        if (_isLending) {
            uint256 amountTreasury = _amountToken.mul(treasuryPercentages[1]).div(1000).add(1);
            SafeERC20.safeTransferFrom(_token, msg.sender, address(treasury), amountTreasury);

            uint256 amountROI = _amountToken.mul(ROIPercentages[1]).div(1000);
            amountStabl3Lending = treasury.getAmountOut(_token, amountROI);
            _amountToken -= amountROI;
            SafeERC20.safeTransferFrom(_token, msg.sender, address(ROI), amountROI);
            amountTokenLending = amountROI;

            uint256 amountHQ = _amountToken.mul(HQPercentages[1]).div(1000);
            SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);

            _amountToken = amountTreasury + amountHQ;

            treasury.updatePool(STAKE_POOL, _token, amountTreasury, amountROI, amountHQ, true);
            treasury.updateRate(_token, amountROI);
        }
        else {
            uint256 amountTreasury = _amountToken.mul(treasuryPercentages[0]).div(1000).add(1);
            SafeERC20.safeTransferFrom(_token, msg.sender, address(treasury), amountTreasury);

            uint256 amountROI = _amountToken.mul(ROIPercentages[0]).div(1000);
            SafeERC20.safeTransferFrom(_token, msg.sender, address(ROI), amountROI);

            uint256 amountHQ = _amountToken.mul(HQPercentages[0]).div(1000);
            SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);

            treasury.updatePool(STAKE_POOL, _token, amountTreasury, amountROI, amountHQ, true);
        }

        uint256 timestampToConsider = block.timestamp;

        Staking memory staking = Staking(
            getStakings[msg.sender].length,
            msg.sender,
            true,
            _stakingType,
            _token,
            _amountToken,
            0,
            timestampToConsider,
            0,
            timestampToConsider,
            _isLending,
            false,
            amountTokenLending,
            amountStabl3Lending
        );

        getStakings[msg.sender].push(staking);

        getValues[msg.sender].totalAmountTokenStaked += _amountToken;

        emit Stake(
            staking.user,
            staking.index,
            staking.stakingType,
            staking.token,
            staking.amountTokenStaked,
            getValues[msg.sender].totalAmountTokenStaked,
            staking.isLending,
            timestampToConsider
        );
        ROI.updateAPR();
    }

    // function getAmountRewardSingle(address _user, uint256 _index) external view stakeActive returns (uint256) {
    //     uint256 timestampToConsider = block.timestamp;

    //     uint256 reward = _getAmountRewardSingle(_user, _index, timestampToConsider);

    //     return reward;
    // }

    function _getAmountRewardSingle(address _user, uint256 _index, uint256 _timestamp) internal view returns (uint256) {
        uint256 reward;

        Staking memory staking = getStakings[_user][_index];

        if (staking.amountTokenStaked > 0) {
            uint256 numberOfMinutes = (_timestamp - staking.rewardWithdrawTimeLast) / oneMinuteTime;

            if (numberOfMinutes > 0) {
                uint256 ratio = ROI.getAPR();

                uint256 rewardTotal = _compound(
                    staking.amountTokenStaked,
                    ratio,
                    1
                );

                reward = (rewardTotal * oneMinuteTime * numberOfMinutes) / oneYearTime;
            }
        }

        return reward;
    }

    function getAmountRewardAll(address _user, bool _isLending) public view stakeActive returns (uint256) {
        uint256 totalReward;

        uint256 timestampToConsider = block.timestamp;

        for (uint256 i = 0 ; i < getStakings[_user].length ; i++) {
            Staking memory staking = getStakings[_user][i];

            if (staking.isLending == _isLending) {
                uint256 reward = _getAmountRewardSingle(_user, i, timestampToConsider);

                if (reward > 0) {
                    uint256 decimals = staking.token.decimals();

                    if (decimals < 18) {
                        reward *= 10 ** (18 - decimals);
                    }

                    totalReward += reward;
                }
            }
        }

        return totalReward;
    }

    function _withdrawAmountRewardSingle(uint256 _index, bool _isLending, uint256 _timestamp) internal {
        Staking storage staking = getStakings[msg.sender][_index];

        Values storage values = getValues[msg.sender];

        if (staking.isLending == _isLending) {
            uint256 reward = _getAmountRewardSingle(msg.sender, _index, _timestamp);

            if (reward > 0) {
                uint8 poolType = STAKE_POOL;
                if (staking.isLending) {
                    poolType = LEND_POOL;
                }

                _evaluateReward(staking.token, reward, poolType);

                staking.rewardWithdrawn += reward;
                staking.rewardWithdrawTimeLast = _timestamp;

                values.totalRewardWithdrawn += reward;

                ROI.updateAPR();

                emit WithdrewReward(
                    staking.user,
                    staking.index,
                    staking.token,
                    reward,
                    values.totalRewardWithdrawn,
                    _isLending,
                    _timestamp
                );
            }
        }
    }

    function withdrawAmountRewardAll(bool _isLending) external stakeActive {
        require(getAmountRewardAll(msg.sender, _isLending) > 0, "Stabl3Staking: No reward to withdraw");

        uint256 timestampToConsider = block.timestamp;

        for (uint256 i = 0 ; i < getStakings[msg.sender].length ; i++) {
            _withdrawAmountRewardSingle(i, _isLending, timestampToConsider);
        }
    }

    function _getClaimableStabl3LendingSingle(
        address _user,
        uint256 _index,
        uint256 _timestamp
    ) internal view stakeActive returns (uint256) {
        uint256 claimableStabl3Lending;

        Staking memory staking = getStakings[_user][_index];

        if (
            staking.amountTokenStaked > 0 &&
            staking.isLending == true &&
            !staking.isClaimedStabl3Lending &&
            _timestamp > staking.startTime + lendingStabl3ClaimTime
        ) {
            claimableStabl3Lending = staking.amountStabl3Lending;
        }

        return claimableStabl3Lending;
    }

    function getClaimableStabl3LendingAll(address _user) public view stakeActive returns (uint256) {
        uint256 totalClaimableStabl3Lending;

        uint256 timestampToConsider = block.timestamp;

        for (uint256 i = 0 ; i < getStakings[_user].length ; i++) {
            uint256 claimableStabl3Lending = _getClaimableStabl3LendingSingle(_user, i, timestampToConsider);

            if (claimableStabl3Lending > 0) {
                totalClaimableStabl3Lending += claimableStabl3Lending;
            }
        }

        return totalClaimableStabl3Lending;
    }

    function _claimStabl3LendingSingle(uint256 _index, uint256 _timestamp) internal {
        Staking storage staking = getStakings[msg.sender][_index];

        Values storage values = getValues[msg.sender];

        uint256 amountStabl3Lending = _getClaimableStabl3LendingSingle(msg.sender, _index, _timestamp);

        if (amountStabl3Lending > 0) {
            stabl3.transferFrom(address(treasury), msg.sender, amountStabl3Lending);

            staking.isClaimedStabl3Lending = true;

            values.totalAmountStabl3Lending += amountStabl3Lending;

            emit ClaimedLendingStabl3(
                staking.user,
                staking.index,
                staking.token,
                staking.amountTokenLending,
                staking.amountStabl3Lending,
                values.totalAmountStabl3Lending,
                _timestamp
            );
        }
    }

    function claimStabl3LendingAll() external stakeActive {
        require(getClaimableStabl3LendingAll(msg.sender) > 0, "Stabl3Staking: No Lending Stabl3 to claim");

        uint256 timestampToConsider = block.timestamp;

        for (uint256 i = 0 ; i < getStakings[msg.sender].length ; i++) {
            _claimStabl3LendingSingle(i, timestampToConsider);
        }
    }

    function getAmountStakedAll(address _user, bool _isLending) public view stakeActive returns (uint256) {
        uint256 totalAmountTokenStaked;

        for (uint256 i = 0 ; i < getStakings[_user].length ; i++) {
            Staking memory staking = getStakings[_user][i];

            if (staking.isLending == _isLending) {
                if (staking.amountTokenStaked > 0) {
                    uint256 amountTokenStaked = staking.amountTokenStaked;

                    uint256 decimals = staking.token.decimals();

                    if (decimals < 18) {
                        amountTokenStaked *= 10 ** (18 - decimals);
                    }

                    totalAmountTokenStaked += amountTokenStaked;
                }
            }
        }

        return totalAmountTokenStaked;
    }

    function _withdrawAmountStakedSingle(uint256 _index, uint256 _amountToWithdraw) internal {
        Staking storage staking = getStakings[msg.sender][_index];

        uint256 fee = _amountToWithdraw.mul(unstakeFeePercentage).div(1000);

        uint256 amountToWithdrawWithFee = _amountToWithdraw - fee;

        staking.amountTokenStaked -= _amountToWithdraw;

        uint8 poolType = STAKE_POOL;
        if (staking.isLending) {
            poolType = LEND_POOL;
        }

        SafeERC20.safeTransferFrom(staking.token, address(treasury), address(ROI), fee);

        SafeERC20.safeTransferFrom(staking.token, address(treasury), msg.sender, amountToWithdrawWithFee);

        treasury.updatePool(poolType, staking.token, amountToWithdrawWithFee, 0, 0, false);
        treasury.updatePool(poolType, staking.token, 0, fee, 0, true);

        ROI.updateAPR();

        emit WithdrewAmountStaked(msg.sender, _index, staking.token, _amountToWithdraw, staking.isLending);
    }

    function withdrawAmountStakedSingle(uint256 _index, uint256 _amountToWithdraw) external stakeActive {
        Staking memory staking = getStakings[msg.sender][_index];

        require(getAmountStakedAll(msg.sender, staking.isLending) > 0, "Stabl3Staking: No Staked Amount to withdraw");
        require(staking.amountTokenStaked > 0, "Stabl3Staking: No such stake or lend active");
        require(block.timestamp > staking.startTime + lockTimes[staking.stakingType - 1], "Stabl3Staking: Cannot unstake before end time");
        require(_amountToWithdraw < staking.amountTokenStaked, "Stabl3Staking: Incorrect amount");

        _withdrawAmountRewardSingle(_index, staking.isLending, block.timestamp);

        _withdrawAmountStakedSingle(_index, _amountToWithdraw);
    }

    // function withdrawAmountStakedMultiple(uint256[] memory _indexes, uint256[] memory _amountsToWithdraw) external stakeActive {
    //     require(_indexes.length == _amountToWithdraw.length, "Stabl3Staking: Incorrect array lengths");

    //     for (uint256 i = 0 ; i < _indexes.length ; i++) {
    //         Staking storage staking = getStakings[msg.sender][_index];
    //     }
    // }

    function unstakeSingle(uint256 _index) public stakeActive {
        Staking storage staking = getStakings[msg.sender][_index];

        require(getAmountStakedAll(msg.sender, staking.isLending) > 0, "Stabl3Staking: No Staked Amount to withdraw");
        require(staking.status, "Stabl3Staking: Already unstaked");
        require(staking.amountTokenStaked > 0, "Stabl3Staking: No such stake or lend active");
        require(block.timestamp > staking.startTime + lockTimes[staking.stakingType - 1], "Stabl3Staking: Cannot unstake before end time");

        uint256 timestampToConsider = block.timestamp;

        if (staking.isLending) {
            _claimStabl3LendingSingle(_index, timestampToConsider);
        }

        _withdrawAmountRewardSingle(_index, staking.isLending, timestampToConsider);

        _withdrawAmountStakedSingle(_index, staking.amountTokenStaked);

        uint256 amountTokenStakedToConsider = staking.amountTokenStaked;

        staking.status = false;
        staking.amountTokenStaked = 0;

        emit Unstake(
            staking.user,
            staking.index,
            staking.token,
            amountTokenStakedToConsider,
            staking.rewardWithdrawn,
            staking.stakingType,
            staking.isLending
        );
    }

    function unstakeMultiple(uint256[] memory _indexes) external stakeActive {
        for (uint256 i = 0 ; i < _indexes.length ; i++) {
            unstakeSingle(_indexes[i]);
        }
    }

    function _evaluateReward(IERC20 _rewardToken, uint256 _amountRewardToken, uint8 _poolType) internal {
        uint8 rewardDistributionType = _poolType + 4;

        uint256 amountRewardTokenROI = _rewardToken.balanceOf(address(ROI));

        if (_amountRewardToken > amountRewardTokenROI) {
            if (amountRewardTokenROI != 0) {
                SafeERC20.safeTransferFrom(_rewardToken, address(ROI), msg.sender, amountRewardTokenROI);

                _amountRewardToken -= amountRewardTokenROI;

                treasury.updatePool(_poolType, _rewardToken, 0, amountRewardTokenROI, 0, false);
                treasury.updatePool(rewardDistributionType, _rewardToken, 0, amountRewardTokenROI, 0, true);
            }

            uint256 decimalsRewardToken = _rewardToken.decimals();

            for (uint256 i = 0 ; i < treasury.allReservedTokensLength() && _amountRewardToken > 0 ; i++) {
                IERC20 reservedToken = treasury.allReservedTokens(i);
                if (
                    treasury.isReservedToken(reservedToken) &&
                    reservedToken != _rewardToken &&
                    _amountRewardToken != 0
                ) {
                    uint256 amountReservedTokenROI = reservedToken.balanceOf(address(ROI));

                    uint256 decimalsReservedToken = reservedToken.decimals();

                    uint256 amountRewardTokenConverted;
                    if (decimalsRewardToken > decimalsReservedToken) {
                        amountRewardTokenConverted = _amountRewardToken / (10 ** (decimalsRewardToken - decimalsReservedToken));
                    }
                    else if (decimalsRewardToken < decimalsReservedToken) {
                        amountRewardTokenConverted = _amountRewardToken * (10 ** (decimalsReservedToken - decimalsRewardToken));
                    }

                    if (amountRewardTokenConverted > amountReservedTokenROI) {
                        SafeERC20.safeTransferFrom(reservedToken, address(ROI), msg.sender, amountReservedTokenROI);

                        treasury.updatePool(_poolType, reservedToken, 0, amountReservedTokenROI, 0, false);
                        treasury.updatePool(rewardDistributionType, reservedToken, 0, amountReservedTokenROI, 0, true);

                        if (decimalsRewardToken > decimalsReservedToken) {
                            _amountRewardToken -= amountReservedTokenROI * (10 ** (decimalsRewardToken - decimalsReservedToken));
                        }
                        else if (decimalsRewardToken < decimalsReservedToken) {
                            _amountRewardToken -= amountReservedTokenROI / (10 ** (decimalsReservedToken - decimalsRewardToken));
                        }
                    }
                    else {
                        SafeERC20.safeTransferFrom(reservedToken, address(ROI), msg.sender, amountRewardTokenConverted);

                        treasury.updatePool(_poolType, reservedToken, 0, amountRewardTokenConverted, 0, false);
                        treasury.updatePool(rewardDistributionType, reservedToken, 0, amountRewardTokenConverted, 0, true);

                        _amountRewardToken = 0;
                        break;
                    }
                }
            }
        }
        else {
            SafeERC20.safeTransferFrom(_rewardToken, address(ROI), msg.sender, _amountRewardToken);

            treasury.updatePool(_poolType, _rewardToken, 0, _amountRewardToken, 0, false);
            treasury.updatePool(rewardDistributionType, _rewardToken, 0, _amountRewardToken, 0, true);
        }
    }

    function _compound(uint256 _principal, uint256 _ratio, uint256 _exponent) internal pure returns (uint256) {
        if (_exponent == 0) {
            return 0;
        }

        uint256 accruedReward = ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);

        return accruedReward.sub(_principal);
    }
    
    // modifiers

    modifier stakeActive() {
        require(stakeState, "Stabl3Staking: Stake and Lend not yet started");
        _;
    }

    modifier reserved(IERC20 _token) {
        require(treasury.isReservedToken(_token), "Stabl3Staking: Not a reserved token");
        _;
    }
}