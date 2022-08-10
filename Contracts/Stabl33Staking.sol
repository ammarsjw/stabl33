// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.16;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";

import "./IStabl33BuyAndBond.sol";

contract Stabl33Staking is Ownable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20 for IERC20;

    IStabl33BuyAndBond public stabl33BuyAndBond;

    address public treasury;
    address public ROI;
    address public HQ;

    uint256[] public treasuryPercentages;
    uint256[] public ROIPercentages;
    uint256[] public HQPercentages;

    uint256 public ROIFeePercentage;

    IERC20 public usdc = IERC20(0x8Af5a6599BD2406C44588FCf84FD6Eb1bB2e0243);
    IERC20 public dai = IERC20(0xA83a21816ae63D3315c540396f887F53cfF274fA);

    IERC20 public stabl3 = IERC20(0x20A91B0d2A5545BF05bcA96778e138E2E154e083);

    uint256[] public lockTimes;

    uint256 public rewardPercentage;

    // structs

    struct Staking {
        uint256 index;
        address user;
        bool status;
        IERC20 token;
        uint256 amountToken;
        uint8 stakingType;
        uint256 endTime;
    }

    // mappings

    // ongoing stakings
    mapping (address => Staking[]) public getStakings;

    // supported tokens to stake
    mapping (IERC20 => bool) public getSupportedTokens;

    // array for supported tokens
    IERC20[] public allSupportedTokens;

    // total amount of tokens received
    mapping (IERC20 => uint256) public totalStakedAmount;

    // events

    event Buy(address indexed user, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event Stake(uint256 index, address indexed user, IERC20 token, uint256 amountToken, uint8 stakingType);

    event Unstake(uint256 index, address indexed user, IERC20 token, uint256 amountTokenAccrued, uint8 stakingType);

    event UpdatedSupportedToken(IERC20 token, bool state);

    // constructor

    constructor(address _stabl33BuyAndBond) {
        stabl33BuyAndBond = IStabl33BuyAndBond(_stabl33BuyAndBond);

        treasury = 0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80;
        ROI = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        treasuryPercentages = [975, 800];
        ROIPercentages = [0, 175];
        HQPercentages = [25, 25];

        ROIFeePercentage = 50;

        updateSupportedToken(usdc, true);
        updateSupportedToken(dai, true);

        lockTimes = [7776000, 15552000, 23328000, 31104000];   // 3, 6, 9 and 12 months time in seconds

        // TODO
        rewardPercentage = 1;
    }

    function updateTreasury(address _treasury) external onlyOwner {
        require(treasury != _treasury, "STABL33: Treasury is already this address");
        treasury = _treasury;
    }

    function updateROI(address _ROI) external onlyOwner {
        require(ROI != _ROI, "STABL33: ROI is already this address");
        ROI = _ROI;
    }

    function updateHQ(address _HQ) external onlyOwner {
        require(HQ != _HQ, "STABL33: HQ is already this address");
        HQ = _HQ;
    }

    function updateSupportedToken(IERC20 token, bool state) public onlyOwner {
        require(getSupportedTokens[token] != state, "STABL33: Supported token is already of the value 'state'");
        getSupportedTokens[token] = state;
        emit UpdatedSupportedToken(token, state);
    }

    function _validatePool(IERC20 _token, uint256 _amountToken) internal view returns (bool) {
        uint256 maxPool;
        uint256 currentPool;

        uint256 decimalsSupportedToken;
        uint256 amountSupportedTokenBuyAndBond;
        uint256 amountSupportedTokenReceived;
        for (uint256 i = 0 ; i < allSupportedTokens.length ; i++) {
            amountSupportedTokenBuyAndBond = stabl33BuyAndBond.getTotalTokenAmounts(allSupportedTokens[i]).mul(70).div(100);

            amountSupportedTokenReceived = totalStakedAmount[allSupportedTokens[i]];

            decimalsSupportedToken = IERC20(allSupportedTokens[i]).decimals();
            if (decimalsSupportedToken < 18) {
                amountSupportedTokenBuyAndBond = amountSupportedTokenBuyAndBond.mul(10 ** (18 - decimalsSupportedToken));

                amountSupportedTokenReceived = amountSupportedTokenReceived.mul(10 ** (18 - decimalsSupportedToken));
            }

            maxPool += amountSupportedTokenBuyAndBond;

            currentPool += amountSupportedTokenReceived;
        }

        uint256 decimalsToken = IERC20(_token).decimals();
        if (decimalsToken < 18) {
            _amountToken = _amountToken.mul(10 ** (18 - decimalsToken));
        }

        bool isValid = currentPool.add(_amountToken) <= maxPool;

        return isValid;
    }

    function stake(IERC20 _token, uint256 _amountToken, uint8 _stakingType) external {
        require(getSupportedTokens[_token], "STABL33: Token not supported");
        require(_amountToken > 0, "STABL33: Amount should be greater than zero");
        require(1 <= _stakingType && _stakingType <= 4, "STABL33: Incorrect staking type");
        require(_validatePool(_token, _amountToken), "STABL33: Staking pool limit reached");

        Staking memory staking = Staking(
            getStakings[msg.sender].length,
            msg.sender,
            true,
            _token,
            _amountToken,
            _stakingType,
            block.timestamp + lockTimes[_stakingType - 1]
        );
        emit Stake(staking.index, staking.user, staking.token, staking.amountToken, staking.stakingType);
        getStakings[msg.sender].push(staking);

        totalStakedAmount[_token] += _amountToken;

        uint256 amountTreasury = _amountToken.mul(treasuryPercentages[0]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, treasury, amountTreasury);

        uint256 amountHQ = _amountToken.mul(HQPercentages[0]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);
    }

    function unstake(uint256 index) external {
        Staking storage staking = getStakings[msg.sender][index];

        require(staking.status, "STABL33: Already unstaked");
        require(block.timestamp > staking.endTime, "STABL33: Cannot unstake before end time");

        uint256 reward = staking.amountToken.mul(rewardPercentage).div(100);

        uint256 fee = staking.amountToken.mul(ROIFeePercentage).div(1000);

        uint256 finalAmountToken = staking.amountToken + reward - fee;

        SafeERC20.safeTransferFrom(IERC20(staking.token), treasury, ROI, fee);

        SafeERC20.safeTransferFrom(IERC20(staking.token), treasury, msg.sender, finalAmountToken);

        staking.status = false;

        totalStakedAmount[staking.token] -= staking.amountToken;

        emit Unstake(staking.index, staking.user, staking.token, finalAmountToken, staking.stakingType);
    }
}