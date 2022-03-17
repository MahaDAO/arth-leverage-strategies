// SPDX-License-Identifier: GNU-3

pragma solidity ^0.8.0;

import {ILeverageAccount} from "../interfaces/ILeverageAccount.sol";
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

  function _canExecute(address who) internal view returns (bool) {
    return hasRole(STRATEGY_ROLE, who) || hasRole(DEFAULT_ADMIN_ROLE, who);
  }

  function canExecute(address who) external view override returns (bool) {
    return _canExecute(who);
  }

  function approveStrategy(address strategy) external override onlyAdmin {
    _grantRole(STRATEGY_ROLE, strategy);
  }

  function revokeStrategy(address strategy) external override onlyAdmin {
    _revokeRole(STRATEGY_ROLE, strategy);
  }

  function callFn(address target, bytes memory signature) external override onlyStrategiesOrAdmin {
    (bool success, bytes memory response) = target.call(signature);

    // Has the function call reverted?
    if (!success) {
      // Is there a reason string available for the revert?
      if (response.length > 0) {
        // Try to fetch the reason for revert.
        assembly {
          let response_size := mload(response)
          revert(add(32, response), response_size)
        }
      } else {
        string memory responseInStr = abi.decode(response, (string));
        revert(responseInStr);
      }
    }

    // Fallback check.
    require(success, "callFn failed");
  }
}
