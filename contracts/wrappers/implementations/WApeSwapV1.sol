// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IMasterChef} from "../../interfaces/IMasterChef.sol";
import {WMasterChef} from "../WMasterChef.sol";

interface IMiniApeV1 is IMasterChef {
  function pendingCake(uint256 _pid, address _user) external view returns (uint256);
}

contract WApeSwapV1 is WMasterChef {
  using SafeMath for uint256;

  constructor(
    string memory _name,
    string memory _symbol,
    IMasterChef _chef,
    uint256 _pid,
    address _lpToken,
    address _rewardToken,
    address _rewardDestination,
    uint256 _rewardFee,
    address _governance
  )
    WMasterChef(
      _name,
      _symbol,
      _chef,
      _pid,
      _lpToken,
      _rewardToken,
      _rewardDestination,
      _rewardFee,
      _governance
    )
  {}

  function _accumulatedRewards() internal view override returns (uint256) {
    return IMiniApeV1(address(chef)).pendingCake(pid, address(this)).add(rewardTokenBalance());
  }
}
