// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "../../Contracts/Ownable.sol";
import "../../Contracts/SafeMath.sol";
import "../../Contracts/SafeERC20.sol";

import "../../Contracts/IUniswapV2Router.sol";
import "../../Contracts/IUniswapV2Factory.sol";
import "../../Contracts/IUniswapV2Pair.sol";

contract Treasury is Ownable {
    using SafeMath for uint256;

    uint256 private constant MAX_INT = 2 ** 256 - 1;

    IUniswapV2Router02 public uniswapRouter;
    IUniswapV2Factory public uniswapFactory;

    address public ROI;
    address public HQ;

    IERC20 public immutable stabl3;
    uint256 public stabl3CirculatingSupply;

    IERC20 public ucd;

    uint256 public exchangeFee;

    RateInfo public rateInfo;

    // structs

    struct RateInfo {
        uint256 compoundPercentage;
        uint256 rate;
        uint256 tokenWindow;
        uint256 stabl3Window;
        uint256 tokenWindowConsumed;
    }

    // mappings

    // contracts with permission to access treasury funds
    mapping (address => bool) public permitted;

    // reserved tokens to buy STABL3
    mapping (IERC20 => bool) public isReservedToken;

    // array for reserved tokens
    IERC20[] public allReservedTokens;

    // record for funds pooled
    mapping (uint8 => mapping(IERC20 => uint256)) public getTreasuryPool;
    mapping (uint8 => mapping(IERC20 => uint256)) public getROIPool;
    mapping (uint8 => mapping(IERC20 => uint256)) public getHQPool;

    // events

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedHQ(address newHQ, address oldHQ);

    event UpdatedExchangeFee(uint256 newExchangeFee, uint256 oldExchangeFee);

    event UpdatedPermission(address contractAddress, bool state);

    event UpdatedReservedToken(IERC20 token, bool state);

    event Rate(uint256 rate, uint256 totalValueLocked, uint256 reserves, uint256 stabl3CirculatingSupply, uint256 blockTimestampLast);

    // constructor

    constructor() {
        // TODO change
        uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());

        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        stabl3 = IERC20(0xc3Bf0c0172E3638d383361801e9BF63B4FfE0d6e);
        ucd = IERC20(0xB0124F5d0e906d3652d0b58F03E315eC42A57E9a);

        exchangeFee = 3;

        rateInfo = RateInfo(1 * (10 ** 15), 0.0007 * (10 ** 18), 10000 * (10 ** 18), 0, 0);
        rateInfo.stabl3Window = (rateInfo.tokenWindow * (10 ** 6)) / rateInfo.rate;

        IERC20 USDC = IERC20(0x16c1038a989E7c52c7B0FBDE889249C02d7e205D);
        IERC20 DAI = IERC20(0x63720e1a9E780865B9FbDb148c25AEa0B59170F1);

        updateReservedToken(USDC, true);
        updateReservedToken(DAI, true);
    }

    function updateROI(address _ROI) external onlyOwner {
        require(ROI != _ROI, "Treasury: ROI is already this address");
        emit UpdatedROI(_ROI, ROI);
        ROI = _ROI;
    }

    function updateHQ(address _HQ) external onlyOwner {
        require(HQ != _HQ, "Treasury: HQ is already this address");
        emit UpdatedHQ(_HQ, HQ);
        HQ = _HQ;
    }

    function initializeUCD(address _ucd) external onlyOwner {
        require(address(ucd) != _ucd, "Treasury: UCD is already this address");
        ucd = IERC20(_ucd);
    }

    function updateExchangeFee(uint256 _exchangeFee) external onlyOwner {
        require(exchangeFee != _exchangeFee, "Treasury: Exchange Fee is already this value");
        emit UpdatedExchangeFee(_exchangeFee, exchangeFee);
        exchangeFee = _exchangeFee;
    }

    function updatePermission(address _contractAddress, bool _state) external onlyOwner {
        require(permitted[_contractAddress] != _state, "Treasury: Address is already this state");
        permitted[_contractAddress] = _state;

        if (_state) {
            delegateApprove(stabl3, _contractAddress, true);

            // delegateApprove(ucd, _contractAddress, true);

            for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
                delegateApprove(allReservedTokens[i], _contractAddress, true);
            }
        }
        else {
            delegateApprove(stabl3, _contractAddress, false);

            // delegateApprove(ucd, _contractAddress, false);

            for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
                delegateApprove(allReservedTokens[i], _contractAddress, false);
            }
        }

        emit UpdatedPermission(_contractAddress, _state);
    }

    function updateReservedToken(IERC20 _token, bool _state) public onlyOwner {
        require(isReservedToken[_token] != _state, "Treasury: Reserved token is already this state");
        isReservedToken[_token] = _state;
        allReservedTokens.push(_token);
        emit UpdatedReservedToken(_token, _state);
    }

    function allReservedTokensLength() external view returns (uint256) {
        return allReservedTokens.length;
    }

    function allPools(uint8 _type, IERC20 _token) external view returns (uint256, uint256, uint256) {
        return (
            getTreasuryPool[_type][_token],
            getROIPool[_type][_token],
            getHQPool[_type][_token]
        );
    }

    function sumOfAllPools(uint8 _type, IERC20 _token) external view returns (uint256) {
        return getTreasuryPool[_type][_token] + getROIPool[_type][_token] + getHQPool[_type][_token];
    }

    function getReserves() public view returns (uint256) {
        uint256 totalReserves;

        for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
            if (isReservedToken[allReservedTokens[i]]) {
                uint256 amount = allReservedTokens[i].balanceOf(address(this));

                uint256 decimals = allReservedTokens[i].decimals();

                totalReserves += decimals < 18 ? amount * 10 ** (18 - decimals) : amount;
            }
        }

        return totalReserves;
    }

    function getTotalValueLocked() public view returns (uint256) {
        uint256 totalValueLocked;

        for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
            if (isReservedToken[allReservedTokens[i]]) {
                uint256 amount = allReservedTokens[i].balanceOf(address(this));

                amount += allReservedTokens[i].balanceOf(ROI);
                amount += allReservedTokens[i].balanceOf(HQ);

                uint256 decimals = allReservedTokens[i].decimals();

                totalValueLocked += decimals < 18 ? amount * 10 ** (18 - decimals) : amount;
            }
        }

        return totalValueLocked;
    }

    // rate is in 18 decimals
    function getRate() public view returns (uint256) {
        return rateInfo.rate;
    }

    // rate is in 18 decimals
    function getRateImpact(IERC20 _token, uint256 _amountToken) public view reserved(_token) returns (uint256) {
        uint256 amountTokenConverted = _token.decimals() < 18 ? _amountToken * 10 ** (18 - _token.decimals()) : _amountToken;

        uint256 amountTokenToConsider = amountTokenConverted + rateInfo.tokenWindowConsumed;

        if (amountTokenToConsider <= rateInfo.tokenWindow) {
            return rateInfo.rate;
        }
        else {
            uint256 rateToConsider = rateInfo.rate;

            uint256 tokenWindowToConsider = rateInfo.tokenWindow;

            amountTokenToConsider = amountTokenToConsider.safeSub(tokenWindowToConsider);

            while (amountTokenToConsider > 0) {
                rateToConsider += _compoundSingle(rateToConsider, rateInfo.compoundPercentage);

                tokenWindowToConsider += _compoundSingle(tokenWindowToConsider, rateInfo.compoundPercentage);

                amountTokenToConsider = amountTokenToConsider.safeSub(tokenWindowToConsider);
            }

            return rateToConsider;
        }
    }

    function getAmountOut(IERC20 _token, uint256 _amountToken) external view reserved(_token) returns (uint256) {
        require(_amountToken > 0, "Treasury: Insufficient amount");
        if (stabl3.balanceOf(address(this)) == 0) {
            return 0;
        }

        uint256 amountTokenConverted = _token.decimals() < 18 ? _amountToken * 10 ** (18 - _token.decimals()) : _amountToken;

        uint256 amountTokenToConsider = amountTokenConverted + rateInfo.tokenWindowConsumed;

        if (amountTokenToConsider <= rateInfo.tokenWindow) {
            return (amountTokenConverted * rateInfo.stabl3Window) / rateInfo.tokenWindow;
        }
        else {
            uint256 tokenWindowToConsider = rateInfo.tokenWindow;

            uint256 stabl3WindowToConsider = rateInfo.stabl3Window;

            uint256 tokenWindowRemainingToConsider = tokenWindowToConsider - rateInfo.tokenWindowConsumed;

            uint256 amountStabl3ToConsider = (tokenWindowRemainingToConsider * stabl3WindowToConsider) / tokenWindowToConsider;

            amountTokenToConsider = amountTokenToConsider.checkSub(tokenWindowToConsider);

            tokenWindowToConsider += _compoundSingle(tokenWindowToConsider, rateInfo.compoundPercentage);

            stabl3WindowToConsider -= _compoundSingle(stabl3WindowToConsider, rateInfo.compoundPercentage);

            while (amountTokenToConsider > tokenWindowToConsider) {
                amountStabl3ToConsider += stabl3WindowToConsider;

                amountTokenToConsider = amountTokenToConsider.checkSub(tokenWindowToConsider);

                tokenWindowToConsider += _compoundSingle(tokenWindowToConsider, rateInfo.compoundPercentage);

                stabl3WindowToConsider -= _compoundSingle(stabl3WindowToConsider, rateInfo.compoundPercentage);
            }

            amountStabl3ToConsider += (amountTokenToConsider * stabl3WindowToConsider) / tokenWindowToConsider;

            return amountStabl3ToConsider;
        }
    }

    function getAmountIn(uint256 _amountStabl3, IERC20 _token) external view reserved(_token) returns (uint256) {
        require(_amountStabl3 > 0, "Treasury: Insufficient amount");
        if (stabl3.balanceOf(address(this)) == 0) {
            return 0;
        }

        uint256 stabl3WindowConsumed = (rateInfo.tokenWindowConsumed * rateInfo.stabl3Window) / rateInfo.tokenWindow;

        uint256 amountStabl3ToConsider = _amountStabl3 + stabl3WindowConsumed;

        uint256 amountTokenToConsider;

        if (amountStabl3ToConsider <= rateInfo.stabl3Window) {
            amountTokenToConsider = (_amountStabl3 * rateInfo.tokenWindow) / rateInfo.stabl3Window;
        }
        else {
            uint256 tokenWindowToConsider = rateInfo.tokenWindow;

            uint256 stabl3WindowToConsider = rateInfo.stabl3Window;

            uint256 stabl3WindowRemainingToConsider = stabl3WindowToConsider - stabl3WindowConsumed;

            amountTokenToConsider = (stabl3WindowRemainingToConsider * tokenWindowToConsider) / stabl3WindowToConsider;

            amountStabl3ToConsider = amountStabl3ToConsider.checkSub(stabl3WindowToConsider);

            tokenWindowToConsider += _compoundSingle(tokenWindowToConsider, rateInfo.compoundPercentage);

            stabl3WindowToConsider -= _compoundSingle(stabl3WindowToConsider, rateInfo.compoundPercentage);

            while (amountStabl3ToConsider > stabl3WindowToConsider) {
                amountTokenToConsider += tokenWindowToConsider;

                amountStabl3ToConsider = amountStabl3ToConsider.checkSub(stabl3WindowToConsider);

                tokenWindowToConsider += _compoundSingle(tokenWindowToConsider, rateInfo.compoundPercentage);

                stabl3WindowToConsider -= _compoundSingle(stabl3WindowToConsider, rateInfo.compoundPercentage);
            }

            amountTokenToConsider += (amountStabl3ToConsider * tokenWindowToConsider) / stabl3WindowToConsider;
        }

        if (_token.decimals() < 18) {
            amountTokenToConsider /= 10 ** (18 - _token.decimals());
        }

        return amountTokenToConsider;
    }

    function getExchangeAmountOut(
        IERC20 _exchangingToken,
        IERC20 _token,
        uint256 _amountToken
    ) external view reserved(_token) returns (uint256) {
        require(_amountToken > 0, "Treasury: Insufficient amount");
        if (_exchangingToken.balanceOf(address(this)) == 0) {
            return 0;
        }

        uint256 fee = (_amountToken * exchangeFee) / 1000;
        uint256 amountTokenWithFee = _amountToken - fee;

        address pair = uniswapFactory.getPair(address(_token), address(_exchangingToken));

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();

        uint256 amountExchangingToken =
            IUniswapV2Pair(pair).token0() == address(_token) ?
            uniswapRouter.quote(amountTokenWithFee, reserve0, reserve1) :
            uniswapRouter.quote(amountTokenWithFee, reserve1, reserve0);

        return amountExchangingToken;
    }

    function getExchangeAmountIn(
        IERC20 _exchangingToken,
        uint256 _amountExchangingToken,
        IERC20 _token
    ) external view reserved(_token) returns (uint256) {
        require(_amountExchangingToken > 0, "Treasury: Insufficient amount");
        if (_exchangingToken.balanceOf(address(this)) == 0) {
            return 0;
        }

        address pair = uniswapFactory.getPair(address(_token), address(_exchangingToken));

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();

        uint256 amountToken =
            IUniswapV2Pair(pair).token0() == address(_exchangingToken) ?
            uniswapRouter.quote(_amountExchangingToken, reserve0, reserve1) :
            uniswapRouter.quote(_amountExchangingToken, reserve1, reserve0);

        uint256 amountTokenWithFee = (amountToken * 1000) / (1000 - exchangeFee);

        return amountTokenWithFee;
    }

    function updatePool(
        uint8 _type,
        IERC20 _token,
        uint256 _amountTokenTreasury,
        uint256 _amountTokenROI,
        uint256 _amountTokenHQ,
        bool _isIncrease
    ) external permission {
        if (_isIncrease) {
            getTreasuryPool[_type][_token] += _amountTokenTreasury;
            getROIPool[_type][_token] += _amountTokenROI;
            getHQPool[_type][_token] += _amountTokenHQ;
        }
        else {
            getTreasuryPool[_type][_token] = getTreasuryPool[_type][_token].safeSub(_amountTokenTreasury);
            getROIPool[_type][_token] = getROIPool[_type][_token].safeSub(_amountTokenROI);
            getHQPool[_type][_token] = getHQPool[_type][_token].safeSub(_amountTokenHQ);
        }
    }

    function updateStabl3CirculatingSupply(uint256 _amountStabl3, bool _isIncrease) external permission {
        if (_isIncrease) {
            stabl3CirculatingSupply += _amountStabl3;
        }
        else {
            stabl3CirculatingSupply -= _amountStabl3;
        }
    }

    function updateRate(IERC20 _token, uint256 _amountToken) external permission reserved(_token) {
        uint256 amountTokenConverted = _token.decimals() < 18 ? _amountToken * 10 ** (18 - _token.decimals()) : _amountToken;

        uint256 amountTokenToConsider = amountTokenConverted + rateInfo.tokenWindowConsumed;

        if (amountTokenToConsider > rateInfo.tokenWindow) {
            uint256 rateToConsider = rateInfo.rate;

            uint256 tokenWindowToConsider = rateInfo.tokenWindow;

            uint256 stabl3WindowToConsider = rateInfo.stabl3Window;

            uint256 tokenWindowConsumedToConsider = rateInfo.tokenWindowConsumed;

            amountTokenToConsider = amountTokenToConsider.safeSub(tokenWindowToConsider);

            while (amountTokenToConsider > 0) {
                rateToConsider += _compoundSingle(rateToConsider, rateInfo.compoundPercentage);

                tokenWindowToConsider += _compoundSingle(tokenWindowToConsider, rateInfo.compoundPercentage);

                stabl3WindowToConsider -= _compoundSingle(stabl3WindowToConsider, rateInfo.compoundPercentage);

                tokenWindowConsumedToConsider = amountTokenToConsider;

                amountTokenToConsider = amountTokenToConsider.safeSub(tokenWindowToConsider);
            }

            rateInfo.rate = rateToConsider;

            rateInfo.tokenWindow = tokenWindowToConsider;

            rateInfo.stabl3Window = stabl3WindowToConsider;

            rateInfo.tokenWindowConsumed = tokenWindowConsumedToConsider;
        }
        else {
            rateInfo.tokenWindowConsumed += amountTokenConverted;
        }

        uint256 reserves = getReserves();

        uint256 totalValueLocked = getTotalValueLocked();

        emit Rate(rateInfo.rate, totalValueLocked, reserves, stabl3CirculatingSupply, block.timestamp);
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
        require(!isReservedToken[_token], "Treasury: Funds Locked");
        SafeERC20.safeTransfer(_token, owner(), _amountToken);
    }

    function withdrawAllFunds(IERC20 _token) external onlyOwner {
        require(!isReservedToken[_token], "Treasury: Funds Locked");
        SafeERC20.safeTransfer(_token, owner(), _token.balanceOf(address(this)));
    }

    function _compoundSingle(uint256 _principal, uint256 _ratio) internal pure returns (uint256) {
        uint256 accruedAmount = _principal.mul(_ratio).div(10 ** 18);

        return accruedAmount;
    }

    // TODO remove
    // Testing only
    function testWithdrawAllFunds(IERC20 _token) external onlyOwner {
        SafeERC20.safeTransfer(_token, owner(), _token.balanceOf(address(this)));
    }

    // modifiers

    modifier permission() {
        require(permitted[msg.sender] || msg.sender == owner(), "Treasury: Not permitted");
        _;
    }

    modifier reserved(IERC20 _token) {
        require(isReservedToken[_token], "Treasury: Not a reserved token");
        _;
    }
}