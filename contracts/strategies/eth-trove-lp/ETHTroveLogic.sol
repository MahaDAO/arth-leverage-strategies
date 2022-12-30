// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {IBorrowerOperations} from "../../interfaces/IBorrowerOperations.sol";
import {IPriceFeed} from "../../interfaces/IPriceFeed.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {ETHTroveData} from "./ETHTroveData.sol";

library ETHTroveLogic {
    using SafeMath for uint256;

    event Deposit(address indexed src, uint256 wad, uint256 arthWad, uint256 price);
    event Rebalance(
        address indexed src,
        uint256 wad,
        uint256 arthWad,
        uint256 arthBurntWad,
        uint256 price
    );
    event Withdrawal(address indexed dst, uint256 wad, uint256 arthWad);
    event RevenueClaimed(uint256 wad);
    event PauseToggled(bool val);

    struct DepositParams {
        IPriceFeed priceFeed;
        uint256 minCollateralRatio;
        IBorrowerOperations borrowerOperations;
        IERC20 mArth;
        address me;
        ILendingPool pool;
        address arth;
    }

    function deposit(
        mapping(address => ETHTroveData.Position) storage positions,
        ETHTroveData.LoanParams memory loanParams,
        DepositParams memory params
    ) public returns (uint256 _mArthMinted) {
        // Check that position is not already open.
        require(!positions[msg.sender].isActive, "Position already open");

        // Check that min. cr for the strategy is met.
        // Important! If this check is not there then a user can possibly
        // manipulate the trove.
        uint256 price = params.priceFeed.fetchPrice();
        require(
            price.mul(msg.value).div(loanParams.arthAmount) >= params.minCollateralRatio,
            "min CR not met"
        );

        // 2. Mint ARTH
        params.borrowerOperations.adjustTrove{value: msg.value}(
            loanParams.maxFee,
            0, // No coll withdrawal.
            loanParams.arthAmount, // Mint ARTH.
            true, // Debt increasing.
            loanParams.upperHint,
            loanParams.lowerHint
        );

        // 3. Supply ARTH in the lending pool
        uint256 mArthBeforeLending = params.mArth.balanceOf(params.me);
        params.pool.supply(
            params.arth,
            loanParams.arthAmount,
            params.me, // On behalf of this contract
            0
        );

        // 4. and track how much mARTH was minted
        uint256 mArthAfterLending = params.mArth.balanceOf(params.me);
        _mArthMinted = mArthAfterLending.sub(mArthBeforeLending);

        // 5. Record the position.
        positions[msg.sender] = ETHTroveData.Position({
            isActive: true,
            ethForLoan: msg.value,
            arthFromLoan: loanParams.arthAmount,
            arthInLendingPool: _mArthMinted
        });

        emit Deposit(msg.sender, msg.value, loanParams.arthAmount, price);
    }

    struct WithdrawParams {
        IBorrowerOperations borrowerOperations;
        address me;
        ILendingPool pool;
        address arth;
    }

    function withdraw(
        mapping(address => ETHTroveData.Position) storage positions,
        ETHTroveData.LoanParams memory loanParams,
        WithdrawParams memory params
    ) external returns (uint256) {
        require(positions[msg.sender].isActive, "Position not open");

        // 1. Remove the position and withdraw the stake for stopping further rewards.
        ETHTroveData.Position memory position = positions[msg.sender];
        delete positions[msg.sender];

        // 2. Withdraw from the lending pool.
        // 3. Ensure that we received correct amount of arth
        require(
            params.pool.withdraw(params.arth, position.arthFromLoan, params.me) ==
                position.arthFromLoan,
            "arth withdrawn != loan position"
        );

        // 4. Adjust the trove, remove ETH on behalf of the user and burn the
        // ARTH that was minted.
        params.borrowerOperations.adjustTrove(
            loanParams.maxFee,
            position.ethForLoan,
            position.arthFromLoan,
            false,
            loanParams.upperHint,
            loanParams.lowerHint
        );

        // 5. The contract now has eth inside it. Send it back to the user
        payable(msg.sender).transfer(position.ethForLoan);

        emit Withdrawal(msg.sender, position.ethForLoan, position.arthFromLoan);
        return position.arthInLendingPool;
    }

    function increase(
        mapping(address => ETHTroveData.Position) storage positions,
        ETHTroveData.LoanParams memory loanParams,
        DepositParams memory params
    ) external returns (uint256 mArthMinted) {
        // Check that position is already open.
        ETHTroveData.Position memory position = positions[msg.sender];
        require(position.isActive, "Position not open");

        // Check that min. cr for the strategy is met.
        uint256 price = params.priceFeed.fetchPrice();
        require(
            price.mul(msg.value).div(loanParams.arthAmount) >= params.minCollateralRatio,
            "min CR not met"
        );

        // 2. Mint ARTH and track ARTH balance changes due to this current tx.
        params.borrowerOperations.adjustTrove{value: msg.value}(
            loanParams.maxFee,
            0, // No coll withdrawal.
            loanParams.arthAmount, // Mint ARTH.
            true, // Debt increasing.
            loanParams.upperHint,
            loanParams.lowerHint
        );

        // 3. Supply ARTH in the lending pool
        uint256 mArthBeforeLending = params.mArth.balanceOf(params.me);
        params.pool.supply(
            params.arth,
            loanParams.arthAmount,
            params.me, // On behalf of this contract
            0
        );

        // 4. and track how much mARTH was minted
        uint256 mArthAfterLending = params.mArth.balanceOf(params.me);
        mArthMinted = mArthAfterLending.sub(mArthBeforeLending);

        // 5. Update the position.
        positions[msg.sender] = ETHTroveData.Position({
            isActive: true,
            ethForLoan: position.ethForLoan.add(msg.value),
            arthFromLoan: position.arthFromLoan.add(loanParams.arthAmount),
            arthInLendingPool: position.arthInLendingPool.add(mArthMinted)
        });

        emit Deposit(msg.sender, msg.value, loanParams.arthAmount, price);
    }

    // /// @notice in case operator needs to rebalance the position for a particular user
    // /// this function can be used.
    // // TODO: make this publicly accessible somehow
    // function rebalance(
    //     address who,
    //     LoanParams memory loanParams,
    //     uint256 arthToBurn
    // ) external payable {
    //     require(positions[who].isActive, "!position");
    //     Position memory position = positions[who];

    //     // only allow a rebalance if the CR has fallen below the min CR
    //     uint256 price = priceFeed.fetchPrice();
    //     require(
    //         price.mul(position.ethForLoan).div(position.arthFromLoan) < minCollateralRatio,
    //         "cr healthy"
    //     );

    //     // 1. Reduce the stake
    //     position.arthFromLoan = position.arthFromLoan.sub(arthToBurn);

    //     // 2. Withdraw from the lending pool the amount of arth to burn.
    //     uint256 mArthBeforeLending = mArth.balanceOf(me);
    //     require(arthToBurn == pool.withdraw(_arth, arthToBurn, me), "!arthToBurn");

    //     // 3. update mARTH tracker variable
    //     totalmArthSupplied = totalmArthSupplied.sub(mArthBeforeLending.sub(mArth.balanceOf(me)));

    //     // 4. Adjust the trove, to remove collateral on behalf of the user
    //     borrowerOperations.adjustTrove(
    //         loanParams.maxFee,
    //         0,
    //         arthToBurn,
    //         false,
    //         loanParams.upperHint,
    //         loanParams.lowerHint
    //     );

    //     // now the new user has now been rebalanced
    //     emit Rebalance(who, position.ethForLoan, position.arthFromLoan, arthToBurn, price);
    // }

    // --- View functions
}
