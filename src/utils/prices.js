const { ADDRESSES } = require('../common/constants.js');
const { TroveManagerABI } = require('../common/abi/troveManagerABI.js');
const { CHAINLINK_ABI } = require('../common/abi/chainlinkABI.js');
const { Token, SupportedChainId } = require('@uniswap/sdk-core')
const { Pool } = require('@uniswap/v3-sdk/')
const IUniswapV3PoolABI = require('@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json')
const abiDecoder = require('abi-decoder');
// const { ethers } = require('ethers')
const { ethers } = require('hardhat')
const ERC20ABI = require("../common/abi/ERC20.json")
const { createTrade, executeTrade } = require("./trading")
const PriceFeedABI = require('../common/abi/PriceFeed.json')
const HintHelpersABI = require('../common/abi/HintHelpers.json')
const SortedTrovesABI = require("../common/abi/SortedTroves.json")

const ETH_NETWORK = SupportedChainId.MAINNET;
const NETWORK = 'MAINNET';
const ARTH = new Token(ETH_NETWORK, ADDRESSES[NETWORK]['ARTH'], 18);
const WETH = new Token(ETH_NETWORK, ADDRESSES[NETWORK]['WETH'], 18);

const POINT_TWO_ETH = ethers.BigNumber.from('200000000000000000');
const PART_OF_ARTH_POOL_TO_USE = ethers.BigNumber.from(8); // 8th of the liquidity reserve will be used (12.5%)
const UNISWAP_ARTH_PROVIDER_FEE = 0.003;

abiDecoder.addABI(TroveManagerABI);

const poolAddress = "0xe7cdba5e9b0d5e044aab795cd3d659aac8db869b";


const arbitrageStatus = async (provider, wallet) => {
	const poolContract = await ethers.getContractAt(IUniswapV3PoolABI.abi, poolAddress, wallet);
	
	// const arth = await EthersARTH.connect(wallet);
	// const pair = await Fetcher.fetchPairData(ARTH, WETH[ARTH.chainId], provider).catch(e=>{console.log("----------------",e)})

	const { 
		// trade, 
		ethForSwap, 
		// populatedRedemption
	} = 
	await getFeasibleTrade(
		// arth,
		null,
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
	
	console.log("----5----", priceRatio, ethUsed, profit)
	// if (profit > 0) {
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
	} else {
		return {
			status: 0,
			amountIn: ethForSwap,
			// populatedRedemption: populatedRedemption,
			profit: profit,
		};
	}
};

const getFeasibleTrade = async (arth, pair, wallet) => {
	// const ethUniswapReserve = toBN(toWei(pair.reserve0.toSignificant(8), 'Mwei')).div(
	// 	PART_OF_ARTH_POOL_TO_USE
	// );
	const ERC20Contract = new ethers.Contract(WETH.address, ERC20ABI, wallet);
	console.log("-----456------------", (await ERC20Contract.balanceOf(pair.address)).toString())
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
	// const route = new Route([pair], WETH);
	// let trade = new Trade(route, new TokenAmount(WETH, ethTradeAmout), TradeType.EXACT_INPUT);
	// const lusdObtainedFromUni = parseFloat(fromWei(trade.outputAmount.toSignificant(6), 'micro'));
	// const populatedRedemption = await arth.populate
	// 	.redeemARTH(lusdObtainedFromUni.toString())
	// 	.catch(function (error) {
	// 		console.log(
	// 			'possibly wallet does not contain any ARTH. Keep a standing balance' + error
	// 		);
	// 	});

	// let redeemableLusdAmount = toWei(populatedRedemption.redeemableARTHAmount.toString(), 'ether');
	// console.log("----------------------------", redeemableLusdAmount)
	// // Create new trade based on redeemable ARTH amount. This is because the ARTH amount can change.
	// trade = new Trade(route, new TokenAmount(ARTH, redeemableLusdAmount), TradeType.EXACT_OUTPUT);
	// ethTradeAmout = toBN(toWei(trade.inputAmount.toFixed(), 'Mwei'));

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

const executeArbitrage = async (amountIn, wallet) => {
	console.log("=====================execute Arbitrage======================", (await wallet.provider.getBalance(wallet.address)))
	try{
		await createTrade(wallet, amountIn);
		// if( (await executeTrade(trade, wallet, amountIn)) === 'Sent') {
		// 	// redeem ARTH using TroveManager
		// 	const troveManager = await ethers.getContractAt(TroveManagerABI, ADDRESSES[NETWORK]['TroveManager']);
		// 	const priceFeed = await ethers.getContractAt(PriceFeedABI, ADDRESSES[NETWORK]['PRICEFEED']);
		// 	const hintHelpers = await ethers.getContractAt(HintHelpersABI, ADDRESSES[NETWORK]['HINTHELPERS']);
		// 	const sortedTroves = await ethers.getContractAt(SortedTrovesABI, ADDRESSES[NETWORK]['SortedTroves']);
		// 	const price = await priceFeed.getPrice();

		// 	// Find hints for redeeming 20 ARTH
		// 	const { partialRedemptionHintNICR } = await hintHelpers.getRedemptionHints(
		// 		amountIn,
		// 		price,
		// 		0
		// 	);

		// 	// We don't need to use getApproxHint for this test, since it's not the subject of this
		// 	// test case, and the list is very small, so the correct position is quickly found
		// 	const {
		// 	0: upperPartialRedemptionHint,
		// 	1: lowerPartialRedemptionHint
		// 	} = await sortedTroves.findInsertPosition(partialRedemptionHintNICR, dennis, dennis);

		// 	// skip bootstrapping phase
		// 	await th.fastForwardTime(timeValues.SECONDS_IN_ONE_WEEK * 2, web3.currentProvider);

		// 	// Dennis redeems 20 ARTH
		// 	// Don't pay for gas, as it makes it easier to calculate the received Ether
		// 	const redemptionTx = await troveManager.connect(wallet).redeemCollateral(
		// 		amountIn,
		// 		"0x" + "0".repeat(40), // invalid first hint
		// 		upperPartialRedemptionHint,
		// 		lowerPartialRedemptionHint,
		// 		partialRedemptionHintNICR,
		// 		0,
		// 		"1000000000000000000",
		// 		{
		// 			from: wallet.address,
		// 			gasPrice: 10000000
		// 		}
		// 	);
		// } else {
		// 	console.log("Fail in trading Uniswap V3")
		// 	return;
		// }
	} catch(e) {
		console.log("Error in trading Uniswap V3:", e)
		return;
	}
};

exports.arbitrageStatus = arbitrageStatus;
exports.executeArbitrage = executeArbitrage;
exports.getFeasibleTrade = getFeasibleTrade;
