// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";

import "./ITreasury.sol";
import "./IROI.sol";

contract Stabl3Borrowing is Ownable, ReentrancyGuard {
    using SafeMathUpgradeable for uint256;

    uint8 private constant UCD_BORROW_POOL = 8;
    uint8 private constant UCD_EXCHANGE_POOL = 9;
    uint8 private constant UCD_BURN_POOL = 10;
    uint8 private constant UCD_RETURN_POOL = 11;
    uint8 private constant COLLATERAL_STABL3_POOL = 12;

    ITreasury public treasury;
    IROI public ROI;
    address public HQ;

    IERC20 public immutable stabl3;

    IERC20 public immutable ucd;

    bool public borrowState;

    // structs

    // mappings

    // events

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedHQ(address newHQ, address oldHQ);

    // constructor

    constructor(address _treasury, address _ROI) {
        treasury = ITreasury(_treasury);
        ROI = IROI(_ROI);
        // TODO change
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        // TODO change
        stabl3 = IERC20(0xDf9c4990a8973b6cC069738592F27Ea54b27D569);
        ucd = IERC20(0x01fa8dEEdDEA8E4e465f158d93e162438d61c9eB);
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

    function updateBorrowState(bool _state) external onlyOwner {
        require(borrowState != _state, "Stabl3Borrowing: Borrow State is already of the value 'state'");
        borrowState = _state;
    }

    // modifiers

    modifier bondActive() {
        require(borrowState, "Stabl3Borrowing: Borrow not yet started");
        _;
    }

    modifier reserved(IERC20 _token) {
        require(treasury.isReservedToken(_token), "Stabl3Borrowing: Not a reserved token");
        _;
    }
}