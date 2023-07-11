// SPDX-License-Identifier: GNU GPLv3

pragma solidity ^0.8.0;

interface IROIStruct {

    struct TimeWeightedAPR {
        uint256 APR;
        uint256 timeWeight;
    }
}