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
    uint8 private constant STAKE_REWARD_POOL = 4;
    uint8 private constant LEND_REWARD_POOL = 5;

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
        uint256 startTime;
        uint256 rewardWithdrawn;
        uint256 rewardWithdrawTimeLast;
        bool isLending;
        bool isClaimedStabl3Lending;
        uint256 amountTokenLending;
        uint256 amountStabl3Lending;
    }

    struct Record {
        uint256 totalAmountTokenStaked;
        uint256 totalRewardWithdrawn;
        uint256 totalAmountStabl3Withdrawn;
    }

    // mappings

    // user staking
    mapping (address => Staking[]) public getStakings;

    // user lifetime record
    mapping (address => mapping (bool => Record)) public getRecords;

    // contracts with permission to access certain Staking functions
    mapping (address => bool) public permitted;

    // events

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedHQ(address newHQ, address oldHQ);

    event UpdatedUnstakeFeePercentage(uint256 newUnstakeFeePercentage, uint256 oldUnstakeFeePercentage);

    event UpdatedLockTime(uint256[4] newLockTimes, uint256[4] oldLockTimes);

    event UpdatedLendingStabl3Percentage(uint256 newLendingStabl3Percentage, uint256 oldLendingStabl3Percentage);

    event UpdatedLendingStabl3ClaimTime(uint256 newLendingStabl3ClaimTime, uint256 oldLendingStabl3ClaimTime);

    event UpdatedPermission(address contractAddress, bool state);

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
        uint256 totalAmountStabl3Withdrawn,
        uint256 timestamp
    );

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

        // TODO remove
        oneMinuteTime = 30;
        oneYearTime = 10800;
        lockTimes = [2700, 5400, 8100, 10800];   // 0:45, 1:30, 2:15 and 3:00 hours time in seconds
        // oneMinuteTime = 60;
        // oneYearTime = 31104000;
        // lockTimes = [7776000, 15552000, 23328000, 31104000];   // 3, 6, 9 and 12 months time in seconds

        // TODO remove
        lendingStabl3ClaimTime = 900; // 0:15 hours time in seconds
        // lendingStabl3ClaimTime = 2592000; // 1 month time in seconds
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

    function updatePermission(address _contractAddress, bool _state) external onlyOwner {
        require(permitted[_contractAddress] != _state, "Stabl3Staking: Contract is already of the value 'state'");
        permitted[_contractAddress] = _state;
        emit UpdatedPermission(_contractAddress, _state);
    }

    function allStakingsLength(address _user) external view returns (uint256) {
        return getStakings[_user].length;
    }

    function allStakings(address _user) external view returns (
        Staking[] memory unlockedLending,
        Staking[] memory lockedLending,
        Staking[] memory unlockedStaking,
        Staking[] memory lockedStaking
    ) {
        uint256 unlockedLendingLength;
        uint256 lockedLendingLength;
        uint256 unlockedStakingLength;
        uint256 lockedStakingLength;

        for (uint256 i = 0 ; i < getStakings[_user].length ; i++) {
            Staking memory staking = getStakings[_user][i];

            if (staking.status) {
                uint256 endTime = staking.startTime + lockTimes[staking.stakingType - 1];

                if (block.timestamp >= endTime) {
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

        for (uint256 i = 0 ; i < getStakings[_user].length ; i++) {
            Staking memory staking = getStakings[_user][i];

            if (staking.status) {
                uint256 endTime = staking.startTime + lockTimes[staking.stakingType - 1];

                if (block.timestamp >= endTime) {
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

    function stake(IERC20 _token, uint256 _amountToken, uint8 _stakingType, bool _isLending) public stakeActive reserved(_token) {
        require(_amountToken > 0, "Stabl3Staking: Amount should be greater than zero");
        require(1 <= _stakingType && _stakingType <= 4, "Stabl3Staking: Incorrect staking type");
        require(validatePool(_token, _amountToken), "Stabl3Staking: Staking pool limit reached");

        uint256 amountTokenLending;
        uint256 amountStabl3Lending;

        if (_isLending) {
            uint256 amountTreasury = _amountToken.mul(treasuryPercentages[1]).div(1000);

            uint256 amountROI = _amountToken.mul(ROIPercentages[1]).div(1000);

            uint256 amountHQ = _amountToken.mul(HQPercentages[1]).div(1000);

            amountTokenLending = amountROI + amountHQ;
            amountStabl3Lending = treasury.getAmountOut(_token, amountTokenLending);

            uint256 totalAmountDistributed = amountTreasury + amountROI + amountHQ;
            if (_amountToken > totalAmountDistributed) {
                amountTreasury += _amountToken - totalAmountDistributed;
            }

            SafeERC20.safeTransferFrom(_token, msg.sender, address(treasury), amountTreasury);
            SafeERC20.safeTransferFrom(_token, msg.sender, address(ROI), amountROI);
            SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);

            stabl3.transferFrom(address(treasury), address(this), amountStabl3Lending);

            treasury.updatePool(STAKE_POOL, _token, amountTreasury, amountROI, amountHQ, true);
            treasury.updatePool(BUY_POOL, _token, 0, amountROI, amountHQ, true);
            treasury.updateRate(_token, amountTokenLending);
        }
        else {
            uint256 amountTreasury = _amountToken.mul(treasuryPercentages[0]).div(1000);

            uint256 amountROI = _amountToken.mul(ROIPercentages[0]).div(1000);

            uint256 amountHQ = _amountToken.mul(HQPercentages[0]).div(1000);

            uint256 totalAmountDistributed = amountTreasury + amountROI + amountHQ;
            if (_amountToken > totalAmountDistributed) {
                amountTreasury += _amountToken - totalAmountDistributed;
            }

            SafeERC20.safeTransferFrom(_token, msg.sender, address(treasury), amountTreasury);
            SafeERC20.safeTransferFrom(_token, msg.sender, address(ROI), amountROI);
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
            timestampToConsider,
            0,
            timestampToConsider,
            _isLending,
            false,
            amountTokenLending,
            amountStabl3Lending
        );

        getStakings[msg.sender].push(staking);

        getRecords[msg.sender][_isLending].totalAmountTokenStaked += _amountToken;

        ROI.updateAPR();

        emit Stake(
            staking.user,
            staking.index,
            staking.stakingType,
            staking.token,
            staking.amountTokenStaked,
            getRecords[staking.user][staking.isLending].totalAmountTokenStaked,
            staking.isLending,
            timestampToConsider
        );
    }

    function getAmountRewardSingle(
        address _user,
        uint256 _index,
        bool _isLending,
        uint256 _timestamp
    ) public view stakeActive returns (uint256) {
        uint256 reward;

        Staking memory staking = getStakings[_user][_index];

        if (
            staking.status &&
            staking.isLending == _isLending
        ) {
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
                uint256 reward = getAmountRewardSingle(_user, i, _isLending, timestampToConsider);

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

        uint256 reward = getAmountRewardSingle(msg.sender, _index, _isLending, _timestamp);

        if (reward > 0) {
            Record storage record = getRecords[msg.sender][staking.isLending];

            uint8 poolType = STAKE_POOL;
            if (staking.isLending) {
                poolType = LEND_POOL;
            }

            _evaluateReward(staking.token, reward, poolType);

            staking.rewardWithdrawn += reward;
            staking.rewardWithdrawTimeLast = _timestamp;

            record.totalRewardWithdrawn += reward;

            ROI.updateAPR();

            emit WithdrewReward(
                staking.user,
                staking.index,
                staking.token,
                reward,
                record.totalRewardWithdrawn,
                _isLending,
                _timestamp
            );
        }
    }

    function withdrawAmountRewardAll(bool _isLending) external stakeActive {
        require(getAmountRewardAll(msg.sender, _isLending) > 0, "Stabl3Staking: No reward to withdraw");

        uint256 timestampToConsider = block.timestamp;

        for (uint256 i = 0 ; i < getStakings[msg.sender].length ; i++) {
            _withdrawAmountRewardSingle(i, _isLending, timestampToConsider);
        }
    }

    function getClaimableStabl3LendingSingle(
        address _user,
        uint256 _index,
        uint256 _timestamp
    ) public view stakeActive returns (uint256) {
        uint256 claimableStabl3Lending;

        Staking memory staking = getStakings[_user][_index];

        if (
            staking.status &&
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
            uint256 claimableStabl3Lending = getClaimableStabl3LendingSingle(_user, i, timestampToConsider);

            if (claimableStabl3Lending > 0) {
                totalClaimableStabl3Lending += claimableStabl3Lending;
            }
        }

        return totalClaimableStabl3Lending;
    }

    function _claimStabl3LendingSingle(uint256 _index, uint256 _timestamp) internal {
        Staking storage staking = getStakings[msg.sender][_index];

        Record storage record = getRecords[msg.sender][true];

        uint256 amountStabl3Lending = getClaimableStabl3LendingSingle(msg.sender, _index, _timestamp);

        if (amountStabl3Lending > 0) {
            stabl3.transferFrom(address(this), msg.sender, amountStabl3Lending);

            staking.isClaimedStabl3Lending = true;

            record.totalAmountStabl3Withdrawn += amountStabl3Lending;

            emit ClaimedLendingStabl3(
                staking.user,
                staking.index,
                staking.token,
                staking.amountTokenLending,
                staking.amountStabl3Lending,
                record.totalAmountStabl3Withdrawn,
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

    function _unstakeSingle(uint256 _index, uint256 _amountToUnstake) internal {
        Staking storage staking = getStakings[msg.sender][_index];

        uint256 fee = staking.amountTokenStaked.mul(unstakeFeePercentage).div(1000);

        uint256 amountToWithdrawWithFee = staking.amountTokenStaked - fee;

        uint8 poolType = STAKE_POOL;
        if (staking.isLending) {
            poolType = LEND_POOL;
        }

        SafeERC20.safeTransferFrom(staking.token, address(treasury), address(ROI), fee);

        SafeERC20.safeTransferFrom(staking.token, address(treasury), msg.sender, amountToWithdrawWithFee);

        treasury.updatePool(poolType, staking.token, staking.amountTokenStaked, 0, 0, false);
        treasury.updatePool(poolType, staking.token, 0, fee, 0, true);

        ROI.updateAPR();

        staking.status = false;

        emit Unstake(
            staking.user,
            staking.index,
            staking.token,
            _amountToUnstake,
            staking.rewardWithdrawn,
            staking.stakingType,
            staking.isLending
        );
    }

    function restakeSingle(uint256 _index, uint256 _amountToWithdraw, uint8 _stakingType) external stakeActive {
        Staking storage staking = getStakings[msg.sender][_index];

        require(staking.status, "Stabl3Staking: Wrong index given");
        require(block.timestamp > staking.startTime + lockTimes[staking.stakingType - 1], "Stabl3Staking: Cannot unstake before end time");
        require(_amountToWithdraw < staking.amountTokenStaked, "Stabl3Staking: Incorrect amount for restaking");

        uint256 timestampToConsider = block.timestamp;

        if (staking.isLending) {
            _claimStabl3LendingSingle(_index, timestampToConsider);
        }

        _withdrawAmountRewardSingle(_index, staking.isLending, timestampToConsider);

        _unstakeSingle(_index, _amountToWithdraw);

        uint256 amountToRestake = staking.amountTokenStaked - _amountToWithdraw;

        stake(staking.token, amountToRestake, _stakingType, staking.isLending);
    }

    function unstakeSingle(uint256 _index) public stakeActive {
        Staking storage staking = getStakings[msg.sender][_index];

        require(staking.status, "Stabl3Staking: Wrong index given");
        require(block.timestamp > staking.startTime + lockTimes[staking.stakingType - 1], "Stabl3Staking: Cannot unstake before end time");

        uint256 timestampToConsider = block.timestamp;

        if (staking.isLending) {
            _claimStabl3LendingSingle(_index, timestampToConsider);
        }

        _withdrawAmountRewardSingle(_index, staking.isLending, timestampToConsider);

        _unstakeSingle(_index, staking.amountTokenStaked);
    }

    function unstakeMultiple(uint256[] memory _indexes) external stakeActive {
        for (uint256 i = 0 ; i < _indexes.length ; i++) {
            unstakeSingle(_indexes[i]);
        }
    }

    function _evaluateReward(IERC20 _rewardToken, uint256 _amountRewardToken, uint8 _poolType) internal {
        uint8 rewardPoolType = _poolType + 2;

        uint256 amountRewardTokenROI = _rewardToken.balanceOf(address(ROI));

        if (_amountRewardToken > amountRewardTokenROI) {
            if (amountRewardTokenROI != 0) {
                SafeERC20.safeTransferFrom(_rewardToken, address(ROI), msg.sender, amountRewardTokenROI);

                _amountRewardToken -= amountRewardTokenROI;

                treasury.updatePool(_poolType, _rewardToken, 0, amountRewardTokenROI, 0, false);
                treasury.updatePool(rewardPoolType, _rewardToken, 0, amountRewardTokenROI, 0, true);
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
                        treasury.updatePool(rewardPoolType, reservedToken, 0, amountReservedTokenROI, 0, true);

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
                        treasury.updatePool(rewardPoolType, reservedToken, 0, amountRewardTokenConverted, 0, true);

                        _amountRewardToken = 0;
                        break;
                    }
                }
            }
        }
        else {
            SafeERC20.safeTransferFrom(_rewardToken, address(ROI), msg.sender, _amountRewardToken);

            treasury.updatePool(_poolType, _rewardToken, 0, _amountRewardToken, 0, false);
            treasury.updatePool(rewardPoolType, _rewardToken, 0, _amountRewardToken, 0, true);
        }
    }

    function _compound(uint256 _principal, uint256 _ratio, uint256 _exponent) internal pure returns (uint256) {
        if (_exponent == 0) {
            return 0;
        }

        uint256 accruedReward = ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);

        return accruedReward.sub(_principal);
    }

    // TODO remove
    // Testing only
    function testWithdrawAllFunds(IERC20 _token) external onlyOwner {
        SafeERC20.safeTransfer(_token, owner(), _token.balanceOf(address(this)));
    }

    // modifiers

    modifier stakeActive() {
        require(stakeState, "Stabl3Staking: Stake and Lend not yet started");
        _;
    }

    modifier permission() {
        require(permitted[msg.sender] || msg.sender == owner(), "Stabl3Staking: Not permitted");
        _;
    }

    modifier reserved(IERC20 _token) {
        require(treasury.isReservedToken(_token), "Stabl3Staking: Not a reserved token");
        _;
    }
}