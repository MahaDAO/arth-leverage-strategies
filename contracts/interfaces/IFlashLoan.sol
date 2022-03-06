// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

interface IFlashLoan {
    function flashLoan(
        address receiverAddress,
        uint256 amount,
        bytes calldata params
    ) external;
}
