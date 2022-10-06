// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";

import "./ITreasury.sol";
import "./IStabl3Staking.sol";

contract ROI is Ownable, ReentrancyGuard, IStabl3StakingStruct {
    using SafeMathUpgradeable for uint256;
    using SafeERC20 for IERC20;

    uint256 private immutable MAX_INT = 2 ** 256 - 1;

    uint8 private constant BUY_POOL = 0;

    uint8 private constant BOND_POOL = 1;

    uint8 private constant STAKE_POOL = 2;
    uint8 private constant STAKE_REWARD_POOL = 3;
    // uint8 private constant STAKE_FEE_POOL = 4;
    uint8 private constant LEND_POOL = 5;
    uint8 private constant LEND_REWARD_POOL = 6;
    // uint8 private constant LEND_FEE_POOL = 7;

    ITreasury public treasury;

    IERC20 public stabl3;

    IERC20 public ucd;

    IStabl3Staking public stabl3Staking;
    uint256 public maxPoolPercentage;

    // mappings

    // contracts with permission to access ROI pool funds
    mapping (address => bool) public permitted;

    // events

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedPermission(address contractAddress, bool state);

    event APR(uint256 APR, uint256 reserves, uint256 totalRewardDistributed, uint256 blockTimestampLast);

    // constructor

    constructor(ITreasury _treasury) {
        treasury = _treasury;

        stabl3 = IERC20(0xDf9c4990a8973b6cC069738592F27Ea54b27D569);

        maxPoolPercentage = 700;

        updatePermission(address(_treasury), true);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        require(address(treasury) != _treasury, "ROI: Treasury is already this address");
        updatePermission(address(treasury), false);
        updatePermission(_treasury, true);
        emit UpdatedTreasury(_treasury, address(treasury));
        treasury = ITreasury(_treasury);
    }

    function initializeUCD(address _ucd) external onlyOwner {
        require(address(ucd) != _ucd, "ROI: UCD is already this address");
        ucd = IERC20(_ucd);
    }

    function updateStabl3Staking(address _stabl3Staking) external onlyOwner {
        require(address(stabl3Staking) != _stabl3Staking, "ROI: Stabl3 Staking is already this address");
        stabl3Staking = IStabl3Staking(_stabl3Staking);
    }

    function updateMaxPoolPercentage(uint256 _maxPoolPercentage) external onlyOwner {
        require(maxPoolPercentage != _maxPoolPercentage, "Stabl3Staking: Max Pool Percentage is already this value");
        maxPoolPercentage = _maxPoolPercentage;
    }

    function updatePermission(address _contractAddress, bool _state) public onlyOwner {
        require(permitted[_contractAddress] != _state, "ROI: Address is already of the value 'state'");
        permitted[_contractAddress] = _state;

        if (_state) {
            delegateApprove(stabl3, _contractAddress, true);

            // delegateApprove(ucd, _contractAddress, true);

            for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
                delegateApprove(treasury.allReservedTokens(i), _contractAddress, true);
            }
        }
        else {
            delegateApprove(stabl3, _contractAddress, false);

            // delegateApprove(ucd, _contractAddress, false);

            for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
                delegateApprove(treasury.allReservedTokens(i), _contractAddress, false);
            }
        }

        emit UpdatedPermission(_contractAddress, _state);
    }

    function getTotalRewardDistributed() public view returns (uint256) {
        uint256 totalRewardDistributed;

        for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
            IERC20 reservedToken = treasury.allReservedTokens(i);

            if (treasury.isReservedToken(reservedToken)) {
                uint256 stakeRewardAmount = treasury.sumOfAllPools(STAKE_REWARD_POOL, reservedToken);
                uint256 lendRewardAmount = treasury.sumOfAllPools(LEND_REWARD_POOL, reservedToken);

                uint256 decimals = reservedToken.decimals();

                if (decimals < 18) {
                    stakeRewardAmount *= 10 ** (18 - decimals);
                    lendRewardAmount *= 10 ** (18 - decimals);
                }

                totalRewardDistributed += stakeRewardAmount + lendRewardAmount;
            }
        }

        return totalRewardDistributed;
    }

    function getReserves() public view returns (uint256) {
        uint256 totalReserves;

        for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
            IERC20 reservedToken = treasury.allReservedTokens(i);

            if (treasury.isReservedToken(reservedToken)) {
                uint256 amount = reservedToken.balanceOf(address(this));

                uint256 decimals = reservedToken.decimals();

                if (decimals < 18) {
                    amount *= 10 ** (18 - decimals);
                }

                totalReserves += amount;
            }
        }

        return totalReserves;
    }

    // APR is in 18 decimals
    function getAPR() public view returns (uint256) {
        uint256 totalStakedAmount;
        uint256 totalLendedAmount;

        for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
            IERC20 reservedToken = treasury.allReservedTokens(i);

            if (treasury.isReservedToken(reservedToken)) {
                uint256 stakedAmount = treasury.sumOfAllPools(STAKE_POOL, reservedToken);
                uint256 lendedAmount = treasury.sumOfAllPools(LEND_POOL, reservedToken);    // ROI Pool for lending is 0 by default

                uint256 decimalsReservedToken = reservedToken.decimals();

                if (decimalsReservedToken < 18) {
                    stakedAmount *= 10 ** (18 - decimalsReservedToken);
                    lendedAmount *= 10 ** (18 - decimalsReservedToken);
                }

                totalStakedAmount += stakedAmount;
                totalLendedAmount += lendedAmount;
            }
        }

        uint256 totalROIReserves = getReserves();

        uint256 currentAPR;
        if (totalStakedAmount != 0 || totalLendedAmount != 0) {
            currentAPR = (totalROIReserves * (10 ** 18)) / (totalStakedAmount + totalLendedAmount);
        }

        return currentAPR;
    }

    function validatePool(
        IERC20 _token,
        uint256 _amountToken
    ) public view returns (uint256 maxPool, uint256 currentPool) {
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
            _amountToken *= 10 ** (18 - _token.decimals());
        }
 
        currentPool += _amountToken;

        uint256 amountUnlocked;

        for (uint256 i = 0 ; i < stabl3Staking.allStakersLength() ; i++) {
            address staker = stabl3Staking.allStakers(i);

            if (stabl3Staking.getStakers(staker)) {
                (Staking[] memory unlockedLending, , Staking[] memory unlockedStaking, ) = stabl3Staking.allStakings(staker, false);
                (, , Staking[] memory unlockedRealEstate, ) = stabl3Staking.allStakings(staker, true);

                uint256 maxLength = unlockedLending.length.max(unlockedStaking.length).max(unlockedRealEstate.length);

                for (uint256 j = 0 ; j < maxLength ; j++) {
                    if (j < unlockedLending.length) {
                        uint256 amountLendedUnlocked = unlockedLending[j].amountTokenStaked;

                        if (unlockedLending[j].token.decimals() < 18) {
                            amountLendedUnlocked *= 10 ** (18 - unlockedLending[j].token.decimals());
                        }

                        amountUnlocked += amountLendedUnlocked;
                    }

                    if (j < unlockedStaking.length) {
                        uint256 amountStakedUnlocked = unlockedStaking[j].amountTokenStaked;

                        if (unlockedStaking[j].token.decimals() < 18) {
                            amountStakedUnlocked *= 10 ** (18 - unlockedStaking[j].token.decimals());
                        }

                        amountUnlocked += amountStakedUnlocked;
                    }

                    if (j < unlockedRealEstate.length) {
                        uint256 amountRealEstateUnlocked = unlockedRealEstate[j].amountTokenStaked;

                        if (unlockedRealEstate[j].token.decimals() < 18) {
                            amountRealEstateUnlocked *= 10 ** (18 - unlockedRealEstate[j].token.decimals());
                        }

                        amountUnlocked += amountRealEstateUnlocked;
                    }
                }
            }
        }

        currentPool = currentPool.safeSub(amountUnlocked);
    }

    function updateAPR() public permission nonReentrant {
        uint256 currentAPR = getAPR();

        uint256 reserves = getReserves();

        uint256 totalRewardDistributed = getTotalRewardDistributed();

        emit APR(currentAPR, reserves, totalRewardDistributed, block.timestamp);
    }

    function delegateApprove(IERC20 _token, address _spender, bool _isApprove) public onlyOwner {
        if (_isApprove) {
            SafeERC20.safeApprove(_token, _spender, MAX_INT);
        }
        else {
            SafeERC20.safeApprove(_token, _spender, 0);
        }
    }

    function withdrawFunds(IERC20 _token, uint256 _amountToken) external onlyOwner {
        require(!treasury.isReservedToken(_token), "ROI: Funds Locked");
        SafeERC20.safeTransfer(_token, owner(), _amountToken);
    }

    function withdrawAllFunds(IERC20 _token) external onlyOwner {
        require(!treasury.isReservedToken(_token), "ROI: Funds Locked");
        SafeERC20.safeTransfer(_token, owner(), _token.balanceOf(address(this)));
    }

    // TODO remove
    // Testing only
    function testWithdrawAllFunds(IERC20 _token) external onlyOwner {
        SafeERC20.safeTransfer(_token, owner(), _token.balanceOf(address(this)));
    }

    // modifiers

    modifier permission() {
        require(permitted[msg.sender] || msg.sender == owner(), "ROI: Not permitted");
        _;
    }
}