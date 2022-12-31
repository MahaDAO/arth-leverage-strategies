// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ETHTroveData {
    struct Position {
        bool isActive;
        uint256 ethForLoan; // ETH deposited
        uint256 arthFromLoan; // ARTH minted
        uint256 arthInLendingPool; // mARTH contributed
    }
}
