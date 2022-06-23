// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {IBorrowerOperations} from "../interfaces/IBorrowerOperations.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BNBDDDVault is Ownable {
    using SafeMath for uint256;

    IBorrowerOperations public borrowerOperations;
    ITroveManager public troveManager;

    IERC20 public ddd;
    IERC20 public epx;
    IERC20 public arth;
    IERC20 public arthEPXLP;
    IERC20Wrapper public arthUsd;

    address public arthEPXStableSwap;
    address public dddLocker;
    address public factory;
    address private me;

    constructor(
        address _ddd,
        address _epx,
        address _dddLocker,
        address _arthUsd,
        address _arthEPXLP,
        address _arthEPXStableSwap,
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

        dddLocker = _dddLocker;
        arthEPXStableSwap = _arthEPXStableSwap;
        factory = msg.sender;

        me = address(this);
        _transferOwnership(_owner);
    }

    modifier onlyFactoryOrOwner() {
        require(msg.sender == factory || msg.sender == owner(), "only factory or owner");
        _;
    }

    function deposit() external payable onlyFactoryOrOwner {
        _flush();
    }

    function withdraw(uint256 amount) external onlyFactoryOrOwner {
        _flush();
    }

    function getReward() external onlyFactoryOrOwner returns (bytes32) {}

    function earned() external view returns (uint256) {
        return 0;
    }

    function balanceOf() external view returns (uint256) {
        return 0;
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
