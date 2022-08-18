// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.16;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";

contract Treasury is Ownable {
    using SafeMathUpgradeable for uint256;

    uint256 immutable MAX_INT = 2 ** 256 - 1;

    IERC20 public stabl3;
    uint256 public decimalsStabl3;

    uint256 initialRate;
    uint256 initialLiquidity;

    uint256 private blockTimestampLast;

    uint private unlocked = 1;

    // mappings

    // contracts with permission to access treasury funds
    mapping (address => bool) public permitted;

    // reserved tokens to buy STABL3
    mapping (IERC20 => bool) reservedToken;

    // decimals of reserved token
    mapping (IERC20 => uint256) decimalsReservedToken;

    // array for reserved tokens
    IERC20[] allReservedTokens;

    // events

    event UpdatedPermission(address contractAddress, bool state);

    event UpdatedReservedToken(IERC20 token, uint256 decimals, bool state);

    event Rate(uint256 rate, uint256 reserveIn, uint256 reserveOut, uint256 blockTimestampLast);

    // constructor

    constructor() {
        stabl3 = IERC20(0x20A91B0d2A5545BF05bcA96778e138E2E154e083);
        decimalsStabl3 = stabl3.decimals();

        initialRate = 0.0007 * (10 ** 18);

        IERC20 _USDC = IERC20(0x8Af5a6599BD2406C44588FCf84FD6Eb1bB2e0243);
        IERC20 _DAI = IERC20(0xA83a21816ae63D3315c540396f887F53cfF274fA);

        updateReservedToken(_USDC, 6, true);
        updateReservedToken(_DAI, 18, true);
    }

    function provideInitialLiquidity(uint256 _amountStabl3) external onlyOwner {
        require(initialLiquidity == 0, "Treasury: Liquidty already set");
        require(_amountStabl3 > 0, "Treasury: Insufficient amount");

        stabl3.transferFrom(owner(), address(this), _amountStabl3);

        initialLiquidity = _amountStabl3.mul(10 ** (18 - decimalsStabl3)).mul(initialRate).div(10 ** 18);

        update();
    }

    function updatePermission(address contractAddress, bool state) external onlyOwner {
        require(permitted[contractAddress] != state, "Treasury: Contract is already of the value 'state'");
        permitted[contractAddress] = state;

        if (state) {
            approveTreasury(stabl3, contractAddress, true);

            for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
                approveTreasury(allReservedTokens[i], contractAddress, true);
            }
        }
        else {
            approveTreasury(stabl3, contractAddress, false);

            for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
                approveTreasury(allReservedTokens[i], contractAddress, false);
            }
        }

        emit UpdatedPermission(contractAddress, state);
    }

    function isReservedToken(IERC20 token) public view returns (bool) {
        return reservedToken[token];
    }

    function updateReservedToken(IERC20 token, uint256 decimals, bool state) public onlyOwner {
        require(reservedToken[token] != state, "Treasury: Reserved token is already of the value 'state'");
        reservedToken[token] = state;
        decimalsReservedToken[token] = decimals;
        allReservedTokens.push(token);
        emit UpdatedReservedToken(token, decimals, state);
    }

    function getDecimalsReservedToken(IERC20 token) public view returns (uint256) {
        return decimalsReservedToken[token];
    }

    function _getReserves() internal view returns (uint256 totalReserves) {
        uint256 decimals;
        uint256 amount;
        for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
            if (reservedToken[allReservedTokens[i]]) {
                amount = allReservedTokens[i].balanceOf(address(this));

                decimals = decimalsReservedToken[allReservedTokens[i]];
                if (decimals < 18) {
                    amount = amount * (10 ** (18 - decimals));
                }

                totalReserves += amount;
            }
        }

        totalReserves += initialLiquidity;
    }

    function getAmountOut(IERC20 _token, uint256 _amountToken) external view returns (uint256) {
        require(reservedToken[_token], "Treasury: Token not reserved");
        require(_amountToken > 0, "Treasury: Insufficient input amount");

        _amountToken *= 10 ** (18 - decimalsReservedToken[_token]);
        uint256 reserveIn = _getReserves(); // amount of backed tokens
        uint256 reserveOut = stabl3.balanceOf(address(this)) * (10 ** (18 - decimalsStabl3)); // amount of stabl3

        require(reserveIn > 0 && reserveOut > 0, "Treasury: Insufficient reserves");

        uint numerator = _amountToken.mul(reserveOut);
        uint denominator = reserveIn.add(_amountToken);
        uint256 amountOut = numerator / denominator;

        amountOut /= 10 ** (18 - decimalsStabl3);

        return amountOut;
    }

    function update() public permission lock {
        uint256 reserveIn = _getReserves(); // amount of backed tokens
        uint256 reserveOut = stabl3.balanceOf(address(this)) * (10 ** (18 - decimalsStabl3)); // amount of stabl3

        require(reserveIn > 0 && reserveOut > 0, "Treasury: Insufficient reserves");

        uint256 rate = reserveIn / reserveOut;

        blockTimestampLast = block.timestamp;

        emit Rate(rate, reserveIn, reserveOut, blockTimestampLast);
    }

    function approveTreasury(IERC20 token, address spender, bool isApprove) public onlyOwner {
        if (isApprove) {
            SafeERC20.safeApprove(token, spender, MAX_INT);
        }
        else {
            SafeERC20.safeApprove(token, spender, 0);
        }
    }

    function withdrawFunds(IERC20 token, uint256 amountToken) external onlyOwner {
        SafeERC20.safeTransfer(token, owner(), amountToken);
    }

    function withdrawAllFunds(IERC20 token) external onlyOwner {
        SafeERC20.safeTransfer(token, owner(), token.balanceOf(address(this)));
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