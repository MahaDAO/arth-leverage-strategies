// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IPriceFeed} from "../interfaces/IPriceFeed.sol";

contract MockOracle is IPriceFeed {
  uint256 public price;

  constructor(uint256 _price) {
    price = _price;
  }

  function setPrice(uint256 _price) external {
    price = _price;
  }

  function fetchPrice() external view override returns (uint256) {
    return price;
  }
}
