// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.16;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";

import "./ITreasury.sol";

contract ROI is Ownable {
    using SafeMathUpgradeable for uint256;

    uint256 public magnitude = 10 ** 3;

    uint8 constant INITIAL_POOL = 0;
    uint8 constant BUY_POOL = 1;
    uint8 constant BOND_POOL = 2;
    uint8 constant STAKE_POOL = 3;
    uint8 constant LEND_POOL = 4;
    uint8 constant BORROW_POOL = 5;

    ITreasury public treasury;

    constructor(ITreasury _treasury) {
        treasury = _treasury;
    }

    function getRewardAPY(IERC20 _token) external view returns (uint256) {
        // (uint256 buyAmountTreasury, uint256 buyAmountROI, uint256 buyAmountHQ) = treasury.getPools(BUY_POOL, _token);
        // uint256 buyAmountTotal = buyAmountTreasury + buyAmountROI + buyAmountHQ;

        // (uint256 bondAmountTreasury, uint256 bondAmountROI, uint256 bondAmountHQ) = treasury.getPools(BOND_POOL, _token);
        // uint256 bondAmountTotal = bondAmountTreasury + bondAmountROI + bondAmountHQ;

        // uint256 buyAndBondAmountTotal = buyAmountTotal + bondAmountTotal;
        // buyAndBondAmountTotal = (buyAndBondAmountTotal * 950) / magnitude;

        // (uint256 borrowAmountTreasury, uint256 borrowAmountROI, uint256 borrowAmountHQ) = treasury.getPools(BORROW_POOL, _token);
        // uint256 borrowAmountTotal = borrowAmountTreasury + borrowAmountROI + borrowAmountHQ;

        // borrowAmountTotal = (borrowAmountTotal * 975) / magnitude;

        (uint256 buyAmountTreasury, , ) = treasury.getPools(BUY_POOL, _token);
        (uint256 bondAmountTreasury, , ) = treasury.getPools(BOND_POOL, _token);

        uint256 buyAndBondAmountTreasuryTotal = buyAmountTreasury + bondAmountTreasury;
    }
}

// account for division between staking and lending
// account for max pool possible of staking compared to lending
// let the reward apy stay constant
// compound over 1 month