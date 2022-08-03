// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.15;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./MathUpgradeable.sol";

contract BuyAndBond is Ownable {
    using SafeMath for uint256;
    using MathUpgradeable for uint256;
    using SafeERC20 for IERC20;

    address public treasuryWallet;
    address public ROIWallet;
    address public HQWallet;

    uint256[] public treasuryPercentages;
    uint256[] public ROIPercentages;
    uint256[] public HQPercentages;

    IERC20 usdc = IERC20(0x8Af5a6599BD2406C44588FCf84FD6Eb1bB2e0243);
    IERC20 dai = IERC20(0xA83a21816ae63D3315c540396f887F53cfF274fA);

    IERC20 stabl3 = IERC20(0x20A91B0d2A5545BF05bcA96778e138E2E154e083);

    uint256 discount;
    uint256 bondTime;

    bool saleState;

    // structs

    struct Bond {
        uint256 index;
        address recipient;
        bool status;
        uint256 amountStabl3;
        IERC20 token;
        uint256 amountToken;
        uint256 startTime;
    }

    // mappings

    // ongoing bonds
    mapping(address => Bond[]) public getBonds;

    // supported tokens to buy STABL3
    mapping(IERC20 => bool) public getSupportedTokens;

    // events

    event Buy(address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event CreatedBond(uint256 index, address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event ClaimedBond(uint256 index, address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event UpdatedDiscount(uint256 newAmount, uint256 oldAmount);

    event AddedSupportedToken(IERC20 token, bool state);

    constructor() {
        treasuryWallet = 0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80;
        ROIWallet = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;
        HQWallet = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        treasuryPercentages = [800, 800];
        ROIPercentages = [161, 161];
        HQPercentages = [39, 39];

        addSupportedToken(usdc, true);
        addSupportedToken(dai, true);

        discount = 10;
        // bondTime = 30 days;
        bondTime = 1 minutes;
    }

    function updateTreasuryWallet(address _treasuryWallet) external onlyOwner {
        require(treasuryWallet != _treasuryWallet, "STABL33: Treasury wallet is already this address");
        treasuryWallet = _treasuryWallet;
    }

    function updateROIWallet(address _ROIWallet) external onlyOwner {
        require(ROIWallet != _ROIWallet, "STABL33: ROI wallet is already this address");
        ROIWallet = _ROIWallet;
    }

    function updateHQWallet(address _HQWallet) external onlyOwner {
        require(HQWallet != _HQWallet, "STABL33: HQ wallet is already this address");
        HQWallet = _HQWallet;
    }

    function updateSaleState(bool state) external onlyOwner {
        require(saleState != state, "STABL33: Sale state is already of the value 'state'");
        saleState = state;
    }

    function updateDiscount(uint256 _discount) external onlyOwner {
        require(_discount > 0, "STABL33: Discount should be greater than zero");
        emit UpdatedDiscount(_discount, discount);
        discount = _discount;
    }

    function addSupportedToken(IERC20 token, bool state) public onlyOwner {
        require(getSupportedTokens[token] != state, "STABL33: Supported token is already of the value 'state'");
        getSupportedTokens[token] = state;
        emit AddedSupportedToken(token, state);
    }

    function buy(uint256 _amountStabl3, IERC20 _token) external {
        require(getSupportedTokens[_token], "STABL33: Token not supported");
        require(_amountStabl3 > 0, "STABL33: Amount should be greater than zero");

        stabl3.transferFrom(treasuryWallet, msg.sender, _amountStabl3);

        uint256 amountToken = _amountStabl3;

        uint256 amountTreasury = amountToken.mul(treasuryPercentages[0]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, treasuryWallet, amountTreasury);

        uint256 amountROI = amountToken.mul(ROIPercentages[0]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, ROIWallet, amountROI);

        uint256 amountHQ = amountToken.mul(HQPercentages[0]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQWallet, amountHQ);

        emit Buy(msg.sender, _amountStabl3, _token, amountToken);
    }

    function createBond(uint256 _amountStabl3, IERC20 _token) external {
        require(getSupportedTokens[_token], "STABL33: Token not supported");
        require(_amountStabl3 > 0, "STABL33: Amount should be greater than zero");

        uint256 amountToken = _amountStabl3;
        amountToken -= _amountStabl3.mul(discount).div(100);

        Bond memory bond = Bond(getBonds[msg.sender].length, msg.sender, true, _amountStabl3, _token, amountToken, block.timestamp);
        emit CreatedBond(bond.index, bond.recipient, bond.amountStabl3, bond.token, bond.amountToken);
        getBonds[msg.sender].push(bond);

        uint256 amountTreasury = amountToken.mul(treasuryPercentages[1]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, treasuryWallet, amountTreasury);

        uint256 amountROI = amountToken.mul(ROIPercentages[1]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, ROIWallet, amountROI);

        uint256 amountHQ = amountToken.mul(HQPercentages[1]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQWallet, amountHQ);
    }

    function claimBond(uint256 index, IERC20 _token) external {
        Bond storage bond = getBonds[msg.sender][index];

        require(getSupportedTokens[_token], "STABL33: Token not supported");
        require(bond.status, "STABL33: Bond already claimed");
        require(block.timestamp > bond.startTime.add(bondTime), "STABL33: Bond time not finished");

        stabl3.transferFrom(treasuryWallet, msg.sender, bond.amountStabl3);

        bond.status = false;

        emit ClaimedBond(bond.index, bond.recipient, bond.amountStabl3, bond.token, bond.amountToken);
    }
}