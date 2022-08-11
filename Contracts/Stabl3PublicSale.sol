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

    uint256 public initialRate;

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
    mapping (IERC20 => bool) public isReservedToken;

    // decimals of reserved token
    mapping (IERC20 => uint256) public decimalsReservedToken;

    // array for reserved tokens
    IERC20[] public allReservedTokens;

    // total amount of tokens received
    mapping (IERC20 => uint256) amountReservedTokenPooled;

    // events

    event UpdatedDiscount(uint256 newAmount, uint256 oldAmount);

    event UpdatedBondTime(uint256 newBondTime,uint256 oldBondTime);

    event UpdatedReservedToken(IERC20 token, bool state);

    event Buy(address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event CreatedBond(uint256 index, address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event ClaimedBond(uint256 index, address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    // constructor

    constructor() {
        treasury = 0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80;
        ROI = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        treasuryPercentages = [800, 800];
        ROIPercentages = [161, 161];
        HQPercentages = [39, 39];

        updateReservedToken(usdc, 6, true);
        updateReservedToken(dai, 18, true);

        initialRate = 0.0007 * (10 ** 18);

        discount = 10;

        // TODO
        // bondTime = 30 days;
        bondTime = 5 minutes;
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

    function updateDistributionPercentages(
        uint256[2] memory _treasuryPercentages,
        uint256[2] memory _ROIPercentages,
        uint256[2] memory _HQPercentages
    ) external onlyOwner {
        require(_treasuryPercentages[0] + _ROIPercentages[0] + _HQPercentages[0] == 1000,
            "STABL3: Sum of magnified buy percentages should equal 1000");
        require(_treasuryPercentages[1] + _ROIPercentages[1] + _HQPercentages[1] == 1000,
            "STABL3: Sum of magnified bond percentages should equal 1000");

        treasuryPercentages = _treasuryPercentages;
        ROIPercentages = _ROIPercentages;
        HQPercentages = _HQPercentages;
    }

    function updateReservedToken(IERC20 token, uint256 decimals, bool state) public onlyOwner {
        require(isReservedToken[token] != state, "STABL33: Reserved token is already of the value 'state'");
        isReservedToken[token] = state;
        decimalsReservedToken[token] = decimals;
        allReservedTokens.push(token);
        emit UpdatedReservedToken(token, state);
    }

    function updateDiscount(uint256 _discount) external onlyOwner {
        emit UpdatedDiscount(_discount, discount);
        discount = _discount;
    }

    function updateBondTime(uint256 _bondTime) external onlyOwner {
        emit UpdatedBondTime(_bondTime, bondTime);
        bondTime = _bondTime;
    }

    function getAmountReservedTokenPooled(IERC20 token) external view returns (uint256) {
        return amountReservedTokenPooled[token];
    }

    function updateSaleState(bool state) external onlyOwner {
        require(saleState != state, "STABL33: Sale state is already of the value 'state'");
        saleState = state;
    }

    function _getRate() internal view returns (uint256) {
        uint256 totalAmountReservedTokenTreasury;

        uint256 decimals;
        uint256 amountReservedTokenTreasury;
        for (uint256 i = 0 ; i < allReservedTokens.length ; i++) {
            if (isReservedToken[allReservedTokens[i]]) {
                amountReservedTokenTreasury = allReservedTokens[i].balanceOf(treasury);

                decimals = decimalsReservedToken[allReservedTokens[i]];
                if (decimals < 18) {
                    amountReservedTokenTreasury = amountReservedTokenTreasury.mul(10 ** (18 - decimals));
                }

                totalAmountReservedTokenTreasury += amountReservedTokenTreasury;
            }
        }

        return initialRate + totalAmountReservedTokenTreasury;
    }

    function buy(IERC20 _token, uint256 _amountToken) external {
        require(saleState, "STABL33: Sale not yet started");
        require(isReservedToken[_token], "STABL33: Token not reserved");
        require(_amountToken > 0, "STABL33: Amount should be greater than zero");

        uint256 rate = _getRate();

        uint256 amountStabl3 = _amountToken.mul(10 ** (18 - decimalsReservedToken[_token])).mul(10 ** 6).div(rate);

        amountReservedTokenPooled[_token] += _amountToken;

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
        require(saleState, "STABL33: Sale not yet started");
        require(isReservedToken[_token], "STABL33: Token not reserved");
        require(_amountToken > 0, "STABL33: Amount should be greater than zero");

        uint256 rate = _getRate();

        uint256 amountStabl3 = _amountToken.mul(10 ** (18 - decimalsReservedToken[_token])).mul(10 ** 6).div(rate);

        amountStabl3 += amountStabl3.mul(discount).div(100);

        amountReservedTokenPooled[_token] += _amountToken;

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
        require(saleState, "STABL33: Sale not yet started");
        Bond storage bond = getBonds[msg.sender][index];

        require(bond.status, "STABL33: Bond already claimed");
        require(block.timestamp > bond.endTime, "STABL33: Bond time not finished");

        stabl3.transferFrom(treasury, msg.sender, bond.amountStabl3);

        bond.status = false;

        emit ClaimedBond(bond.index, bond.recipient, bond.amountStabl3, bond.token, bond.amountToken);
    }
}