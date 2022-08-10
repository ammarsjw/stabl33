// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.16;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";

contract Stabl33BuyAndBond is Ownable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20 for IERC20;

    address public treasuryWallet;
    address public ROIWallet;
    address public HQWallet;

    uint256[] public treasuryPercentages;
    uint256[] public ROIPercentages;
    uint256[] public HQPercentages;

    IERC20 public usdc = IERC20(0x8Af5a6599BD2406C44588FCf84FD6Eb1bB2e0243);
    IERC20 public dai = IERC20(0xA83a21816ae63D3315c540396f887F53cfF274fA);

    IERC20 public stabl3 = IERC20(0x20A91B0d2A5545BF05bcA96778e138E2E154e083);

    uint256 public discount;

    uint256 public bondTime;

    bool public saleState;

    // structs

    struct Bond {
        uint256 index;
        address recipient;
        bool status;
        uint256 amountStabl3;
        IERC20 token;
        uint256 amountToken;
        uint256 endTime;
    }

    // mappings

    // ongoing bonds
    mapping (address => Bond[]) public getBonds;

    // supported tokens to buy STABL3
    mapping (IERC20 => bool) public getSupportedTokens;

    // total amount of tokens received
    mapping (IERC20 => uint256) totalTokenAmounts;

    // events

    event Buy(address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event CreatedBond(uint256 index, address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event ClaimedBond(uint256 index, address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event UpdatedDiscount(uint256 newAmount, uint256 oldAmount);

    event AddedSupportedToken(IERC20 token, bool state);

    // constructor

    constructor() {
        treasuryWallet = 0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80;
        ROIWallet = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;
        HQWallet = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        treasuryPercentages = [800, 800];
        ROIPercentages = [161, 161];
        HQPercentages = [39, 39];

        addSupportedToken(usdc, true);
        addSupportedToken(dai, true);

        // TODO confirm
        discount = 10;

        // TODO
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

    function getTotalTokenAmounts(IERC20 token) external view returns (uint256) {
        return totalTokenAmounts[token];
    }

    function _processAmount(uint256 _amountStabl3, IERC20 _token) internal view returns (uint256) {
        if (_token.decimals() > 6) {
            uint256 reduceBy = _token.decimals() - stabl3.decimals();
            _amountStabl3 = _amountStabl3.div(reduceBy);
        }
        else if (_token.decimals() < 6) {
            uint256 increaseBy = stabl3.decimals() - _token.decimals();
            _amountStabl3 = _amountStabl3.mul(increaseBy);
        }

        return _amountStabl3;
    }

    function buy(IERC20 _token, uint256 _amountToken) external {
        require(getSupportedTokens[_token], "STABL33: Token not supported");
        require(_amountToken > 0, "STABL33: Amount should be greater than zero");

        // TODO get true rate from treasury
        uint256 rate = 0.0007 * (10 ** 18);

        uint256 amountStabl3 = _amountToken.mul(rate).div(10 ** 18);

        amountStabl3 = _processAmount(amountStabl3, _token);

        totalTokenAmounts[_token] += _amountToken;

        stabl3.transferFrom(treasuryWallet, msg.sender, amountStabl3);

        uint256 amountTreasury = _amountToken.mul(treasuryPercentages[0]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, treasuryWallet, amountTreasury);

        uint256 amountROI = _amountToken.mul(ROIPercentages[0]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, ROIWallet, amountROI);

        uint256 amountHQ = _amountToken.mul(HQPercentages[0]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQWallet, amountHQ);

        emit Buy(msg.sender, amountStabl3, _token, _amountToken);
    }

    function createBond(IERC20 _token, uint256 _amountToken) external {
        require(getSupportedTokens[_token], "STABL33: Token not supported");
        require(_amountToken > 0, "STABL33: Amount should be greater than zero");

        // TODO get true rate from treasury
        uint256 rate = 0.0007 * (10 ** 18);

        uint256 amountStabl3 = _amountToken.mul(rate).div(10 ** 18);

        amountStabl3 = _processAmount(amountStabl3, _token);

        amountStabl3 += amountStabl3.mul(discount).div(100);

        totalTokenAmounts[_token] += _amountToken;

        Bond memory bond = Bond(getBonds[msg.sender].length, msg.sender, true, amountStabl3, _token, _amountToken, block.timestamp + bondTime);
        emit CreatedBond(bond.index, bond.recipient, bond.amountStabl3, bond.token, bond.amountToken);
        getBonds[msg.sender].push(bond);

        uint256 amountTreasury = _amountToken.mul(treasuryPercentages[1]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, treasuryWallet, amountTreasury);

        uint256 amountROI = _amountToken.mul(ROIPercentages[1]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, ROIWallet, amountROI);

        uint256 amountHQ = _amountToken.mul(HQPercentages[1]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQWallet, amountHQ);
    }

    function claimBond(uint256 index) external {
        Bond storage bond = getBonds[msg.sender][index];

        require(bond.status, "STABL33: Bond already claimed");
        require(block.timestamp > bond.endTime, "STABL33: Bond time not finished");

        stabl3.transferFrom(treasuryWallet, msg.sender, bond.amountStabl3);

        bond.status = false;

        emit ClaimedBond(bond.index, bond.recipient, bond.amountStabl3, bond.token, bond.amountToken);
    }
}