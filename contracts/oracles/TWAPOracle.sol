// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Epoch} from "../utils/Epoch.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "hardhat/console.sol";

contract TWAPOracle is Epoch, IPriceFeed {
  using SafeMath for uint256;

  IPriceFeed public oracle;
  uint256 public lastPriceIndex;
  mapping(uint256 => uint256) public priceHistory;
  uint256 precision = 1e9;
  uint256 maxPriceChange;

  constructor(
    address _oracle,
    uint256 _epoch,
    uint256 _maxPriceChange
  ) Epoch(_epoch, block.timestamp, 0) {
    oracle = IPriceFeed(_oracle);

    lastPriceIndex = 3;

    uint256 price = oracle.fetchPrice();
    priceHistory[0] = price;
    priceHistory[1] = price;
    priceHistory[2] = price;
    priceHistory[3] = price;

    maxPriceChange = _maxPriceChange;
  }

  function updatePrice() public checkEpoch {
    lastPriceIndex += 1;
    priceHistory[lastPriceIndex] = oracle.fetchPrice();

    uint256 minPrice = Math.min(priceHistory[lastPriceIndex], priceHistory[lastPriceIndex - 1]);
    uint256 maxPrice = Math.max(priceHistory[lastPriceIndex], priceHistory[lastPriceIndex - 1]);

    uint256 priceChange = maxPrice.sub(minPrice).mul(precision).mul(100).div(maxPrice);
    // console.log("price change", priceChange);
    // console.log("maxPriceChange", maxPriceChange);
    // console.log("precision", precision);
    require(priceChange < maxPriceChange, "too much price deviation");
  }

  function fetchPrice() external view override returns (uint256) {
    require(!callable(), "price is stale");

    uint256 priceTotal = 0;
    for (uint256 index = lastPriceIndex; index > lastPriceIndex - 3; index--) {
      // console.log("index", index);
      // console.log("priceTotal before", priceTotal);
      priceTotal = priceTotal.add(priceHistory[index]);
      // console.log("priceTotal after", priceTotal);
    }

    return priceTotal.div(3); // average it out!
  }
}
