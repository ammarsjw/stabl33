// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.16;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";

import "./ITreasury.sol";

contract Stabl3PublicSale is Ownable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20 for IERC20;

    address public treasury;
    address public ROI;
    address public HQ;

    IERC20 public stabl3 = IERC20(0x20A91B0d2A5545BF05bcA96778e138E2E154e083);

    uint256[] public treasuryPercentages;
    uint256[] public ROIPercentages;
    uint256[] public HQPercentages;

    uint256 public exchangeFee;

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
        uint256 startTime;
    }

    // mappings

    // ongoing bonds
    mapping (address => Bond[]) public getBonds;

    // events

    event UpdatedExchangeFee(uint256 newExchangeFee, uint256 oldExchangeFee);

    event UpdatedDiscount(uint256 newDiscount, uint256 oldDiscount);

    event UpdatedBondTime(uint256 newBondTime,uint256 oldBondTime);

    event Buy(address indexed recipient, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event Exchanged(address indexed recipient, IERC20 exchangingToken, uint256 amountExchangingToken, uint256 fee, IERC20 token, uint256 amountToken);

    event CreatedBond(address indexed recipient, uint256 index, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    event ClaimedBond(address indexed recipient, uint256 index, uint256 amountStabl3, IERC20 token, uint256 amountToken);

    // constructor

    constructor(address _treasury) {
        treasury = _treasury;
        ROI = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        treasuryPercentages = [800, 800];
        ROIPercentages = [161, 161];
        HQPercentages = [39, 39];

        exchangeFee = 3;

        discount = 100;

        // TODO
        // bondTime = 30 days;
        bondTime = 5 minutes;
    }

    function updateTreasury(address _treasury) external onlyOwner {
        require(treasury != _treasury, "Stabl3PublicSale: Treasury is already this address");
        treasury = _treasury;
    }

    function updateROI(address _ROI) external onlyOwner {
        require(ROI != _ROI, "Stabl3PublicSale: ROI is already this address");
        ROI = _ROI;
    }

    function updateHQ(address _HQ) external onlyOwner {
        require(HQ != _HQ, "Stabl3PublicSale: HQ is already this address");
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

    function updateExchangeFee(uint256 _exchangeFee) external onlyOwner {
        emit UpdatedExchangeFee(_exchangeFee, exchangeFee);
        exchangeFee = _exchangeFee;
    }

    function updateDiscount(uint256 _discount) external onlyOwner {
        emit UpdatedDiscount(_discount, discount);
        discount = _discount;
    }

    function updateBondTime(uint256 _bondTime) external onlyOwner {
        emit UpdatedBondTime(_bondTime, bondTime);
        bondTime = _bondTime;
    }

    function updateSaleState(bool state) external onlyOwner {
        require(saleState != state, "Stabl3PublicSale: Sale state is already of the value 'state'");
        saleState = state;
    }

    function _distributeFunds(IERC20 _token, uint256 _amountToken, uint256 _percentagesIndex) internal {
        uint256 amountTreasury = _amountToken.mul(treasuryPercentages[_percentagesIndex]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, treasury, amountTreasury);

        uint256 amountROI = _amountToken.mul(ROIPercentages[_percentagesIndex]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, ROI, amountROI);

        uint256 amountHQ = _amountToken.mul(HQPercentages[_percentagesIndex]).roundDiv(1000);
        SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);
    }

    function buy(IERC20 _token, uint256 _amountToken) external {
        require(saleState, "Stabl3PublicSale: Sale not yet started");
        require(ITreasury(treasury).isReservedToken(_token), "Stabl3PublicSale: Token not reserved");
        require(_amountToken > 0, "Stabl3PublicSale: Insufficient amount");

        uint256 amountStabl3 = ITreasury(treasury).getAmountOut(_token, _amountToken);

        _distributeFunds(_token, _amountToken, 0);

        stabl3.transferFrom(treasury, msg.sender, amountStabl3);

        emit Buy(msg.sender, amountStabl3, _token, _amountToken);
        ITreasury(treasury).update();
    }

    function exchange(IERC20 _exchangingToken, IERC20 _token, uint256 _amountToken) external {
        require(saleState, "Stabl3PublicSale: Sale not yet started");
        require(
            ITreasury(treasury).isReservedToken(_token) &&
            ITreasury(treasury).isReservedToken(_exchangingToken),
            "Stabl3PublicSale: Token(s) not reserved"
        );
        require(_exchangingToken != _token, "Stabl3PublicSale: Invalid exchange");
        require(_amountToken > 0, "Stabl3PublicSale: Insufficient amount");

        uint256 fee = (_amountToken * exchangeFee) / 1000;
        _amountToken -= fee;

        uint256 amountExchangingToken;
        uint256 decimalsExchangingToken = ITreasury(treasury).getDecimalsReservedToken(_exchangingToken);
        uint256 decimalsToken = ITreasury(treasury).getDecimalsReservedToken(_token);
        if (decimalsExchangingToken > decimalsToken) {
            amountExchangingToken = _amountToken * (10 ** (decimalsExchangingToken - decimalsToken));
        }
        else if (decimalsToken > decimalsExchangingToken) {
            amountExchangingToken = _amountToken / (10 ** (decimalsToken - decimalsExchangingToken));
        }
        else {
            amountExchangingToken = _amountToken;
        }

        SafeERC20.safeTransferFrom(_token, msg.sender, ROI, fee);

        _distributeFunds(_token, _amountToken, 0);

        SafeERC20.safeTransferFrom(_exchangingToken, treasury, msg.sender, amountExchangingToken);

        emit Exchanged(msg.sender, _exchangingToken, amountExchangingToken, fee, _token, _amountToken);
        ITreasury(treasury).update();
    }

    function createBond(IERC20 _token, uint256 _amountToken) external {
        require(saleState, "Stabl3PublicSale: Sale not yet started");
        require(ITreasury(treasury).isReservedToken(_token), "Stabl3PublicSale: Token not reserved");
        require(_amountToken > 0, "Stabl3PublicSale: Insufficient amount");

        uint256 amountStabl3 = ITreasury(treasury).getAmountOut(_token, _amountToken);

        amountStabl3 += (amountStabl3 * discount) / 1000;

        Bond memory bond = Bond(getBonds[msg.sender].length, msg.sender, true, amountStabl3, _token, _amountToken, block.timestamp);
        getBonds[msg.sender].push(bond);

        _distributeFunds(_token, _amountToken, 1);

        emit CreatedBond(bond.recipient, bond.index, bond.amountStabl3, bond.token, bond.amountToken);
        ITreasury(treasury).update();
    }

    function claimBond(uint256 index) external {
        require(saleState, "Stabl3PublicSale: Sale not yet started");
        Bond storage bond = getBonds[msg.sender][index];

        require(bond.status, "Stabl3PublicSale: Bond already claimed");
        require(block.timestamp > bond.startTime + bondTime, "Stabl3PublicSale: Bond time not finished");

        stabl3.transferFrom(treasury, msg.sender, bond.amountStabl3);

        bond.status = false;

        emit ClaimedBond(bond.recipient, bond.index, bond.amountStabl3, bond.token, bond.amountToken);
        ITreasury(treasury).update();
    }
}