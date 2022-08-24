// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.16;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";

import "./ITreasury.sol";

contract Stabl3PublicSale is Ownable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20 for IERC20;

    uint8 constant BUY_POOL = 1;

    ITreasury public treasury;
    address public ROI;
    address public HQ;

    IERC20 public stabl3;

    uint256 public treasuryPercentage;
    uint256 public ROIPercentage;
    uint256 public HQPercentage;

    uint256 public exchangeFee;

    bool public saleState;

    // structs

    struct Bond {
        uint256 index;
        address recipient;
        bool status;
        uint256 amountStabl3;
        IERC20 token;
        uint256 amountToken;
        uint256 startTime;
    }

    // mappings

    // ongoing bonds
    mapping (address => Bond[]) public getBonds;

    // events

    event UpdatedExchangeFee(uint256 newExchangeFee, uint256 oldExchangeFee);

    event UpdatedDiscount(uint256 newDiscount, uint256 oldDiscount);

    event UpdatedBondTime(uint256 newBondTime,uint256 oldBondTime);

    event Buy(address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event Exchanged(address indexed recipient, IERC20 exchangingToken, uint256 amountExchangingToken, uint256 fee, IERC20 token, uint256 amountToken);

    event CreatedBond(address indexed recipient, uint256 index, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event ClaimedBond(address indexed recipient, uint256 index, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    // constructor

    constructor(ITreasury _treasury) {
        treasury = _treasury;
        ROI = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        stabl3 = IERC20(0x20A91B0d2A5545BF05bcA96778e138E2E154e083);

        treasuryPercentage = 800;
        ROIPercentage = 161;
        HQPercentage = 39;

        exchangeFee = 3;
    }

    function updateTreasury(ITreasury _treasury) external onlyOwner {
        treasury = _treasury;
    }

    function updateROI(address _ROI) external onlyOwner {
        require(ROI != _ROI, "Stabl3PublicSale: ROI is already this address");
        ROI = _ROI;
    }

    function updateHQ(address _HQ) external onlyOwner {
        require(HQ != _HQ, "Stabl3PublicSale: HQ is already this address");
        HQ = _HQ;
    }

    function updateDistributionPercentages(
        uint256 _treasuryPercentage,
        uint256 _ROIPercentage,
        uint256 _HQPercentage
    ) external onlyOwner {
        require(_treasuryPercentage + _ROIPercentage + _HQPercentage == 1000,
            "STABL3: Sum of magnified buy percentages should equal 1000");

        treasuryPercentage = _treasuryPercentage;
        ROIPercentage = _ROIPercentage;
        HQPercentage = _HQPercentage;
    }

    function updateExchangeFee(uint256 _exchangeFee) external onlyOwner {
        emit UpdatedExchangeFee(_exchangeFee, exchangeFee);
        exchangeFee = _exchangeFee;
    }

    function updateSaleState(bool state) external onlyOwner {
        require(saleState != state, "Stabl3PublicSale: Sale state is already of the value 'state'");
        saleState = state;
    }

    function buy(IERC20 _token, uint256 _amountToken) external {
        require(saleState, "Stabl3PublicSale: Sale not yet started");
        require(treasury.isReservedToken(_token), "Stabl3PublicSale: Token not reserved");
        require(_amountToken > 0, "Stabl3PublicSale: Insufficient amount");

        uint256 amountStabl3 = treasury.getAmountOut(_token, _amountToken);

        uint256 amountTreasury = _amountToken.mul(treasuryPercentage).ceilDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, address(treasury), amountTreasury);

        uint256 amountROI = _amountToken.mul(ROIPercentage).div(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, ROI, amountROI);

        uint256 amountHQ = _amountToken.mul(HQPercentage).div(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);

        stabl3.transferFrom(address(treasury), msg.sender, amountStabl3);

        emit Buy(msg.sender, amountStabl3, _token, _amountToken);
        treasury.updatePool(BUY_POOL, _token, amountTreasury, amountROI, amountHQ, true);
        treasury.updateRate();
    }

    function exchange(IERC20 _exchangingToken, IERC20 _token, uint256 _amountToken) external {
        require(saleState, "Stabl3PublicSale: Sale not yet started");
        require(
            treasury.isReservedToken(_token) &&
            treasury.isReservedToken(_exchangingToken),
            "Stabl3PublicSale: Token(s) not reserved"
        );
        require(_exchangingToken != _token, "Stabl3PublicSale: Invalid exchange");
        require(_amountToken > 0, "Stabl3PublicSale: Insufficient amount");

        uint256 fee = (_amountToken * exchangeFee) / 1000;
        _amountToken -= fee;

        SafeERC20.safeTransferFrom(_token, msg.sender, ROI, fee);

        uint256 amountExchangingToken;
        uint256 decimalsExchangingToken = _exchangingToken.decimals();
        uint256 decimalsToken = _token.decimals();
        if (decimalsExchangingToken > decimalsToken) {
            amountExchangingToken = _amountToken * (10 ** (decimalsExchangingToken - decimalsToken));
        }
        else if (decimalsToken > decimalsExchangingToken) {
            amountExchangingToken = _amountToken / (10 ** (decimalsToken - decimalsExchangingToken));
        }
        else {
            amountExchangingToken = _amountToken;
        }

        uint256 amountTreasury = _amountToken.mul(treasuryPercentage).ceilDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, address(treasury), amountTreasury);

        uint256 amountROI = _amountToken.mul(ROIPercentage).div(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, ROI, amountROI);

        uint256 amountHQ = _amountToken.mul(HQPercentage).div(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);

        SafeERC20.safeTransferFrom(_exchangingToken, address(treasury), msg.sender, amountExchangingToken);

        emit Exchanged(msg.sender, _exchangingToken, amountExchangingToken, fee, _token, _amountToken);
        treasury.updatePool(BUY_POOL, _token, amountTreasury, amountROI + fee, amountHQ, true);
        treasury.updatePool(BUY_POOL, _exchangingToken, amountExchangingToken, 0, 0, false);
        treasury.updateRate();
    }
}