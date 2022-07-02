// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IDotDotLPStaker, BNBDDDVault} from "./BNBDDDVault.sol";

contract BNBDDDVaultFactory {
    mapping(address => BNBDDDVault) public vaults;

    address private ddd;
    address private epx;
    address private dddLocker;
    address private arthUsd;
    address private arthEPXLP;
    address private arthEPXStableSwap;
    address private borrowerOperations;
    address private troveManager;
    address private epxZapper;

    constructor(
        address _ddd,
        address _epx,
        address _dddLocker,
        address _arthUsd,
        address _arthEPXLP,
        address _arthEPXStableSwap,
        address _epxZapper,
        address _borrowerOperations,
        address _troveManager
    ) {
        ddd = _ddd;
        epx = _epx;
        dddLocker = _dddLocker;
        arthUsd = _arthUsd;
        arthEPXLP = _arthEPXLP;
        arthEPXStableSwap = _arthEPXStableSwap;
        borrowerOperations = _borrowerOperations;
        troveManager = _troveManager;
        epxZapper = _epxZapper;
    }

    function deposit() external payable {
        if (address(vaults[msg.sender]) == address(0)) {
            vaults[msg.sender] = new BNBDDDVault(
                ddd,
                epx,
                dddLocker,
                arthUsd,
                arthEPXLP,
                arthEPXStableSwap,
                epxZapper,
                borrowerOperations,
                troveManager,
                msg.sender
            );
        }

        BNBDDDVault vault = vaults[msg.sender];
        vault.deposit{value: msg.value}();
    }

    function withdraw(uint256 amount) external {
        BNBDDDVault vault = vaults[msg.sender];
        require(address(vault) != address(0), "no vault craeted");
        vault.withdraw(amount);
    }

    function getReward() external {
        BNBDDDVault vault = vaults[msg.sender];
        require(address(vault) != address(0), "no vault craeted");
        vault.getReward();
    }

    function earned(address who) external view returns (IDotDotLPStaker.Amounts[] memory) {
        BNBDDDVault vault = vaults[who];
        if (address(vault) != address(0)) return vault.earned();

        IDotDotLPStaker.Amounts[] memory blank;
        return blank;
    }

    function balanceOf(address who) external view returns (IDotDotLPStaker.ExtraReward[] memory) {
        BNBDDDVault vault = vaults[who];
        if (address(vault) != address(0)) return vault.balanceOf();
        return [];
    }
}
