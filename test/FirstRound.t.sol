// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "../lib/forge-std/src/Test.sol";

import "./utils/Constants.sol";

import "../contracts/ROI.sol";
import "../contracts/Stabl3Borrowing.sol";
import "../contracts/Stabl3PublicSale.sol";
import "../contracts/Stabl3Staking.sol";
import "../contracts/Treasury.sol";

contract FirstRoundTest is Test, Constants {

    uint256 numInvestments;

    Treasury treasury;
    ROI roi;
    address hq = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

    Stabl3PublicSale publicSale;
    Stabl3Staking staking;
    Stabl3Borrowing borrowing;

    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(0x8954AfA98594b838bda56FE4C12a09D7739D179b);
    IUniswapV2Factory uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());

    IERC20 stabl3 = IERC20(0xc3Bf0c0172E3638d383361801e9BF63B4FfE0d6e);
    IUCD ucd = IUCD(0x78Ef94529fC06F08756a43f6Bdfe61395C0e1428);

    IERC20 usdc = IERC20(0x16c1038a989E7c52c7B0FBDE889249C02d7e205D);
    IERC20 dai = IERC20(0x63720e1a9E780865B9FbDb148c25AEa0B59170F1);

    /// @dev Invoked before each test.
    function setUp() public {
        vm.deal(address(this), 1_000_000_000 * 1e18);
        numInvestments = 5;

        treasury = new Treasury();
        address treasuryAddress = address(treasury);
        ITreasury treasuryInterface = ITreasury(treasuryAddress);
        roi = new ROI(treasuryInterface);
        publicSale = new Stabl3PublicSale(address(treasury), address(roi));
        staking = new Stabl3Staking(address(treasury), address(roi));
        borrowing = new Stabl3Borrowing(address(treasury), address(roi));

        treasury.updateROI(address(roi));
        treasury.updatePermission(address(publicSale), true);
        treasury.updatePermission(address(staking), true);
        treasury.updatePermission(address(borrowing), true);
        roi.updateStabl3Staking(address(staking));
        roi.updatePermission(address(publicSale), true);
        roi.updatePermission(address(borrowing), true);
        publicSale.updateState(true);
        staking.updateState(true);
        borrowing.updateState(true);

        // Pranking at dev address.
        vm.startPrank(0x45faf7923BAb5A5380515E055CA700519B3e4705);

        stabl3.transfer(address(treasury), stabl3.balanceOf(0x45faf7923BAb5A5380515E055CA700519B3e4705));
        ucd.updatePermission(address(borrowing), true);

        usdc.transfer(address(this), usdc.balanceOf(0x45faf7923BAb5A5380515E055CA700519B3e4705));
        dai.transfer(address(this), dai.balanceOf(0x45faf7923BAb5A5380515E055CA700519B3e4705));

        // Stopping prank.
        vm.stopPrank();
    }

    // function test_Invest() external {
    //     dai.approve(address(publicSale), type(uint256).max);

    //     for (uint256 i = 0 ; i < numInvestments ; i++) {
    //         publicSale.buy(dai, investments[i]);

    //         console.log("-----", i + 1, "-----");
    //         console.log("Price              :", treasury.getRate());
    //         console.log("Circulating Supply :", treasury.stabl3CirculatingSupply());
    //         console.log("Total Value Locked :", treasury.getTotalValueLocked());
    //         console.log("Market Cap         :", treasury.getMarketCap());
    //         i + 1 < 10 ?
    //             console.log("-------------") :
    //             i + 1 < 100 ?
    //                 console.log("--------------") :
    //                 console.log("---------------");
    //     }
    // }

    function test_Invest_Borrow() external {
        dai.approve(address(publicSale), type(uint256).max);
        stabl3.approve(address(borrowing), type(uint256).max);

        for (uint256 i = 0 ; i < numInvestments ; i++) {
            publicSale.buy(dai, investments[i]);
            // Only considering the part of the investment that does not go into the HQ wallet.
            uint256 borrowUCD = investments[i] / 1e12;
            // The given amount of Dollars is reduced with respect to the price and the amount of Stabl3 taken is kept the same.
            // Hence causing a deterministic reduction of amount being paid back to the user.
            uint256 borrowStabl3 = treasury.getBorrowingAmount(borrowUCD);
            uint256 balanceUCDBefore = ucd.balanceOf(address(this));
            borrowing.borrow(borrowUCD);
            uint256 balanceUCDAfter = ucd.balanceOf(address(this));

            console.log("-----", i + 1, "-----");
            console.log("UCD borrow   :", borrowUCD);
            console.log("UCD received :", balanceUCDAfter - balanceUCDBefore);
            console.log("Stabl3 used  :", borrowStabl3);
            assertLt(balanceUCDAfter - balanceUCDBefore, borrowUCD);
            i + 1 < 10 ?
                console.log("-------------") :
                i + 1 < 100 ?
                    console.log("--------------") :
                    console.log("---------------");
        }
    }

    function test_Invest_Borrow_Twice() external {
        dai.approve(address(publicSale), type(uint256).max);
        stabl3.approve(address(borrowing), type(uint256).max);

        for (uint256 i = 0 ; i < numInvestments ; i++) {
            publicSale.buy(dai, investments[i]);
            // Only considering the part of the investment that does not go into the HQ wallet.
            uint256 borrowUCD = investments[i] / 1e12;
            uint256 borrowUCDHalf = borrowUCD / 2;
            // The given amount of Dollars is reduced with respect to the price and the amount of Stabl3 taken is kept the same.
            // Hence causing a deterministic reduction of amount being paid back to the user.
            uint256 balanceUCDBefore = ucd.balanceOf(address(this));
            uint256 borrowStabl3 = treasury.getBorrowingAmount(borrowUCD);
            borrowing.borrow(borrowUCDHalf);
            borrowStabl3 += treasury.getBorrowingAmount(borrowUCD);
            borrowing.borrow(borrowUCDHalf);
            uint256 balanceUCDAfter = ucd.balanceOf(address(this));

            console.log("-----", i + 1, "-----");
            console.log("UCD borrow   :", borrowUCD);
            console.log("UCD received :", balanceUCDAfter - balanceUCDBefore);
            console.log("Stabl3 used  :", borrowStabl3);
            assertLt(balanceUCDAfter - balanceUCDBefore, borrowUCD);
            i + 1 < 10 ?
                console.log("-------------") :
                i + 1 < 100 ?
                    console.log("--------------") :
                    console.log("---------------");
        }
    }

    // function test_Invest_Borrow_Payback() external {
    //     dai.approve(address(publicSale), type(uint256).max);
    //     stabl3.approve(address(borrowing), type(uint256).max);

    //     for (uint256 i = 0 ; i < numInvestments ; i++) {
    //         publicSale.buy(dai, investments[i]);
    //         // Only considering the part of the investment that does not go into the HQ wallet.
    //         uint256 borrowUCD = investments[i] / 1e12;
    //         // The given amount of Dollars is reduced with respect to the price and the amount of Stabl3 taken is kept the same.
    //         // Hence causing a deterministic reduction of amount being paid back to the user.
    //         uint256 balanceUCDBefore = ucd.balanceOf(address(this));
    //         borrowing.borrow(borrowUCD);
    //         uint256 balanceUCDAfter = ucd.balanceOf(address(this));
    //         borrowing.payback(balanceUCDAfter - balanceUCDBefore);

    //         console.log("-----", i + 1, "-----");
    //         console.log("Price              :", treasury.getRate());
    //         console.log("Circulating Supply :", treasury.stabl3CirculatingSupply());
    //         console.log("Total Value Locked :", treasury.getTotalValueLocked());
    //         console.log("Market Cap         :", treasury.getMarketCap());
    //         console.log("Donation Stabl3    :", stabl3.balanceOf(address(borrowing.donationWallet())));
    //         assertEq(treasury.getRate(), prices[i]);
    //         assertLt(treasury.stabl3CirculatingSupply(), cs[i]);
    //         assertEq(treasury.getTotalValueLocked(), tvl[i]);
    //         assertEq(treasury.getMarketCap(), mc[i]);
    //         assertEq(stabl3.balanceOf(address(borrowing.donationWallet())), 0);
    //         i + 1 < 10 ?
    //             console.log("-------------") :
    //             i + 1 < 100 ?
    //                 console.log("--------------") :
    //                 console.log("---------------");
    //     }
    // }

    // function test_Invest_Borrow_ExchangeUCD() external {
    //     dai.approve(address(publicSale), type(uint256).max);
    //     stabl3.approve(address(borrowing), type(uint256).max);

    //     for (uint256 i = 0 ; i < numInvestments ; i++) {
    //         publicSale.buy(dai, investments[i]);
    //         // Only considering the part of the investment that does not go into the HQ wallet.
    //         uint256 borrowUCD = investments[i] / 1e12;
    //         // The given amount of Dollars is reduced with respect to the price and the amount of Stabl3 taken is kept the same.
    //         // Hence causing a deterministic reduction of amount being paid back to the user.
    //         uint256 balanceUCDBefore = ucd.balanceOf(address(this));
    //         borrowing.borrow(borrowUCD);
    //         uint256 balanceUCDAfter = ucd.balanceOf(address(this));
    //         borrowing.exchangeUCD(dai, balanceUCDAfter - balanceUCDBefore);

    //         console.log("-----", i + 1, "-----");
    //         console.log("Price              :", treasury.getRate());
    //         console.log("Circulating Supply :", treasury.stabl3CirculatingSupply());
    //         console.log("Total Value Locked :", treasury.getTotalValueLocked());
    //         console.log("Market Cap         :", treasury.getMarketCap());
    //         console.log("Donation Stabl3    :", stabl3.balanceOf(address(borrowing.donationWallet())));
    //         assertEq(treasury.getRate(), prices[i]);
    //         assertLt(treasury.stabl3CirculatingSupply(), cs[i]);
    //         assertLe(treasury.getTotalValueLocked(), tvl[i]);
    //         assertLe(treasury.getMarketCap(), mc[i]);
    //         assertEq(stabl3.balanceOf(address(borrowing.donationWallet())), 0);
    //         i + 1 < 10 ?
    //             console.log("-------------") :
    //             i + 1 < 100 ?
    //                 console.log("--------------") :
    //                 console.log("---------------");
    //     }
    // }

    // function test_Invest_Borrow_ExchangeUCD_Twice() external {
    //     dai.approve(address(publicSale), type(uint256).max);
    //     stabl3.approve(address(borrowing), type(uint256).max);

    //     for (uint256 i = 0 ; i < numInvestments ; i++) {
    //         publicSale.buy(dai, investments[i]);
    //         // Only considering the part of the investment that does not go into the HQ wallet.
    //         uint256 borrowUCD = investments[i] / 1e12;
    //         uint256 borrowUCDHalf = borrowUCD / 2;
    //         // The given amount of Dollars is reduced with respect to the price and the amount of Stabl3 taken is kept the same.
    //         // Hence causing a deterministic reduction of amount being paid back to the user.
    //         uint256 balanceUCDBefore = ucd.balanceOf(address(this));
    //         uint256 borrowStabl3 = treasury.getBorrowingAmount(borrowUCD);
    //         borrowing.borrow(borrowUCDHalf);
    //         borrowStabl3 += treasury.getBorrowingAmount(borrowUCD);
    //         borrowing.borrow(borrowUCDHalf);
    //         uint256 balanceUCDAfter = ucd.balanceOf(address(this));
    //         borrowing.exchangeUCD(dai, balanceUCDAfter - balanceUCDBefore);

    //         console.log("-----", i + 1, "-----");
    //         console.log("Price              :", treasury.getRate());
    //         console.log("Circulating Supply :", treasury.stabl3CirculatingSupply());
    //         console.log("Total Value Locked :", treasury.getTotalValueLocked());
    //         console.log("Market Cap         :", treasury.getMarketCap());
    //         console.log("Donation Stabl3    :", stabl3.balanceOf(address(borrowing.donationWallet())));
    //         assertEq(treasury.getRate(), prices[i]);
    //         assertLt(treasury.stabl3CirculatingSupply(), cs[i]);
    //         assertLe(treasury.getTotalValueLocked(), tvl[i]);
    //         assertLe(treasury.getMarketCap(), mc[i]);
    //         assertEq(stabl3.balanceOf(address(borrowing.donationWallet())), 0);
    //         i + 1 < 10 ?
    //             console.log("-------------") :
    //             i + 1 < 100 ?
    //                 console.log("--------------") :
    //                 console.log("---------------");
    //     }
    // }
}