// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IMasterChef} from "../../interfaces/IMasterChef.sol";
import {WMasterChef} from "../WMasterChef.sol";

interface IEllipsisStaking is IMasterChef {
  function claimableReward(uint256 _pid, address _user) external view returns (uint256);
}

contract WEllipsis3EPS is WMasterChef {
  using SafeMath for uint256;

  constructor(
    string memory _name,
    string memory _symbol,
    IEllipsisStaking _chef,
    uint256 _pid,
    address _lpToken,
    address _rewardToken,
    address _rewardDestination,
    uint256 _rewardFeeRate,
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
      _rewardFeeRate,
      _governance
    )
  {
    // do nothing
  }

  function _accumulatedRewards() internal view override returns (uint256) {
    return
      IEllipsisStaking(address(chef)).claimableReward(pid, address(this)).add(rewardTokenBalance());
  }
}
