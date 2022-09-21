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

import {IBorrowerOperations} from "../../interfaces/IBorrowerOperations.sol";
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
    Counters.Counter private _tokenIdTracker;
    mapping(uint256 => Position) public positions;

    IERC20 public arth;
    IERC20 public weth;
    IBorrowerOperations public borrowerOperations;
    INonfungiblePositionManager public uniswapNFTManager;

    // TODO: the scenario when the trove gets liquidated?

    constructor(
        address _borrowerOperations,
        address _uniswapNFTManager,
        address _arth,
        address _weth,
        uint24 _fee
    ) 
        ERC721("ARTH/ETH LP Strategy", "ARTHETH-lp") 
    {
        fee = _fee;
        arth = IERC20(_arth);
        weth = IERC20(_weth);
        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        uniswapNFTManager = INonfungiblePositionManager(_uniswapNFTManager);

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

    /// @notice Open trove, and keep the ARTH minted in the contract itself.
    function openTrove() external payable onlyOwner nonReentrant {
        // borrowerOperations.openTrove{value: msg.value}(
        //     _maxFee, 
        //     _ARTHAmount, 
        //     _upperHint, 
        //     _lowerHint, 
        //     _frontEndTag
        // );
    }

    /// @notice Closes the trove, and keep the ETH returned in the contract itself.
    function closeTrove() external payable onlyOwner nonReentrant {
        borrowerOperations.closeTrove();
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
        // Mint the new strategy NFT.
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
            arthToMint,
            ethToLock,
            true,
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
            eth: msg.value,
            coll: ethToLock,
            debt: arthToMint,
            uniswapNftId: tokenId,
            liquidity: liquidity,
            amount0: amount0,
            amount1: amount1
        });
        
        // 5. Refund any dust ETH/WETH or ARTH that might be left after new LP position?
        if (amount0 < mintParams.amount0Desired) {
            arth.transfer(msg.sender, amount0.sub(mintParams.amount0Desired));
        }

        if (amount1 < mintParams.amount1Desired) {
            uint256 refundAmount = amount1.sub(mintParams.amount1Desired);
            (bool success, /* bytes data */) = msg.sender.call{value: refundAmount}("");
            require(success, "Refund failed");
        }

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
            // TODO: If yes, then we swap the ETH for ARTH in the ARTH/ETH pool
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

        // 6. Check if we still have some ARTH left
        if (amount0 > 0) {
            // TODO: If yes, then swap ARTH for ETH
        }

        // 7. Send the ether back.
        (bool success, /* bytes data */) = msg.sender.call{value: position.eth}("");
        require(success, "Withdraw failed");

        emit Withdrawal(msg.sender, position.eth, tokenId);
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
