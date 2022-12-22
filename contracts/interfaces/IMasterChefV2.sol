//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IMasterChefV2 {
    function deposit(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function withdraw(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function harvest(uint256 pid, address to) external;
}
