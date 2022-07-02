// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {IBorrowerOperations} from "../interfaces/IBorrowerOperations.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IZapDepositor} from "../interfaces/IZapDepositor.sol";
import {IStableSwap} from "../interfaces/IStableSwap.sol";
import {IDotDotLPStaker} from "../interfaces/IDotDotLPStaker.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// todo: need to take care of slippage

contract BNBDDDVault is Ownable {
    using SafeMath for uint256;

    IBorrowerOperations public borrowerOperations;
    ITroveManager public troveManager;

    IERC20 public ddd;
    IERC20 public epx;
    IERC20 public arth;
    IERC20 public arthEPXLP;
    IERC20Wrapper public arthUsd;

    IZapDepositor public epxZapper;
    IStableSwap public arthEPXStableSwap;

    IDotDotLPStaker public dddLocker;
    address public factory;
    address private me;

    uint256 private infinity = 0xffff;

    constructor(
        address _ddd,
        address _epx,
        address _dddLocker,
        address _arthUsd,
        address _arthEPXLP,
        address _arthEPXStableSwap,
        address _epxZapper,
        address _borrowerOperations,
        address _troveManager,
        address _owner
    ) {
        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        troveManager = ITroveManager(_troveManager);

        ddd = IERC20(_ddd);
        arth = IERC20(troveManager.arthToken());
        epx = IERC20(_epx);
        arthUsd = IERC20Wrapper(_arthUsd);
        arthEPXLP = IERC20(_arthEPXLP);

        dddLocker = IDotDotLPStaker(_dddLocker);
        arthEPXStableSwap = IStableSwap(_arthEPXStableSwap);
        epxZapper = IZapDepositor(_epxZapper);

        factory = msg.sender;

        me = address(this);
        _transferOwnership(_owner);

        // give infinite approvals to save on gas
        arth.approve(address(arthUsd), infinity);
        arthUsd.approve(address(arthEPXStableSwap), infinity);
        arthEPXLP.approve(address(dddLocker), infinity);
    }

    modifier onlyFactoryOrOwner() {
        require(msg.sender == factory || msg.sender == owner(), "only factory or owner");
        _;
    }

    function deposit() external payable onlyFactoryOrOwner {
        uint256 arth200cr = 0;
        uint256 maxFee = 0;
        address upperHint;
        address lowerHint;
        address borrower = owner();

        // mint arth
        if (troveManager.getTroveColl(borrower) == 0) {
            borrowerOperations.openTrove(maxFee, arth200cr, upperHint, lowerHint, address(0));
        }
        arthUsd.deposit(arth.balanceOf(me));

        // add liquidity to EPX
        uint256[] memory depositAmounts = new uint256[](2);
        depositAmounts[0] = arth.balanceOf(me);
        arthEPXStableSwap.add_liquidity(depositAmounts, 0);

        // stake on DotDot
        dddLocker.deposit(borrower, address(arthEPXLP), arthEPXLP.balanceOf(me));
        _flush();
    }

    function withdraw(uint256 amount) external onlyFactoryOrOwner {
        uint256 arth200cr = 0;
        uint256 maxFee = 0;
        address upperHint;
        address lowerHint;

        address borrower = owner();

        // unstake on DotDot
        dddLocker.withdraw(
            borrower,
            address(arthEPXLP),
            dddLocker.userBalances(me, address(arthEPXLP))
        );

        // remove liquidity to EPX
        arthEPXStableSwap.remove_liquidity_one_coin(arthEPXLP.balanceOf(me), 0, 0);

        // burn arth and close loan
        arthUsd.withdraw(arthUsd.balanceOf(me).mul(2));
        borrowerOperations.closeTrove(); // todo need to have enough arth to close loans

        _flush();
    }

    function getReward() external onlyFactoryOrOwner returns (bytes32) {}

    function earned() external view returns (IDotDotLPStaker.Amounts[] memory) {
        address[] memory tokens = new address[](1);
        tokens[0] = address(arthEPXLP);

        return dddLocker.claimable(owner(), tokens);
    }

    function balanceOf() external view returns (IDotDotLPStaker.ExtraReward[] memory) {
        IDotDotLPStaker.ExtraReward[] memory tokens = new IDotDotLPStaker.ExtraReward[](3);
        address borrower = owner();

        tokens[0] = IDotDotLPStaker.ExtraReward({
            token: address(0),
            amount: troveManager.getTroveColl(borrower)
        });

        tokens[1] = IDotDotLPStaker.ExtraReward({
            token: address(arth),
            amount: troveManager.getTroveDebt(borrower)
        });

        tokens[2] = IDotDotLPStaker.ExtraReward({
            token: address(arth),
            amount: troveManager.getTroveDebt(borrower)
        });

        return tokens;
    }

    function _flush() internal {
        address to = owner();
        if (arth.balanceOf(me) > 0) arth.transfer(to, arth.balanceOf(me));
        if (ddd.balanceOf(me) > 0) ddd.transfer(to, ddd.balanceOf(me));
        if (epx.balanceOf(me) > 0) epx.transfer(to, epx.balanceOf(me));
        if (arthEPXLP.balanceOf(me) > 0) arthEPXLP.transfer(to, arthEPXLP.balanceOf(me));
        if (arthUsd.balanceOf(me) > 0) arthUsd.transfer(to, arthUsd.balanceOf(me));
    }
}
