// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {IBorrowerOperations} from "../../interfaces/IBorrowerOperations.sol";
import {StakingRewardsChild} from "./StakingRewardsChild.sol";
import {MerkleWhitelist} from "./MerkleWhitelist.sol";
import {IPriceFeed} from "../../interfaces/IPriceFeed.sol";
import {Multicall} from "../../utils/Multicall.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";

contract ARTHETHTroveLP is Ownable, Initializable, StakingRewardsChild, MerkleWhitelist, Multicall {
    using SafeMath for uint256;

    event Deposit(address indexed src, uint256 wad);
    event Withdrawal(address indexed dst, uint256 wad);

    struct Position {
        bool isActive;
        uint256 ethForLoan;
        uint256 arthFromLoan;
        uint256 arthInLendingPool;
    }

    struct LoanParams {
        uint256 maxFee;
        address upperHint;
        address lowerHint;
        uint256 arthAmount;
    }

    struct WhitelistParams {
        uint256 rootId;
        bytes32[] proof;
    }

    uint256 public mintCollateralRatio = 3 * 1e18; // 300% CR

    address private me;
    address private _arth;
    mapping(address => Position) public positions;

    IERC20 public arth;
    ILendingPool public pool;
    IPriceFeed public priceFeed;
    IBorrowerOperations public borrowerOperations;

    // TODO: the scenario when the trove gets liquidated?

    function initialize(
        address _borrowerOperations,
        address __arth,
        address __maha,
        address _priceFeed,
        address _pool,
        address _owner
    ) initializer {
        arth = IERC20(__arth);
        _arth = __arth;
        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        priceFeed = IPriceFeed(_priceFeed);
        pool = ILendingPool(_pool);
        arth.approve(_pool, type(uint256).max);
        me = address(this);

        _stakingRewardsChildInit(__maha);
    }

    // --- Fallback function ---

    receive() external payable {
        // Fetch the active pool.
        address activePool = borrowerOperations.activePool();
        // Only active pool can send eth to the contract.
        require(msg.sender == activePool, "Not active pool");
    }

    /// @notice admin-only function to open a trove; needed to initialize the contract
    function openTrove(
        uint256 _maxFee,
        uint256 _arthAmount,
        address _upperHint,
        address _lowerHint,
        address _frontEndTag
    ) external payable onlyOwner nonReentrant {
        require(msg.value > 0, "no eth");

        // Open the trove.
        borrowerOperations.openTrove{value: msg.value}(
            _maxFee,
            _arthAmount,
            _upperHint,
            _lowerHint,
            _frontEndTag
        );

        // Send the dust back to onlyOwner.
        _flush(msg.sender);
    }

    /// @notice admin-only function to close the trove; normally not needed if the campaign keeps on running
    function closeTrove(uint256 arthNeeded) external payable onlyOwner nonReentrant {
        // Get the ARTH needed to close the loan.
        arth.transferFrom(msg.sender, me, arthNeeded);

        // Close the trove.
        borrowerOperations.closeTrove();

        // Send the dust back to onlyOwner.
        _flush(msg.sender);
    }

    function deposit(LoanParams memory loanParams, uint16 lendingReferralCode)
        public
        payable
        /*, WhitelistParams memory whitelistParam */
        /* checkWhitelist(msg.sender, whitelistParams.rootId, whitelistParams.proof) */
        nonReentrant
    {
        // Check that we are getting ETH.
        require(msg.value > 0, "no eth");

        // Check that position is not already open.
        require(!positions[msg.sender].isActive, "Position already open");

        // Check that min. cr for the strategy is met.
        // require(
        //     priceFeed.fetchPrice().mul(msg.value).div(loanParams.arthAmount) >= mintCollateralRatio,
        //     "CR must be > 299%"
        // );

        // 2. Mint ARTH and track ARTH balance changes due to this current tx.
        uint256 arthBeforeLoaning = arth.balanceOf(me);
        borrowerOperations.adjustTrove{value: msg.value}(
            loanParams.maxFee,
            0, // No coll withdrawal.
            loanParams.arthAmount, // Mint ARTH.
            true, // Debt increasing.
            loanParams.upperHint,
            loanParams.lowerHint
        );
        uint256 arthAfterLoaning = arth.balanceOf(me);
        uint256 arthFromLoan = arthAfterLoaning.sub(arthBeforeLoaning);

        // 3. Supply ARTH in the lending pool.
        uint256 arthBeforeLending = arth.balanceOf(me);
        pool.supply(
            _arth,
            arthFromLoan,
            me, // On behalf of this contract
            lendingReferralCode
        );
        uint256 arthAfterLending = arth.balanceOf(me);
        uint256 arthInLendingPool = arthBeforeLending.sub(arthAfterLending);

        // 4. Record the position.
        positions[msg.sender] = Position({
            isActive: true,
            ethForLoan: msg.value,
            arthFromLoan: arthFromLoan,
            arthInLendingPool: arthInLendingPool
        });

        // 5. Record the staking in the staking contract for maha rewards
        _stake(msg.sender, msg.value);

        // Send the dust back.
        // _flush(msg.sender);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(LoanParams memory loanParams) public payable nonReentrant {
        require(positions[msg.sender].isActive, "Position not open");

        // 1. Remove the position and withdraw you stake for stopping further rewards.
        Position memory position = positions[msg.sender];
        _withdraw(msg.sender, position.ethForLoan);
        delete positions[msg.sender];

        // 2. TODO- Claim the fees.

        // 3. Withdraw from the lending pool.
        uint256 arthWithdrawn = pool.withdraw(_arth, position.arthInLendingPool, me);

        // 4. Ensure that we received correct amount of arth to remove collateral from loan.
        require(arthWithdrawn >= position.arthFromLoan, "withdrawn is less");

        // 5. Adjust the trove, to remove collateral.
        borrowerOperations.adjustTrove(
            loanParams.maxFee,
            position.ethForLoan,
            arthWithdrawn,
            false,
            loanParams.upperHint,
            loanParams.lowerHint
        );

        // Send the dust back.
        // _flush(msg.sender);
        emit Withdrawal(msg.sender, position.ethForLoan);
    }

    function _flush(address to) internal {
        uint256 arthBalance = arth.balanceOf(me);
        if (arthBalance > 0) arth.transfer(to, arthBalance);

        uint256 ethBalance = me.balance;
        if (ethBalance > 0) {
            (
                bool success, /* bytes memory data */

            ) = to.call{value: ethBalance}("");
            require(success, "ETH transfer failed");
        }
    }

    function flush(address to) external {
        _flush(to);
    }

    function collectRewards() public payable nonReentrant {
        Position memory position = positions[msg.sender];
        require(position.isActive, "Position not open");
        _getReward();
    }

    /// @dev in case admin needs to execute some calls directly
    function emergencyCall(address target, bytes memory signature) external payable onlyOwner {
        (bool success, bytes memory response) = target.call{value: msg.value}(signature);
        require(success, string(response));
    }

    function lastGoodPrice() external view returns (uint256) {
        return priceFeed.lastGoodPrice();
    }
}
