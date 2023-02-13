const { ADDRESSES } = require('../common/constants.js');
const { Token, SupportedChainId } = require('@uniswap/sdk-core')
const { Pool } = require('@uniswap/v3-sdk/')
// const { ethers } = require('ethers')
const { ethers } = require('hardhat')
const { createTrade, sellETHForUSDC, sellARTH, depositAndBorrow } = require("./trading")

const IUniswapV3PoolABI = require('@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json')
const ERC20ABI = require("../common/abi/ERC20.json")
const { CHAINLINK_ABI } = require('../common/abi/chainlinkABI.js');
const { TroveManagerABI } = require('../common/abi/troveManagerABI.js');
const PriceFeedABI = require('../common/abi/PriceFeed.json')
const HintHelpersABI = require('../common/abi/HintHelpers.json')
const SortedTrovesABI = require("../common/abi/SortedTroves.json")
const BorrowerABI = require("../common/abi/BorrowerOperationABI.json")

const ETH_NETWORK = SupportedChainId.MAINNET;
const NETWORK = 'MAINNET';
const ARTH = new Token(ETH_NETWORK, ADDRESSES[NETWORK]['ARTH'], 18);
const WETH = new Token(ETH_NETWORK, ADDRESSES[NETWORK]['WETH'], 18);

const POINT_TWO_ETH = ethers.BigNumber.from('200000000000000000');
const PART_OF_ARTH_POOL_TO_USE = ethers.BigNumber.from(8); // 8th of the liquidity reserve will be used (12.5%)
const UNISWAP_ARTH_PROVIDER_FEE = 0.003;

const arbitrageStatus = async (wallet) => {
	const poolContract = await ethers.getContractAt(IUniswapV3PoolABI.abi, ADDRESSES['MAINNET']['POOL'], wallet);
	
	const { 
		// trade, 
		ethForSwap, 
		// populatedRedemption
	} = 
	await getFeasibleTrade(
		poolContract,
		wallet
	);
	const { uniswapPrice, chainLinkPrice, redemptionFee } = await fetchPrices(
		wallet,
		poolContract,
	);

	const priceRatio = uniswapPrice / chainLinkPrice;
	const ethUsed = parseFloat(ethers.utils.formatEther(ethForSwap));
	const ethAfterArbitrage =
	ethUsed * priceRatio * (1 - redemptionFee) * (1 - UNISWAP_ARTH_PROVIDER_FEE);
	const profit = ethAfterArbitrage - ethUsed;
	
	if(ethUsed > 0 && priceRatio < 0.985)  {  // run first strategy
		console.log('UNISWAP Price:%s', uniswapPrice.toString());
		console.log('Chainlink Price %s', chainLinkPrice.toString());
		console.log('Redemption fee: %s', redemptionFee.toString());
		console.log('Eth used: %s', ethers.utils.formatUnits(ethForSwap.toString(), 'ether'));

		console.log('After Arbitrage(without fees): %d', priceRatio * ethUsed);
		console.log('After arbitrage: %d eth', ethAfterArbitrage);
		console.log('Est. total profit(w/o gas): %d', profit);

		return {
			status: 1,
			amountIn: ethForSwap,
			// populatedRedemption: populatedRedemption,
			profit: profit,
		};
	} else if(ethUsed > 0 && priceRatio > 1.03) {
		console.log('UNISWAP Price:%s', uniswapPrice.toString());
		console.log('Chainlink Price %s', chainLinkPrice.toString());
		console.log('Redemption fee: %s', redemptionFee.toString());
		console.log('Eth used: %s', ethers.utils.formatUnits(ethForSwap.toString(), 'ether'));

		console.log('After Arbitrage(without fees): %d', priceRatio * ethUsed);
		console.log('After arbitrage: %d eth', ethAfterArbitrage);
		console.log('Est. total profit(w/o gas): %d', profit);

		return {
			status: 2,
			amountIn: ethForSwap,
			// populatedRedemption: populatedRedemption,
			profit: profit,
		};
	} else {
		return {
			status: 0,
			amountIn: ethForSwap,
			// populatedRedemption: populatedRedemption,
			profit: profit,
		};
	}
};

const getFeasibleTrade = async (pair, wallet) => {
	// const ethUniswapReserve = toBN(toWei(pair.reserve0.toSignificant(8), 'Mwei')).div(
	// 	PART_OF_ARTH_POOL_TO_USE
	// );
	const ERC20Contract = new ethers.Contract(WETH.address, ERC20ABI, wallet);
	const ethUniswapReserve = (await ERC20Contract.balanceOf(pair.address)).div(
		PART_OF_ARTH_POOL_TO_USE
	);
	const ethBalanceInWallet = await wallet.getBalance();

	let ethTradeAmout;
	if (ethBalanceInWallet.lt(ethUniswapReserve)) {
		// if(ethBalanceInWallet.gt(POINT_TWO_ETH))
			ethTradeAmout = ethBalanceInWallet.sub(POINT_TWO_ETH); // To keep some spare eth for gas prices
		// else ethTradeAmout = ethers.BigNumber.from("0");
	} else {
		ethTradeAmout = ethUniswapReserve;
	}

	console.log("----ethTradeAmount----", ethTradeAmout.toString())

	return {
		// trade: trade,
		ethForSwap: ethTradeAmout,
		// populatedRedemption: populatedRedemption,
	};
};

const fetchPrices = async (wallet, pair) => {
	const priceFeed = await ethers.getContractAt(CHAINLINK_ABI, ADDRESSES[NETWORK]['CHAINLINK']);

	const roundData = await priceFeed.latestRoundData();

	const chainLinkPrice = roundData['answer'];
	// const outputAmount = toBN(toWei(trade.outputAmount.toFixed(), 'Mwei'));

	const immutables = await getPoolImmutables(pair);
    const state = await getPoolState(pair);

    //create a pool
    const POOL = new Pool(
      WETH,
      ARTH,
      immutables.fee,
      state.sqrtPriceX96.toString(),
      state.liquidity.toString(),
      state.tick
    );
    const price1 = POOL.token0Price;
	const WETH_priceFeed = await ethers.getContractAt(CHAINLINK_ABI, ADDRESSES[NETWORK]['CHAINLINK_WETH']);

	const data = await WETH_priceFeed.latestRoundData();

	const ethPrice = data['answer'];
	const p = parseFloat(price1.toFixed(8)) * parseInt(ethPrice.toString()) / 100000000;

	const troveManager = await ethers.getContractAt(TroveManagerABI, ADDRESSES[NETWORK]['TroveManager']);
	const redemptionFeeInWei = await troveManager.getRedemptionRate();
	return {
		uniswapPrice: p,
		// uniswapPrice: outputAmount.div(ethForSwap).toNumber(),
		chainLinkPrice: parseInt(chainLinkPrice.toString()) / 100000000,
		redemptionFee: parseFloat(ethers.utils.formatEther(redemptionFeeInWei)),
	};
};

async function getPoolImmutables(poolContract) {
    const immutables = {
      factory: await poolContract.factory(),
      token0: await poolContract.token0(),
      token1: await poolContract.token1(),
      fee: await poolContract.fee(),
      tickSpacing: await poolContract.tickSpacing(),
      maxLiquidityPerTick: await poolContract.maxLiquidityPerTick(),
    };
    return immutables;
  }

  async function getPoolState(poolContract) {
    const slot = await poolContract.slot0();
    const PoolState = {
      liquidity: await poolContract.liquidity(),
      sqrtPriceX96: slot[0],
      tick: slot[1],
      observationIndex: slot[2],
      observationCardinality: slot[3],
      observationCardinalityNext: slot[4],
      feeProtocol: slot[5],
      unlocked: slot[6],
    };
    return PoolState;
  }

  async function getNetBorrowingAmount(contracts, debtWithFee) {
    const borrowingRate = await contracts.troveManager.getBorrowingRateWithDecay();
    return ethers.BigNumber.from(debtWithFee)
      .mul("1000000000000000000")
      .div(ethers.BigNumber.from("1000000000000000000").add(borrowingRate));
  }

  function dec(val, scale) {
    let zerosCount;

    if (scale == "ether") {
      zerosCount = 18;
    } else if (scale == "finney") zerosCount = 15;
    else {
      zerosCount = scale;
    }

    const strVal = val.toString();
    const strZeros = "0".repeat(zerosCount);

    return strVal.concat(strZeros);
  }

  async function getOpenTroveTotalDebt(contracts, arthAmount) {
    const fee = await contracts.troveManager.getBorrowingFee(arthAmount);
    const compositeDebt = await contracts.borrowerOperations.getCompositeDebt(arthAmount);
    return compositeDebt.add(fee);
  }

  async function openTrove(
    contracts,
	price,
    { maxFeePercentage, extraARTHAmount, upperHint, lowerHint, ICR, extraParams }
  ) {
    if (!maxFeePercentage) maxFeePercentage = "1000000000000000000";
    if (!extraARTHAmount) extraARTHAmount = ethers.BigNumber.from(0);
    else if (typeof extraARTHAmount == "string") extraARTHAmount = ethers.BigNumber.from(extraARTHAmount);
    if (!upperHint) upperHint = "0x" + "0".repeat(40);
    if (!lowerHint) lowerHint = "0x" + "0".repeat(40);

    const MIN_DEBT = (
      await getNetBorrowingAmount(contracts, await contracts.borrowerOperations.MIN_NET_DEBT())
    )
    const arthAmount = MIN_DEBT.add(extraARTHAmount);
    if (!ICR && !extraParams.value) ICR = ethers.BigNumber.from(dec(15, 17));
    // 150%
    else if (typeof ICR == "string") ICR = ethers.BigNumber.from(ICR);
    const totalDebt = await getOpenTroveTotalDebt(contracts, arthAmount);
    if (ICR) {
      extraParams.value = ICR.mul(totalDebt).div(price);
    }
    const tx = await (contracts.borrowerOperations).openTrove(
      maxFeePercentage,
      arthAmount,
      upperHint,
      lowerHint,
      "0x" + "0".repeat(40),
      extraParams
    );

    return {
      arthAmount,
      totalDebt,
      ICR,
      collateral: extraParams.value,
      tx
    };
  }

const executeArbitrage = async (amountIn, wallet) => {
	try{
		const tradingResult = await createTrade(wallet, amountIn);
		if( tradingResult.isZero() === false ) {
			// redeem ARTH using TroveManager
			const troveManager = await ethers.getContractAt(TroveManagerABI, ADDRESSES[NETWORK]['TroveManager'], wallet);
			const priceFeed = await ethers.getContractAt(PriceFeedABI, ADDRESSES[NETWORK]['PRICEFEED'], wallet);
			const hintHelpers = await ethers.getContractAt(HintHelpersABI, ADDRESSES[NETWORK]['HINTHELPERS'], wallet);
			const sortedTroves = await ethers.getContractAt(SortedTrovesABI, ADDRESSES[NETWORK]['SortedTroves'], wallet);
			const borrowerOperation = await ethers.getContractAt(BorrowerABI, ADDRESSES[NETWORK]['BorrowerOperation'], wallet);

			const contracts = {
				troveManager: troveManager,
				priceFeed: priceFeed,
				borrowerOperations: borrowerOperation
			}



			let price = await priceFeed.fetchPrice();
			let tx = await price.wait()

			console.log("------price-----", tx.events[tx.events.length-1].args._lastGoodPrice.toString())
			// Find hints for redeeming 20 ARTH
			price = tx.events[tx.events.length-1].args._lastGoodPrice.toString();

			await openTrove(contracts, price, {
				extraARTHAmount: tradingResult.toString(),
				extraParams: {  },
			  });
			
			// // skip bootstrapping phase
			// await th.fastForwardTime(timeValues.SECONDS_IN_ONE_WEEK * 2, web3.currentProvider);

			// Don't pay for gas, as it makes it easier to calculate the received Ether

			const { partialRedemptionHintNICR } = await hintHelpers.getRedemptionHints(
				tradingResult,
				price,
				0
			);
			// We don't need to use getApproxHint for this test, since it's not the subject of this
			// test case, and the list is very small, so the correct position is quickly found
			const {
			0: upperPartialRedemptionHint,
			1: lowerPartialRedemptionHint
			} = await sortedTroves.findInsertPosition(partialRedemptionHintNICR, wallet.address, wallet.address);
			
			console.log("==============before ETH=========", (await wallet.provider.getBalance(wallet.address)).toString())
			await troveManager.redeemCollateral(
				tradingResult,
				"0x" + "0".repeat(40), // invalid first hint
				upperPartialRedemptionHint,
				lowerPartialRedemptionHint,
				partialRedemptionHintNICR,
				0,
				"1000000000000000000"
			);
			console.log("==============after ETH=========", (await wallet.provider.getBalance(wallet.address)).toString())
		} else {
			console.log("Fail in trading Uniswap V3")
			return;
		}
	} catch(e) {
		console.log("Error in trading Uniswap V3:", e)
		return;
	}
};

const executeArbitrageAbovePeg = async (amountIn, wallet) => {
	try{
		const USDCAmount = await sellETHForUSDC(wallet, amountIn);
		const ArthAmount = await depositAndBorrow(wallet, USDCAmount)
		await sellARTH(wallet, ArthAmount)
		
	} catch(e) {
		console.log("Error in trading Uniswap V3:", e)
		return;
	}
};

exports.arbitrageStatus = arbitrageStatus;
exports.executeArbitrage = executeArbitrage;
exports.executeArbitrageAbovePeg = executeArbitrageAbovePeg;
exports.getFeasibleTrade = getFeasibleTrade;
