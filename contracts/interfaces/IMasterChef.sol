//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IMasterChef {
    function deposit(uint256 pid, uint256 amount) external;

    function withdraw(uint256 pid, uint256 amount) external;
}
