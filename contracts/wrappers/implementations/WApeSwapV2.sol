// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IMasterChefV2} from "../../interfaces/IMasterChefV2.sol";
import {WMasterChefV2} from "../WMasterChefV2.sol";

interface IMiniApeV2 is IMasterChefV2 {
  function pendingBanana(uint256 _pid, address _user) external view returns (uint256);
}

contract WApeSwapV2 is WMasterChefV2 {
  using SafeMath for uint256;

  constructor(
    string memory _name,
    string memory _symbol,
    IMasterChefV2 _chef,
    uint256 _pid,
    address _lpToken,
    address _rewardToken,
    address _rewardDestination,
    uint256 _rewardFee,
    address _governance
  )
    WMasterChefV2(
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
    return IMiniApeV2(address(chef)).pendingBanana(pid, address(this)).add(rewardTokenBalance());
  }
}
