// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './Interfaces/IUniswapV2Router02.sol';
// import './Interfaces/IUniswapV2Pair.sol';
import './Interfaces/IUniswapV2Factory.sol';
// import './Interfaces/IUniswapV2ERC20.sol';
import './Interfaces/IARTHToken.sol';
import './Interfaces/ITroveManager.sol';

contract arbitrage {
    IARTHToken public ARTH;
    IUniswapV2Router02 public uniRouter;
    ITroveManager public troveManager;
    address public owner;
    
    event CurrentBalance(uint256 ethBalance, uint256 _ARTHAmount);
    
    constructor(address _router, address _arth, address _troveManager) {
        owner = msg.sender;
        uniRouter = IUniswapV2Router02(_router);
        ARTH = IARTHToken(_arth);
        troveManager = ITroveManager(_troveManager);
    }
    
    fallback() external payable { }
    
    receive() external payable { }
    
    function ethToArthAndBackArbitrage(
        uint amountOutMin,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint _partialRedemptionHintNICR,
        uint _maxIterations,
        uint _maxFee
        ) external payable {
        
        emit CurrentBalance(address(this).balance, ARTH.balanceOf(address(this)));
        
        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = uniRouter.WETH();
        path[1] = address(ARTH);
        uniRouter.swapExactETHForTokens{ value: msg.value }(amountOutMin, path, address(this), block.timestamp);
        
        emit CurrentBalance(address(this).balance, ARTH.balanceOf(msg.sender));
        
        require(ARTH.approve(address(troveManager), amountOutMin), 'approve failed.');
        
        troveManager.redeemCollateral(
            amountOutMin,
            _firstRedemptionHint,
            _upperPartialRedemptionHint,
            _lowerPartialRedemptionHint,
            _partialRedemptionHintNICR,
            _maxIterations,
            _maxFee
        );
        
        emit CurrentBalance(address(this).balance, ARTH.balanceOf(address(this)));
        
        payable(msg.sender).transfer(address(this).balance);
        ARTH.transfer(msg.sender, ARTH.balanceOf(address(this)));
        
        require(msg.value > address(this).balance, 'arbitrage failed.');
    }
    
    function getEthBack() external payable {
        // Fail safe method incase the contract was used wrong.
        payable(msg.sender).transfer(address(this).balance);
    }
}