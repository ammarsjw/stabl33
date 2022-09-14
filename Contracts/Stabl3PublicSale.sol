// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";

import "./ITreasury.sol";

contract Stabl3PublicSale is Ownable, ReentrancyGuard {
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

    // events

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedHQ(address newHQ, address oldHQ);

    event UpdatedExchangeFee(uint256 newExchangeFee, uint256 oldExchangeFee);

    event Buy(address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken, uint256 timestamp);

    event Exchange(
        address indexed recipient,
        IERC20 exchangingToken,
        uint256 amountExchangingToken,
        IERC20 token,
        uint256 amountToken,
        uint256 fee,
        uint256 timestamp
    );

    // constructor

    constructor(address _treasury, address _ROI) {
        treasury = ITreasury(_treasury);
        ROI = _ROI;
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        stabl3 = IERC20(0xDf9c4990a8973b6cC069738592F27Ea54b27D569);

        treasuryPercentage = 800;
        ROIPercentage = 161;
        HQPercentage = 39;

        exchangeFee = 3;
    }

    function updateTreasury(address _treasury) external onlyOwner {
        require(address(treasury) != _treasury, "Stabl3PublicSale: Treasury is already this address");
        emit UpdatedTreasury(_treasury, address(treasury));
        treasury = ITreasury(_treasury);
    }

    function updateROI(address _ROI) external onlyOwner {
        require(ROI != _ROI, "Stabl3PublicSale: ROI is already this address");
        emit UpdatedROI(_ROI, ROI);
        ROI = _ROI;
    }

    function updateHQ(address _HQ) external onlyOwner {
        require(HQ != _HQ, "Stabl3PublicSale: HQ is already this address");
        emit UpdatedHQ(_HQ, HQ);
        HQ = _HQ;
    }

    function updateDistributionPercentages(
        uint256 _treasuryPercentage,
        uint256 _ROIPercentage,
        uint256 _HQPercentage
    ) external onlyOwner {
        require(_treasuryPercentage + _ROIPercentage + _HQPercentage == 1000,
            "STABL3: Sum of magnified percentages should equal 1000");

        treasuryPercentage = _treasuryPercentage;
        ROIPercentage = _ROIPercentage;
        HQPercentage = _HQPercentage;
    }

    function updateExchangeFee(uint256 _exchangeFee) external onlyOwner {
        require(exchangeFee != _exchangeFee, "Stabl3PublicSale: Exchange Fee is already this value");
        emit UpdatedExchangeFee(_exchangeFee, exchangeFee);
        exchangeFee = _exchangeFee;
    }

    function updateSaleState(bool _state) external onlyOwner {
        require(saleState != _state, "Stabl3PublicSale: Sale state is already of the value 'state'");
        saleState = _state;
    }

    function buy(IERC20 _token, uint256 _amountToken) external nonReentrant saleActive reserved(_token) {
        require(_amountToken > 0, "Stabl3PublicSale: Insufficient amount");

        uint256 amountTreasury = _amountToken.mul(treasuryPercentage).div(1000);

        uint256 amountROI = _amountToken.mul(ROIPercentage).div(1000);

        uint256 amountHQ = _amountToken.mul(HQPercentage).div(1000);

        uint256 totalAmountDistributed = amountTreasury + amountROI + amountHQ;
        if (_amountToken > totalAmountDistributed) {
            amountTreasury += _amountToken - totalAmountDistributed;
        }

        SafeERC20.safeTransferFrom(_token, msg.sender, address(treasury), amountTreasury);
        SafeERC20.safeTransferFrom(_token, msg.sender, ROI, amountROI);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);

        uint256 amountStabl3 = treasury.getAmountOut(_token, _amountToken);

        stabl3.transferFrom(address(treasury), msg.sender, amountStabl3);

        treasury.updatePool(BUY_POOL, _token, amountTreasury, amountROI, amountHQ, true);
        treasury.updateRate(_token, _amountToken);

        emit Buy(msg.sender, amountStabl3, _token, _amountToken, block.timestamp);
    }

    // TODO rework, no buying stabl3, 5 minute pause per user, 24 hour limit 30% of treasury per user, AMM for price
    function exchange(
        IERC20 _exchangingToken,
        IERC20 _token,
        uint256 _amountToken
    ) external nonReentrant saleActive reserved(_exchangingToken) reserved(_token) {
        require(_exchangingToken != _token, "Stabl3PublicSale: Invalid exchange");
        require(_amountToken > 0, "Stabl3PublicSale: Insufficient amount");

        uint256 fee = (_amountToken * exchangeFee) / 1000;
        uint256 amountTokenWithFee = _amountToken - fee;

        SafeERC20.safeTransferFrom(_token, msg.sender, ROI, fee);

        uint256 amountStabl3 = treasury.getAmountOut(_token, fee);

        stabl3.transferFrom(address(treasury), msg.sender, amountStabl3);

        treasury.updatePool(BUY_POOL, _token, 0, fee, 0, true);
        treasury.updateRate(_token, fee);

        emit Buy(msg.sender, amountStabl3, _token, fee, block.timestamp);

        uint256 amountExchangingToken;
        if (_exchangingToken.decimals() > _token.decimals()) {
            amountExchangingToken = amountTokenWithFee * (10 ** (_exchangingToken.decimals() - _token.decimals()));
        }
        else if (_token.decimals() > _exchangingToken.decimals()) {
            amountExchangingToken = amountTokenWithFee / (10 ** (_token.decimals() - _exchangingToken.decimals()));
        }
        else {
            amountExchangingToken = amountTokenWithFee;
        }

        SafeERC20.safeTransferFrom(_token, msg.sender, address(treasury), amountTokenWithFee);
        SafeERC20.safeTransferFrom(_exchangingToken, address(treasury), msg.sender, amountExchangingToken);

        treasury.updatePool(BUY_POOL, _token, amountTokenWithFee, 0, 0, true);
        treasury.updatePool(BUY_POOL, _exchangingToken, amountExchangingToken, 0, 0, false);

        emit Exchange(msg.sender, _exchangingToken, amountExchangingToken, _token, amountTokenWithFee, fee, block.timestamp);
    }

    // modifiers

    modifier saleActive() {
        require(saleState, "Stabl3PublicSale: Sale not yet started");
        _;
    }

    modifier reserved(IERC20 _token) {
        require(treasury.isReservedToken(_token), "Stabl3PublicSale: Not a reserved token");
        _;
    }
}