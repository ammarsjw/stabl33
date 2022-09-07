// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.16;

import "./IERC20.sol";

interface ITreasury {
    function isReservedToken(IERC20 _token) external view returns (bool);

    function allReservedTokens(uint) external view returns (IERC20);

    function getTreasuryPool(uint8, IERC20) external view returns (uint256);
    function getROIPool(uint8, IERC20) external view returns (uint256);
    function getHQPool(uint8, IERC20) external view returns (uint256);

    function updateROI(address _ROI) external;

    function updateHQ(address _HQ) external;

    function updatePermission(address _contractAddress, bool _state) external;

    function updateReservedToken(IERC20 _token, bool _state) external;

    function allReservedTokensLength() external view returns (uint256);

    function allPools(uint8 _type, IERC20 _token) external view returns (uint256, uint256, uint256);

    function sumOfAllPools(uint8 _type, IERC20 _token) external view returns (uint256);

    function circulatingSupply() external view returns (uint256);

    function provideInitialTreasurySupply(uint256 _amountStabl3) external;

    function getReserves() external view returns (uint256);

    function getRate() external view returns (uint256);

    function getRateImpact(IERC20 _token, uint256 _amountToken) external view returns (uint256);

    function getAmountOut(IERC20 _token, uint256 _amountToken) external view returns (uint256);

    function getAmountIn(uint256 _amountStabl3, IERC20 _token) external view returns (uint256);

    function updatePool(
        uint8 _type,
        IERC20 _token,
        uint256 _amountTokenTreasury,
        uint256 _amountTokenROI,
        uint256 _amountTokenHQ,
        bool _isIncrease
    ) external;

    function updateRate(IERC20 _token, uint256 _amountTokenTotal) external;

    function delegateApprove(IERC20 _token, address _spender, bool _isApprove) external;

    function withdrawFunds(IERC20 _token, uint256 _amountToken) external;

    function withdrawAllFunds(IERC20 _token) external;
}