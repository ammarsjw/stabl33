// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.16;

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
    uint256[] public lockTimes;

    uint256 public lendingStabl3Percentage;
    uint256 public lendingStabl3ClaimTime;

    bool public stakeState;

    // structs

    struct Staking {
        uint256 index;
        address user;
        bool status;
        IERC20 token;
        uint256 amountStakedToken;
        uint8 stakingType;
        uint256 startTime;
        uint256 rewardWithdrawn;
        uint256 rewardWithdrawTimeLast;
        bool isLending;
        bool isClaimedLendingStabl3;
        uint256 amountLendingToken;
        uint256 amountLendingStabl3;
    }

    // mappings

    // user staking
    mapping (address => Staking[]) public getStakings;

    // events

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedHQ(address newHQ, address oldHQ);

    event UpdatedUnstakeFeePercentage(uint256 newUnstakeFeePercentage, uint256 oldUnstakeFeePercentage);

    event UpdatedLockTimes(uint256[4] newLockTimes, uint256[] oldLockTimes);

    event UpdatedLendingStabl3Percentage(uint256 newLendingStabl3Percentage, uint256 oldLendingStabl3Percentage);

    event UpdatedLendingStabl3ClaimTime(uint256 newLendingStabl3ClaimTime, uint256 oldLendingStabl3ClaimTime);

    event Staked(address indexed user, uint256 index, IERC20 token, uint256 amountToken, uint8 stakingType, bool isLend);

    event WithdrewReward(address indexed user, uint256 index, IERC20 token, uint256 reward, uint256 rewardWithdrawTimeLast);

    event Unstaked(address indexed user, uint256 index, IERC20 token, uint256 amountToken, uint256 reward, uint8 stakingType, bool isLend);

    event ClaimedLendingStabl3(address indexed user, uint256 index, IERC20 token, uint256 amountToken, uint256 amountStabl3);

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
        lockTimes = [7776000, 15552000, 23328000, 31104000];   // 3, 6, 9 and 12 months time in seconds

        lendingStabl3Percentage = 200;
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
        emit UpdatedLockTimes(_lockTimes, lockTimes);
        lockTimes = _lockTimes;
    }

    function updateLendingStabl3Percentage(uint256 _lendingStabl3Percentage) external onlyOwner {
        require(lendingStabl3Percentage != _lendingStabl3Percentage, "Stabl3Staking: Lending Stabl3 Percentage is already this value");
        emit UpdatedLendingStabl3Percentage(_lendingStabl3Percentage, lendingStabl3Percentage);
        lendingStabl3Percentage = _lendingStabl3Percentage;
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

    function validatePool(IERC20 _token, uint256 _amountToken) public view stakeActive reserved(_token) returns (bool) {
        uint256 maxPool;
        uint256 currentPool;

        IERC20 reservedToken;
        uint256 decimalsReservedToken;
        uint256 boughtAmountReservedToken;
        uint256 bondedAmountReservedToken;

        uint256 stakedAmountReservedToken;
        uint256 lendedAmountReservedToken;
        for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
            reservedToken = treasury.allReservedTokens(i);
            if (treasury.isReservedToken(reservedToken)) {
                boughtAmountReservedToken = treasury.getTreasuryPool(BUY_POOL, reservedToken);
                bondedAmountReservedToken = treasury.getTreasuryPool(BOND_POOL, reservedToken);

                stakedAmountReservedToken = treasury.sumOfAllPools(STAKE_POOL, reservedToken);
                lendedAmountReservedToken = treasury.sumOfAllPools(LEND_POOL, reservedToken);

                decimalsReservedToken = reservedToken.decimals();

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

        uint256 amountLendingToken;
        uint256 amountLendingStabl3;
        if (_isLending) {
            amountLendingToken = _amountToken.mul(lendingStabl3Percentage).div(1000);
            amountLendingStabl3 = treasury.getAmountOut(_token, amountLendingToken);
        }

        Staking memory staking = Staking(
            getStakings[msg.sender].length,
            msg.sender,
            true,
            _token,
            _amountToken,
            _stakingType,
            block.timestamp,
            0,
            block.timestamp,
            _isLending,
            false,
            amountLendingToken,
            amountLendingStabl3
        );

        getStakings[msg.sender].push(staking);

        uint256 percentageDistributionIndex;
        uint8 poolType;
        if (_isLending) {
            percentageDistributionIndex = 1;
            poolType = LEND_POOL;
        }
        else {
            percentageDistributionIndex = 0;
            poolType = STAKE_POOL;
        }

        uint256 amountTreasury = _amountToken.mul(treasuryPercentages[percentageDistributionIndex]).ceilDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, address(treasury), amountTreasury);

        uint256 amountROI;
        if (ROIPercentages[percentageDistributionIndex] != 0) {
            amountROI = _amountToken.mul(ROIPercentages[percentageDistributionIndex]).div(1000);
            SafeERC20.safeTransferFrom(_token, msg.sender, address(ROI), amountROI);
        }

        uint256 amountHQ = _amountToken.mul(HQPercentages[percentageDistributionIndex]).div(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);

        treasury.updatePool(poolType, _token, amountTreasury, amountROI, amountHQ, true);

        emit Staked(staking.user, staking.index, staking.token, staking.amountStakedToken, staking.stakingType, staking.isLending);
        ROI.updateAPR();
    }

    // TODO different modules different unstakes
    function unstake(uint256 index) external stakeActive {
        Staking storage staking = getStakings[msg.sender][index];

        require(staking.amountStakedToken > 0, "Stabl3Staking: No such stake or lend exists");
        require(staking.status, "Stabl3Staking: Already unstaked");
        require(block.timestamp > staking.startTime + lockTimes[staking.stakingType - 1], "Stabl3Staking: Cannot unstake before end time");

        uint256 endTime = staking.startTime + lockTimes[staking.stakingType - 1];

        uint256 rewardPercentagePerDay = ROI.getAPR() / 365;

        uint256 numberOfDays = (endTime - staking.rewardWithdrawTimeLast) / oneMinuteTime;

        uint256 reward = _compound(
            staking.amountStakedToken,
            rewardPercentagePerDay,
            numberOfDays
        );

        uint256 fee = staking.amountStakedToken.mul(unstakeFeePercentage).div(1000);

        uint256 amountTokenWithFee = staking.amountStakedToken - fee;

        if (staking.isLending && !staking.isClaimedLendingStabl3) {
            _claimLendingStabl3(staking);
        }

        uint8 poolType;
        if (staking.isLending) {
            poolType = LEND_POOL;
        }
        else {
            poolType = STAKE_POOL;
        }

        SafeERC20.safeTransferFrom(staking.token, address(treasury), address(ROI), fee);
        treasury.updatePool(poolType, staking.token, fee, 0, 0, false);
        treasury.updatePool(poolType, staking.token, 0, fee, 0, true);

        _balanceReward(staking.token, amountTokenWithFee + reward, poolType);

        staking.status = false;
        staking.rewardWithdrawn += reward;
        staking.rewardWithdrawTimeLast = block.timestamp;

        emit Unstaked(
            staking.user,
            staking.index,
            staking.token,
            amountTokenWithFee,
            staking.rewardWithdrawn,
            staking.stakingType,
            staking.isLending
        );
        ROI.updateAPR();
    }

    function getAmountRewardAll(address _user, bool _isLending) public view stakeActive returns (uint256) {
        uint256 totalReward;

        Staking memory staking;
        uint256 reward;
        for (uint256 i = 0 ; i < getStakings[_user].length ; i++) {
            staking = getStakings[_user][i];

            if (staking.isLending == _isLending) {
                if (staking.amountStakedToken > 0) {
                    uint256 endTime = block.timestamp;

                    uint256 numberOfMinutes = (endTime - staking.rewardWithdrawTimeLast) / oneMinuteTime;

                    if (numberOfMinutes > 0) {
                        uint256 ratio = ROI.getAPR() / 100;

                        uint256 rewardTotal = _compound(
                            staking.amountStakedToken,
                            ratio,
                            1
                        );

                        reward = rewardTotal / 31536000 * oneMinuteTime * numberOfMinutes;

                        totalReward += reward;
                    }
                }
            }
        }

        return totalReward;
    }

    function getAmountStakedAll(address _user, bool _isLending) public view stakeActive returns (uint256) {
        uint256 totalAmountStakedToken;

        Staking memory staking;
        uint256 amountStakedToken;
        for (uint256 i = 0 ; i < getStakings[_user].length ; i++) {
            staking = getStakings[_user][i];

            if (staking.isLending == _isLending) {
                if (staking.amountStakedToken > 0) {
                    amountStakedToken = staking.amountStakedToken;

                    totalAmountStakedToken += amountStakedToken;
                }
            }
        }

        return totalAmountStakedToken;
    }

    // TODO match naming convention
    function getWithdrawableRewardSingle(address _user, uint256 _index) public view stakeActive returns (uint256) {
        Staking memory staking = getStakings[_user][_index];

        if (staking.amountStakedToken == 0) {
            return 0;
        }

        uint256 endTime = block.timestamp;

        uint256 numberOfMinutes = (endTime - staking.rewardWithdrawTimeLast) / oneMinuteTime;

        if (numberOfMinutes == 0) {
            return 0;
        }

        uint256 ratio = ROI.getAPR() / 100;

        uint256 rewardTotal = _compound(
            staking.amountStakedToken,
            ratio,
            1
        );

        uint256 reward = rewardTotal / 31536000 * oneMinuteTime * numberOfMinutes;

        return reward;
    }

    // TODO match naming convention
    function withdrawRewardSingle(uint256 _index) external {
        Staking storage staking = getStakings[msg.sender][_index];

        require(staking.amountStakedToken > 0, "Stabl3Staking: No such stake or lend exists");
        require(staking.status, "Stabl3Staking: Already unstaked");

        uint256 reward = getWithdrawableRewardSingle(msg.sender, _index);

        uint8 poolType;
        if (staking.isLending) {
            poolType = LEND_POOL;
        }
        else {
            poolType = STAKE_POOL;
        }

        _balanceReward(staking.token, reward, poolType);

        staking.rewardWithdrawn += reward;
        staking.rewardWithdrawTimeLast = block.timestamp;

        emit WithdrewReward(staking.user, staking.index, staking.token, reward, staking.rewardWithdrawTimeLast);
        ROI.updateAPR();
    }

    function claimLendingStabl3(uint256 index) external stakeActive {
        Staking storage staking = getStakings[msg.sender][index];

        require(staking.amountStakedToken > 0, "Stabl3Staking: No such lend exists");
        require(staking.status, "Stabl3Staking: Already unstaked");
        require(staking.isLending, "Stabl3Staking: Stabl3 can only be claimed when lending");
        require(!staking.isClaimedLendingStabl3, "Stabl3Staking: Stabl3 already claimed");
        require(block.timestamp > staking.startTime + lendingStabl3ClaimTime, "Stabl3Staking: Cannot claim Stabl3 before Claim Time");

        _claimLendingStabl3(staking);
    }

    function _claimLendingStabl3(Staking storage _staking) internal {
        stabl3.transferFrom(address(treasury), msg.sender, _staking.amountLendingStabl3);

        _staking.isClaimedLendingStabl3 = true;

        emit ClaimedLendingStabl3(
            _staking.user,
            _staking.index,
            _staking.token,
            _staking.amountLendingToken,
            _staking.amountLendingStabl3
        );
        treasury.updatePool(BUY_POOL, _staking.token, 0, _staking.amountLendingToken, 0, true);
        treasury.updateRate(_staking.token, _staking.amountLendingToken);
        ROI.updateAPR();
    }

    function _balanceReward(IERC20 _returnToken, uint256 _amountReturnToken, uint8 _poolType) internal {
        uint256 amountReturnTokenTreasury = _returnToken.balanceOf(address(treasury));

        if (_amountReturnToken > amountReturnTokenTreasury) {

            if (amountReturnTokenTreasury != 0) {
                SafeERC20.safeTransferFrom(_returnToken, address(treasury), msg.sender, amountReturnTokenTreasury);

                _amountReturnToken -= amountReturnTokenTreasury;

                treasury.updatePool(_poolType, _returnToken, amountReturnTokenTreasury, 0, 0, false);
            }

            IERC20 reservedToken;
            uint256 decimalsReservedToken;
            uint256 amountReservedTokenTreasury;
            uint256 amountReturnTokenConverted;
            for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
                reservedToken = treasury.allReservedTokens(i);
                if (
                    treasury.isReservedToken(reservedToken) &&
                    reservedToken != _returnToken &&
                    _amountReturnToken != 0
                ) {
                    amountReservedTokenTreasury = reservedToken.balanceOf(address(treasury));

                    decimalsReservedToken = reservedToken.decimals();

                    if (_returnToken.decimals() > decimalsReservedToken) {
                        amountReturnTokenConverted = _amountReturnToken / (10 ** (_returnToken.decimals() - decimalsReservedToken));
                    }
                    else if (_returnToken.decimals() < decimalsReservedToken) {
                        amountReturnTokenConverted = _amountReturnToken * (10 ** (decimalsReservedToken - _returnToken.decimals()));
                    }

                    if (amountReturnTokenConverted > amountReservedTokenTreasury) {
                        SafeERC20.safeTransferFrom(reservedToken, address(treasury), msg.sender, amountReservedTokenTreasury);

                        treasury.updatePool(_poolType, reservedToken, amountReservedTokenTreasury, 0, 0, false);

                        amountReturnTokenConverted -= amountReservedTokenTreasury;
                        if (_returnToken.decimals() > decimalsReservedToken) {
                            _amountReturnToken -= amountReturnTokenConverted * (10 ** (_returnToken.decimals() - decimalsReservedToken));
                        }
                        else if (_returnToken.decimals() < decimalsReservedToken) {
                            _amountReturnToken -= amountReturnTokenConverted / (10 ** (decimalsReservedToken - _returnToken.decimals()));
                        }
                    }
                    else {
                        SafeERC20.safeTransferFrom(reservedToken, address(treasury), msg.sender, amountReturnTokenConverted);

                        treasury.updatePool(_poolType, reservedToken, amountReturnTokenConverted, 0, 0, false);

                        _amountReturnToken = 0;
                        break;
                    }
                }
            }
        }
        else {
            SafeERC20.safeTransferFrom(_returnToken, address(treasury), msg.sender, _amountReturnToken);

            treasury.updatePool(_poolType, _returnToken, _amountReturnToken, 0, 0, false);
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