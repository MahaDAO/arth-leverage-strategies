// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Context, Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

contract MerkleWhitelist is Ownable {
    bytes32[] public merkleRoots;
    mapping(address => bool) internal whitelist;

    function registerMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoots.push(root);
    }

    function isWhitelisted(
        address _who,
        uint256 _proofIndex,
        bytes32[] memory proof
    ) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encode(_who));
        return MerkleProof.verify(proof, merkleRoots[_proofIndex], leaf);
    }

    modifier checkWhitelist(
        address _who,
        uint256 _proofIndex,
        bytes32[] memory proof
    ) {
        if (whitelist[_who]) {
            _;
            return;
        }

        bytes32 leaf = keccak256(abi.encode(_who));
        require(isWhitelisted(_who, _proofIndex, proof), "not in whitelist");
        whitelist[_who] = true;
        _;
    }
}
