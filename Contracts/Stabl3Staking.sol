// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";

import "./ITreasury.sol";
import "./IROI.sol";
import "./IStabl3StakingStruct.sol";

contract Stabl3Staking is Ownable, ReentrancyGuard, IStabl3StakingStruct {
    using SafeMathUpgradeable for uint256;

    uint8 private constant BUY_POOL = 0;

    uint8 private constant STAKE_POOL = 2;
    uint8 private constant STAKE_REWARD_POOL = 3;
    uint8 private constant STAKE_FEE_POOL = 4;
    uint8 private constant LEND_POOL = 5;
    uint8 private constant LEND_REWARD_POOL = 6;
    uint8 private constant LEND_FEE_POOL = 7;

    ITreasury public treasury;
    IROI public ROI;
    address public HQ;

    IERC20 public immutable stabl3;

    uint256[2] public treasuryPercentages;
    uint256[2] public ROIPercentages;
    uint256[2] public HQPercentages;

    uint256 public lendingStabl3ClaimTime;
    uint256 public lendingStabl3Percentage;

    uint256 public unstakeFeePercentage;

    uint256 private immutable oneDayTime;
    uint256 private immutable oneYearTime;
    uint256[5] public lockTimes;

    address public stabl3RealEstate;

    bool public stakeState;

    // mappings

    // user stakings
    mapping (address => Staking[]) public getStakings;

    // all users
    mapping (address => bool) public getStakers;
    address[] public allStakers;

    /**
     * @notice This mapping stores each user's lifetime staking records
     * @dev No deductions when unstaking
     */
    mapping (address => mapping (bool => Record)) public getRecords;

    /**
     * @notice This mapping stores the current amounts staked per staking type
     * @dev Deductions when unstaking
     */
    mapping (uint8 => uint256) public getAmountStakedPerStakingType;

    // events

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedHQ(address newHQ, address oldHQ);

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

        // TODO change
        stabl3 = IERC20(0xDf9c4990a8973b6cC069738592F27Ea54b27D569);

        treasuryPercentages = [975, 761];
        ROIPercentages = [0, 0];
        HQPercentages = [25, 39];

        // TODO remove
        lendingStabl3ClaimTime = 300; // 0:15 hours time in seconds
        // lendingStabl3ClaimTime = 2592000; // 1 month time in seconds
        lendingStabl3Percentage = 200;

        unstakeFeePercentage = 50;

        // TODO remove
        oneDayTime = 10; // it is seen as 1 day in testing
        oneYearTime = 3600;
        lockTimes = [0, 900, 1800, 2700, 3600];   // 0:45, 1:30, 2:15 and 3:00 hours time in seconds
        // oneDayTime = 86400;
        // oneYearTime = 31104000;
        // lockTimes = [0, 7776000, 15552000, 23328000, 31104000];   // 3, 6, 9 and 12 months time in seconds

        // TODO maybe consider times like this to complete 365 days
        // 31+28+31, 30+31+30, 31+31+30, 31+30+31
        // 90, 91, 92, 92
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
            if (lendingStabl3Percentage != _lendingStabl3Percentage) {
                lendingStabl3Percentage = _lendingStabl3Percentage;
            }
        }
        else {
            require(_treasuryPercentage + _ROIPercentage + _HQPercentage == 1000,
                "Stabl3Staking: Sum of magnified Stake percentages should equal 1000");

            treasuryPercentages[0] = _treasuryPercentage;
            ROIPercentages[0] = _ROIPercentage;
            HQPercentages[0] = _HQPercentage;
        }
    }

    function updateUnstakeFeePercentage(uint256 _unstakeFeePercentage) external onlyOwner {
        require(unstakeFeePercentage != _unstakeFeePercentage, "Stabl3Staking: Unstake Fee is already this value");
        unstakeFeePercentage = _unstakeFeePercentage;
    }

    function updateLockTimes(uint256[4] memory _lockTimes) external onlyOwner {
        lockTimes = _lockTimes;
    }

    function updateLendingStabl3ClaimTime(uint256 _lendingStabl3ClaimTime) external onlyOwner {
        require(lendingStabl3ClaimTime != _lendingStabl3ClaimTime, "Stabl3Staking: Lending Stabl3 Claim Time is already this value");
        lendingStabl3ClaimTime = _lendingStabl3ClaimTime;
    }

    function updateStabl3RealEstate(address _stabl3RealEstate) external onlyOwner {
        require(stabl3RealEstate != _stabl3RealEstate, "Stabl3Staking: Stabl3RealEstate is already this address");
        stabl3RealEstate = _stabl3RealEstate;
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
        uint256 unlockedLendingLength;
        uint256 lockedLendingLength;
        uint256 unlockedStakingLength;
        uint256 lockedStakingLength;

        for (uint256 i = 0 ; i < getStakings[_user].length ; i++) {
            Staking memory staking = getStakings[_user][i];

            if (
                staking.status &&
                staking.isRealEstate == _isRealEstate
            ) {
                if (block.timestamp >= staking.endTime) {
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

            if (
                staking.status &&
                staking.isRealEstate == _isRealEstate
            ) {
                if (block.timestamp >= staking.endTime) {
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

    function stake(
        IERC20 _token,
        uint256 _amountToken,
        uint8 _stakingType,
        bool _isLending
    ) public stakeActive reserved(_token) nonReentrant {
        require(1 <= _stakingType && _stakingType <= 4, "Stabl3Staking: Incorrect staking type");
        require(_amountToken > 1, "Stabl3Staking: Insufficient amount");
        (uint256 maxPool, uint256 currentPool) = ROI.validatePool(_token, _amountToken, _stakingType, _isLending);
        require(currentPool <= maxPool, "Stabl3Staking: Staking pool limit reached. Please try again later or try a different amount");

        if (!getStakers[msg.sender]) {
            getStakers[msg.sender] = true;
            allStakers.push(msg.sender);
        }

        uint256 amountTokenLending;
        uint256 amountStabl3Lending;

        if (_isLending) {
            uint256 amountTreasury = _amountToken.mul(treasuryPercentages[1]).div(1000);

            uint256 amountROI = _amountToken.mul(ROIPercentages[1]).div(1000);

            uint256 amountHQ = _amountToken.mul(HQPercentages[1]).div(1000);

            amountTokenLending = _amountToken.mul(lendingStabl3Percentage).div(1000);
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

        uint256 timestampToConsider = block.timestamp;

        Staking memory staking = Staking({
            index: getStakings[msg.sender].length,
            user: msg.sender,
            status: true,
            stakingType: _stakingType,
            token: _token,
            amountTokenStaked: _amountToken,
            startTime: timestampToConsider,
            endTime: timestampToConsider + lockTimes[_stakingType],
            rewardWithdrawn: 0,
            rewardWithdrawTimeLast: timestampToConsider,
            isLending: _isLending,
            isClaimedStabl3Lending: false,
            amountTokenLending: amountTokenLending,
            amountStabl3Lending: amountStabl3Lending,
            isRealEstate: false
        });

        getStakings[msg.sender].push(staking);

        Record storage record = getRecords[msg.sender][_isLending];

        uint256 amountTokenConverted = _token.decimals() < 18 ? _amountToken * 10 ** (18 - _token.decimals()) : _amountToken;

        record.totalAmountTokenStaked += amountTokenConverted;
        getAmountStakedPerStakingType[_stakingType] += amountTokenConverted;

        ROI.updateAPR();

        emit Stake(
            staking.user,
            staking.index,
            staking.stakingType,
            staking.token,
            staking.amountTokenStaked,
            record.totalAmountTokenStaked,
            staking.isLending,
            timestampToConsider
        );
    }

    /**
     * @notice This function is called externally by the Stabl3RealEstate contract to provide APR on a certain value
     * @dev Requires permit
     * @dev Requires external checks, transfers, records, updatePool calls, updateAPR calls and event emissions
     */
    function accessWithPermit(address _user, Staking memory _staking, uint8 _identifier) external {
        require(msg.sender == stabl3RealEstate, "Stabl3Staking: Not allowed");

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
        uint256 amountReward;

        Staking memory staking = getStakings[_user][_index];

        if (
            staking.status &&
            staking.isLending == _isLending &&
            staking.isRealEstate == _isRealEstate &&
            staking.rewardWithdrawTimeLast < staking.endTime
        ) {
            uint256 numberOfMinutes =
                _timestamp > staking.endTime ?
                (staking.endTime - staking.rewardWithdrawTimeLast) / oneDayTime :
                (_timestamp - staking.rewardWithdrawTimeLast) / oneDayTime;

            if (numberOfMinutes > 0) {
                uint256 ratio = ROI.getAPR();

                uint256 rewardTotal = _compoundSingle(staking.amountTokenStaked, ratio);

                amountReward = (rewardTotal * oneDayTime * numberOfMinutes) / oneYearTime;
            }
        }

        return amountReward;
    }

    function getAmountRewardAll(address _user, bool _isLending, bool _isRealEstate) public view returns (uint256) {
        uint256 totalAmountReward;

        uint256 timestampToConsider = block.timestamp;

        for (uint256 i = 0 ; i < getStakings[_user].length ; i++) {
            Staking memory staking = getStakings[_user][i];

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

    function _withdrawAmountRewardSingle(uint256 _index, bool _isLending, uint256 _timestamp) internal nonReentrant {
        Staking storage staking = getStakings[msg.sender][_index];

        uint256 reward = getAmountRewardSingle(msg.sender, _index, _isLending, false, _timestamp);

        if (reward > 0) {
            Record storage record = getRecords[msg.sender][staking.isLending];

            _evaluateReward(staking.token, reward, staking.isLending);

            staking.rewardWithdrawn += reward;
            staking.rewardWithdrawTimeLast = _timestamp > staking.endTime ? staking.endTime : _timestamp;

            uint256 rewardConverted = staking.token.decimals() < 18 ? reward * 10 ** (18 - staking.token.decimals()) : reward;
            record.totalRewardWithdrawn += rewardConverted;

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
        uint256 claimableStabl3Lending;

        Staking memory staking = getStakings[_user][_index];

        if (
            staking.status &&
            staking.isLending &&
            !staking.isClaimedStabl3Lending &&
            _timestamp > staking.startTime + lendingStabl3ClaimTime
        ) {
            claimableStabl3Lending = staking.amountStabl3Lending;
        }

        return claimableStabl3Lending;
    }

    function getClaimableStabl3LendingAll(address _user) public view returns (uint256) {
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

    function _claimStabl3LendingSingle(uint256 _index, uint256 _timestamp) internal nonReentrant {
        Staking storage staking = getStakings[msg.sender][_index];

        Record storage record = getRecords[msg.sender][true];

        uint256 amountStabl3Lending = getClaimableStabl3LendingSingle(msg.sender, _index, _timestamp);

        if (amountStabl3Lending > 0) {
            stabl3.transferFrom(address(treasury), msg.sender, amountStabl3Lending);

            staking.isClaimedStabl3Lending = true;

            record.totalAmountStabl3Withdrawn += amountStabl3Lending;

            treasury.updateStabl3CirculatingSupply(amountStabl3Lending, true);

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

    function _unstakeSingle(uint256 _index, uint256 _amountToUnstake) internal nonReentrant {
        Staking storage staking = getStakings[msg.sender][_index];

        uint256 fee = staking.amountTokenStaked.mul(unstakeFeePercentage).div(1000);
        uint256 amountToWithdrawWithFee = staking.amountTokenStaked - fee;

        SafeERC20.safeTransferFrom(staking.token, address(treasury), address(ROI), fee);

        SafeERC20.safeTransferFrom(staking.token, address(treasury), msg.sender, amountToWithdrawWithFee);

        staking.status = false;

        (uint8 poolType, uint8 feeType) = staking.isLending ? (LEND_POOL, LEND_FEE_POOL) : (STAKE_POOL, STAKE_FEE_POOL);

        treasury.updatePool(poolType, staking.token, staking.amountTokenStaked, 0, 0, false);
        treasury.updatePool(feeType, staking.token, 0, fee, 0, true);

        uint256 amountTokenConverted =
            staking.token.decimals() < 18 ? staking.amountTokenStaked * 10 ** (18 - staking.token.decimals()) : staking.amountTokenStaked;

        getAmountStakedPerStakingType[staking.stakingType] -= amountTokenConverted;

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

    function restakeSingle(uint256 _index, uint256 _amountToWithdraw, uint8 _stakingType) external stakeActive {
        Staking storage staking = getStakings[msg.sender][_index];

        require(staking.status, "Stabl3Staking: Invalid Staking");
        require(!staking.isRealEstate, "Stabl3Staking: Not allowed");
        require(block.timestamp > staking.endTime, "Stabl3Staking: Cannot unstake before end time");
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

        require(staking.status, "Stabl3Staking: Invalid Staking");
        require(!staking.isRealEstate, "Stabl3Staking: Not allowed");
        require(block.timestamp > staking.endTime, "Stabl3Staking: Cannot unstake before end time");

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

    function _evaluateReward(IERC20 _rewardToken, uint256 _amountRewardToken, bool _isLending) internal {
        uint8 rewardPoolType = _isLending ? LEND_REWARD_POOL : STAKE_REWARD_POOL;

        uint256 amountRewardTokenROI = _rewardToken.balanceOf(address(ROI));

        if (_amountRewardToken > amountRewardTokenROI) {
            if (amountRewardTokenROI != 0) {
                SafeERC20.safeTransferFrom(_rewardToken, address(ROI), msg.sender, amountRewardTokenROI);

                _amountRewardToken -= amountRewardTokenROI;

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

                        treasury.updatePool(rewardPoolType, reservedToken, 0, amountRewardTokenConverted, 0, true);

                        _amountRewardToken = 0;
                        break;
                    }
                }
            }
        }
        else {
            SafeERC20.safeTransferFrom(_rewardToken, address(ROI), msg.sender, _amountRewardToken);

            treasury.updatePool(rewardPoolType, _rewardToken, 0, _amountRewardToken, 0, true);
        }
    }

    function _compoundSingle(uint256 _principal, uint256 _ratio) internal pure returns (uint256) {
        uint256 accruedAmount = _principal.mul(_ratio).div(10 ** 18);

        return accruedAmount;
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