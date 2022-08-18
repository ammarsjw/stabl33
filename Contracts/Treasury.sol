// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.16;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";

contract Treasury is Ownable {
    using SafeMathUpgradeable for uint256;

    address public publicSale;

    IERC20 public USDC = IERC20(0x8Af5a6599BD2406C44588FCf84FD6Eb1bB2e0243);
    IERC20 public DAI = IERC20(0xA83a21816ae63D3315c540396f887F53cfF274fA);

    IERC20 public stabl3 = IERC20(0x20A91B0d2A5545BF05bcA96778e138E2E154e083);
    uint256 public decimalsStabl3 = 6;

    // uint256 initialLiquidity = 70000000 * (10 ** 18);
    uint256 initialLiquidity = 700000 * (10 ** 18);

    uint256 public buyFee;

    uint256 immutable MAX_INT = 2 ** 256 - 1;

    // mappings

    // reserved tokens to buy STABL3
    mapping (IERC20 => bool) reservedToken;

    // decimals of reserved token
    mapping (IERC20 => uint256) decimalsReservedToken;

    // array for reserved tokens
    IERC20[] allReservedTokens;

    // events

    event UpdatedBuyFee(uint256 newBuyFee, uint256 oldBuyFee);

    event UpdatedReservedToken(IERC20 token, uint256 decimals, bool state);

    // constructor

    constructor() {
        updateReservedToken(USDC, 6, true);
        updateReservedToken(DAI, 18, true);

        buyFee = 20;
    }

    function updatePublicSale(address _publicSale) external onlyOwner {
        require(publicSale != _publicSale, "Treasury: PublicSale is already this address");
        publicSale = _publicSale;

        approveUsage(_publicSale, stabl3);

        for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
            approveUsage(_publicSale, allReservedTokens[i]);
        }
    }

    function updateBuyFee(uint256 _buyFee) external onlyOwner {
        emit UpdatedBuyFee(_buyFee, buyFee);
        buyFee = _buyFee;
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

    function getAmountOut(IERC20 _token, uint256 _amountToken) external view returns (uint256, uint256) {
        require(reservedToken[_token], "Treasury: Token not reserved");
        require(_amountToken > 0, "Treasury: Insufficient input amount");

        _amountToken *= 10 ** (18 - decimalsReservedToken[_token]);
        uint256 reserveIn = _getReserves(); // amount of backed tokens
        uint256 reserveOut = stabl3.balanceOf(address(this)) * (10 ** (18 - decimalsStabl3)); // amount of stabl3

        require(reserveIn > 0 && reserveOut > 0, "Treasury: Insufficient reserves");

        uint256 fee = _amountToken.mul(buyFee).div(1000);

        uint amountInWithFee = _amountToken.mul(1000 - buyFee);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        uint256 amountOut = numerator / denominator ;

        amountOut /= 10 ** (18 - decimalsStabl3);

        fee /= 10 ** (18 - decimalsReservedToken[_token]);

        return (amountOut, fee);
    }

    function approveUsage(address spender, IERC20 token) public onlyOwner {
        SafeERC20.safeApprove(token, spender, MAX_INT);
    }

    // TODO testing only
    function testWithdraw(IERC20 _token) external {
        SafeERC20.safeTransfer(_token, msg.sender, _token.balanceOf(address(this)));
    }
}