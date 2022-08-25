// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.16;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";
import "./ABDKMath64x64.sol";

import "./ITreasury.sol";

contract Extra is Ownable {
    using SafeMathUpgradeable for uint256;

    uint256 private immutable MAX_INT = 2 ** 256 - 1;

    uint8 private constant BUY_POOL = 0;
    uint8 private constant BOND_POOL = 1;
    uint8 private constant STAKE_POOL = 2;
    uint8 private constant LEND_POOL = 3;
    uint8 private constant BORROW_POOL = 4;
    uint8 private constant EXCHANGE_POOL = 5;

    ITreasury public treasury;

    // events

    event UpdatedTreasury();

    // constructor

    constructor(ITreasury _treasury) {
        treasury = _treasury;
    }

    function getRewardAPY() external view returns (uint256) {
        uint256 totalROIReserves; // numerator for totalAPY
        uint256 totalStakeAndLendAmountTreasury; // denominator for totalAPY

        uint256 totalBuyAndBondAmountTreasury; // numerator for collateralAPY
        uint256 totalExchangeAmountTreasury; // denominator for collateralAPY

        uint256 decimals;

        uint256 ROIReserves;
        uint256 stakeAndLendAmountTreasury;

        uint256 buyAndBondAmountTreasury;
        uint256 exchangeAmountTreasury;

        IERC20 reservedToken;
        for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
            reservedToken = treasury.allReservedTokens(i);
            if (treasury.isReservedToken(reservedToken)) {
                ROIReserves = reservedToken.balanceOf(address(this));
                stakeAndLendAmountTreasury = treasury.getTreasuryPool(STAKE_POOL, reservedToken);
                stakeAndLendAmountTreasury += treasury.getTreasuryPool(LEND_POOL, reservedToken);

                buyAndBondAmountTreasury = treasury.getTreasuryPool(BUY_POOL, reservedToken);
                buyAndBondAmountTreasury += treasury.getTreasuryPool(BOND_POOL, reservedToken);
                exchangeAmountTreasury = treasury.getTreasuryPool(EXCHANGE_POOL, reservedToken);

                decimals = reservedToken.decimals();

                if (decimals < 18) {
                    ROIReserves = ROIReserves * (10 ** (18 - decimals));
                    stakeAndLendAmountTreasury = stakeAndLendAmountTreasury * (10 ** (18 - decimals));

                    buyAndBondAmountTreasury = buyAndBondAmountTreasury * (10 ** (18 - decimals));
                    exchangeAmountTreasury = exchangeAmountTreasury * (10 ** (18 - decimals));
                }

                totalROIReserves += ROIReserves;
                totalStakeAndLendAmountTreasury += stakeAndLendAmountTreasury;

                totalBuyAndBondAmountTreasury += buyAndBondAmountTreasury;
                totalExchangeAmountTreasury += exchangeAmountTreasury;
            }
        }

        uint256 totalAPY = (totalROIReserves * (10 ** 18)) / totalStakeAndLendAmountTreasury;

        uint256 collateralAPY;
        uint256 currentAPY;
        if (totalExchangeAmountTreasury > totalBuyAndBondAmountTreasury) {
            uint256 collateralAmount = totalExchangeAmountTreasury - totalBuyAndBondAmountTreasury;

            collateralAPY = (collateralAmount * (10 ** 18)) / totalStakeAndLendAmountTreasury;

            currentAPY = totalAPY - collateralAPY;
        }
        else {
            uint256 collateralAmount = totalBuyAndBondAmountTreasury - totalExchangeAmountTreasury;

            collateralAPY = (collateralAmount * (10 ** 18)) / totalStakeAndLendAmountTreasury;

            currentAPY = totalAPY + collateralAPY;
        }

        return currentAPY;
    }

    function approveTreasury(IERC20 _token, address _spender, bool _isApprove) public onlyOwner {
        if (_isApprove) {
            SafeERC20.safeApprove(_token, _spender, MAX_INT);
        }
        else {
            SafeERC20.safeApprove(_token, _spender, 0);
        }
    }

    function withdrawFunds(IERC20 _token, uint256 _amountToken) external onlyOwner {
        SafeERC20.safeTransfer(_token, owner(), _amountToken);
    }

    function withdrawAllFunds(IERC20 _token) external onlyOwner {
        SafeERC20.safeTransfer(_token, owner(), _token.balanceOf(address(this)));
    }

    function _compound(uint256 _principal, uint256 _ratio, uint256 _exponent) internal pure returns (uint256) {
        if (_exponent == 0) {
            return 0;
        }

        uint256 accruedReward = ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);

        return accruedReward.sub(_principal);
    }
}

// TODO
    // function createBond(IERC20 _token, uint256 _amountToken) external {
    //     require(saleState, "Stabl3PublicSale: Sale not yet started");
    //     require(treasury.isReservedToken(_token), "Stabl3PublicSale: Token not reserved");
    //     require(_amountToken > 0, "Stabl3PublicSale: Insufficient amount");

    //     uint256 amountStabl3 = treasury.getAmountOut(_token, _amountToken);

    //     amountStabl3 += (amountStabl3 * discount) / 1000;

    //     Bond memory bond = Bond(getBonds[msg.sender].length, msg.sender, true, amountStabl3, _token, _amountToken, block.timestamp);
    //     getBonds[msg.sender].push(bond);

    //     _distributeFunds(_token, _amountToken, 1);

    //     emit CreatedBond(bond.recipient, bond.index, bond.amountStabl3, bond.token, bond.amountToken);
    //     treasury.update();
    // }

    // function claimBond(uint256 index) external {
    //     require(saleState, "Stabl3PublicSale: Sale not yet started");
    //     Bond storage bond = getBonds[msg.sender][index];

    //     require(bond.status, "Stabl3PublicSale: Bond already claimed");
    //     require(block.timestamp > bond.startTime + bondTime, "Stabl3PublicSale: Bond time not finished");

    //     stabl3.transferFrom(address(treasury), msg.sender, bond.amountStabl3);

    //     bond.status = false;

    //     emit ClaimedBond(bond.recipient, bond.index, bond.amountStabl3, bond.token, bond.amountToken);
    //     treasury.update();
    // }