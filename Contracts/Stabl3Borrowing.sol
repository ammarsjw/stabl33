// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";

import "./ITreasury.sol";
import "./IROI.sol";
import "./IUCD.sol";

contract Stabl3Borrowing is Ownable, ReentrancyGuard {
    using SafeMathUpgradeable for uint256;

    uint8 private constant UCD_BORROW_POOL = 8;
    uint8 private constant UCD_PAYBACK_POOL = 9;
    uint8 private constant UCD_TO_TOKEN_EXCHANGE_POOL = 10;
    uint8 private constant STABL3_COLLATERAL_POOL = 11;

    ITreasury public treasury;
    IROI public ROI;
    address public HQ;

    IERC20 public immutable stabl3;

    IUCD public ucd;

    uint256 public exchangeFee;

    bool public borrowState;

    // structs

    struct Borrowing {
        uint256 amountStabl3;
        uint256 amountUCD;
    }

    // mappings

    mapping (address => Borrowing) public getBorrowings;

    // events

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedHQ(address newHQ, address oldHQ);

    event UpdatedExchangeFee(uint256 newExchangeFee, uint256 oldExchangeFee);

    event Borrow(
        address indexed user,
        uint256 amountStabl3,
        uint256 amountUCD,
        uint256 timestamp
    );

    event Payback(
        address indexed user,
        uint256 amountUCD,
        uint256 amountStabl3,
        uint256 timestamp
    );

    event Exchange(
        address indexed user,
        IERC20 token,
        uint256 amountToken,
        uint256 fee,
        uint256 timestamp
    );

    // constructor

    constructor(address _treasury, address _ROI) {
        treasury = ITreasury(_treasury);
        ROI = IROI(_ROI);
        // TODO change
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        // TODO change
        stabl3 = IERC20(0x59f78fB97FB36adbaDCbB43Fa9031797faAad54A);
        ucd = IUCD(0x01fa8dEEdDEA8E4e465f158d93e162438d61c9eB);

        exchangeFee = 3;
    }

    function updateTreasury(address _treasury) external onlyOwner {
        require(address(treasury) != _treasury, "Stabl3Borrowing: Treasury is already this address");
        emit UpdatedTreasury(_treasury, address(treasury));
        treasury = ITreasury(_treasury);
    }

    function updateROI(address _ROI) external onlyOwner {
        require(address(ROI) != _ROI, "Stabl3Borrowing: ROI is already this address");
        emit UpdatedROI(_ROI, address(ROI));
        ROI = IROI(_ROI);
    }

    function updateHQ(address _HQ) external onlyOwner {
        require(HQ != _HQ, "Stabl3Borrowing: HQ is already this address");
        emit UpdatedHQ(_HQ, HQ);
        HQ = _HQ;
    }

    function updateUCD(address _ucd) external onlyOwner {
        require(address(ucd) != _ucd, "Stabl3Borrowing: UCD is already this address");
        ucd = IUCD(_ucd);
    }

    function updateExchangeFee(uint256 _exchangeFee) external onlyOwner {
        require(exchangeFee != _exchangeFee, "Stabl3Borrowing: Exchange Fee is already this value");
        emit UpdatedExchangeFee(_exchangeFee, exchangeFee);
        exchangeFee = _exchangeFee;
    }

    function updateBorrowState(bool _state) external onlyOwner {
        require(borrowState != _state, "Stabl3Borrowing: Borrow State is already of the value 'state'");
        borrowState = _state;
    }

    function getEquivalenceToken() public view returns (IERC20) {
        IERC20 equivalenceToken;

        for (uint256 i = 0 ; i < treasury.allReservedTokensLength() ; i++) {
            IERC20 reservedToken = treasury.allReservedTokens(i);

            if (treasury.isReservedToken(reservedToken)) {
                if (ucd.decimals() == reservedToken.decimals()) {
                    equivalenceToken = reservedToken;
                    break;
                }
            }
        }

        return equivalenceToken;
    }

    /**
     * @dev This function allows users to deposit stabl3 and to receive UCD at current protocol rates
     */
    function borrow(uint256 _amountStabl3) external borrowActive {
        require(_amountStabl3 > 0, "Stabl3Borrowing: Insufficient amount");

        IERC20 equivalenceToken = getEquivalenceToken();
        require(address(equivalenceToken) != address(0), "Stabl3Borrowing: No Equivalent Token");

        uint256 amountUCD = treasury.getAmountIn(_amountStabl3, equivalenceToken);

        Borrowing storage borrowing = getBorrowings[msg.sender];

        borrowing.amountUCD += amountUCD;
        borrowing.amountStabl3 += _amountStabl3;

        stabl3.transferFrom(msg.sender, address(treasury), _amountStabl3);

        ucd.mintWithPermit(msg.sender, amountUCD);

        treasury.updatePool(UCD_BORROW_POOL, ucd, amountUCD, 0, 0, true);
        treasury.updatePool(STABL3_COLLATERAL_POOL, stabl3, _amountStabl3, 0, 0, true);

        treasury.updateStabl3CirculatingSupply(_amountStabl3, false);

        emit Borrow(msg.sender, _amountStabl3, amountUCD, block.timestamp);
    }

    // add ROI.returnFunds here
    function exchange(IERC20 _token, uint256 _amountUCD) external borrowActive {
        require(_amountUCD > 0, "Stabl3Borrowing: Insufficient amount");

        // handleLimit?

        uint256 amountTokenWithFee = _amountUCD.mul(exchangeFee).div(1000);

        SafeERC20.safeTransferFrom(_token, address(treasury), msg.sender, amountTokenWithFee);
    }

    // flashloan protection?
    // any security features?
    // when a user has fully returned his UCD do we uncollateralize the rest of his collateralized Stabl3?
    // consider current price when borrowing/paying back
    /**
     * @dev This function allows users to repay their borrowed UCD in return for Stabl3 Token at current protocol rates
     */
    function payback(uint256 _amountUCD) external borrowActive {
        require(_amountUCD > 0, "Stabl3Borrowing: Insufficient amount");

        Borrowing storage borrowing = getBorrowings[msg.sender];

        require(borrowing.amountUCD > 0, "Stabl3Borrowing: No UCD to payback");

        IERC20 equivalenceToken = getEquivalenceToken();
        require(address(equivalenceToken) != address(0), "Stabl3Borrowing: No Equivalent Token");

        uint256 amountStabl3 = treasury.getAmountOut(equivalenceToken, _amountUCD);

        borrowing.amountUCD -= _amountUCD;
        borrowing.amountStabl3 -= amountStabl3;

        ucd.burnWithPermit(msg.sender, _amountUCD);

        stabl3.transferFrom(address(treasury), msg.sender, amountStabl3);

        treasury.updatePool(UCD_PAYBACK_POOL, ucd, _amountUCD, 0, 0, true);
        treasury.updatePool(STABL3_COLLATERAL_POOL, stabl3, amountStabl3, 0, 0, false);
        if (borrowing.amountUCD == 0) {
            treasury.updatePool(STABL3_COLLATERAL_POOL, stabl3, borrowing.amountStabl3, 0, 0, false);
        }

        treasury.updateStabl3CirculatingSupply(amountStabl3, true);

        emit Payback(msg.sender, amountStabl3, _amountUCD, block.timestamp);
    }

    // modifiers

    modifier borrowActive() {
        require(borrowState, "Stabl3Borrowing: Borrow not yet started");
        _;
    }

    modifier reserved(IERC20 _token) {
        require(treasury.isReservedToken(_token), "Stabl3Borrowing: Not a reserved token");
        _;
    }
}