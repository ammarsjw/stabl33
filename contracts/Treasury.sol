// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.19;

import "./Ownable.sol";

import "./SafeMath.sol";
import "./SafeERC20.sol";

import "./IUniswapV2Router.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";

contract Treasury is Ownable {
    using SafeMath for uint256;

    uint256 private constant MAX_INT = 2 ** 256 - 1;

    IUniswapV2Router02 public uniswapRouter;
    IUniswapV2Factory public uniswapFactory;

    address public ROI;
    address public HQ;

    IERC20 public immutable STABL3;
    uint256 private _stabl3CirculatingSupply;

    IERC20 public UCD;

    uint256 public exchangeFee;

    uint256 private immutable rateImpactSlope;
    RateHistory public rateHistory;
    RateInfo public rateInfo;

    uint8[] public lockedStabl3Pools;

    // structs

    struct RateInfo {
        uint256 rate;
        uint256 totalValueLocked;
        uint256 stabl3CirculatingSupply;
    }

    struct RateHistory {
        uint256 singleValue;
        uint256 totalValue;
        uint256 singleStabl3;
        uint256 totalStabl3;
    }

    // storage

    /// @dev Reserved tokens that interact with the protocol
    mapping (IERC20 => bool) public isReservedToken;

    /// @dev Array for iteration of reserved tokens
    IERC20[] public allReservedTokens;

    /// @dev Record for funds pooled
    mapping (uint8 => mapping (IERC20 => uint256)) public getTreasuryPool;
    mapping (uint8 => mapping (IERC20 => uint256)) public getROIPool;
    mapping (uint8 => mapping (IERC20 => uint256)) public getHQPool;

    /// @dev Contracts with permission to access TREASURY funds
    mapping (address => bool) public permitted;

    // events

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedHQ(address newHQ, address oldHQ);

    event UpdatedExchangeFee(uint256 newExchangeFee, uint256 oldExchangeFee);

    event UpdatedPermission(address contractAddress, bool state);

    event UpdatedReservedToken(IERC20 token, bool state);

    event Rate(
        uint256 rate,
        uint256 reserves,
        uint256 totalValueLocked,
        uint256 stabl3CirculatingSupply,
        uint256 timestamp
    );

    // constructor

    constructor() {
        // TODO change
        uniswapRouter = IUniswapV2Router02(0x8954AfA98594b838bda56FE4C12a09D7739D179b);
        uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());

        // TODO change
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        // TODO change
        STABL3 = IERC20(0xc3Bf0c0172E3638d383361801e9BF63B4FfE0d6e);

        // TODO change
        UCD = IERC20(0x78Ef94529fC06F08756a43f6Bdfe61395C0e1428);

        exchangeFee = 3;

        rateImpactSlope = 0.000000000699993 * (10 ** 18);
        rateInfo.rate = 0.0007 * (10 ** 18);
        // rateInfo.stabl3CirculatingSupply = 0;
        // rateInfo.totalValueLocked = 0;

        lockedStabl3Pools = [11, 25];

        // TODO change
        IERC20 USDC = IERC20(0x16c1038a989E7c52c7B0FBDE889249C02d7e205D);
        IERC20 DAI = IERC20(0x63720e1a9E780865B9FbDb148c25AEa0B59170F1);

        updateReservedToken(USDC, true);
        updateReservedToken(DAI, true);
    }

    function updateDEX(address _router) external onlyOwner {
        require(address(uniswapRouter) != _router, "Treasury: Router is already this address");
        uniswapRouter = IUniswapV2Router02(_router);
        uniswapFactory = IUniswapV2Factory(IUniswapV2Router02(_router).factory());
    }

    function updateROI(address _ROI) external onlyOwner {
        require(ROI != _ROI, "Treasury: ROI is already this address");
        if (address(ROI) != address(0)) updatePermission(address(ROI), false);
        updatePermission(_ROI, true);
        emit UpdatedROI(_ROI, ROI);
        ROI = _ROI;
    }

    function updateHQ(address _HQ) external onlyOwner {
        require(HQ != _HQ, "Treasury: HQ is already this address");
        emit UpdatedHQ(_HQ, HQ);
        HQ = _HQ;
    }

    function stabl3CirculatingSupply() public view returns (uint256) {
        return _stabl3CirculatingSupply + getTreasuryPool[lockedStabl3Pools[0]][STABL3];
    }

    function updateUCD(address _ucd) external onlyOwner {
        require(address(UCD) != _ucd, "Treasury: UCD is already this address");
        UCD = IERC20(_ucd);
    }

    function updateExchangeFee(uint256 _exchangeFee) external onlyOwner {
        require(exchangeFee != _exchangeFee, "Treasury: Exchange Fee is already this value");
        emit UpdatedExchangeFee(_exchangeFee, exchangeFee);
        exchangeFee = _exchangeFee;
    }

    function updateLockedStabl3Pools(uint8[] memory _lockedStabl3Pools) external onlyOwner {
        lockedStabl3Pools = _lockedStabl3Pools;
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

    function updatePermission(address _contractAddress, bool _state) public onlyOwner {
        require(permitted[_contractAddress] != _state, "Treasury: Contract Address is already this state");

        permitted[_contractAddress] = _state;

        if (_state) {
            delegateApprove(STABL3, _contractAddress, true);
            delegateApprove(UCD, _contractAddress, true);

            for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
                delegateApprove(allReservedTokens[i], _contractAddress, true);
            }
        }
        else {
            delegateApprove(STABL3, _contractAddress, false);
            delegateApprove(UCD, _contractAddress, false);

            for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
                delegateApprove(allReservedTokens[i], _contractAddress, false);
            }
        }

        emit UpdatedPermission(_contractAddress, _state);
    }

    function updatePermissionMultiple(address[] memory _contractAddresses, bool _state) public onlyOwner {
        for (uint256 i = 0 ; i < _contractAddresses.length ; i++) {
            updatePermission(_contractAddresses[i], _state);
        }
    }

    function getReserves() public view returns (uint256) {
        uint256 totalReserves;

        for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
            if (isReservedToken[allReservedTokens[i]]) {
                uint256 amountToken = allReservedTokens[i].balanceOf(address(this));

                uint256 decimals = allReservedTokens[i].decimals();

                totalReserves += decimals < 18 ? amountToken * (10 ** (18 - decimals)) : amountToken;
            }
        }

        return totalReserves;
    }

    function getTotalValueLocked() public view returns (uint256) {
        uint256 totalValueLocked;

        for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
            if (isReservedToken[allReservedTokens[i]]) {
                uint256 amountToken = allReservedTokens[i].balanceOf(address(this));

                amountToken += allReservedTokens[i].balanceOf(ROI);
                amountToken += allReservedTokens[i].balanceOf(HQ);

                uint256 decimals = allReservedTokens[i].decimals();

                totalValueLocked += decimals < 18 ? amountToken * (10 ** (18 - decimals)) : amountToken;
            }
        }

        return totalValueLocked;
    }

    function reservedTokenSelector() external view returns (IERC20) {
        IERC20 selectedReservedToken;

        uint256 maxAmountReservedToken;

        for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
            if (isReservedToken[allReservedTokens[i]]) {
                uint256 amountReservedToken = allReservedTokens[i].balanceOf(address(this));

                uint256 decimals = allReservedTokens[i].decimals();

                uint256 amountReservedTokenConverted =
                    decimals < 18 ?
                    (amountReservedToken * (10 ** (18 - decimals))) :
                    amountReservedToken;

                if (amountReservedTokenConverted > maxAmountReservedToken) {
                    selectedReservedToken = allReservedTokens[i];

                    maxAmountReservedToken = amountReservedTokenConverted;
                }
            }
        }

        return selectedReservedToken;
    }

    function getLockedAmount() external view returns (uint256) {
        uint256 amountStabl3Locked;

        for (uint256 i = 0 ; i < lockedStabl3Pools.length ; i++) {
            amountStabl3Locked += getTreasuryPool[lockedStabl3Pools[i]][STABL3];
        }

        return amountStabl3Locked;
    }

    /// @notice Rate is in 18 decimals
    function getRate() external view returns (uint256) {
        return rateInfo.rate;
    }

    /// @notice Rate is in 18 decimals
    function getRateImpact(IERC20 _token, uint256 _amountToken) public view returns (uint256) {
        if (_amountToken == 0) {
            return rateInfo.rate;
        }

        uint256 amountTokenConverted = _token.decimals() < 18 ? _amountToken * (10 ** (18 - _token.decimals())) : _amountToken;

        uint256 rate = rateInfo.rate + ((amountTokenConverted * rateImpactSlope) / (10 ** 18));

        return rate;
    }

    function getAmountOut(IERC20 _token, uint256 _amountToken) public view returns (uint256) {
        if (_amountToken == 0) {
            return 0;
        }

        uint256 rate = getRateImpact(_token, _amountToken);

        uint256 amountTokenConverted = _token.decimals() < 18 ? _amountToken * (10 ** (18 - _token.decimals())) : _amountToken;

        uint256 projectedStabl3CirculatingSupply = ((amountTokenConverted + rateInfo.totalValueLocked) * (10 ** 6)) / rate;

        uint256 amountStabl3 = projectedStabl3CirculatingSupply.safeSub(rateInfo.stabl3CirculatingSupply);

        return amountStabl3;
    }

    function getAmountIn(uint256 _amountStabl3, IERC20 _token) external view returns (uint256) {
        if (_amountStabl3 == 0) {
            return 0;
        }

        uint256 projectedStabl3CirculatingSupply = _amountStabl3 + rateInfo.stabl3CirculatingSupply;

        uint256 amountTokenConverted =
            ((((projectedStabl3CirculatingSupply * rateInfo.rate) / (10 ** 6)) - rateInfo.totalValueLocked) * (10 ** 18)) /
            ((1 * (10 ** 18)) - ((projectedStabl3CirculatingSupply * rateImpactSlope) / (10 ** 6)));

        uint256 amountToken = _token.decimals() < 18 ? amountTokenConverted / (10 ** (18 - _token.decimals())) : amountTokenConverted;

        return amountToken;
    }

    function getBaseAmountOut(uint256 _amountToken) external view returns (uint256) {
        if (_amountToken == 0) {
            return 0;
        }

        (uint256 circulatingSupply, uint256 valueLocked) =
            _amountToken * 1e12 > rateHistory.singleValue ?
            (rateHistory.totalStabl3, rateHistory.totalValue) :
            (rateHistory.singleStabl3, rateHistory.singleValue);
        uint256 amountStabl3 = (_amountToken * circulatingSupply * 1e12) / valueLocked;

        return amountStabl3;
    }

    function getBaseAmountIn(uint256 _amountStabl3) external view returns (uint256) {
        if (_amountStabl3 == 0) {
            return 0;
        }

        (uint256 valueLocked, uint256 circulatingSupply) =
            _amountStabl3 > rateHistory.singleStabl3 ?
            (rateHistory.totalValue, rateHistory.totalStabl3) :
            (rateHistory.singleValue, rateHistory.singleStabl3);
        uint256 amountToken = (_amountStabl3 * valueLocked) / (circulatingSupply * 1e12);

        return amountToken;
    }

    function getExchangeAmountOut(IERC20 _exchangingToken, IERC20 _token, uint256 _amountToken) external view returns (uint256) {
        if (_amountToken == 0) {
            return 0;
        }

        uint256 fee = _amountToken.mul(exchangeFee).div(1000);
        uint256 amountTokenWithFee = _amountToken - fee;

        address pair = uniswapFactory.getPair(address(_token), address(_exchangingToken));

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();

        address token0 = IUniswapV2Pair(pair).token0();
        (uint256 reserveToken, uint256 reserveExchangingToken) =
            address(_token) == token0 ?
            (reserve0, reserve1) :
            (reserve1, reserve0);

        uint256 amountExchangingToken = uniswapRouter.quote(amountTokenWithFee, reserveToken, reserveExchangingToken);

        return amountExchangingToken;
    }

    function getExchangeAmountIn(IERC20 _exchangingToken, uint256 _amountExchangingToken, IERC20 _token) external view returns (uint256) {
        if (_amountExchangingToken == 0) {
            return 0;
        }

        address pair = uniswapFactory.getPair(address(_token), address(_exchangingToken));

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();

        address token0 = IUniswapV2Pair(pair).token0();
        (uint256 reserveExchangingToken, uint256 reserveToken) =
            address(_exchangingToken) == token0 ?
            (reserve0, reserve1) :
            (reserve1, reserve0);

        uint256 amountToken = uniswapRouter.quote(_amountExchangingToken, reserveExchangingToken, reserveToken);

        uint256 amountTokenWithFee = amountToken.mul(1000).div(1000 - exchangeFee);

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
            _stabl3CirculatingSupply += _amountStabl3;
        }
        else {
            _stabl3CirculatingSupply -= _amountStabl3;
        }

        uint256 reserves = getReserves();

        uint256 totalValueLocked = getTotalValueLocked();

        uint256 circulatingSupply = stabl3CirculatingSupply();

        emit Rate(rateInfo.rate, reserves, totalValueLocked, circulatingSupply, block.timestamp);
    }

    function updateRate(IERC20 _token, uint256 _amountToken) external permission reserved(_token) {
        uint256 amountTokenConverted = _token.decimals() < 18 ? _amountToken * (10 ** (18 - _token.decimals())) : _amountToken;
        uint256 amountStabl3 = getAmountOut(_token, _amountToken);

        rateInfo.rate = getRateImpact(_token, _amountToken);
        rateInfo.totalValueLocked += amountTokenConverted;
        rateInfo.stabl3CirculatingSupply += amountStabl3;

        uint256 reserves = getReserves();

        uint256 totalValueLocked = getTotalValueLocked();
        rateHistory.singleValue = amountTokenConverted;
        rateHistory.totalValue = totalValueLocked;

        uint256 circulatingSupply = stabl3CirculatingSupply();
        rateHistory.singleStabl3 = amountStabl3;
        rateHistory.totalStabl3 = circulatingSupply;

        emit Rate(rateInfo.rate, reserves, totalValueLocked, circulatingSupply, block.timestamp);
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

    // TODO remove
    // Testing only
    // function testReset() external {
    //     rateHistory.stabl3CirculatingSupply = 0;
    //     rateHistory.totalValueLocked = 0;
    //     rateHistory.rate = 0.0007 * (10 ** 18);

    //     rateInfo.stabl3CirculatingSupply = 0;
    //     rateInfo.totalValueLocked = 0;
    //     rateInfo.rate = 0.0007 * (10 ** 18);
    // }

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