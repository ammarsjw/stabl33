// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "../lib/forge-std/src/Test.sol";

import "./utils/Constants.sol";

import "../contracts/Treasury.sol";
import "../contracts/ROI.sol";
import "../contracts/Stabl3PublicSale.sol";
import "../contracts/Stabl3Staking.sol";

contract FirstTest is Test, Constants {

    Treasury treasury;
    ROI roi;
    address hq = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

    Stabl3PublicSale publicSale;
    Stabl3Staking staking;

    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(0x8954AfA98594b838bda56FE4C12a09D7739D179b);
    IUniswapV2Factory uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());

    IERC20 stabl3 = IERC20(0xc3Bf0c0172E3638d383361801e9BF63B4FfE0d6e);
    IERC20 ucd = IERC20(0x78Ef94529fC06F08756a43f6Bdfe61395C0e1428);
    IERC20 usdc = IERC20(0x16c1038a989E7c52c7B0FBDE889249C02d7e205D);
    IERC20 dai = IERC20(0x63720e1a9E780865B9FbDb148c25AEa0B59170F1);

    /// @dev Invoked before each test.
    function setUp() public {
        treasury = new Treasury();
        address treasuryAddress = address(treasury);
        ITreasury treasuryInterface = ITreasury(treasuryAddress);
        roi = new ROI(treasuryInterface);
        publicSale = new Stabl3PublicSale(address(treasury), address(roi));
        staking = new Stabl3Staking(address(treasury), address(roi));

        treasury.updateROI(address(roi));
        treasury.updatePermission(address(publicSale), true);
        treasury.updatePermission(address(staking), true);
        roi.updateStabl3Staking(address(staking));
        roi.updatePermission(address(publicSale), true);
        publicSale.updateState(true);
        staking.updateState(true);

        vm.deal(address(this), 1_000_000_000 * 1e18);

        vm.startPrank(0x45faf7923BAb5A5380515E055CA700519B3e4705);
        stabl3.transfer(address(treasury), stabl3.balanceOf(0x45faf7923BAb5A5380515E055CA700519B3e4705));
        usdc.transfer(address(this), usdc.balanceOf(0x45faf7923BAb5A5380515E055CA700519B3e4705));
        dai.transfer(address(this), dai.balanceOf(0x45faf7923BAb5A5380515E055CA700519B3e4705));
        vm.stopPrank();
    }

    function test_MarketCap() external {
        dai.approve(address(publicSale), type(uint256).max);

        for (uint256 i = 0 ; i < 100 ; i++) {
            publicSale.buy(dai, firstHundredInvestments[i]);

            console.log("-----", i + 1, "-----");
            console.log(
                "Price      :",
                treasury.getRate()
            );
            // console.log(treasury.getReserves());
            // console.log(treasury.getTotalValueLocked());
            console.log(
                "Market Cap :",
                // treasury.getBaseAmountIn(stabl3.balanceOf(address(this))),
                treasury.getBaseAmountIn(treasury.stabl3CirculatingSupply())
            );
            i + 1 < 10 ? console.log("-------------") : i + 1 < 100 ? console.log("--------------") : console.log("---------------");
        }
    }
}