// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {VersionedInitializable} from "../../proxy/VersionedInitializable.sol";
import {StakingRewardsChild} from "../../staking/StakingRewardsChild.sol";

contract ARTHUSDCCurveStrategyTestnet is VersionedInitializable, StakingRewardsChild {
    using SafeMath for uint256;

    struct Position {
        uint64 depositedAt;
        uint64 lockDuration;
        uint256 totalUsdc;
        uint256 usdcSupplied;
        uint256 arthBorrowed;
        uint256 usdcInLp;
        uint256 lpTokensMinted;
    }

    address private _me;
    mapping(address => Position) public positions;

    IERC20 public arth;
    IERC20 public lp;
    IERC20 public varDebtArth;
    IERC20 public usdc;

    uint64 public minLockDuration;
    uint64 public minLockDurationForPermit;

    uint256 public withdrawalPenalty;
    uint256 public minDepositForPermit;
    uint256 public totalUsdcSupplied;
    uint256 public totalArthBorrowed;

    constructor(
        address _usdc,
        address _maha,
        uint256 _rewardsDuration,
        address _owner
    ) {
        usdc = IERC20(_usdc);

        _me = address(this);

        _stakingRewardsChildInit(_maha, _rewardsDuration, _owner);
        _transferOwnership(_owner);

        minDepositForPermit = 1000 * 1e6; // min 1000$ for gasless tx's
        minLockDuration = 60 * 5; // 5 minute lock for normal deposits
        minLockDurationForPermit = 60 * 30; // 30 minute lock for gasless deposits
    }

    function deposit(uint256 usdcSupplied, uint256 minLiquidityReceived) external {
        _deposit(msg.sender, usdcSupplied, minLiquidityReceived, minLockDuration);
    }

    function depositWithPermit(
        address who,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 usdcSupplied,
        uint256 minLiquidityReceived
    ) external {
        require(value >= minDepositForPermit, "!minDepositForPermit");
        IERC20Permit(address(usdc)).permit(who, _me, value, deadline, v, r, s);
        _deposit(who, usdcSupplied, minLiquidityReceived, minLockDurationForPermit);
    }

    function _deposit(
        address who,
        uint256 usdcSupplied,
        uint256 minLiquidityReceived,
        uint64 lockDuration
    ) internal nonReentrant {
        usdc.transferFrom(who, _me, usdcSupplied);

        uint256 usdcToLendingPool = usdcSupplied.mul(51282051).div(100000000); // 51% into lending
        uint256 usdcToLiquidityPool = usdcSupplied.sub(usdcToLendingPool);

        uint256 arthBorrowed = usdcToLendingPool.mul(95e30).div(208 * 1e16).div(100);

        positions[who] = Position({
            depositedAt: uint64(block.timestamp),
            lockDuration: lockDuration,
            arthBorrowed: arthBorrowed,
            totalUsdc: usdcSupplied,
            usdcSupplied: usdcToLendingPool,
            usdcInLp: usdcToLiquidityPool,
            lpTokensMinted: minLiquidityReceived
        });

        totalArthBorrowed += arthBorrowed;
        totalUsdcSupplied += usdcSupplied;

        // Record the staking in the staking contract for maha rewards
        _stake(who, usdcSupplied);
    }

    function withdraw() external {
        _withdraw(msg.sender);
    }

    function _withdraw(address who) internal nonReentrant {
        // Record the staking in the staking contract for maha rewards
        _withdraw(who, positions[who].totalUsdc);

        uint256 _usdcSupplied = positions[who].totalUsdc;
        uint256 _totalArthBorrowed = positions[who].arthBorrowed;

        delete positions[who];

        usdc.transfer(who, _usdcSupplied);

        totalArthBorrowed -= _totalArthBorrowed;
        totalUsdcSupplied -= _usdcSupplied;
    }

    function getRevision() public pure virtual override returns (uint256) {
        return 0;
    }
}
