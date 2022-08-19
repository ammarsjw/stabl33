// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.16;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";

import "./IStabl3PublicSale.sol";

contract Stabl3Staking is Ownable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20 for IERC20;

    IStabl3PublicSale public stabl3PublicSale;

    address public treasury;
    address public ROI;
    address public HQ;

    uint256[] public treasuryPercentages;
    uint256[] public ROIPercentages;
    uint256[] public HQPercentages;

    uint256 public ROIFeePercentage;

    uint256 public claimStabl3Percentage;

    IERC20 public usdc = IERC20(0x8Af5a6599BD2406C44588FCf84FD6Eb1bB2e0243);
    IERC20 public dai = IERC20(0xA83a21816ae63D3315c540396f887F53cfF274fA);

    IERC20 public stabl3 = IERC20(0x20A91B0d2A5545BF05bcA96778e138E2E154e083);

    uint256[] public lockTimes;

    uint256 public claimTime;

    uint256 public rewardPercentage;

    // structs

    struct Staking {
        uint256 index;
        address user;
        bool status;
        IERC20 token;
        uint256 amountToken;
        uint8 stakingType;
        uint256 startTime;
        bool isLend;
        bool isClaimedStabl3;
    }

    // mappings

    // stakings data
    mapping (address => Staking[]) public getStakings;

    // reserved tokens to stake
    mapping (IERC20 => bool) public isReservedToken;

    // decimals of reserved token
    mapping (IERC20 => uint256) public decimalsReservedToken;

    // array for reserved tokens
    IERC20[] public allReservedTokens;

    // total amount of tokens staked
    mapping (IERC20 => uint256) public amountReservedTokenStaked;

    // total amount of tokens lended
    mapping (IERC20 => uint256) public amountReservedTokenLended;

    // events

    event UpdatedReservedToken(IERC20 token, uint256 decimals, bool state);

    event UpdatedROIFeePercentage(uint256 newROIFeePercentage, uint256 oldROIFeePercentage);

    event UpdatedRewardPercentage(uint256 newRewardPercentage, uint256 oldRewardPercentage); 

    event Staked( address indexed user, uint256 index, IERC20 token, uint256 amountToken, uint8 stakingType, bool isLend);

    event Unstaked( address indexed user, uint256 index, IERC20 token, uint256 amountTokenAccrued, uint8 stakingType, bool isLend);

    event ClaimedStabl3( address indexed user, uint256 index, uint256 amountStabl3);

    // constructor

    constructor(address _stabl3PublicSale) {
        stabl3PublicSale = IStabl3PublicSale(_stabl3PublicSale);

        treasury = 0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80;
        ROI = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        treasuryPercentages = [975, 800];
        ROIPercentages = [0, 175];
        HQPercentages = [25, 25];

        ROIFeePercentage = 50;

        claimStabl3Percentage = 200;

        updateReservedToken(usdc, 6, true);
        updateReservedToken(dai, 18, true);

        lockTimes = [7776000, 15552000, 23328000, 31104000];   // 3, 6, 9 and 12 months time in seconds

        claimTime = 2592000;

        // TODO
        rewardPercentage = 1;
    }

    function updateTreasury(address _treasury) external onlyOwner {
        require(treasury != _treasury, "Stabl3: Treasury is already this address");
        treasury = _treasury;
    }

    function updateROI(address _ROI) external onlyOwner {
        require(ROI != _ROI, "Stabl3: ROI is already this address");
        ROI = _ROI;
    }

    function updateHQ(address _HQ) external onlyOwner {
        require(HQ != _HQ, "Stabl3: HQ is already this address");
        HQ = _HQ;
    }

    function updateDistributionPercentages(
        uint256[2] memory _treasuryPercentages,
        uint256[2] memory _ROIPercentages,
        uint256[2] memory _HQPercentages
    ) external onlyOwner {
        require(_treasuryPercentages[0] + _ROIPercentages[0] + _HQPercentages[0] == 1000,
            "STABL3: Sum of magnified buy percentages should equal 1000");
        require(_treasuryPercentages[1] + _ROIPercentages[1] + _HQPercentages[1] == 1000,
            "STABL3: Sum of magnified bond percentages should equal 1000");

        treasuryPercentages = _treasuryPercentages;
        ROIPercentages = _ROIPercentages;
        HQPercentages = _HQPercentages;
    }

    function updateReservedToken(IERC20 token, uint256 decimals, bool state) public onlyOwner {
        require(isReservedToken[token] != state, "Stabl3: Reserved token is already of the value 'state'");
        isReservedToken[token] = state;
        decimalsReservedToken[token] = decimals;
        allReservedTokens.push(token);
        emit UpdatedReservedToken(token, decimals, state);
    }

    function updateROIFeePercentage(uint256 _ROIFeePercentage) external onlyOwner {
        emit UpdatedROIFeePercentage(_ROIFeePercentage, ROIFeePercentage);
        ROIFeePercentage = _ROIFeePercentage;
    }

    function _validatePool(IERC20 _token, uint256 _amountToken, bool _isLend) internal view returns (bool) {
        uint256 maxPool;
        uint256 currentPool;

        uint256 decimals;
        uint256 amountReservedTokenPooled;
        uint256 amountReservedTokenReceived;
        for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
            if (isReservedToken[allReservedTokens[i]]) {
                amountReservedTokenPooled = stabl3PublicSale.getAmountReservedTokenPooled(allReservedTokens[i]).mul(70).div(100);

                if (_isLend) {
                    amountReservedTokenReceived = amountReservedTokenLended[allReservedTokens[i]];
                }
                else {
                    amountReservedTokenReceived = amountReservedTokenStaked[allReservedTokens[i]];
                }

                decimals = decimalsReservedToken[allReservedTokens[i]];
                if (decimals < 18) {
                    amountReservedTokenPooled = amountReservedTokenPooled.mul(10 ** (18 - decimals));

                    amountReservedTokenReceived = amountReservedTokenReceived.mul(10 ** (18 - decimals));
                }

                maxPool += amountReservedTokenPooled;

                currentPool += amountReservedTokenReceived;
            }
        }

        uint256 decimalsToken = decimalsReservedToken[_token];
        if (decimalsToken < 18) {
            _amountToken = _amountToken.mul(10 ** (18 - decimalsToken));
        }

        bool isValid = currentPool.add(_amountToken) <= maxPool;

        return isValid;
    }

    function stake(IERC20 _token, uint256 _amountToken, uint8 _stakingType, uint8 _stakeOrLend) external {
        require(_stakeOrLend == 0 || _stakeOrLend == 1, "Stabl3: Should be either staking or lending");
        bool isLend = _stakeOrLend == 1;

        require(isReservedToken[_token], "Stabl3: Token not reserved");
        require(_amountToken > 0, "Stabl3: Amount should be greater than zero");
        require(1 <= _stakingType && _stakingType <= 4, "Stabl3: Incorrect staking type");
        require(_validatePool(_token, _amountToken, isLend), "Stabl3: Staking pool limit reached");

        Staking memory staking = Staking(
            getStakings[msg.sender].length,
            msg.sender,
            true,
            _token,
            _amountToken,
            _stakingType,
            block.timestamp,
            isLend,
            false
        );
        emit Staked(staking.user, staking.index, staking.token, staking.amountToken, staking.stakingType, staking.isLend);
        getStakings[msg.sender].push(staking);

        if (isLend) {
            amountReservedTokenLended[_token] += _amountToken;
        }
        else {
            amountReservedTokenStaked[_token] += _amountToken;
        }

        uint256 amountTreasury = _amountToken.mul(treasuryPercentages[_stakeOrLend]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, treasury, amountTreasury);

        if (isLend) {
            uint256 amountROI = _amountToken.mul(ROIPercentages[_stakeOrLend]).roundDiv(1000);
            SafeERC20.safeTransferFrom(_token, msg.sender, ROI, amountROI);
        }

        uint256 amountHQ = _amountToken.mul(HQPercentages[_stakeOrLend]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);
    }

    function unstake(uint256 index) external {
        Staking storage staking = getStakings[msg.sender][index];

        require(staking.amountToken > 0, "Stabl3: No such stake or lend exists");
        require(staking.status, "Stabl3: Already unstaked");
        require(block.timestamp > staking.startTime + lockTimes[staking.stakingType - 1], "Stabl3: Cannot unstake before end time");

        uint256 reward = staking.amountToken.mul(rewardPercentage).div(100);

        uint256 fee = staking.amountToken.mul(ROIFeePercentage).div(1000);

        uint256 amountTokenAccrued = staking.amountToken + reward - fee;

        SafeERC20.safeTransferFrom(IERC20(staking.token), treasury, ROI, fee);

        SafeERC20.safeTransferFrom(IERC20(staking.token), treasury, msg.sender, amountTokenAccrued);

        staking.status = false;

        amountReservedTokenStaked[staking.token] -= staking.amountToken;

        emit Unstaked(staking.user, staking.index, staking.token, amountTokenAccrued, staking.stakingType, staking.isLend);
    }

    function claimStabl3(uint256 index) external {
        Staking storage staking = getStakings[msg.sender][index];

        require(staking.amountToken > 0, "Stabl3: No such lend exists");
        require(staking.status, "Stabl3: Already unstaked");
        require(staking.isLend, "Stabl3: Stabl3 can only be claimed when lending");
        require(!staking.isClaimedStabl3, "Stabl3: Stabl3 already claimed");
        require(block.timestamp > staking.startTime + claimTime, "Stabl3: Cannot claim Stabl3 before 30 days");

        uint256 amountStabl3 = staking.amountToken.mul(claimStabl3Percentage).div(1000);

        stabl3.transferFrom(treasury, msg.sender, amountStabl3);

        staking.isClaimedStabl3 = true;

        emit ClaimedStabl3(staking.user, staking.index, amountStabl3);
    }
}