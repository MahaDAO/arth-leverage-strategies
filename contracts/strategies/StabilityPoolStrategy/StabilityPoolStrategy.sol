// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "../../interfaces/AggregatorV3Interface.sol";
import {CropJoinAdapter} from "./CropJoinAdapter.sol";
import {IPriceFeed} from "../../interfaces/IPriceFeed.sol";
import {IStabilityPool} from "../../interfaces/IStabilityPool.sol";
import {PriceFormula} from "./PriceFormula.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StabilityPoolStrategy is CropJoinAdapter, PriceFormula, Ownable {
    using SafeMath for uint256;

    AggregatorV3Interface public immutable priceAggregator;
    AggregatorV3Interface public immutable arth2UsdPriceAggregator;
    IERC20 public immutable ARTH;
    IStabilityPool public immutable SP;

    address payable public immutable feePool;
    uint256 public constant MAX_FEE = 100; // 1%
    uint256 public fee = 0; // fee in bps
    uint256 public A = 20;
    uint256 public constant MIN_A = 20;
    uint256 public constant MAX_A = 200;

    uint256 public immutable maxDiscount; // max discount in bips

    address public immutable frontEndTag;
    uint256 public constant PRECISION = 1e18;

    event ParamsSet(uint256 A, uint256 fee);
    event UserDeposit(address indexed user, uint256 arthAmount, uint256 numShares);
    event UserWithdraw(
        address indexed user,
        uint256 arthAmount,
        uint256 ethAmount,
        uint256 numShares
    );
    event RebalanceSwap(
        address indexed user,
        uint256 arthAmount,
        uint256 ethAmount,
        uint256 timestamp
    );

    constructor(
        address _priceAggregator,
        address _arth2UsdPriceAggregator,
        address payable _SP,
        address _ARTH,
        address _MAHA,
        uint256 _maxDiscount,
        address payable _feePool,
        address _fronEndTag
    ) public CropJoinAdapter(_MAHA) {
        priceAggregator = AggregatorV3Interface(_priceAggregator);
        arth2UsdPriceAggregator = AggregatorV3Interface(_arth2UsdPriceAggregator);
        ARTH = IERC20(_ARTH);
        SP = IStabilityPool(_SP);

        feePool = _feePool;
        maxDiscount = _maxDiscount;
        frontEndTag = _fronEndTag;
    }

    function setParams(uint256 _A, uint256 _fee) external onlyOwner {
        require(_fee <= MAX_FEE, "setParams: fee is too big");
        require(_A >= MIN_A, "setParams: A too small");
        require(_A <= MAX_A, "setParams: A too big");

        fee = _fee;
        A = _A;

        emit ParamsSet(_A, _fee);
    }

    function fetchPrice() public view returns (uint256) {
        uint256 chainlinkDecimals;
        uint256 chainlinkLatestAnswer;
        uint256 chainlinkTimestamp;

        // First, try to get current decimal precision:
        try priceAggregator.decimals() returns (uint8 decimals) {
            // If call to Chainlink succeeds, record the current decimal precision
            chainlinkDecimals = decimals;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return 0;
        }

        // Secondly, try to get latest price data:
        try priceAggregator.latestRoundData() returns (
            uint80, /* roundId */
            int256 answer,
            uint256, /* startedAt */
            uint256 timestamp,
            uint80 /* answeredInRound */
        ) {
            // If call to Chainlink succeeds, return the response and success = true
            chainlinkLatestAnswer = uint256(answer);
            chainlinkTimestamp = timestamp;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return 0;
        }

        if (chainlinkTimestamp + 1 hours < now) return 0; // price is down

        uint256 chainlinkFactor = 10**chainlinkDecimals;
        return chainlinkLatestAnswer.mul(PRECISION) / chainlinkFactor;
    }

    function deposit(uint256 arthAmount) external {
        // update share
        uint256 arthValue = SP.getCompoundedARTHDeposit(address(this));
        uint256 ethValue = SP.getDepositorETHGain(address(this)).add(address(this).balance);

        uint256 price = fetchPrice();
        require(ethValue == 0 || price > 0, "deposit: chainlink is down");

        uint256 totalValue = arthValue.add(ethValue.mul(price) / PRECISION);

        // this is in theory not reachable. if it is, better halt deposits
        // the condition is equivalent to: (totalValue = 0) ==> (total = 0)
        require(totalValue > 0 || total == 0, "deposit: system is rekt");

        uint256 newShare = PRECISION;
        if (total > 0) newShare = total.mul(arthAmount) / totalValue;

        // deposit
        require(
            ARTH.transferFrom(msg.sender, address(this), arthAmount),
            "deposit: transferFrom failed"
        );
        SP.provideToSP(arthAmount, frontEndTag);

        // update LP token
        mint(msg.sender, newShare);

        emit UserDeposit(msg.sender, arthAmount, newShare);
    }

    function withdraw(uint256 numShares) external {
        uint256 arthValue = SP.getCompoundedARTHDeposit(address(this));
        uint256 ethValue = SP.getDepositorETHGain(address(this)).add(address(this).balance);

        uint256 arthAmount = arthValue.mul(numShares).div(total);
        uint256 ethAmount = ethValue.mul(numShares).div(total);

        // this withdraws arth, maha, and eth
        SP.withdrawFromSP(arthAmount);

        // update LP token
        burn(msg.sender, numShares);

        // send arth and eth
        if (arthAmount > 0) ARTH.transfer(msg.sender, arthAmount);
        if (ethAmount > 0) {
            (bool success, ) = msg.sender.call{value: ethAmount}(""); // re-entry is fine here
            require(success, "withdraw: sending ETH failed");
        }

        emit UserWithdraw(msg.sender, arthAmount, ethAmount, numShares);
    }

    function addBps(uint256 n, int256 bps) internal pure returns (uint256) {
        require(bps <= 10000, "reduceBps: bps exceeds max");
        require(bps >= -10000, "reduceBps: bps exceeds min");

        return n.mul(uint256(10000 + bps)) / 10000;
    }

    function compensateForArthDeviation(uint256 ethAmount)
        public
        view
        returns (uint256 newEthAmount)
    {
        uint256 chainlinkDecimals;
        uint256 chainlinkLatestAnswer;

        // get current decimal precision:
        chainlinkDecimals = arth2UsdPriceAggregator.decimals();

        // Secondly, try to get latest price data:
        (, int256 answer, , , ) = arth2UsdPriceAggregator.latestRoundData();
        chainlinkLatestAnswer = uint256(answer);

        // adjust only if 1 ARTH > 1 USDC. If ARTH < USD, then we give a discount, and rebalance will happen anw
        if (chainlinkLatestAnswer > 10**chainlinkDecimals) {
            newEthAmount = ethAmount.mul(chainlinkLatestAnswer) / (10**chainlinkDecimals);
        } else newEthAmount = ethAmount;
    }

    function getSwapEthAmount(uint256 arthQty)
        public
        view
        returns (uint256 ethAmount, uint256 feeArthAmount)
    {
        uint256 arthBalance = SP.getCompoundedARTHDeposit(address(this));
        uint256 ethBalance = SP.getDepositorETHGain(address(this)).add(address(this).balance);

        uint256 eth2usdPrice = fetchPrice();
        if (eth2usdPrice == 0) return (0, 0); // chainlink is down

        uint256 ethUsdValue = ethBalance.mul(eth2usdPrice) / PRECISION;
        uint256 maxReturn = addBps(arthQty.mul(PRECISION) / eth2usdPrice, int256(maxDiscount));

        uint256 xQty = arthQty;
        uint256 xBalance = arthBalance;
        uint256 yBalance = arthBalance.add(ethUsdValue.mul(2));

        uint256 usdReturn = getReturn(xQty, xBalance, yBalance, A);
        uint256 basicEthReturn = usdReturn.mul(PRECISION) / eth2usdPrice;

        basicEthReturn = compensateForArthDeviation(basicEthReturn);

        if (ethBalance < basicEthReturn) basicEthReturn = ethBalance; // cannot give more than balance
        if (maxReturn < basicEthReturn) basicEthReturn = maxReturn;

        ethAmount = basicEthReturn;
        feeArthAmount = addBps(arthQty, int256(fee)).sub(arthQty);
    }

    // get ETH in return to ARTH
    function swap(
        uint256 arthAmount,
        uint256 minEthReturn,
        address payable dest
    ) public returns (uint256) {
        (uint256 ethAmount, uint256 feeAmount) = getSwapEthAmount(arthAmount);

        require(ethAmount >= minEthReturn, "swap: low return");

        ARTH.transferFrom(msg.sender, address(this), arthAmount);
        SP.provideToSP(arthAmount.sub(feeAmount), frontEndTag);

        if (feeAmount > 0) ARTH.transfer(feePool, feeAmount);
        (bool success, ) = dest.call{value: ethAmount}(""); // re-entry is fine here
        require(success, "swap: sending ETH failed");

        emit RebalanceSwap(msg.sender, arthAmount, ethAmount, now);

        return ethAmount;
    }

    // kyber network reserve compatible function
    function trade(
        IERC20, /* srcToken */
        uint256 srcAmount,
        IERC20, /* destToken */
        address payable destAddress,
        uint256, /* conversionRate */
        bool /* validate */
    ) external payable returns (bool) {
        return swap(srcAmount, 0, destAddress) > 0;
    }

    function getConversionRate(
        IERC20, /* src */
        IERC20, /* dest */
        uint256 srcQty,
        uint256 /* blockNumber */
    ) external view returns (uint256) {
        (uint256 ethQty, ) = getSwapEthAmount(srcQty);
        return ethQty.mul(PRECISION) / srcQty;
    }

    receive() external payable {}
}
