// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.16;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";

contract Treasury is Ownable {
    using SafeMathUpgradeable for uint256;

    uint256 immutable MAX_INT = 2 ** 256 - 1;

    address public ROI;
    address public HQ;

    IERC20 public stabl3;
    uint256 public decimalsStabl3;

    uint256 public initialRate;
    uint256 public initialLiquidity;

    uint private unlocked = 1;

    // mappings

    // contracts with permission to access treasury funds
    mapping (address => bool) public permitted;

    // reserved tokens to buy STABL3
    mapping (IERC20 => bool) reservedToken;

    // decimals of reserved token
    mapping (IERC20 => uint256) decimalsReservedToken;

    // array for reserved tokens
    IERC20[] public allReservedTokens;

    // events

    event UpdatedPermission(address contractAddress, bool state);

    event UpdatedReservedToken(IERC20 token, uint256 decimals, bool state);

    event Rate(uint256 rate, uint256 blockTimestampLast);

    // constructor

    constructor() {
        ROI = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        stabl3 = IERC20(0x20A91B0d2A5545BF05bcA96778e138E2E154e083);
        decimalsStabl3 = stabl3.decimals();

        initialRate = 0.0007 * (10 ** 18);

        IERC20 _USDC = IERC20(0x8Af5a6599BD2406C44588FCf84FD6Eb1bB2e0243);
        IERC20 _DAI = IERC20(0xA83a21816ae63D3315c540396f887F53cfF274fA);

        updateReservedToken(_USDC, 6, true);
        updateReservedToken(_DAI, 18, true);
    }

    function provideInitialLiquidity(uint256 _amountStabl3) external onlyOwner {
        require(stabl3.balanceOf(address(this)) == 0, "Treasury: Liquidty already set");
        require(_amountStabl3 > 0, "Treasury: Insufficient amount");

        stabl3.transferFrom(owner(), address(this), _amountStabl3);

        initialLiquidity = _amountStabl3.mul(10 ** (18 - decimalsStabl3)).mul(initialRate).div(10 ** 18);

        update();
    }

    function updatePermission(address _contractAddress, bool _state) external onlyOwner {
        require(permitted[_contractAddress] != _state, "Treasury: Contract is already of the value 'state'");
        permitted[_contractAddress] = _state;

        if (_state) {
            approveTreasury(stabl3, _contractAddress, true);

            for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
                approveTreasury(allReservedTokens[i], _contractAddress, true);
            }
        }
        else {
            approveTreasury(stabl3, _contractAddress, false);

            for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
                approveTreasury(allReservedTokens[i], _contractAddress, false);
            }
        }

        emit UpdatedPermission(_contractAddress, _state);
    }

    function isReservedToken(IERC20 _token) public view returns (bool) {
        return reservedToken[_token];
    }

    function updateReservedToken(IERC20 _token, uint256 _decimals, bool _state) public onlyOwner {
        require(reservedToken[_token] != _state, "Treasury: Reserved token is already of the value 'state'");
        reservedToken[_token] = _state;
        decimalsReservedToken[_token] = _decimals;
        allReservedTokens.push(_token);
        emit UpdatedReservedToken(_token, _decimals, _state);
    }

    function getDecimalsReservedToken(IERC20 _token) public view returns (uint256) {
        return decimalsReservedToken[_token];
    }

    function allReservedTokensLength() external view returns (uint256) {
        return allReservedTokens.length;
    }

    function _getReserves() internal view returns (uint256 totalReserves) {
        uint256 decimals;
        uint256 amount;
        for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
            if (reservedToken[allReservedTokens[i]]) {
                amount = allReservedTokens[i].balanceOf(address(this));

                amount += allReservedTokens[i].balanceOf(ROI);
                amount += allReservedTokens[i].balanceOf(HQ);

                decimals = decimalsReservedToken[allReservedTokens[i]];

                if (decimals < 18) {
                    amount = amount * (10 ** (18 - decimals));
                }

                totalReserves += amount;
            }
        }

        totalReserves += initialLiquidity;
    }

    // rate is in 18 decimals
    function getRate() public view returns (uint256) {
        uint256 reserveIn = _getReserves(); // amount of backed tokens
        uint256 reserveOut = stabl3.balanceOf(address(this)) * (10 ** (18 - decimalsStabl3)); // amount of stabl3

        require(reserveIn > 0 && reserveOut > 0, "Treasury: Insufficient reserves");

        uint256 rate = (reserveIn * (10 ** 18)) / reserveOut;

        return rate;
    }

    function getAmountOut(IERC20 _token, uint256 _amountToken) external view returns (uint256) {
        require(reservedToken[_token], "Treasury: Token not reserved");
        require(_amountToken > 0, "Treasury: Insufficient input amount");

        _amountToken *= 10 ** (18 - decimalsReservedToken[_token]);

        uint256 rate = getRate();

        uint256 amountStabl3 = (_amountToken * (10 ** 18)) / rate;

        amountStabl3 /= 10 ** (18 - decimalsStabl3);

        return amountStabl3;
    }

    function getAmountIn(uint256 _amountStabl3, IERC20 _token) external view returns (uint256) {
        require(_amountStabl3 > 0, "Treasury: Insufficient input amount");

        _amountStabl3 *= 10 ** (18 - decimalsStabl3);

        uint256 rate = getRate();

        uint256 amountToken = (_amountStabl3 * rate) / 10 ** 18;

        amountToken /= 10 ** (18 - decimalsReservedToken[_token]);

        return amountToken;
    }

    function update() public lock permission {
        uint256 rate = getRate();

        emit Rate(rate, block.timestamp);
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