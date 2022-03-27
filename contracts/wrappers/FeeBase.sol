// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";

contract FeeBase is Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  uint256 public pct100 = 100000000000;
  uint256 public rewardFeeRate = 500000000; // 0.5% in 10^9
  uint256 public referralFeeRate = 5000000000; // 5% in 10^9
  address public rewardFeeDestination;

  mapping(address => address) public referralMapping;

  event ReferralFeeChanged(uint256 _old, uint256 _new);
  event RewardFeeChanged(uint256 _old, uint256 _new);
  event RewardAddressChanged(address _old, address _new);
  event RewardFeeCharged(uint256 initialAmount, uint256 feeAmount, address feeDestination);

  event ReferralFeeCharged(uint256 initialAmount, uint256 feeAmount, address feeDestination);

  function setRewardFeeRate(uint256 _new) external onlyOwner {
    _setRewardFeeRate(_new);
  }

  function setRewardFeeAddress(address _new) external onlyOwner {
    _setRewardFeeAddress(_new);
  }

  function setReferralFeeRate(uint256 _new) external onlyOwner {
    _setReferralFeeRate(_new);
  }

  function _setRewardFeeAddress(address _new) internal {
    emit RewardAddressChanged(rewardFeeDestination, _new);
    rewardFeeDestination = _new;
  }

  function _setRewardFeeRate(uint256 _new) internal {
    require(_new >= 0, "fee is not >= 0%");
    require(_new <= pct100, "fee is not <= 100%");

    emit RewardFeeChanged(rewardFeeRate, _new);
    rewardFeeRate = _new;
  }

  function _setReferralFeeRate(uint256 _new) internal {
    require(_new >= 0, "fee is not >= 0%");
    require(_new <= pct100, "fee is not <= 100%");

    emit ReferralFeeChanged(referralFeeRate, _new);
    referralFeeRate = _new;
  }

  function _chargeFeeAndTransfer(
    IERC20 token,
    uint256 earnings,
    address who
  ) internal {
    if (earnings == 0) return;

    uint256 feeToCharge = earnings.mul(rewardFeeRate).div(pct100);
    uint256 remainderToSend = earnings.sub(feeToCharge);

    // check and pay out for referrals
    address referrer = referralMapping[who];
    if (referrer != address(0)) {
      uint256 referrerEarning = remainderToSend.mul(referralFeeRate).div(pct100);
      token.safeTransfer(referrer, referrerEarning);
      emit ReferralFeeCharged(remainderToSend, referrerEarning, referrer);

      remainderToSend = remainderToSend.sub(referrerEarning);
    }

    // send the remainder back to the user
    token.safeTransfer(who, remainderToSend);

    // pay out fees to governance
    if (feeToCharge > 0 && rewardFeeDestination != address(0)) {
      token.safeTransfer(rewardFeeDestination, feeToCharge);
      emit RewardFeeCharged(earnings, feeToCharge, rewardFeeDestination);
    }
  }
}
