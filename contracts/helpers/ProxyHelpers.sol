// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {DSProxy} from "../proxy/DSProxy.sol";

abstract contract ProxyHelpers {
  function captureTokenViaProxy(
    DSProxy userProxy,
    address token,
    uint256 amount
  ) internal {
    // send tokens back to the contract
    bytes memory transferData = abi.encodeWithSignature(
      "transfer(address,uint256)",
      address(this),
      amount
    );
    userProxy.execute(token, transferData);
  }

  function captureTokenViaProxy2(
    DSProxy userProxy,
    address token,
    bytes memory transferData
  ) internal {
    userProxy.execute(token, transferData);
  }
}
