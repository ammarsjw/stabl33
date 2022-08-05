// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.15;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";

import "./IStabl33BuyAndBond.sol";

contract Stabl33Staking is Ownable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20 for IERC20;

    IStabl33BuyAndBond public stabl33BuyAndBond;

    address public treasuryWallet;
    address public ROIWallet;
    address public HQWallet;

    uint256 public treasuryPercentage;
    uint256 public HQPercentage;

    uint256 public ROIFeePercentage;

    IERC20 public usdc = IERC20(0x8Af5a6599BD2406C44588FCf84FD6Eb1bB2e0243);
    IERC20 public dai = IERC20(0xA83a21816ae63D3315c540396f887F53cfF274fA);

    IERC20 public stabl3 = IERC20(0x20A91B0d2A5545BF05bcA96778e138E2E154e083);

    uint256[] public stakeTimes;

    uint256 public rewardPercentage;

    // structs

    struct Staking {
        uint256 index;
        address recipient;
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

    event Buy(address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event Stake(uint256 index, address indexed recipient, IERC20 token, uint256 amountToken, uint8 stakingType);

    event Unstake(uint256 index, address indexed recipient, IERC20 token, uint256 amountToken, uint8 stakingType);

    event AddedSupportedToken(IERC20 token, bool state);

    // constructor

    constructor(address _stabl33BuyAndBond) {
        stabl33BuyAndBond = IStabl33BuyAndBond(_stabl33BuyAndBond);

        treasuryWallet = 0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80;
        ROIWallet = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;
        HQWallet = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        treasuryPercentage = 975;
        HQPercentage = 25;

        ROIFeePercentage = 50;

        addSupportedToken(usdc, true);
        addSupportedToken(dai, true);

        stakeTimes = [7776000, 15552000, 23328000, 31104000];   // 3, 6, 9 and 12 months time in seconds

        // TODO
        rewardPercentage = 1;
    }

    function updateTreasuryWallet(address _treasuryWallet) external onlyOwner {
        require(treasuryWallet != _treasuryWallet, "STABL33: Treasury wallet is already this address");
        treasuryWallet = _treasuryWallet;
    }

    function updateROIWallet(address _ROIWallet) external onlyOwner {
        require(ROIWallet != _ROIWallet, "STABL33: ROI wallet is already this address");
        ROIWallet = _ROIWallet;
    }

    function updateHQWallet(address _HQWallet) external onlyOwner {
        require(HQWallet != _HQWallet, "STABL33: HQ wallet is already this address");
        HQWallet = _HQWallet;
    }

    function addSupportedToken(IERC20 token, bool state) public onlyOwner {
        require(getSupportedTokens[token] != state, "STABL33: Supported token is already of the value 'state'");
        getSupportedTokens[token] = state;
        emit AddedSupportedToken(token, state);
    }

    function _validateStaking(IERC20 _token, uint256 _amountToken) internal view returns (bool) {
        uint256 maxStakePool;
        uint256 currentStakePool;

        uint256 decimalsSupportedToken;
        uint256 amountSupportedTokenBuyAndBond;
        uint256 amountSupportedTokenStake;
        for (uint256 i = 0 ; i < allSupportedTokens.length ; i++) {
            decimalsSupportedToken = IERC20(allSupportedTokens[i]).decimals();

            amountSupportedTokenBuyAndBond = stabl33BuyAndBond.getTotalTokenAmounts(allSupportedTokens[i]).mul(70).div(100);

            amountSupportedTokenStake = totalStakedAmount[allSupportedTokens[i]];

            if (decimalsSupportedToken < 18) {
                amountSupportedTokenBuyAndBond = amountSupportedTokenBuyAndBond.mul(10 ** (18 - decimalsSupportedToken));

                amountSupportedTokenStake = amountSupportedTokenStake.mul(10 ** (18 - decimalsSupportedToken));
            }

            maxStakePool += amountSupportedTokenBuyAndBond;

            currentStakePool += amountSupportedTokenStake;
        }

        uint256 decimalsToken = IERC20(_token).decimals();
        if (decimalsToken < 18) {
            _amountToken = _amountToken.mul(10 ** (18 - decimalsToken));
        }

        bool isValid = currentStakePool.add(_amountToken) <= maxStakePool;

        return isValid;
    }

    function stake(IERC20 _token, uint256 _amountToken, uint8 _stakingType) external {
        require(getSupportedTokens[_token], "STABL33: Token not supported");
        require(_amountToken > 0, "STABL33: Amount should be greater than zero");
        require(1 <= _stakingType && _stakingType <= 4, "STABL33: Incorrect staking type");
        require(_validateStaking(_token, _amountToken), "STABL33: Staking pool limit reached");

        Staking memory staking = Staking(
            getStakings[msg.sender].length,
            msg.sender,
            true,
            _token,
            _amountToken,
            _stakingType,
            block.timestamp + stakeTimes[_stakingType - 1]
        );
        emit Stake(staking.index, staking.recipient, staking.token, staking.amountToken, staking.stakingType);
        getStakings[msg.sender].push(staking);

        uint256 amountTreasury = _amountToken.mul(treasuryPercentage).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, treasuryWallet, amountTreasury);

        uint256 amountHQ = _amountToken.mul(HQPercentage).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQWallet, amountHQ);
    }

    function unstake(uint256 index) external {
        Staking storage staking = getStakings[msg.sender][index];

        require(staking.status, "STABL33: Staking already claimed");
        require(block.timestamp > staking.endTime, "STABL33: Staking time not finished");

        uint256 reward = staking.amountToken.mul(rewardPercentage).div(100);

        uint256 fee = reward.mul(ROIFeePercentage).div(1000);
        reward -= fee;

        SafeERC20.safeTransferFrom(IERC20(staking.token), treasuryWallet, ROIWallet, fee);

        SafeERC20.safeTransferFrom(IERC20(staking.token), treasuryWallet, msg.sender, reward);

        staking.status = false;

        emit Unstake(staking.index, staking.recipient, staking.token, staking.amountToken, staking.stakingType);
    }
}