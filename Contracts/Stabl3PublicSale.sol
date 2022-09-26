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

    uint8 constant BUY_POOL = 0;

    ITreasury public treasury;
    address public ROI;
    address public HQ;

    IERC20 public stabl3;

    uint256 public treasuryPercentage;
    uint256 public ROIPercentage;
    uint256 public HQPercentage;

    uint256 public exchangePauseTime;
    uint256 public exchangeLimitTime;
    uint256 public exchangeLimitPercentage;

    bool public saleState;

    // structs

    struct Limit {
        address user;
        uint256 amount;
        uint256 startTime;
        uint256 lastExchangeTime;
    }

    // mappings

    mapping (address => Limit) public getLimit;

    // events

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedHQ(address newHQ, address oldHQ);

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

        exchangePauseTime = 300;
        exchangeLimitTime = 86400;
        exchangeLimitPercentage = 300;
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

    function updateExchangePauseTime(uint256 _exchangePauseTime) external onlyOwner {
        require(exchangePauseTime != _exchangePauseTime, "Stabl3PublicSale: Exchange Pause Time is already this value");
        exchangePauseTime = _exchangePauseTime;
    }

    function updateExchangeLimitTime(uint256 _exchangeLimitTime) external onlyOwner {
        require(exchangeLimitTime != _exchangeLimitTime, "Stabl3PublicSale: Exchange Limit Time is already this value");
        exchangeLimitTime = _exchangeLimitTime;
    }

    function updateExchangeLimitPercentage(uint256 _exchangeLimitPercentage) external onlyOwner {
        require(exchangeLimitPercentage != _exchangeLimitPercentage, "Stabl3PublicSale: Exchange Limit Percentage is already this value");
        exchangeLimitPercentage = _exchangeLimitPercentage;
    }

    function updateSaleState(bool _state) external onlyOwner {
        require(saleState != _state, "Stabl3PublicSale: Sale state is already of the value 'state'");
        saleState = _state;
    }

    function buy(IERC20 _token, uint256 _amountToken) external saleActive nonReentrant reserved(_token) {
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

    function _handleLimit(IERC20 _exchangingToken, uint256 _amountExchangingToken) internal {
        Limit storage limit = getLimit[msg.sender];

        uint256 amountExchangingTokenConverted = _amountExchangingToken;
        if (_exchangingToken.decimals() < 18) {
            amountExchangingTokenConverted *= 10 ** (18 - _exchangingToken.decimals());
        }

        if (limit.user != msg.sender) {
            limit.user = msg.sender;
            limit.amount = amountExchangingTokenConverted;
            limit.startTime = block.timestamp;
        }

        if (block.timestamp > limit.lastExchangeTime + exchangePauseTime) {
            limit.lastExchangeTime = block.timestamp;
        }
        else {
            revert("Stabl3PublicSale: Exchange Time Lock. Try again later");
        }

        // TODO
        // uint256 treasuryReserves = treasury.getReserves();
        uint256 amountExchangingTokenTreasury = _exchangingToken.balanceOf(address(treasury));

        if (limit.amount + amountExchangingTokenConverted > amountExchangingTokenTreasury.mul(exchangeLimitPercentage).div(1000)) {
            require(block.timestamp > limit.startTime.add(exchangeLimitTime),
                "Stabl3PublicSale: Exchange Limit Reached. Try again later or try a smaller value");
        }

        if (block.timestamp > limit.startTime.add(exchangeLimitTime)) {
            limit.amount = amountExchangingTokenConverted;
            limit.startTime = block.timestamp;
        }
        else {
            limit.amount += amountExchangingTokenConverted;
        }
    }

    // 5 minute pause per user, limited to 30% of treasury exchangeable within 24 hour per user, AMM for price
    function exchange(
        IERC20 _exchangingToken,
        IERC20 _token,
        uint256 _amountToken
    ) external saleActive nonReentrant reserved(_exchangingToken) reserved(_token)  {
        require(_exchangingToken != _token, "Stabl3PublicSale: Invalid exchange");
        require(_amountToken > 0, "Stabl3PublicSale: Insufficient amount");

        uint256 fee = (_amountToken * treasury.exchangeFee()) / 1000;
        uint256 amountTokenWithFee = _amountToken - fee;

        uint256 amountExchangingToken = treasury.getExchangeAmountOut(_exchangingToken, _token, _amountToken);

        _handleLimit(_exchangingToken, amountExchangingToken);

        SafeERC20.safeTransferFrom(_token, msg.sender, address(treasury), amountTokenWithFee);
        SafeERC20.safeTransferFrom(_exchangingToken, address(treasury), msg.sender, amountExchangingToken);

        treasury.updatePool(BUY_POOL, _token, amountTokenWithFee, 0, 0, true);
        treasury.updatePool(BUY_POOL, _exchangingToken, amountExchangingToken, 0, 0, false);

        emit Exchange(msg.sender, _exchangingToken, amountExchangingToken, _token, amountTokenWithFee, fee, block.timestamp);

        SafeERC20.safeTransferFrom(_token, msg.sender, ROI, fee);

        uint256 amountStabl3 = treasury.getAmountOut(_token, fee);

        stabl3.transferFrom(address(treasury), msg.sender, amountStabl3);

        treasury.updatePool(BUY_POOL, _token, 0, fee, 0, true);
        treasury.updateRate(_token, fee);

        emit Buy(msg.sender, amountStabl3, _token, fee, block.timestamp);
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