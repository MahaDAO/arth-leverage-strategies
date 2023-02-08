require('dotenv').config();
const express = require('express');
const Web3 = require('web3');
const store = require('data-store')({ path: process.cwd() + '/localstore.json' });
const { arbitrageStatus, executeArbitrage } = require('./src/utils/prices');
const { Wallet } = require('ethers');
const { ethers } = require('hardhat')

const HTTPS_PROVIDER_URL = process.env.HTTPS_PROVIDER;
const WSS_PROVIDER_URL = process.env.WSS_PROVIDER;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

// let webSocketProvider;
const webSocketProvider = new Web3.providers.WebsocketProvider(WSS_PROVIDER_URL);
const webSocketWeb3 = new Web3(webSocketProvider);
// const webSocketWeb3 = new ethers.providers.WebSocketProvider(WSS_PROVIDER_URL)

let jsonRpcProvider;
// let jsonRpcProvider = new providers.JsonRpcProvider(HTTPS_PROVIDER_URL);
let wallet;
// let wallet = new Wallet(PRIVATE_KEY).connect(jsonRpcProvider);
const app = express();
const port = 3000;
const ONGOING_STATUS = 'TX_ONGOING';

let subscription;
let status;

app.get('/', async (req, res) => {
	res.send(
		'Start arbitrage server by hitting url: <ip>:3000/subscribe' +
			'<br/>Unsubscribe by hitting url: <ip>:3000/unsubscribe'
	);
});

app.get('/subscribe', async (req, res) => {
	subscription = webSocketWeb3.eth
		.subscribe('newBlockHeaders', function (error, result) {
			if (!error) {
				performArbitrage().catch(function (error) {
					console.log('There seems to be an error, will try again later. \n' + error);
				});
			}
		})
		.on('connected', function (subscriptionId) {
			console.log("subscriptionId: ",subscriptionId);
			res.send(
				'Subscribed to ethereum events. Will continously monitor for arbitrage opportunities!'
			);
		})
		.on('error', (error)=>(console.error("error-------------------",error)));
});

app.get('/unsubscribe', async (req, res) => {
	if (subscription == null) {
		res.send('Subscribe first before unsubscribing');
		return;
	}
	subscription.unsubscribe(function (error, success) {
		if (success) {
			console.log('Successfully unsubscribed!');
			res.send('Unsubscribed');
		}
	});
});

const performArbitrage = async () => {
	if (!store.get(ONGOING_STATUS)) {
		store.set(ONGOING_STATUS, true);
		console.log("------------start------------")
		status = await arbitrageStatus(jsonRpcProvider, wallet);
		if (status['status'] == 1) {
			await executeArbitrage(
				status['amountIn'],
				wallet
			);
		}
		store.set(ONGOING_STATUS, false);
	}
};

const init = async() => {
	console.log("----init----")
	console.log("-------Alchemy address-------", HTTPS_PROVIDER_URL)
	await ethers.provider.send(
		"hardhat_reset",
		[
			{
				forking: {
					jsonRpcUrl: HTTPS_PROVIDER_URL,
					
					// blockNumber: 15611047
				},
			},
		],
	);

	const accounts = await ethers.getSigners()
	wallet = accounts[0];
	store.set(ONGOING_STATUS, false);
	webSocketWeb3.eth.accounts.wallet.add(PRIVATE_KEY);
};

app.listen(port, async() => {
	await init();
	console.log(`Arbitrage app listening at http://localhost:${port}`);
});
