// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {VersionedInitializable} from "../../proxy/VersionedInitializable.sol";
import {IBorrowerOperations} from "../../interfaces/IBorrowerOperations.sol";
import {StakingRewardsChild} from "../../staking/StakingRewardsChild.sol";
import {IPriceFeed} from "../../interfaces/IPriceFeed.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {ETHTroveData, ETHTroveLogic} from "./ETHTroveLogic.sol";

/**
 * @title ETHTroveStrategy
 * @author MahaDAO
 *
 * @notice A ETH staking contract that takes in ETH and uses it to mint ARTH and provide liquidity to MahaLend.
 * This strategy is a low risk strategy albeit some risks such as ETH price fluctuation and smart-contract bugs.
 * Most liquidity providers who participate in this strategy will be able to withdraw the
 * same amount of ETH that they provided.
 **/
contract ETHTroveStrategy is VersionedInitializable, StakingRewardsChild {
    using SafeMath for uint256;

    event Rebalance(
        address indexed src,
        uint256 wad,
        uint256 arthWad,
        uint256 arthBurntWad,
        uint256 price
    );
    event RevenueClaimed(uint256 wad);
    event PauseToggled(bool val);

    uint256 public minCollateralRatio;
    address private me;
    address private _arth;
    mapping(address => ETHTroveData.Position) public positions;

    IERC20 public arth;

    /// @dev the MahaLend lending pool
    ILendingPool public pool;

    /// @dev the ARTH price feed
    IPriceFeed public priceFeed;

    /// @dev Borrower operations for minting ARTH
    IBorrowerOperations public borrowerOperations;

    /// @dev the MahaLend aToken for ARTH.
    IERC20 public mArth;

    /// @dev for collection of revenue
    address public treasury;

    /// @dev to track how much interest this pool has earned.
    uint256 public totalmArthSupplied;

    /// @dev is the contract paused?
    bool public paused;

    function initialize(
        address _borrowerOperations,
        address __arth,
        address __maha,
        address _priceFeed,
        address _pool,
        uint256 _rewardsDuration,
        address _owner,
        address _treasury,
        uint256 _minCr
    ) external initializer {
        arth = IERC20(__arth);
        _arth = __arth;
        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        priceFeed = IPriceFeed(_priceFeed);
        pool = ILendingPool(_pool);

        arth.approve(_pool, type(uint256).max);
        arth.approve(_borrowerOperations, type(uint256).max);

        me = address(this);

        mArth = IERC20((pool.getReserveData(__arth)).aTokenAddress);
        minCollateralRatio = _minCr;
        treasury = _treasury;

        _stakingRewardsChildInit(__maha, _rewardsDuration, _owner);
        _transferOwnership(_owner);
    }

    function deposit(ETHTroveData.LoanParams memory loanParams) external payable nonReentrant {
        // Check that we are getting ETH.
        require(msg.value > 0, "no eth");
        require(!paused, "paused");

        uint256 mArthMinted = ETHTroveLogic.deposit(
            positions, // mapping(address => Position) memory positions
            loanParams, // LoanParams memory loanParams,
            ETHTroveLogic.DepositParams({
                priceFeed: priceFeed, // IPriceFeed priceFeed,
                minCollateralRatio: minCollateralRatio, // uint256 minCollateralRatio,
                borrowerOperations: borrowerOperations, // IBorrowerOperations borrowerOperations,
                mArth: mArth, // IERC20 mArth,
                me: me, // address me,
                pool: pool, // ILendingPool pool,
                arth: _arth // address _arth,
            })
        );

        totalmArthSupplied = totalmArthSupplied.add(mArthMinted);

        // Record the eth deposited in the staking contract for maha rewards
        _stake(msg.sender, msg.value);
    }

    function withdraw(ETHTroveData.LoanParams memory loanParams) external nonReentrant {
        require(!paused, "paused");
        _withdraw(msg.sender, positions[msg.sender].ethForLoan);

        uint256 arthInLendingPool = ETHTroveLogic.withdraw(
            positions, // mapping(address => Position) memory positions
            loanParams, // LoanParams memory loanParams,
            ETHTroveLogic.WithdrawParams({
                borrowerOperations: borrowerOperations, // IBorrowerOperations borrowerOperations,
                me: me, // address me,
                pool: pool, // ILendingPool pool,
                arth: _arth // address _arth,
            })
        );

        totalmArthSupplied = totalmArthSupplied.sub(arthInLendingPool);
    }

    function increase(ETHTroveData.LoanParams memory loanParams) external payable nonReentrant {
        // Check that we are getting ETH.
        require(msg.value > 0, "no eth");
        require(!paused, "paused");

        uint256 mArthMinted = ETHTroveLogic.increase(
            positions, // mapping(address => Position) memory positions
            loanParams, // LoanParams memory loanParams,
            ETHTroveLogic.DepositParams({
                priceFeed: priceFeed, // IPriceFeed priceFeed,
                minCollateralRatio: minCollateralRatio, // uint256 minCollateralRatio,
                borrowerOperations: borrowerOperations, // IBorrowerOperations borrowerOperations,
                mArth: mArth, // IERC20 mArth,
                me: me, // address me,
                pool: pool, // ILendingPool pool,
                arth: _arth // address _arth,
            })
        );

        // 4. and track how much mARTH was minted
        totalmArthSupplied = totalmArthSupplied.add(mArthMinted);

        // 6. Record the eth deposited in the staking contract for maha rewards
        _stake(msg.sender, msg.value);
    }

    /// @notice Send the revenue the strategy has generated to the treasury <3
    function collectRevenue() public {
        uint256 revenue = revenueMArth();
        mArth.transfer(treasury, revenue);
        _flush(treasury);
        emit RevenueClaimed(revenue);
    }

    /// --- Admin only functions

    /// @notice admin-only function to open a trove; needed to initialize the contract
    function openTrove(
        uint256 _maxFee,
        uint256 _arthAmount,
        address _upperHint,
        address _lowerHint
    ) external payable onlyOwner {
        require(msg.value > 0, "no eth");

        // Open the trove.
        borrowerOperations.openTrove{value: msg.value}(
            _maxFee,
            _arthAmount,
            _upperHint,
            _lowerHint,
            address(0)
        );

        // Send the dust back to owner.
        _flush(msg.sender);
    }

    /// @notice admin-only function to close the trove; normally not needed if the campaign keeps on running
    function closeTrove(uint256 arthNeeded) external payable onlyOwner {
        // Get the ARTH needed to close the loan.
        arth.transferFrom(msg.sender, me, arthNeeded);

        // Close the trove.
        borrowerOperations.closeTrove();

        // Send the dust back to owner.
        _flush(msg.sender);
    }

    /// @notice admin-only function in case admin needs to execute some calls directly
    function emergencyCall(address target, bytes memory signature) external payable onlyOwner {
        (bool success, bytes memory response) = target.call{value: msg.value}(signature);
        require(success, string(response));
    }

    /// @notice Emergency function to modify a position in case it has been corrupted.
    function modifyPosition(address who, ETHTroveData.Position memory position) external onlyOwner {
        positions[who] = position;
    }

    /// @notice Toggle pausing the contract in the event of any bugs
    function togglePause() external onlyOwner {
        paused = !paused;
        emit PauseToggled(paused);
    }

    /// @notice in case operator needs to rebalance the position for a particular user
    /// this function can be used.
    // TODO: make this publicly accessible somehow
    function rebalance(
        address who,
        ETHTroveData.LoanParams memory loanParams,
        uint256 arthToBurn
    ) external payable onlyOperator {
        require(positions[who].isActive, "!position");
        ETHTroveData.Position memory position = positions[who];

        // only allow a rebalance if the CR has fallen below the min CR
        uint256 price = priceFeed.fetchPrice();
        require(
            price.mul(position.ethForLoan).div(position.arthFromLoan) < minCollateralRatio,
            "cr healthy"
        );

        // 1. Reduce the stake
        position.arthFromLoan = position.arthFromLoan.sub(arthToBurn);

        // 2. Withdraw from the lending pool the amount of arth to burn.
        uint256 mArthBeforeLending = mArth.balanceOf(me);
        require(arthToBurn == pool.withdraw(_arth, arthToBurn, me), "!arthToBurn");

        // 3. update mARTH tracker variable
        totalmArthSupplied = totalmArthSupplied.sub(mArthBeforeLending.sub(mArth.balanceOf(me)));

        // 4. Adjust the trove, to remove collateral on behalf of the user
        borrowerOperations.adjustTrove(
            loanParams.maxFee,
            0,
            arthToBurn,
            false,
            loanParams.upperHint,
            loanParams.lowerHint
        );

        // now the new user has now been rebalanced
        emit Rebalance(who, position.ethForLoan, position.arthFromLoan, arthToBurn, price);
    }

    // --- View functions

    /// @notice Version number for upgradability
    function getRevision() public pure virtual override returns (uint256) {
        return 1;
    }

    /// @notice Returns how much mARTH revenue we have generated so far.
    function revenueMArth() public view returns (uint256 revenue) {
        // Since mARTH.balanceOf is always an increasing number,
        // this will always be positive.
        revenue = mArth.balanceOf(me) - totalmArthSupplied;
    }

    // TODO
    // /// @notice Returns how much mARTH revenue we have generated so far.
    // function arthInLending() public view returns (uint256 revenue) {
    //     // Since mARTH.balanceOf is always an increasing number,
    //     // this will always be positive.
    //     revenue = mArth.balanceOf(me) - totalmArthSupplied;
    // }

    // /// @notice Returns how much ARTH has been minted so far by the contract
    // function arthMinted() public view returns (uint256 revenue) {
    // }

    // --- Internal functions

    function _flush(address to) internal {
        uint256 arthBalance = arth.balanceOf(me);
        if (arthBalance > 0) arth.transfer(to, arthBalance);

        uint256 ethBalance = me.balance;
        if (ethBalance > 0) payable(to).transfer(ethBalance);
    }
}
