// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

import "./Ownable.sol";
import "./SafeMathUpgradeable.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";

import "./ITreasury.sol";
import "./IROI.sol";

contract Stabl3Bonding is Ownable, ReentrancyGuard {
    using SafeMathUpgradeable for uint256;

    uint8 private constant BOND_POOL = 1;

    ITreasury public treasury;
    IROI public ROI;
    address public HQ;

    IERC20 public immutable stabl3;

    uint256 public treasuryPercentage;
    uint256 public ROIPercentage;
    uint256 public HQPercentage;

    uint256 public bondingClaimTime;

    uint256 public totalBondTypes;

    bool public bondState;

    // structs

    struct BondInfo {
        uint256 bondType;
        bool status;
        IERC20 token;
        uint256 bondAmount;
        uint256 bondAmountConsumed;
        uint256 discount;
        uint256 startTime;
        uint256 expiryTime;
    }

    struct Bonding {
        uint256 index;
        address user;
        bool status;
        uint256 bondType;
        IERC20 token;
        uint256 amountToken;
        uint256 amountStabl3;
        uint256 startTime;
        uint256 endTime;
    }

    struct Record {
        uint256 totalAmountToken;
        uint256 totalAmountStabl3;
    }

    // mappings

    // bonds created by admin/owner
    BondInfo[] public getBondInfo;

    // user bondings
    mapping (address => Bonding[]) public getBondings;

    // user lifetime bonding records
    mapping (address => Record) public getRecords;

    // admins are accounts that have permission to access certain bonding functions
    mapping (address => bool) public admin;

    // events

    event UpdatedTreasury(address newTreasury, address oldTreasury);

    event UpdatedROI(address newROI, address oldROI);

    event UpdatedHQ(address newHQ, address oldHQ);

    event UpdatedBondingClaimTime(uint256 newBondingClaimTime, uint256 oldBondingClaimTime);

    event UpdatedAdmin(address account, bool state);

    event CreatedBond(
        uint256 bondType,
        IERC20 token,
        uint256 bondAmount,
        uint256 discount,
        uint256 expiryTime
    );

    event UpdatedBond(
        uint256 bondType,
        bool status,
        IERC20 token,
        uint256 bondAmount,
        uint256 discount,
        uint256 expiryTime
    );

    event Bond(
        address indexed user,
        uint256 bondType,
        uint256 index,
        IERC20 token,
        uint256 amountToken,
        uint256 amountStabl3,
        uint256 totalAmountToken,
        uint256 timestamp
    );

    event ClaimedBond(
        address indexed user,
        uint256 bondType,
        uint256 index,
        uint256 amountToken,
        uint256 amountStabl3,
        uint256 totalAmountStabl3,
        uint256 timestamp
    );

    // constructor

    constructor(address _treasury, address _ROI) {
        treasury = ITreasury(_treasury);
        ROI = IROI(_ROI);
        // TODO change
        HQ = 0x294d0487fdf7acecf342ae70AFc5549A6E90f3e0;

        // TODO change
        stabl3 = IERC20(0x6d4eaE732C9f34C6EAE0CFFD9c267b2d25583782);

        treasuryPercentage = 800;
        ROIPercentage = 161;
        HQPercentage = 39;

        // TODO remove
        bondingClaimTime = 300; // 0:15 hours time in seconds
        // bondingClaimTime = 2592000; // 1 month time in seconds
    }

    function updateTreasury(address _treasury) external onlyOwner {
        require(address(treasury) != _treasury, "Stabl3Bonding: Treasury is already this address");
        emit UpdatedTreasury(_treasury, address(treasury));
        treasury = ITreasury(_treasury);
    }

    function updateROI(address _ROI) external onlyOwner {
        require(address(ROI) != _ROI, "Stabl3Bonding: ROI is already this address");
        emit UpdatedROI(_ROI, address(ROI));
        ROI = IROI(_ROI);
    }

    function updateHQ(address _HQ) external onlyOwner {
        require(HQ != _HQ, "Stabl3Bonding: HQ is already this address");
        emit UpdatedHQ(_HQ, HQ);
        HQ = _HQ;
    }

    function updateDistributionPercentages(
        uint256 _treasuryPercentage,
        uint256 _ROIPercentage,
        uint256 _HQPercentage
    ) external onlyOwner {
        require(_treasuryPercentage + _ROIPercentage + _HQPercentage == 1000,
            "Stabl3Bonding: Sum of magnified percentages should equal 1000");

        treasuryPercentage = _treasuryPercentage;
        ROIPercentage = _ROIPercentage;
        HQPercentage = _HQPercentage;
    }

    function updateBondingClaimTime(uint256 _bondingClaimTime) external onlyOwner {
        require(bondingClaimTime != _bondingClaimTime, "Stabl3Bonding: Bonding Claim Time is already this value");
        emit UpdatedBondingClaimTime(_bondingClaimTime, bondingClaimTime);
        bondingClaimTime = _bondingClaimTime;
    }

    function updateBondState(bool _state) external onlyOwner {
        require(bondState != _state, "Stabl3Bonding: Bond State is already of the value 'state'");
        bondState = _state;
    }

    function updateAdmin(address _account, bool _state) external onlyOwner {
        require(admin[_account] != _state, "Stabl3Bonding: Account is already of the value 'state'");
        admin[_account] = _state;
        emit UpdatedAdmin(_account, _state);
    }

    function createBond(
        IERC20 _token,
        uint256 _bondAmount,
        uint256 _discount,
        uint256 _expiryTime
    ) external bondActive onlyAdmin reserved(_token) {
        require(_bondAmount > 0, "Stabl3Bonding: Insufficient amount");

        uint256 timestampToConsider = block.timestamp;

        BondInfo memory bondInfo;
        bondInfo.bondType = totalBondTypes;
        bondInfo.status = true;
        bondInfo.token = _token;
        bondInfo.bondAmount = _bondAmount;
        // bondInfo.bondAmountConsumed = 0;
        bondInfo.discount = _discount;
        bondInfo.startTime = timestampToConsider;
        bondInfo.expiryTime = timestampToConsider + _expiryTime;

        getBondInfo.push(bondInfo);

        totalBondTypes++;

        emit CreatedBond(bondInfo.bondType, bondInfo.token, bondInfo.bondAmount, bondInfo.discount, bondInfo.expiryTime);
    }

    function updateBond(
        uint256 _bondType,
        bool _status,
        IERC20 _token,
        uint256 _bondAmount,
        uint256 _discount,
        uint256 _expiryTime
    ) external bondActive onlyAdmin reserved(_token) {
        require(_bondAmount > 0, "Stabl3Bonding: Insufficient amount");

        BondInfo storage bondInfo = getBondInfo[_bondType];

        require(bondInfo.bondAmount > 0, "Stabl3Bonding: Invalid bond type");

        if (!_status) {
            bondInfo.status = false;
        }
        else {
            bondInfo.status = _status;
            bondInfo.token = _token;
            bondInfo.bondAmount = _bondAmount;
            bondInfo.discount = _discount;
            bondInfo.expiryTime = _expiryTime;
        }

        emit UpdatedBond(bondInfo.bondType, bondInfo.status, bondInfo.token, bondInfo.bondAmount, bondInfo.discount, bondInfo.expiryTime);
    }

    function bond(uint256 _bondType, IERC20 _token, uint256 _amountToken) external bondActive reserved(_token) nonReentrant {
        require(_amountToken > 0, "Stabl3Bonding: Insufficient amount");

        BondInfo storage bondInfo = getBondInfo[_bondType];

        uint256 timestampToConsider = block.timestamp;

        require(bondInfo.status, "Stabl3Bonding: Invalid Bond Type");
        require(timestampToConsider < bondInfo.expiryTime, "Stabl3Bonding: Bond has expired");
        require(bondInfo.bondAmountConsumed + _amountToken <= bondInfo.bondAmount, "Stabl3Bonding: Bond limit reached");

        {
            uint256 amountTreasury = _amountToken.mul(treasuryPercentage).div(1000);

            uint256 amountROI = _amountToken.mul(ROIPercentage).div(1000);

            uint256 amountHQ = _amountToken.mul(HQPercentage).div(1000);

            uint256 totalAmountDistributed = amountTreasury + amountROI + amountHQ;
            if (_amountToken > totalAmountDistributed) {
                amountTreasury += _amountToken - totalAmountDistributed;
            }

            SafeERC20.safeTransferFrom(_token, msg.sender, address(treasury), amountTreasury);
            SafeERC20.safeTransferFrom(_token, msg.sender, address(ROI), amountROI);
            SafeERC20.safeTransferFrom(_token, msg.sender, HQ, amountHQ);

            treasury.updatePool(BOND_POOL, _token, amountTreasury, amountROI, amountHQ, true);
        }

        uint256 amountStabl3 = treasury.getAmountOut(_token, _amountToken);

        amountStabl3 = amountStabl3.mul(1000).div(1000 - bondInfo.discount);

        Bonding memory bonding;
        bonding.index = getBondings[msg.sender].length;
        bonding.user = msg.sender;
        bonding.status = true;
        bonding.bondType = bondInfo.bondType;
        bonding.token = _token;
        bonding.amountToken = _amountToken;
        bonding.amountStabl3 = amountStabl3;
        bonding.startTime = timestampToConsider;
        bonding.endTime = timestampToConsider + bondingClaimTime;

        getBondings[msg.sender].push(bonding);

        bondInfo.bondAmountConsumed += _amountToken;

        Record storage record = getRecords[msg.sender];

        uint256 amountTokenConverted = _token.decimals() < 18 ? _amountToken * 10 ** (18 - _token.decimals()) : _amountToken;
        record.totalAmountToken += amountTokenConverted;

        treasury.updateRate(_token, _amountToken);

        ROI.updateAPR();

        emit Bond(
            bonding.user,
            bonding.bondType,
            bonding.index,
            bonding.token,
            bonding.amountToken,
            bonding.amountStabl3,
            record.totalAmountToken,
            timestampToConsider
        );
    }

    function claimBond(uint256 _index) external bondActive nonReentrant {
        Bonding storage bonding = getBondings[msg.sender][_index];

        uint256 timestampToConsider = block.timestamp;

        require(bonding.status, "Stabl3Bonding: Invalid Bonding");
        require(timestampToConsider >= bonding.endTime, "Stabl3Bonding: Bonding not yet claimable");

        stabl3.transferFrom(address(treasury), msg.sender, bonding.amountStabl3);

        bonding.status = false;

        Record storage record = getRecords[msg.sender];

        record.totalAmountStabl3 += bonding.amountStabl3;

        treasury.updateStabl3CirculatingSupply(bonding.amountStabl3, true);

        emit ClaimedBond(
            bonding.user,
            bonding.bondType,
            bonding.index,
            bonding.amountToken,
            bonding.amountStabl3,
            record.totalAmountStabl3,
            timestampToConsider
        );
    }

    // modifiers

    modifier bondActive() {
        require(bondState, "Stabl3Bonding: Bond not yet started");
        _;
    }

    modifier onlyAdmin() {
        require(admin[msg.sender] || msg.sender == owner(), "Stabl3Bonding: Caller is not an admin");
        _;
    }

    modifier reserved(IERC20 _token) {
        require(treasury.isReservedToken(_token), "Stabl3Bonding: Not a reserved token");
        _;
    }
}