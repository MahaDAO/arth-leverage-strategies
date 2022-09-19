// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Pausable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {IBorrowerOperations} from "../../interfaces/IBorrowerOperations.sol";
import {INonfungiblePositionManager} from "../../interfaces/INonfungiblePositionManager.sol";

contract ARTHETHTroveLP is Ownable, ERC721Enumerable, ERC721Burnable, ERC721Pausable {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    struct Position {
        uint256 uniswapNftId;
        uint256 eth;
        uint256 coll;
        uint256 debt;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
    }

    IERC20 public arth;
    IERC20 public weth;
    uint24 public fee;

    Counters.Counter private _tokenIdTracker;
    mapping(uint256 => Position) public positions;
    IBorrowerOperations public borrowerOperations;
    INonfungiblePositionManager public uniswapNFTManager;

    // todo; need to handle the scenario when the trove gets liquidated?

    constructor(
        address _borrowerOperations,
        address _uniswapNFTManager,
        address _arth,
        address _weth,
        uint24 _fee
    ) ERC721("ARTH/ETH LP Strategy", "ARTHETH-lp") {
        arth = IERC20(_arth);
        weth = IERC20(_weth);
        fee = _fee;
        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        uniswapNFTManager = INonfungiblePositionManager(uniswapNFTManager);

        arth.approve(uniswapNFTManager, uint256.max);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function openTrove() external payable onlyOwner {
        // used by the fund manager to open the trove
    }

    function closeTrove() external payable onlyOwner {
        // used by the fund manager to close the trove
    }

    function deposit(
        uint256 arthToMint,
        uint256 ethToLock,
        uint256 maxFee,
        address upperHint,
        address lowerHint,
        INonfungiblePositionManager.MintParams memory mintParams
    ) public payable {
        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        _mint(msg.sender, _tokenIdTracker.current());

        // 1. mint ARTH
        borrowerOperations.adjustTrove{value: ethToLock}(
            maxFee,
            arthToMint,
            ethToLock,
            true,
            upperHint,
            lowerHint
        );

        // 2. LP the ARTH/ETH
        mintParams.recipient = address(this);
        mintParams.token0 = address(arth);
        mintParams.token1 = address(weth);
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = uniswapNFTManager
            .mint(mintParams);

        // record the position
        positions[_tokenIdTracker.current()] = Position({
            eth: msg.value,
            coll: ethToLock,
            debt: arthToMint,
            uniswapNftId: tokenId,
            liquidty: liquidity,
            amount0: amount0,
            amount1: amount1
        });

        emit Deposit(msg.sender, msg.value, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    function withdraw(
        uint256 tokenId,
        uint256 maxFee,
        address upperHint,
        address lowerHint,
        INonfungiblePositionManager.DecreaseLiquidityParams memory decreaseLiquidityParams,
        INonfungiblePositionManager.CollectParams memory collectParams
    ) public {
        require(ERC721.ownerOf(tokenId) == msg.sender, "not owner");
        _burn(msg.sender, tokenId);

        Position memory position = positions[tokenId];

        // trigger the withdrawal
        // 2. Remove the LP for ARTH/ETH
        decreaseLiquidityParams.tokenId = position.uniswapNftId;
        (uint256 amount0, uint256 amount1) = uniswapNFTManager.decreaseLiquidity(
            decreaseLiquidityParams
        );

        // todo: if we have less ARTH then we swap the ETH for ARTH in the ARTH/ETH pool

        borrowerOperations.adjustTrove(
            maxFee,
            position.coll,
            position.debt,
            false,
            upperHint,
            lowerHint
        );

        // todo: if we have more ARTH then we swap the ARTH for ETH in the ARTH/ETH pool

        // send the ether back
        (bool success, ) = msg.sender.call{value: position.eth}("");
        require(success, "withdraw failed");

        emit Withdrawal(msg.sender, position.eth, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        // nothing
    }

    function fallbackCall(address target, bytes memory data) onlyOwner {
        // todo
    }
}
