// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "../../Contracts/Ownable.sol";
import "../../Contracts/SafeMathUpgradeable.sol";
import "../../Contracts/SafeERC20.sol";

import "../../Contracts/ITreasury.sol";
import "../../Contracts/IStabl3Staking.sol";

contract ROI is Ownable, IStabl3StakingStruct {
    using SafeMathUpgradeable for uint256;

    uint256 private constant MAX_INT = 2 ** 256 - 1;

    uint8 private constant BUY_POOL = 0;

    uint8 private constant BOND_POOL = 1;

    uint8 private constant STAKE_POOL = 2;
    uint8 private constant STAKE_REWARD_POOL = 3;
    uint8 private constant LEND_POOL = 5;
    uint8 private constant LEND_REWARD_POOL = 6;

    ITreasury public treasury;

    IERC20 public immutable stabl3;

    IERC20 public ucd;

    IStabl3Staking public stabl3Staking;
    uint256 public maxPoolPercentage;
    uint256 public stakingTypePercentage;

    // mappings

    // contracts with permission to access ROI pool funds
    mapping (address => bool) public permitted;

    // events

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedPermission(address contractAddress, bool state);

    event APR(
        uint256 APR,
        uint256 reserves,
        uint256 totalRewardDistributed,
        uint256 timestamp
    );

    // constructor

    constructor(ITreasury _treasury) {
        treasury = _treasury;

        // TODO change
        stabl3 = IERC20(0xDf9c4990a8973b6cC069738592F27Ea54b27D569);
        ucd = IERC20(0x01fa8dEEdDEA8E4e465f158d93e162438d61c9eB);

        maxPoolPercentage = 700;
        stakingTypePercentage = 250;

        updatePermission(address(_treasury), true);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        require(address(treasury) != _treasury, "ROI: Treasury is already this address");
        if (address(treasury) != address(0)) updatePermission(address(treasury), false);
        updatePermission(_treasury, true);
        emit UpdatedTreasury(_treasury, address(treasury));
        treasury = ITreasury(_treasury);
    }

    function updateUCD(address _ucd) external onlyOwner {
        require(address(ucd) != _ucd, "ROI: UCD is already this address");
        ucd = IERC20(_ucd);
    }

    function updateStabl3Staking(address _stabl3Staking) external onlyOwner {
        require(address(stabl3Staking) != _stabl3Staking, "ROI: Stabl3 Staking is already this address");
        if (address(stabl3Staking) != address(0)) updatePermission(address(stabl3Staking), false);
        updatePermission(_stabl3Staking, true);
        stabl3Staking = IStabl3Staking(_stabl3Staking);
    }

    function updateMaxPoolPercentage(uint256 _maxPoolPercentage) external onlyOwner {
        require(maxPoolPercentage != _maxPoolPercentage, "Stabl3Staking: Max Pool Percentage is already this value");
        maxPoolPercentage = _maxPoolPercentage;
    }

    function updatePermission(address _contractAddress, bool _state) public onlyOwner {
        require(permitted[_contractAddress] != _state, "ROI: Contract Address is already of the value 'state'");

        permitted[_contractAddress] = _state;

        if (_state) {
            delegateApprove(stabl3, _contractAddress, true);

            delegateApprove(ucd, _contractAddress, true);

            for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
                delegateApprove(treasury.allReservedTokens(i), _contractAddress, true);
            }
        }
        else {
            delegateApprove(stabl3, _contractAddress, false);

            delegateApprove(ucd, _contractAddress, false);

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

                totalRewardDistributed +=
                    decimals < 18 ?
                    (stakeRewardAmount * 10 ** (18 - decimals)) + (lendRewardAmount * 10 ** (18 - decimals)) :
                    stakeRewardAmount + lendRewardAmount;
            }
        }

        return totalRewardDistributed;
    }

    function getReserves() public view returns (uint256) {
        uint256 totalReserves;

        for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
            IERC20 reservedToken = treasury.allReservedTokens(i);

            if (treasury.isReservedToken(reservedToken)) {
                uint256 amountToken = reservedToken.balanceOf(address(this));

                uint256 decimals = reservedToken.decimals();

                totalReserves += decimals < 18 ? amountToken * 10 ** (18 - decimals) : amountToken;
            }
        }

        return totalReserves;
    }

    // APR is in 18 decimals
    function getAPR() public view returns (uint256) {
        uint256 totalStakedAndLendedAmount;

        for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
            IERC20 reservedToken = treasury.allReservedTokens(i);

            if (treasury.isReservedToken(reservedToken)) {
                // HQ Pool is included in the Treasury Pool since it earns APR, hence no need to it to either staked or lended amounts
                uint256 stakedAmount = treasury.getTreasuryPool(STAKE_POOL, reservedToken);
                stakedAmount += treasury.getROIPool(STAKE_POOL, reservedToken);                 // ROI Pool for staking is 0 by default
                uint256 lendedAmount = treasury.getTreasuryPool(LEND_POOL, reservedToken);
                lendedAmount += treasury.getROIPool(LEND_POOL, reservedToken);                  // ROI Pool for lending is 0 by default

                uint256 decimals = reservedToken.decimals();

                totalStakedAndLendedAmount +=
                    decimals < 18 ?
                    (stakedAmount * 10 ** (18 - decimals)) + (lendedAmount * 10 ** (18 - decimals)) :
                    stakedAmount + lendedAmount;
            }
        }

        uint256 totalROIReserves = getReserves();

        uint256 currentAPR = totalStakedAndLendedAmount != 0 ? (totalROIReserves * (10 ** 18)) / (totalStakedAndLendedAmount) : 0;

        return currentAPR;
    }

    function validatePool(
        IERC20 _token,
        uint256 _amountToken,
        uint8 _stakingType,
        bool _isLending
    ) public view returns (uint256 maxPool, uint256 currentPool) {
        for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
            IERC20 reservedToken = treasury.allReservedTokens(i);

            if (treasury.isReservedToken(reservedToken)) {
                uint256 boughtAmount = treasury.getTreasuryPool(BUY_POOL, reservedToken);
                uint256 bondedAmount = treasury.getTreasuryPool(BOND_POOL, reservedToken);

                uint256 decimals = reservedToken.decimals();

                maxPool +=
                    decimals < 18 ?
                    (boughtAmount * 10 ** (18 - decimals)) + (bondedAmount * 10 ** (18 - decimals)) :
                    boughtAmount + bondedAmount;
            }
        }

        maxPool = maxPool.mul(maxPoolPercentage).div(1000);
        maxPool = maxPool.mul(stakingTypePercentage).div(1000);

        currentPool = stabl3Staking.getAmountStakedPerStakingType(_stakingType);

        if (_isLending) {
            _amountToken = _amountToken.mul(1000 - stabl3Staking.lendingStabl3Percentage()).div(1000);
        }

        currentPool += _token.decimals() < 18 ? _amountToken * 10 ** (18 - _token.decimals()) : _amountToken;

        /* ========== excluding stakes, that are currently unlocked, from the current pool in the given staking type ========== */

        uint256 amountUnlocked;

        for (uint256 i = 0 ; i < stabl3Staking.allStakersLength() ; i++) {
            address staker = stabl3Staking.allStakers(i);

            if (stabl3Staking.getStakers(staker)) {
                (Staking[] memory unlockedLending, , Staking[] memory unlockedStaking, ) = stabl3Staking.allStakings(staker, false);
                // (, , Staking[] memory unlockedRealEstate, ) = stabl3Staking.allStakings(staker, true);

                // uint256 maxLength = unlockedLending.length.max(unlockedStaking.length).max(unlockedRealEstate.length);
                uint256 maxLength = unlockedLending.length.max(unlockedStaking.length);

                for (uint256 j = 0 ; j < maxLength ; j++) {
                    if (j < unlockedLending.length && unlockedLending[j].stakingType == _stakingType) {
                        uint256 amountToken = unlockedLending[j].amountTokenStaked;

                        amountUnlocked +=
                            unlockedLending[j].token.decimals() < 18 ?
                            amountToken * 10 ** (18 - unlockedLending[j].token.decimals()) :
                            amountToken;
                    }

                    if (j < unlockedStaking.length && unlockedStaking[j].stakingType == _stakingType) {
                        uint256 amountToken = unlockedStaking[j].amountTokenStaked;

                        amountUnlocked +=
                            unlockedStaking[j].token.decimals() < 18 ?
                            amountToken * 10 ** (18 - unlockedStaking[j].token.decimals()) :
                            amountToken;
                    }

                    // if (j < unlockedRealEstate.length && unlockedRealEstate[j].stakingType == _stakingType) {
                    //     uint256 amountToken = unlockedRealEstate[j].amountTokenStaked;

                    //     amountUnlocked +=
                    //         unlockedRealEstate[j].token.decimals() < 18 ?
                    //         amountToken * 10 ** (18 - unlockedRealEstate[j].token.decimals()) :
                    //         amountToken;
                    // }
                }
            }
        }

        currentPool = currentPool.safeSub(amountUnlocked);

        /* ========== ---------------------------------------------------------------------------------------------- ========== */
    }

    function updateAPR() public permission {
        uint256 currentAPR = getAPR();

        uint256 reserves = getReserves();

        uint256 totalRewardDistributed = getTotalRewardDistributed();

        emit APR(currentAPR, reserves, totalRewardDistributed, block.timestamp);
    }

    /**
     * @notice This functions transfers ROI funds to the Treasury
     * @dev Updates values of both treasury and ROI pools
     */
    function returnFunds(IERC20 _token, uint256 _amountToken, uint8[] memory _pools) external permission {
        uint256 amountToUpdate = _amountToken;

        for (uint8 i = 0 ; i <= _pools.length ; i++) {
            uint256 amountPool = treasury.getROIPool(_pools[i], _token);

            if (amountPool != 0) {
                if (amountPool < amountToUpdate) {
                    treasury.updatePool(_pools[i], _token, 0, amountPool, 0, false);
                    treasury.updatePool(_pools[i], _token, amountPool, 0, 0, true);

                    amountToUpdate -= amountPool;
                }
                else {
                    treasury.updatePool(_pools[i], _token, 0, amountToUpdate, 0, false);
                    treasury.updatePool(_pools[i], _token, amountToUpdate, 0, 0, true);

                    amountToUpdate = 0;
                    break;
                }
            }
        }

        require(amountToUpdate == 0, "ROI: Not enough funds in the specified pools");

        SafeERC20.safeTransfer(_token, address(treasury), _amountToken);
    }

    function delegateApprove(IERC20 _token, address _spender, bool _isApprove) public onlyOwner {
        if (_isApprove) {
            SafeERC20.safeApprove(_token, _spender, MAX_INT);
        }
        else {
            SafeERC20.safeApprove(_token, _spender, 0);
        }
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