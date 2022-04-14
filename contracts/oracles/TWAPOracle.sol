// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Epoch} from "../utils/Epoch.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TWAPOracle is Epoch, IPriceFeed {
  using SafeMath for uint256;

  IPriceFeed public oracle;
  uint256 public lastPriceIndex;
  mapping(uint256 => uint256) public priceHistory;

  constructor(address _oracle, uint256 _epoch) Epoch(_epoch, block.timestamp, 0) {
    oracle = IPriceFeed(_oracle);

    lastPriceIndex = 3;

    uint256 price = oracle.fetchPrice();
    priceHistory[0] = price;
    priceHistory[1] = price;
    priceHistory[2] = price;
    priceHistory[3] = price;
  }

  function updatePrice() public checkEpoch {
    priceHistory[lastPriceIndex] = oracle.fetchPrice();
    lastPriceIndex++;
  }

  function fetchPrice() external view override returns (uint256) {
    require(!callable(), "price is stale");

    uint256 priceTotal = 0;
    for (uint256 index = lastPriceIndex; index > lastPriceIndex - 3; index--) {
      priceTotal = priceTotal.add(priceHistory[index]);
    }

    return priceTotal.div(3); // average it out!
  }
}
