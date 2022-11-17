// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "../../Contracts/Ownable.sol";
import "../../Contracts/SafeMathUpgradeable.sol";
import "../../Contracts/SafeERC20.sol";
import "../../Contracts/ReentrancyGuard.sol";

import "../../Contracts/ITreasury.sol";
import "../../Contracts/IROI.sol";
import "../../Contracts/IStabl3StakingStruct.sol";

import "../../Contracts/Stabl3StakingHelper.sol";

contract Stabl3Staking is Ownable, ReentrancyGuard, IStabl3StakingStruct {
    using SafeMathUpgradeable for uint256;

    uint8 private constant BUY_POOL = 0;

    uint8 private constant STAKE_POOL = 2;
    uint8 private constant STAKE_REWARD_POOL = 3;
    uint8 private constant STAKE_FEE_POOL = 4;
    uint8 private constant LEND_POOL = 5;
    uint8 private constant LEND_REWARD_POOL = 6;
    uint8 private constant LEND_FEE_POOL = 7;

    uint8 private constant STAKING_TYPE_POOL = 20;

    ITreasury public treasury;
    IROI public ROI;
    address public HQ;

    Stabl3StakingHelper private stabl3StakingHelper;

    IERC20 public immutable stabl3;

    uint256[2] public treasuryPercentages;
    uint256[2] public ROIPercentages;
    uint256[2] public HQPercentages;

    uint256 public lendingStabl3Percentage;
    uint256 public lendingStabl3ClaimTime;

    uint256 private oneDayTime;
    uint256 private oneYearTime;
    uint256[5] public lockTimes;

    uint256 public excludedFromROIReserves;

    uint8[] public returnPools;

    uint256 public unstakeFeePercentage;

    bool public stakeState;

    // mappings

    // user stakings
    mapping (address => Staking[]) public getStakings;

    // all users
    mapping (address => bool) public getStakers;
    address[] public allStakers;

    /**
     * @notice Stores each user's lifetime staking records
     * @dev No deductions when unstaking
     */
    mapping (address => mapping (bool => Record)) public getRecords;

    // contracts with permission to access Stabl3 Staking functions
    mapping (address => bool) public permitted;

    // events

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedHQ(address newHQ, address oldHQ);

    event UpdatedPermission(address contractAddress, bool state);

    event Stake(
        address indexed user,
        uint256 index,
        bool status,
        uint8 stakingType,
        IERC20 token,
        uint256 amountToken,
        uint256 totalAmountToken,
        uint256 endTime,
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
        uint256 amountStabl3Lending,
        uint256 totalAmountStabl3Withdrawn,
        uint256 timestamp
    );

    event Unstake(
        address indexed user,
        uint256 index,
        IERC20 token,
        uint256 amountToken,
        uint256 reward,
        uint8 stakingType,
        bool isLend
    );

    // constructor

    constructor(address _treasury, address _ROI) {
        treasury = ITreasury(_treasury);
        ROI = IROI(_ROI);
        // TODO change
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        stabl3StakingHelper = new Stabl3StakingHelper();

        // TODO change
        stabl3 = IERC20(0xc3Bf0c0172E3638d383361801e9BF63B4FfE0d6e);

        treasuryPercentages = [975, 761];
        ROIPercentages = [0, 0];
        HQPercentages = [25, 39];

        lendingStabl3Percentage = 200;
        // TODO remove
        // lendingStabl3ClaimTime = 15 minutes;
        lendingStabl3ClaimTime = 4 hours;
        // lendingStabl3ClaimTime = 2592000; // 1 month time in seconds

        // TODO remove
        // oneDayTime = 10;
        // oneYearTime = 3600;
        // lockTimes = [0, 900, 1800, 2700, 3600];
        oneDayTime = 8 minutes;
        oneYearTime = 48 hours;
        lockTimes = [0, 12 hours, 24 hours, 36 hours, 48 hours];
        // oneDayTime = 86400;
        // oneYearTime = 31104000;
        // lockTimes = [0, 7776000, 15552000, 23328000, 31104000];   // 3, 6, 9 and 12 months time in seconds

        // TODO use times like this to complete 365 days
        // 31+28+31, 30+31+30, 31+31+30, 31+30+31
        // 90, 91, 92, 92

        // TODO adjust
        returnPools = [0, 1, 14];

        unstakeFeePercentage = 50;
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

    function updateStabl3StakingHelper(address _stabl3StakingHelper) external onlyOwner {
        require(address(stabl3StakingHelper) != _stabl3StakingHelper, "Stabl3Staking: Stabl3 Staking Helper is already this address");
        stabl3StakingHelper = Stabl3StakingHelper(_stabl3StakingHelper);
    }

    function updateDistributionPercentages(
        uint256 _treasuryPercentage,
        uint256 _ROIPercentage,
        uint256 _HQPercentage,
        uint256 _lendingStabl3Percentage,
        bool _isLending
    ) external onlyOwner {
        if (_isLending) {
            require(_treasuryPercentage + _ROIPercentage + _HQPercentage + _lendingStabl3Percentage == 1000,
                "Stabl3Staking: Sum of magnified Lend percentages should equal 1000");

            treasuryPercentages[1] = _treasuryPercentage;
            ROIPercentages[1] = _ROIPercentage;
            HQPercentages[1] = _HQPercentage;
            lendingStabl3Percentage = _lendingStabl3Percentage;
        }
        else {
            require(_treasuryPercentage + _ROIPercentage + _HQPercentage == 1000,
                "Stabl3Staking: Sum of magnified Stake percentages should equal 1000");

            treasuryPercentages[0] = _treasuryPercentage;
            ROIPercentages[0] = _ROIPercentage;
            HQPercentages[0] = _HQPercentage;
        }
    }

    function updateLendingStabl3ClaimTime(uint256 _lendingStabl3ClaimTime) external onlyOwner {
        require(lendingStabl3ClaimTime != _lendingStabl3ClaimTime, "Stabl3Staking: Lending Stabl3 Claim Time is already this value");
        lendingStabl3ClaimTime = _lendingStabl3ClaimTime;
    }

    function updateLockTimes(uint256[5] memory _lockTimes) external onlyOwner {
        lockTimes = _lockTimes;
        // TODO remove
        oneDayTime = _lockTimes[1].div(90);
        oneYearTime = _lockTimes[4];
    }

    function updateReturnPools(uint8[] memory _returnPools) external onlyOwner {
        returnPools = _returnPools;
    }

    function updateUnstakeFeePercentage(uint256 _unstakeFeePercentage) external onlyOwner {
        require(unstakeFeePercentage != _unstakeFeePercentage, "Stabl3Staking: Unstake Fee is already this value");
        unstakeFeePercentage = _unstakeFeePercentage;
    }

    function updateStakeState(bool _state) external onlyOwner {
        require(stakeState != _state, "Stabl3Staking: Stake State is already of the value 'state'");
        stakeState = _state;
    }

    function allStakersLength() external view returns (uint256) {
        return allStakers.length;
    }

    function allStakingsLength(address _user) external view returns (uint256) {
        return getStakings[_user].length;
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
        (unlockedLending, lockedLending, unlockedStaking, lockedStaking) = stabl3StakingHelper.allStakings(_user, _isRealEstate);
    }

    function updatePermission(address _contractAddress, bool _state) public onlyOwner {
        require(permitted[_contractAddress] != _state, "Stabl3Staking: Contract Address is already of the value 'state'");

        permitted[_contractAddress] = _state;

        emit UpdatedPermission(_contractAddress, _state);
    }

    function stake(
        IERC20 _token,
        uint256 _amountToken,
        uint8 _stakingType,
        bool _isLending
    ) public stakeActive reserved(_token) nonReentrant {
        require(ROI.getAPR() > 0, "Stabl3Staking: No APR to give");
        require(1 <= _stakingType && _stakingType <= 4, "Stabl3Staking: Incorrect staking type");
        require(_amountToken > 1, "Stabl3Staking: Insufficient amount");
        (uint256 maxPool, uint256 currentPool) = ROI.validatePool(_token, _amountToken, _stakingType, _isLending);
        require(currentPool <= maxPool, "Stabl3Staking: Staking pool limit reached. Please try again later or try a different amount");

        if (!getStakers[msg.sender]) {
            getStakers[msg.sender] = true;
            allStakers.push(msg.sender);
        }

        // uint256 amountTokenLending;
        uint256 amountStabl3Lending;

        if (_isLending) {
            uint256 amountTreasury = _amountToken.mul(treasuryPercentages[1]).div(1000);

            uint256 amountROI = _amountToken.mul(ROIPercentages[1]).div(1000);

            uint256 amountHQ = _amountToken.mul(HQPercentages[1]).div(1000);

            uint256 amountTokenLending = _amountToken.mul(lendingStabl3Percentage).div(1000);
            amountStabl3Lending = treasury.getAmountOut(_token, amountTokenLending);

            uint256 totalAmountDistributed = amountTreasury + amountROI + amountHQ + amountTokenLending;
            if (_amountToken > totalAmountDistributed) {
                amountTreasury += _amountToken - totalAmountDistributed;
            }

            _amountToken -= amountTokenLending;

            SafeERC20.safeTransferFrom(_token, msg.sender, address(treasury), amountTreasury);
            SafeERC20.safeTransferFrom(_token, msg.sender, address(ROI), amountROI);
            SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);
            SafeERC20.safeTransferFrom(_token, msg.sender, address(ROI), amountTokenLending);

            treasury.updatePool(LEND_POOL, _token, amountTreasury + amountHQ, amountROI, amountHQ, true);

            treasury.updatePool(BUY_POOL, _token, 0, amountTokenLending, 0, true);
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

            treasury.updatePool(STAKE_POOL, _token, amountTreasury + amountHQ, amountROI, amountHQ, true);
        }

        ROI.updateAPR();

        uint256 timestampToConsider = block.timestamp;

        Staking memory staking;
        staking.index = getStakings[msg.sender].length;
        staking.user = msg.sender;
        staking.status = true;
        staking.stakingType = _stakingType;
        staking.token = _token;
        staking.amountTokenStaked = _amountToken;
        staking.startTime = timestampToConsider;
        staking.stakingAPRIndexLast = ROI.allStakingAPRsLength() - 1;
        // staking.rewardWithdrawn = 0;
        staking.rewardWithdrawTimeLast = timestampToConsider;
        staking.isLending = _isLending;
        staking.amountStabl3Lending = amountStabl3Lending;
        // staking.isDormant = false;
        // staking.isRealEstate = false;

        getStakings[msg.sender].push(staking);

        Record storage record = getRecords[msg.sender][_isLending];

        uint256 amountTokenConverted = _token.decimals() < 18 ? _amountToken * 10 ** (18 - _token.decimals()) : _amountToken;

        treasury.updatePool(STAKING_TYPE_POOL + _stakingType, IERC20(address(0)), amountTokenConverted, 0, 0, true);
        record.totalAmountTokenStaked += amountTokenConverted;
        // getAmountStakedPerStakingType[_stakingType] += amountTokenConverted;

        emit Stake(
            staking.user,
            staking.index,
            staking.status,
            staking.stakingType,
            staking.token,
            staking.amountTokenStaked,
            record.totalAmountTokenStaked,
            timestampToConsider + lockTimes[staking.stakingType],
            staking.isLending,
            timestampToConsider
        );
    }

    /**
     * @notice This function is only called externally by certain contracts to provide APR on a given value
     * @dev Requires permit
     * @dev Requires external checks, transfers, records, updatePool calls, updateAPR calls and event emissions
     */
    function accessWithPermit(address _user, Staking memory _staking, uint8 _identifier) external {
        require(permitted[msg.sender] || msg.sender == owner(), "Stabl3Staking: Not permitted");

        if (_identifier == 0) {
            if (!getStakers[msg.sender]) {
                getStakers[msg.sender] = true;
                allStakers.push(msg.sender);
            }

            getStakings[_user].push(_staking);
        }
        else if (_identifier == 1) {
            getStakings[_user][_staking.index] = _staking;
        }
        // TODO confirm
        // else if (_identifier == 2) {
        //     getStakings[_user][_staking.index] = _staking;

        //     getStakings[_user][_staking.index].status = false;
        // }
    }

    function getAmountRewardSingle(
        address _user,
        uint256 _index,
        bool _isLending,
        bool _isRealEstate,
        uint256 _timestamp
    ) public view returns (uint256) {
        return stabl3StakingHelper.getAmountRewardSingle(_user, _index, _isLending, _isRealEstate, _timestamp);
    }

    function getAmountRewardAll(address _user, bool _isLending, bool _isRealEstate) public view returns (uint256) {
        return stabl3StakingHelper.getAmountRewardAll(_user, _isLending, _isRealEstate);
    }

    function _withdrawAmountRewardSingle(uint256 _index, bool _isLending, uint256 _timestamp) internal nonReentrant {
        Staking storage staking = getStakings[msg.sender][_index];

        uint256 reward = getAmountRewardSingle(msg.sender, _index, _isLending, false, _timestamp);

        if (reward > 0) {
            uint256 endTime = staking.startTime + lockTimes[staking.stakingType];

            Record storage record = getRecords[msg.sender][staking.isLending];

            uint8 poolType = staking.isLending ? LEND_POOL : STAKE_POOL;

            ROI.distributeReward(msg.sender, staking.token, reward, poolType);

            uint256 rewardConverted = staking.token.decimals() < 18 ? reward * 10 ** (18 - staking.token.decimals()) : reward;

            if (staking.isDormant) {
                excludedFromROIReserves = excludedFromROIReserves.safeSub(rewardConverted);
            }

            ROI.updateAPR();

            staking.stakingAPRIndexLast = ROI.allStakingAPRsLength() - 1;
            staking.rewardWithdrawn += reward;
            staking.rewardWithdrawTimeLast = _timestamp > endTime ? endTime : _timestamp;

            record.totalRewardWithdrawn += rewardConverted;

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
        require(getAmountRewardAll(msg.sender, _isLending, false) > 0, "Stabl3Staking: No reward to withdraw");

        uint256 timestampToConsider = block.timestamp;

        for (uint256 i = 0 ; i < getStakings[msg.sender].length ; i++) {
            _withdrawAmountRewardSingle(i, _isLending, timestampToConsider);
        }
    }

    function getClaimableStabl3LendingSingle(
        address _user,
        uint256 _index,
        uint256 _timestamp
    ) public view returns (uint256) {
        return stabl3StakingHelper.getClaimableStabl3LendingSingle(_user, _index, _timestamp);
    }

    function getClaimableStabl3LendingAll(address _user) public view returns (uint256) {
        return stabl3StakingHelper.getClaimableStabl3LendingAll(_user);
    }

    function _claimStabl3LendingSingle(uint256 _index, uint256 _timestamp) internal nonReentrant {
        Staking storage staking = getStakings[msg.sender][_index];

        Record storage record = getRecords[msg.sender][true];

        uint256 amountStabl3Lending = getClaimableStabl3LendingSingle(msg.sender, _index, _timestamp);

        if (amountStabl3Lending > 0) {
            stabl3.transferFrom(address(treasury), msg.sender, amountStabl3Lending);

            record.totalAmountStabl3Withdrawn += amountStabl3Lending;

            treasury.updateStabl3CirculatingSupply(amountStabl3Lending, true);

            emit ClaimedLendingStabl3(
                staking.user,
                staking.index,
                staking.token,
                staking.amountStabl3Lending,
                record.totalAmountStabl3Withdrawn,
                _timestamp
            );

            staking.amountStabl3Lending = 0;
        }
    }

    function claimStabl3LendingAll() external stakeActive {
        require(getClaimableStabl3LendingAll(msg.sender) > 0, "Stabl3Staking: No Lending Stabl3 to claim");

        uint256 timestampToConsider = block.timestamp;

        for (uint256 i = 0 ; i < getStakings[msg.sender].length ; i++) {
            _claimStabl3LendingSingle(i, timestampToConsider);
        }
    }

    function getAmountStakedAll(
        address _user,
        bool _isLending,
        bool _isRealEstate
    ) external view returns (uint256 totalAmountStakedUnlocked, uint256 totalAmountStakedLocked) {
        (totalAmountStakedUnlocked, totalAmountStakedLocked) = stabl3StakingHelper.getAmountStakedAll(_user, _isLending, _isRealEstate);
    }

    function _unstakeSingle(uint256 _index, uint256 _amountToUnstake) internal nonReentrant {
        Staking storage staking = getStakings[msg.sender][_index];

        if (staking.amountTokenStaked > staking.token.balanceOf(address(treasury))) {
            ROI.returnFunds(staking.token, staking.amountTokenStaked - staking.token.balanceOf(address(treasury)), returnPools);
        }

        staking.status = false;

        uint256 fee = staking.amountTokenStaked.mul(unstakeFeePercentage).div(1000);
        uint256 amountToUnstakeWithFee = staking.amountTokenStaked - fee;

        SafeERC20.safeTransferFrom(staking.token, address(treasury), address(ROI), fee);

        SafeERC20.safeTransferFrom(staking.token, address(treasury), msg.sender, amountToUnstakeWithFee);

        if (!staking.isDormant) {
            (uint8 poolType, uint8 feeType) = staking.isLending ? (LEND_POOL, LEND_FEE_POOL) : (STAKE_POOL, STAKE_FEE_POOL);

            treasury.updatePool(poolType, staking.token, staking.amountTokenStaked, 0, 0, false);
            treasury.updatePool(feeType, staking.token, 0, fee, 0, true);

            uint256 amountTokenConverted =
                staking.token.decimals() < 18 ?
                staking.amountTokenStaked * 10 ** (18 - staking.token.decimals()) :
                staking.amountTokenStaked;

            treasury.updatePool(STAKING_TYPE_POOL + staking.stakingType, IERC20(address(0)), amountTokenConverted, 0, 0, false);
            // getAmountStakedPerStakingType[staking.stakingType] -= amountTokenConverted;
        }

        ROI.updateAPR();

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

    function restakeSingle(uint256 _index, uint256 _amountToUnstake, uint8 _stakingType) external stakeActive {
        Staking storage staking = getStakings[msg.sender][_index];

        require(staking.status, "Stabl3Staking: Invalid Staking");
        require(!staking.isRealEstate, "Stabl3Staking: Not allowed");
        require(block.timestamp > staking.startTime + lockTimes[staking.stakingType], "Stabl3Staking: Cannot unstake before end time");
        require(_amountToUnstake < staking.amountTokenStaked, "Stabl3Staking: Incorrect amount for restaking");

        uint256 timestampToConsider = block.timestamp;

        if (staking.isLending) {
            _claimStabl3LendingSingle(_index, timestampToConsider);
        }

        _withdrawAmountRewardSingle(_index, staking.isLending, timestampToConsider);

        _unstakeSingle(_index, _amountToUnstake);

        uint256 amountToRestake = staking.amountTokenStaked - _amountToUnstake;

        stake(staking.token, amountToRestake, _stakingType, staking.isLending);
    }

    function unstakeSingle(uint256 _index) public stakeActive {
        Staking storage staking = getStakings[msg.sender][_index];

        require(staking.status, "Stabl3Staking: Invalid Staking");
        require(!staking.isRealEstate, "Stabl3Staking: Not allowed");
        require(block.timestamp > staking.startTime + lockTimes[staking.stakingType], "Stabl3Staking: Cannot unstake before end time");

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

    // TODO gasLeft()
    function excludeDormantStakings() external stakeActive {
        uint256 timestampToConsider = block.timestamp;

        for (uint256 i = 0 ; i < allStakers.length ; i++) {
            address staker = allStakers[i];

            if (getStakers[staker]) {
                (Staking[] memory unlockedLending, , Staking[] memory unlockedStaking, ) = allStakings(staker, false);
                // (, , Staking[] memory unlockedRealEstate, ) = allStakings(staker, true);

                // uint256 maxLength = unlockedLending.length.max(unlockedStaking.length).max(unlockedRealEstate.length);
                uint256 maxLength = unlockedLending.length.max(unlockedStaking.length);

                for (uint256 j = 0 ; j < maxLength ; j++) {
                    if (j < unlockedLending.length && !unlockedLending[j].isDormant) {
                        Staking memory staking = getStakings[unlockedLending[j].user][unlockedLending[j].index];

                        uint256 decimals = staking.token.decimals();

                        // ROI Pool reduction

                        uint256 reward = getAmountRewardSingle(staking.user, staking.index, staking.isLending, false, timestampToConsider);

                        (uint256 amountTokenConverted, uint256 rewardConverted) =
                            decimals < 18 ?
                            (staking.amountTokenStaked * 10 ** (18 - decimals), reward * 10 ** (18 - decimals)) :
                            (staking.amountTokenStaked, reward);

                        excludedFromROIReserves += rewardConverted;

                        // Current Pool reduction

                        uint256 fee = staking.amountTokenStaked.mul(unstakeFeePercentage).div(1000);

                        (uint8 poolType, uint8 feeType) = staking.isLending ? (LEND_POOL, LEND_FEE_POOL) : (STAKE_POOL, STAKE_FEE_POOL);

                        treasury.updatePool(poolType, staking.token, staking.amountTokenStaked, 0, 0, false);
                        treasury.updatePool(feeType, staking.token, 0, fee, 0, true);

                        treasury.updatePool(STAKING_TYPE_POOL + staking.stakingType, IERC20(address(0)), amountTokenConverted, 0, 0, false);

                        // Designating this stake as Dormant

                        getStakings[unlockedLending[j].user][unlockedLending[j].index].isDormant = true;
                    }

                    if (j < unlockedStaking.length && !unlockedStaking[j].isDormant) {
                        Staking storage staking = getStakings[unlockedStaking[j].user][unlockedStaking[j].index];

                        uint256 decimals = staking.token.decimals();

                        // ROI Pool reduction

                        uint256 reward = getAmountRewardSingle(staking.user, staking.index, staking.isLending, false, timestampToConsider);

                        (uint256 amountTokenConverted, uint256 rewardConverted) =
                            decimals < 18 ?
                            (staking.amountTokenStaked * 10 ** (18 - decimals), reward * 10 ** (18 - decimals)) :
                            (staking.amountTokenStaked, reward);

                        excludedFromROIReserves += rewardConverted;

                        // Current Pool reduction

                        uint256 fee = staking.amountTokenStaked.mul(unstakeFeePercentage).div(1000);

                        (uint8 poolType, uint8 feeType) = staking.isLending ? (LEND_POOL, LEND_FEE_POOL) : (STAKE_POOL, STAKE_FEE_POOL);

                        treasury.updatePool(poolType, staking.token, staking.amountTokenStaked, 0, 0, false);
                        treasury.updatePool(feeType, staking.token, 0, fee, 0, true);

                        treasury.updatePool(STAKING_TYPE_POOL + staking.stakingType, IERC20(address(0)), amountTokenConverted, 0, 0, false);

                        // Designating this stake as Dormant

                        getStakings[unlockedLending[j].user][unlockedLending[j].index].isDormant = true;
                    }

                    // if (j < unlockedRealEstate.length) {
                    //     uint256 amountToken = unlockedRealEstate[j].amountTokenStaked;

                    //     amountUnlocked +=
                    //         unlockedRealEstate[j].token.decimals() < 18 ?
                    //         amountToken * 10 ** (18 - unlockedRealEstate[j].token.decimals()) :
                    //         amountToken;
                    // }
                }
            }
        }

        // currentPool = currentPool.safeSub(amountUnlocked);
    }

    function _compoundSingle(uint256 _principal, uint256 _ratio) internal pure returns (uint256) {
        uint256 accruedAmount = _principal.mul(_ratio).div(10 ** 18);

        return accruedAmount;
    }

    // modifiers

    modifier stakeActive() {
        _stakeActive();
        _;
    }

    function _stakeActive() internal view {
        require(stakeState, "Stabl3Staking: Stake and Lend not yet started");
    }

    modifier reserved(IERC20 _token) {
        _reserved(_token);
        _;
    }

    function _reserved(IERC20 _token) internal view {
        require(treasury.isReservedToken(_token), "Stabl3Staking: Not a reserved token");
    }
}