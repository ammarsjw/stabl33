// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.16;

import "./Ownable.sol";
import "./SafeERC20.sol";

contract Treasury is Ownable {

    uint256 private immutable MAX_INT = 2 ** 256 - 1;

    uint8 private constant BUY_POOL = 0;
    uint8 private constant BOND_POOL = 1;
    uint8 private constant STAKE_POOL = 2;
    uint8 private constant LEND_POOL = 3;
    uint8 private constant BORROW_POOL = 4;
    uint8 private constant EXCHANGE_POOL = 5;

    address public ROI;
    address public HQ;

    IERC20 public stabl3;

    uint256 public initialRate;
    uint256 public initialSupply;

    uint256 private unlocked = 1;

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

    event UpdatedPermission(address contractAddress, bool state);

    event UpdatedReservedToken(IERC20 token, bool state);

    event Rate(uint256 rate, uint256 reserves, uint256 blockTimestampLast);

    // constructor

    constructor() {
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        stabl3 = IERC20(0xDf9c4990a8973b6cC069738592F27Ea54b27D569);

        initialRate = 0.0007 * (10 ** 18);

        IERC20 USDC = IERC20(0x1092d50E8E14479bB769b687427B72BeE70c9534);
        IERC20 DAI = IERC20(0x59f78fB97FB36adbaDCbB43Fa9031797faAad54A);

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

    function provideInitialLiquidity(uint256 _amountStabl3) external onlyOwner {
        require(_amountStabl3 > 0, "Treasury: Insufficient amount");
        require(stabl3.balanceOf(address(this)) == 0, "Treasury: Liquidty already set");

        stabl3.transferFrom(owner(), address(this), _amountStabl3);

        initialSupply = _amountStabl3;
    }

    function updatePermission(address _contractAddress, bool _state) external onlyOwner {
        require(permitted[_contractAddress] != _state, "Treasury: Contract is already of the value 'state'");
        permitted[_contractAddress] = _state;

        if (_state) {
            delegateApprove(stabl3, _contractAddress, true);

            for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
                delegateApprove(allReservedTokens[i], _contractAddress, true);
            }
        }
        else {
            delegateApprove(stabl3, _contractAddress, false);

            for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
                delegateApprove(allReservedTokens[i], _contractAddress, false);
            }
        }

        emit UpdatedPermission(_contractAddress, _state);
    }

    function updateReservedToken(IERC20 _token, bool _state) public onlyOwner {
        require(isReservedToken[_token] != _state, "Treasury: Reserved token is already of the value 'state'");
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
        uint256 amount;
        uint256 decimals;
        for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
            if (isReservedToken[allReservedTokens[i]]) {
                amount = allReservedTokens[i].balanceOf(address(this));

                amount += allReservedTokens[i].balanceOf(ROI);
                amount += allReservedTokens[i].balanceOf(HQ);

                decimals = allReservedTokens[i].decimals();

                if (decimals < 18) {
                    amount = amount * (10 ** (18 - decimals));
                }

                totalReserves += amount;
            }
        }

        return totalReserves;
    }

    // rate is in 18 decimals
    function getRate() public view returns (uint256) {
        uint256 reserveIn = getReserves(); // amount of backed tokens
        uint256 reserveOut = (initialSupply - stabl3.balanceOf(address(this))) * (10 ** (18 - stabl3.decimals())); // amount of stabl3

        uint256 rate;
        if (reserveIn == 0) {
            rate = initialRate;
        }
        else {
            rate = (reserveIn * (10 ** 18)) / reserveOut;
        }

        return rate;
    }

    // rate and both the arguments are in 18 decimals
    function getRateImpact(uint256 _amountStabl3Converted, uint256 _amountTokenConverted) public view returns (uint256) {
        uint256 reserveIn = getReserves(); // amount of backed tokens
        uint256 reserveOut = (initialSupply - stabl3.balanceOf(address(this))) * (10 ** (18 - stabl3.decimals())); // amount of stabl3

        uint256 rate = ((reserveIn + _amountTokenConverted) * (10 ** 18)) / (reserveOut + _amountStabl3Converted);

        return rate;
    }

    function getAmountOut(IERC20 _token, uint256 _amountToken) external view returns (uint256) {
        require(isReservedToken[_token], "Treasury: Token not reserved");
        require(_amountToken > 0, "Treasury: Insufficient input amount");

        _amountToken *= 10 ** (18 - _token.decimals());

        uint256 rate = getRate();

        uint256 amountStabl3 = (_amountToken * (10 ** 18)) / rate;

        rate = getRateImpact(amountStabl3, _amountToken);

        amountStabl3 = (_amountToken * (10 ** 18)) / rate;

        amountStabl3 /= 10 ** (18 - stabl3.decimals());

        return amountStabl3;
    }

    function getAmountIn(uint256 _amountStabl3, IERC20 _token) external view returns (uint256) {
        require(_amountStabl3 > 0, "Treasury: Insufficient input amount");

        _amountStabl3 *= 10 ** (18 - stabl3.decimals());

        uint256 rate = getRate();

        uint256 amountToken = (_amountStabl3 * rate) / 10 ** 18;

        rate = getRateImpact(_amountStabl3, amountToken);

        amountToken = (_amountStabl3 * rate) / 10 ** 18;

        amountToken /= 10 ** (18 - _token.decimals());

        return amountToken;
    }

    function updatePool(uint8 _type, IERC20 _token, uint256 _amountTokenTreasury, uint256 _amountTokenROI, uint256 _amountTokenHQ, bool isIncrease) external lock permission {
        if (isIncrease) {
            getTreasuryPool[_type][_token] += _amountTokenTreasury;
            getROIPool[_type][_token] += _amountTokenROI;
            getHQPool[_type][_token] += _amountTokenHQ;
        }
        else {
            getTreasuryPool[_type][_token] -= _amountTokenTreasury;
            getROIPool[_type][_token] -= _amountTokenROI;
            getHQPool[_type][_token] -= _amountTokenHQ;
        }
    }

    function updateRate() public lock permission {
        uint256 rate = getRate();

        uint256 reserves = getReserves();

        emit Rate(rate, reserves, block.timestamp);
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
        SafeERC20.safeTransfer(_token, owner(), _amountToken);
    }

    function withdrawAllFunds(IERC20 _token) external onlyOwner {
        SafeERC20.safeTransfer(_token, owner(), _token.balanceOf(address(this)));
    }

    // modifiers

    modifier lock() {
        require(unlocked == 1, "Treasury: Locked");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier permission() {
        require(permitted[msg.sender] || msg.sender == owner(), "Treasury: Not permitted");
        _;
    }
}