// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Pausable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import {IERC721, IERC721Metadata, ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import {IUniswapV3Pool} from "../../interfaces/IUniswapV3Pool.sol";
import {IBorrowerOperations} from "../../interfaces/IBorrowerOperations.sol";
import {IUniswapV3SwapRouter} from "../../interfaces/IUniswapV3SwapRouter.sol";
import {INonfungiblePositionManager} from "../../interfaces/INonfungiblePositionManager.sol";

contract ARTHETHTroveLP is Ownable, ERC721Enumerable, ERC721Burnable, ERC721Pausable, ReentrancyGuard {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    event Deposit(address indexed dst, uint256 wad, uint256 tokenId);
    event Withdrawal(address indexed src, uint256 wad, uint256 tokenId);

    struct Position {
        uint256 uniswapNftId;
        uint256 eth;
        uint256 coll;
        uint256 debt;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
    }

    uint24 public fee;
    bool public isARTHToken0;
    Counters.Counter private _tokenIdTracker;
    mapping(uint256 => Position) public positions;

    IERC20 public arth;
    IERC20 public weth;
    
    IBorrowerOperations public borrowerOperations;
    IUniswapV3SwapRouter public uniswapV3SwapRouter;
    INonfungiblePositionManager public uniswapNFTManager;

    // TODO: the scenario when the trove gets liquidated?

    constructor(
        address _borrowerOperations,
        address _uniswapNFTManager,
        address _arth,
        address _weth,
        uint24 _fee,
        address _uniswapV3Pool,
        address _uniswapV3SwapRouter
    ) 
        ERC721("ARTH/ETH LP Strategy", "ARTHETH-lp") 
    {
        fee = _fee;

        arth = IERC20(_arth);
        weth = IERC20(_weth);
        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        uniswapV3SwapRouter = IUniswapV3SwapRouter(_uniswapV3SwapRouter);
        uniswapNFTManager = INonfungiblePositionManager(_uniswapNFTManager);

        IUniswapV3Pool _pool = IUniswapV3Pool(_uniswapV3Pool);
        isARTHToken0 = _pool.token0() == _arth;
        arth.approve(_uniswapNFTManager, type(uint256).max);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function openTrove(
        uint256 _maxFee, 
        uint256 _arthAmount, 
        address _upperHint, 
        address _lowerHint, 
        address _frontEndTag
    ) 
        external 
        payable 
        onlyOwner 
        nonReentrant 
    {
        require(msg.value > 0, "No ETH");
        
        // Open trove.
        borrowerOperations.openTrove{value: msg.value}(
            _maxFee, 
            _arthAmount, 
            _upperHint, 
            _lowerHint, 
            _frontEndTag
        );

        // Return dust ETH or dust ARTH.
        _flush(owner());
    }

    function closeTrove(uint256 arthNeeded) 
        external 
        payable 
        onlyOwner 
        nonReentrant 
    {   
        // Get the ARTH needed to close the loan.
        arth.transferFrom(msg.sender, address(this), arthNeeded);
        
        // Close the trove.
        borrowerOperations.closeTrove();

        // Return any dust amount of ARTH or ETH left.
        _flush(owner());
    }

    function deposit(
        uint256 arthToMint,
        uint256 ethToLock,
        uint256 maxFee,
        address upperHint,
        address lowerHint,
        INonfungiblePositionManager.MintParams memory mintParams
    ) 
        public 
        payable 
        nonReentrant 
    {
        address _me = address(this);

        // Check that we are receiving appropriate amount of ETH and 
        // Mint the new strategy NFT. The ETH amount should cover for
        // the loan and adding liquidity in the uni v3 pool.
        require(
            msg.value == mintParams.amount1Desired.add(ethToLock), 
            "Invalid ETH amount"
        );
        _tokenIdTracker.increment(); // Counters start from 0, hence initial increment is required.
        _mint(msg.sender, _tokenIdTracker.current());

        // 2. Mint ARTH and track ARTH balance changes due to this current tx.
        uint256 arthBeforeMinting = arth.balanceOf(_me);
        borrowerOperations.adjustTrove{value: ethToLock}(
            maxFee,
            0, // No coll withdrawal.
            arthToMint, // Mint ARTH.
            true, // Debt increasing.
            upperHint,
            lowerHint
        );
        uint256 arthAfterMinting = arth.balanceOf(_me);

        // Check that appropriate amount of ARTH was minted.
        require(
            arthAfterMinting.sub(arthBeforeMinting) >= mintParams.amount0Desired, 
            "Not enough ARTH"
        );

        // 3. LP the ARTH/ETH.
        mintParams.fee = fee;
        mintParams.recipient = _me;
        mintParams.token0 = address(arth);
        mintParams.token1 = address(weth);
        mintParams.deadline = block.timestamp;
        (
            uint256 tokenId, 
            uint128 liquidity, 
            uint256 amount0, 
            uint256 amount1
        ) = uniswapNFTManager.mint{value: mintParams.amount1Desired}(mintParams);

        // 4. Record the position.
        positions[_tokenIdTracker.current()] = Position({
            eth: ethToLock.add(amount1),
            coll: ethToLock,
            debt: arthToMint,
            uniswapNftId: tokenId,
            liquidity: liquidity,
            amount0: amount0,
            amount1: amount1
        });
        
        // 5. Refund any dust left.
        _flush(msg.sender);

        emit Deposit(msg.sender, msg.value, _tokenIdTracker.current());
    }

    function withdraw(
        uint256 tokenId,
        uint256 maxFee,
        address upperHint,
        address lowerHint,
        INonfungiblePositionManager.DecreaseLiquidityParams memory decreaseLiquidityParams,
        INonfungiblePositionManager.CollectParams memory collectParams
    )
        public 
        payable 
        nonReentrant 
    {
        require(ERC721.ownerOf(tokenId) == msg.sender, "Not owner");

        // 1. Burn the strategy NFT and fetch position details and remove the position.
        Position memory position = positions[tokenId];
        _burn(tokenId);
        delete positions[tokenId];

        // 2. Claim the fees.
        _collectFees(position, collectParams);

        // 3. Remove the LP for ARTH/ETH.
        decreaseLiquidityParams.deadline = block.timestamp;
        decreaseLiquidityParams.liquidity = position.liquidity;
        decreaseLiquidityParams.tokenId = position.uniswapNftId;
        (uint256 amount0, uint256 amount1) = uniswapNFTManager.decreaseLiquidity(
            decreaseLiquidityParams
        );
        
        // 4. Check if we have less ARTH.
        if (amount0 < position.debt) {
            // Then we swap the ETH for ARTH in the ARTH/ETH pool.
            uint256 arthNeeded = position.debt.sub(amount0);
            IUniswapV3SwapRouter.ExactOutputSingleParams memory params = IUniswapV3SwapRouter.ExactOutputSingleParams({
                tokenIn: address(weth),
                tokenOut: address(arth),
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: arthNeeded,
                amountInMaximum: amount1,
                sqrtPriceLimitX96: 0
            });
            uint256 amountInNeeded = swapRouter.exactOutputSingle(params);
            amount1 = amount1.sub(amountInNeeded);
        }

        // 5. Adjust the trove, to remove collateral.
        borrowerOperations.adjustTrove(
            maxFee,
            position.coll,
            position.debt,
            false,
            upperHint,
            lowerHint
        );

        // 6. Check if we still have some ARTH left.
        if (amount0 > 0) {
            // TODO: If yes, then swap ARTH for ETH
        }

        // 7. Send the ether back.
        (bool success, /* bytes data */) = msg.sender.call{value: position.eth}("");
        require(success, "Withdraw failed");

        emit Withdrawal(msg.sender, position.eth, tokenId);
    }

    function _flush(address to) internal {
        uint256 ethBalance = address(this).balance;
        uint256 arthBalance = arth.balanceOf(address(this));

        if (ethBalance > 0) {
            (bool success, /* bytes memory data */) = to.call{value: ethBalance}("");
            require(success, "ETH transfer failed");
        }

        if (arthBalance > 0) {
            arth.transfer(to, arthBalance);
        }
    }

    function _collectFees(
        Position memory position,
        INonfungiblePositionManager.CollectParams memory collectParams
    )
        internal
    {
        // TODO: add MAHA rewards as well.

        // Form the fees collection params. 
        // Fees will directly be sent to the owner.
        collectParams.recipient = msg.sender;
        collectParams.amount0Max = type(uint128).max;
        collectParams.amount1Max = type(uint128).max;
        collectParams.tokenId = position.uniswapNftId;

        // Trigger the fee collection for the nft owner.
        uniswapNFTManager.collect(collectParams);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) 
        internal 
        virtual 
        override(ERC721, ERC721Enumerable, ERC721Pausable) 
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}
