// SPDX-License-Identifier: GNU-3

pragma solidity ^0.8.0;

import {ILeverageAccount} from "./interfaces/ILeverageAccount.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract LeverageAccount is AccessControl, ILeverageAccount {
  bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");

  constructor(address owner) {
    _setupRole(DEFAULT_ADMIN_ROLE, owner);
    _setRoleAdmin(STRATEGY_ROLE, DEFAULT_ADMIN_ROLE);
  }

  modifier onlyStrategiesOrAdmin() {
    require(_canExecute(msg.sender), "only strategies or owner.");
    _;
  }

  modifier onlyAdmin() {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "only owner.");
    _;
  }

  function canExecute(address who) external view override returns (bool) {
    return _canExecute(who);
  }

  function _canExecute(address who) internal view returns (bool) {
    return hasRole(STRATEGY_ROLE, who) || hasRole(DEFAULT_ADMIN_ROLE, who);
  }

  function approveStrategy(address strategy) external override onlyAdmin {
    _grantRole(STRATEGY_ROLE, strategy);
  }

  function revokeStrategy(address strategy) external override onlyAdmin {
    _revokeRole(STRATEGY_ROLE, strategy);
  }

  function callFn(address target, bytes memory signature) external override onlyStrategiesOrAdmin {
    (bool success, ) = target.call(signature);
    require(success, "callFn fail");
  }
}
