// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "./Ownable.sol";

import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";

import "./IERC721.sol";
import "./ITreasury.sol";
import "./IROI.sol";
import "./IUCD.sol";

contract Stabl3Borrowing is Ownable {
    using SafeMathUpgradeable for uint256;

    uint8 private constant UCD_BORROW_POOL = 8;
    uint8 private constant UCD_PAYBACK_POOL = 9;
    uint8 private constant UCD_TO_TOKEN_EXCHANGE_POOL = 10;
    uint8 private constant STABL3_COLLATERAL_POOL = 11;

    address public donationWallet;

    ITreasury public TREASURY;
    IROI public ROI;

    IERC20 public immutable STABL3;

    IUCD public UCD;

    IERC721 public INVESTORS;

    // uint256 public buybackPercentage;
    // uint256 public donationPercentage;

    uint256 public borrowFee;
    uint256 public exchangeFeeUCD;

    uint8[] public returnBorrowingPools;

    uint256 private burnedUCD;

    bool public borrowState;

    // structs

    struct Borrowing {
        uint256 amountStabl3;
        uint256 amountUCD;
    }

    // storage

    mapping (address => Borrowing) public getBorrowings;

    // events

    event UpdatedDonationWallet(address newDonationWallet, address oldDonationWallet);

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedBorrowFee(uint256 newBorrowFee, uint256 oldBorrowFee);

    event UpdatedExchangeFeeUCD(uint256 newExchangeFeeUCD, uint256 oldExchangeFeeUCD);

    event Borrow(
        address indexed user,
        uint256 amountUCD,
        uint256 amountStabl3,
        uint256 rate,
        uint256 timestamp
    );

    event Payback(
        address indexed user,
        uint256 amountUCD,
        uint256 amountStabl3,
        uint256 rate,
        uint256 timestamp
    );

    event ExchangeUCD(
        address indexed user,
        IERC20 exchangingToken,
        uint256 amountExchangingToken,
        uint256 amountUCD,
        uint256 fee,
        uint256 timestamp
    );

    // constructor

    constructor(address _TREASURY, address _ROI) {
        // TODO change
        donationWallet = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;

        TREASURY = ITreasury(_TREASURY);
        ROI = IROI(_ROI);

        // TODO change
        STABL3 = IERC20(0xDf9c4990a8973b6cC069738592F27Ea54b27D569);

        // TODO change
        UCD = IUCD(0x01fa8dEEdDEA8E4e465f158d93e162438d61c9eB);

        // TODO change
        INVESTORS = IERC721(0x1334E7c1B5CB9Fe515069E313517FC6c31150C91);

        // buybackPercentage = 500;
        // donationPercentage = 500;

        borrowFee = 50;
        exchangeFeeUCD = 25;

        returnBorrowingPools = [0, 1, 2, 5];
    }

    function updateDonationWallet(address _donationWallet) external onlyOwner {
        require(donationWallet != _donationWallet, "Stabl3Borrowing: Donation Wallet is already this address");
        emit UpdatedDonationWallet(_donationWallet, donationWallet);
        donationWallet = _donationWallet;
    }

    function updateTreasury(address _TREASURY) external onlyOwner {
        require(address(TREASURY) != _TREASURY, "Stabl3Borrowing: Treasury is already this address");
        emit UpdatedTreasury(_TREASURY, address(TREASURY));
        TREASURY = ITreasury(_TREASURY);
    }

    function updateROI(address _ROI) external onlyOwner {
        require(address(ROI) != _ROI, "Stabl3Borrowing: ROI is already this address");
        emit UpdatedROI(_ROI, address(ROI));
        ROI = IROI(_ROI);
    }

    function updateUCD(address _ucd) external onlyOwner {
        require(address(UCD) != _ucd, "Stabl3Borrowing: UCD is already this address");
        UCD = IUCD(_ucd);
    }

    // function updateDistributionPercentages(
    //     uint256 _buybackPercentage,
    //     uint256 _donationPercentage
    // ) external onlyOwner {
    //     require(_buybackPercentage + _donationPercentage == 1000,
    //         "Stabl3PublicSale: Sum of magnified percentages should equal 1000");

    //     buybackPercentage = _buybackPercentage;
    //     donationPercentage = _donationPercentage;
    // }

    function updateBorrowFee(uint256 _borrowFee) external onlyOwner {
        require(borrowFee != _borrowFee, "Stabl3Borrowing: Borrow Fee is already this value");
        emit UpdatedBorrowFee(_borrowFee, borrowFee);
        borrowFee = _borrowFee;
    }

    function updateExchangeFeeUCD(uint256 _exchangeFeeUCD) external onlyOwner {
        require(exchangeFeeUCD != _exchangeFeeUCD, "Stabl3Borrowing: Exchange Fee for UCD is already this value");
        emit UpdatedExchangeFeeUCD(_exchangeFeeUCD, exchangeFeeUCD);
        exchangeFeeUCD = _exchangeFeeUCD;
    }

    function updateReturnBorrowingPools(uint8[] memory _returnBorrowingPools) external onlyOwner {
        returnBorrowingPools = _returnBorrowingPools;
    }

    function updateState(bool _state) external onlyOwner {
        require(borrowState != _state, "Stabl3Borrowing: Borrow State is already this state");
        borrowState = _state;
    }

    function getReservesUCD() public view returns (uint256 availableUCD, uint256 borrowedUCD, uint256 returnedUCD) {
        // (, uint256 marketCap, ) = TREASURY.rateInfo();

        // uint256 marketCapToConsider = marketCap / (10 ** (18 - UCD.decimals()));
        uint256 availableReserves = (TREASURY.getReserves() + ROI.getReserves()) / (10 ** (18 - UCD.decimals()));

        return (
            availableReserves.safeSub(UCD.totalSupply()),
            UCD.totalSupply(),
            burnedUCD
        );
    }

    /**
     * @dev This function allows users to deposit STABL3 and to receive UCD at current protocol rates
     * @dev Fees are cut in the form of stablecoins by reducing amount of UCD
     */
    function borrow(uint256 _amountStabl3) external borrowActive {
        require(_amountStabl3 > 0, "Stabl3Borrowing: Insufficient amount");

        uint256 amountUCD = TREASURY.getAmountIn(_amountStabl3, UCD);

        uint256 fee;
        if (INVESTORS.balanceOf(msg.sender) == 0) {
            fee = amountUCD.mul(borrowFee).div(1000);
        }
        uint256 amountUCDWithFee = amountUCD - fee;

        (uint256 availableUCD, , ) = getReservesUCD();
        require(amountUCDWithFee <= availableUCD, "Stabl3Borrowing: Insufficient available UCD");

        Borrowing storage borrowing = getBorrowings[msg.sender];

        borrowing.amountUCD += amountUCDWithFee;
        borrowing.amountStabl3 += _amountStabl3;

        IERC20 reservedToken = TREASURY.reservedTokenSelector();

        uint256 decimalsReservedToken = reservedToken.decimals();
        uint256 decimalsUCD = UCD.decimals();

        if (decimalsReservedToken > decimalsUCD) {
            fee *= 10 ** (decimalsReservedToken - decimalsUCD);
        }
        else if (decimalsReservedToken < decimalsUCD) {
            fee /= 10 ** (decimalsUCD - decimalsReservedToken);
        }

        _returnBorrowingFunds(reservedToken, fee);

        SafeERC20.safeTransferFrom(reservedToken, address(TREASURY), address(ROI), fee);

        STABL3.transferFrom(msg.sender, address(TREASURY), _amountStabl3);

        UCD.mintWithPermit(msg.sender, amountUCDWithFee);

        TREASURY.updatePool(UCD_BORROW_POOL, UCD, amountUCDWithFee, 0, 0, true);
        TREASURY.updatePool(STABL3_COLLATERAL_POOL, STABL3, _amountStabl3, 0, 0, true);

        TREASURY.updateStabl3CirculatingSupply(_amountStabl3, false);

        ROI.updateAPR();

        emit Borrow(msg.sender, amountUCDWithFee, _amountStabl3, TREASURY.getRate(), block.timestamp);
    }

    /**
     * @dev This function allows users to repay their borrowed UCD in return for STABL3 at current protocol rates
     * @dev No fees are cut in this function
     */
    function payback(uint256 _amountUCD) external borrowActive {
        require(_amountUCD > 0, "Stabl3Borrowing: Insufficient amount");

        Borrowing storage borrowing = getBorrowings[msg.sender];

        require(borrowing.amountUCD > 0, "Stabl3Borrowing: No debt to payback");

        uint256 amountStabl3 = TREASURY.getAmountOut(UCD, _amountUCD);
        require(
            STABL3.balanceOf(address(TREASURY)) >= amountStabl3 + TREASURY.getLockedAmount(),
            "Stabl3Borrowing: Insufficient Stabl3 reserves"
        );

        uint256 borrowingUCD = borrowing.amountUCD;
        uint256 borrowingStabl3 = borrowing.amountStabl3;

        borrowing.amountUCD = borrowing.amountUCD.safeSub(_amountUCD);
        borrowing.amountStabl3 = borrowing.amountStabl3.safeSub(amountStabl3);

        UCD.burnWithPermit(msg.sender, _amountUCD);
        burnedUCD += _amountUCD;

        STABL3.transferFrom(address(TREASURY), msg.sender, amountStabl3);

        TREASURY.updatePool(UCD_PAYBACK_POOL, UCD, _amountUCD, 0, 0, true);
        TREASURY.updatePool(STABL3_COLLATERAL_POOL, STABL3, amountStabl3, 0, 0, false);
        // calculating and processing STABL3 amount that is `leftover` after price changes
        _processLeftoverCollateral(borrowingUCD, borrowingStabl3, _amountUCD, amountStabl3);

        TREASURY.updateStabl3CirculatingSupply(amountStabl3, true);

        emit Payback(msg.sender, _amountUCD, amountStabl3, TREASURY.getRate(), block.timestamp);
    }

    /**
     * @dev Fees are cut from amount of exchanging token
     */
    function exchangeUCD(IERC20 _exchangingToken, uint256 _amountUCD) external borrowActive reserved(_exchangingToken) {
        require(_amountUCD > 0, "Stabl3Borrowing: Insufficient amount");

        // payback the user's debt if they owe any
        // if they don't owe any debt, the user is a third-party
        if (getBorrowings[msg.sender].amountUCD > 0) {
            Borrowing storage borrowing = getBorrowings[msg.sender];

            uint256 amountStabl3 = TREASURY.getAmountOut(UCD, _amountUCD);
            require(
                STABL3.balanceOf(address(TREASURY)) >= amountStabl3 + TREASURY.getLockedAmount(),
                "Stabl3Borrowing: Insufficient Stabl3 reserves"
            );

            uint256 borrowingUCD = borrowing.amountUCD;
            uint256 borrowingStabl3 = borrowing.amountStabl3;

            borrowing.amountUCD = borrowing.amountUCD.safeSub(_amountUCD);
            borrowing.amountStabl3 = borrowing.amountStabl3.safeSub(amountStabl3);

            UCD.burnWithPermit(msg.sender, _amountUCD);
            burnedUCD += _amountUCD;

            TREASURY.updatePool(STABL3_COLLATERAL_POOL, STABL3, amountStabl3, 0, 0, false);
            // calculating and processing collateral STABL3 amount that is `leftover` after price changes
            _processLeftoverCollateral(borrowingUCD, borrowingStabl3, _amountUCD, amountStabl3);
        }

        uint256 amountExchangingToken = _amountUCD;

        uint256 decimalsExchangingToken = _exchangingToken.decimals();
        uint256 decimalsUCD = UCD.decimals();

        if (decimalsExchangingToken > decimalsUCD) {
            amountExchangingToken *= 10 ** (decimalsExchangingToken - decimalsUCD);
        }
        else if (decimalsExchangingToken < decimalsUCD) {
            amountExchangingToken /= 10 ** (decimalsUCD - decimalsExchangingToken);
        }

        uint256 fee;
        if (INVESTORS.balanceOf(msg.sender) == 0) {
            fee = amountExchangingToken.mul(exchangeFeeUCD).div(1000);
        }
        uint256 amountExchangingTokenWithFee = amountExchangingToken - fee;

        if (amountExchangingToken > _exchangingToken.balanceOf(address(TREASURY))) {
            ROI.returnFunds(_exchangingToken, amountExchangingToken - _exchangingToken.balanceOf(address(TREASURY)));
        }

        _returnBorrowingFunds(_exchangingToken, amountExchangingToken);

        SafeERC20.safeTransferFrom(_exchangingToken, address(TREASURY), address(ROI), fee);
        SafeERC20.safeTransferFrom(_exchangingToken, address(TREASURY), msg.sender, amountExchangingTokenWithFee);

        TREASURY.updatePool(UCD_TO_TOKEN_EXCHANGE_POOL, _exchangingToken, amountExchangingTokenWithFee, 0, 0, true);
        TREASURY.updatePool(UCD_TO_TOKEN_EXCHANGE_POOL, UCD, _amountUCD, 0, 0, true);

        ROI.updateAPR();

        emit ExchangeUCD(msg.sender, _exchangingToken, amountExchangingTokenWithFee, _amountUCD, fee, block.timestamp);
    }

    /**
     * @dev Handling `leftover` collateral STABL3 amount
     */
    function _processLeftoverCollateral(
        uint256 _borrowingUCD,
        uint256 _borrowingStabl3,
        uint256 _paybackUCD,
        uint256 _paybackStabl3
    ) internal {
        // calculating `leftover` collateral STABL3 amount
        uint256 borrowingRate = _borrowingUCD * (10 ** 18) / _borrowingStabl3;

        uint256 amountStabl3ToConsider = _paybackUCD * (10 ** 18) / borrowingRate;

        uint256 leftoverStabl3 = amountStabl3ToConsider.safeSub(_paybackStabl3);

        // processing `leftover` collateral STABL3 amount
        if (leftoverStabl3 > 0) {
            // donation
            STABL3.transferFrom(address(TREASURY), donationWallet, leftoverStabl3);

            // removing `leftover` collateral STABL3 amount from the STABL3 collateral pool
            TREASURY.updatePool(STABL3_COLLATERAL_POOL, STABL3, leftoverStabl3, 0, 0, false);

            // donation STABL3 amount is not part of the TREASURY and hence is considered into the circulating supply
            TREASURY.updateStabl3CirculatingSupply(leftoverStabl3, true);

            // removing `leftover` collateral STABL3 amount from the user's debt
            getBorrowings[msg.sender].amountStabl3 = getBorrowings[msg.sender].amountStabl3.safeSub(leftoverStabl3);

            // uint256 buybackStabl3 = leftoverStabl3.mul(buybackPercentage).div(1000);
            // uint256 donationStabl3 = leftoverStabl3.mul(donationPercentage).div(1000);

            // uint256 totalAmountStabl3Distributed = buybackStabl3 + donationStabl3;
            // if (leftoverStabl3 > totalAmountStabl3Distributed) {
            //     buybackStabl3 += leftoverStabl3 - totalAmountStabl3Distributed;
            // }

            // // buyback
            // IERC20 reservedToken = TREASURY.reservedTokenSelector();

            // uint256 amountTokenBuyback = TREASURY.getAmountIn(buybackStabl3, reservedToken);

            // SafeERC20.safeTransferFrom(reservedToken, address(TREASURY), address(ROI), amountTokenBuyback);

            // // donation
            // STABL3.transferFrom(address(TREASURY), donationWallet, donationStabl3);

            // // removing `leftover` collateral STABL3 amount from the STABL3 collateral pool
            // TREASURY.updatePool(STABL3_COLLATERAL_POOL, STABL3, buybackStabl3 + donationStabl3, 0, 0, false);

            // // buyback STABL3 amount is part of the TREASURY and hence isn't considered into the circulating supply
            // // donation STABL3 amount is not part of the TREASURY and hence is considered into the circulating supply
            // TREASURY.updateStabl3CirculatingSupply(donationStabl3, true);

            // // updating APR
            // ROI.updateAPR();

            // // removing `leftover` collateral STABL3 amount from the user's debt
            // getBorrowings[msg.sender].amountStabl3 = getBorrowings[msg.sender].amountStabl3.safeSub(buybackStabl3 + donationStabl3);
        }
    }

    /**
     * @dev Calls TREASURY's updatePool to reduce the TREASURY amounts
     */
    function _returnBorrowingFunds(IERC20 _token, uint256 _amountToken) internal {
        uint256 amountToUpdate = _amountToken;

        for (uint8 i = 0 ; i < returnBorrowingPools.length ; i++) {
            uint256 amountPool = TREASURY.getTreasuryPool(returnBorrowingPools[i], _token);

            if (amountPool != 0) {
                if (amountPool < amountToUpdate) {
                    TREASURY.updatePool(returnBorrowingPools[i], _token, amountPool, 0, 0, false);

                    amountToUpdate -= amountPool;
                }
                else {
                    TREASURY.updatePool(returnBorrowingPools[i], _token, amountToUpdate, 0, 0, false);

                    amountToUpdate = 0;
                    break;
                }
            }
        }

        require(amountToUpdate == 0, "Stabl3Borrowing: Not enough funds in the specified pools");
    }

    // modifiers

    modifier borrowActive() {
        require(borrowState, "Stabl3Borrowing: Borrow not yet started");
        _;
    }

    modifier reserved(IERC20 _token) {
        require(TREASURY.isReservedToken(_token), "Stabl3Borrowing: Not a reserved token");
        _;
    }
}