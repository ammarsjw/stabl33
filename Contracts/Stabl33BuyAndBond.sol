// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.16;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";

contract Stabl33BuyAndBond is Ownable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20 for IERC20;

    address public treasury;
    address public ROI;
    address public HQ;

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

    // reserved tokens to buy STABL3
    mapping (IERC20 => bool) public getReservedTokens;

    // array for reserved tokens
    IERC20[] public allReservedTokens;

    // total amount of tokens received
    mapping (IERC20 => uint256) tokenReceivedAmounts;

    // events

    event Buy(address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event CreatedBond(uint256 index, address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event ClaimedBond(uint256 index, address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event UpdatedDiscount(uint256 newAmount, uint256 oldAmount);

    event UpdatedReservedToken(IERC20 token, bool state);

    // constructor

    constructor() {
        treasury = 0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80;
        ROI = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        treasuryPercentages = [800, 800];
        ROIPercentages = [161, 161];
        HQPercentages = [39, 39];

        updateReservedToken(usdc, true);
        updateReservedToken(dai, true);

        // TODO confirm
        discount = 10;

        // TODO
        // bondTime = 30 days;
        bondTime = 1 minutes;
    }

    function updateTreasury(address _treasury) external onlyOwner {
        require(treasury != _treasury, "STABL33: Treasury is already this address");
        treasury = _treasury;
    }

    function updateROI(address _ROI) external onlyOwner {
        require(ROI != _ROI, "STABL33: ROI is already this address");
        ROI = _ROI;
    }

    function updateHQ(address _HQ) external onlyOwner {
        require(HQ != _HQ, "STABL33: HQ is already this address");
        HQ = _HQ;
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

    function updateReservedToken(IERC20 token, bool state) public onlyOwner {
        require(getReservedTokens[token] != state, "STABL33: Reserved token is already of the value 'state'");
        getReservedTokens[token] = state;
        allReservedTokens.push(token);
        emit UpdatedReservedToken(token, state);
    }

    function gettokenReceivedAmounts(IERC20 token) external view returns (uint256) {
        return tokenReceivedAmounts[token];
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
        require(getReservedTokens[_token], "STABL33: Token not reserved");
        require(_amountToken > 0, "STABL33: Amount should be greater than zero");

        // TODO get true rate from treasury
        uint256 rate = 0.0007 * (10 ** 18);

        uint256 amountStabl3 = _amountToken.mul(rate).div(10 ** 18);

        amountStabl3 = _processAmount(amountStabl3, _token);

        tokenReceivedAmounts[_token] += _amountToken;

        stabl3.transferFrom(treasury, msg.sender, amountStabl3);

        uint256 amountTreasury = _amountToken.mul(treasuryPercentages[0]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, treasury, amountTreasury);

        uint256 amountROI = _amountToken.mul(ROIPercentages[0]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, ROI, amountROI);

        uint256 amountHQ = _amountToken.mul(HQPercentages[0]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);

        emit Buy(msg.sender, amountStabl3, _token, _amountToken);
    }

    function createBond(IERC20 _token, uint256 _amountToken) external {
        require(getReservedTokens[_token], "STABL33: Token not reserved");
        require(_amountToken > 0, "STABL33: Amount should be greater than zero");

        // TODO get true rate from treasury
        uint256 rate = 0.0007 * (10 ** 18);

        uint256 amountStabl3 = _amountToken.mul(rate).div(10 ** 18);

        amountStabl3 = _processAmount(amountStabl3, _token);

        amountStabl3 += amountStabl3.mul(discount).div(100);

        tokenReceivedAmounts[_token] += _amountToken;

        Bond memory bond = Bond(getBonds[msg.sender].length, msg.sender, true, amountStabl3, _token, _amountToken, block.timestamp + bondTime);
        emit CreatedBond(bond.index, bond.recipient, bond.amountStabl3, bond.token, bond.amountToken);
        getBonds[msg.sender].push(bond);

        uint256 amountTreasury = _amountToken.mul(treasuryPercentages[1]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, treasury, amountTreasury);

        uint256 amountROI = _amountToken.mul(ROIPercentages[1]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, ROI, amountROI);

        uint256 amountHQ = _amountToken.mul(HQPercentages[1]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);
    }

    function claimBond(uint256 index) external {
        Bond storage bond = getBonds[msg.sender][index];

        require(bond.status, "STABL33: Bond already claimed");
        require(block.timestamp > bond.endTime, "STABL33: Bond time not finished");

        stabl3.transferFrom(treasury, msg.sender, bond.amountStabl3);

        bond.status = false;

        emit ClaimedBond(bond.index, bond.recipient, bond.amountStabl3, bond.token, bond.amountToken);
    }
}