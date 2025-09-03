// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title MerkleTestHelper
/// @notice Helper contract for generating test Merkle roots and proofs for hook validation
contract MerkleTestHelper {
    /// @notice Generate a test Merkle root for ERC4626 deposit and redeem hooks
    /// @param depositHook Address of the Deposit4626VaultHook contract
    /// @param redeemHook Address of the Redeem4626VaultHook contract  
    /// @param mockVault Address of the mock ERC4626 vault
    /// @param mockToken Address of the mock token
    /// @return root The Merkle root for the tree
    /// @return proofs Array of proofs for each leaf [depositProof, redeemProof]
    function generateTestHooksRoot(
        address depositHook,
        address redeemHook,
        address mockVault,
        address mockToken
    ) public pure returns (bytes32 root, bytes32[][] memory proofs) {
        // Create leaves for the two hooks following the exact format from SuperVaultAggregator._createLeaf()
        bytes32[] memory leaves = new bytes32[](2);
        
        // Leaf 1: Deposit hook with mock vault + token args
        // Based on Deposit4626VaultHook data structure: yieldSourceOracleId(32) + yieldSource(20) + amount(32) + usePrevHookAmount(1)
        bytes memory depositArgs = abi.encodePacked(
            bytes32(0), // yieldSourceOracleId placeholder
            mockVault,   // yieldSource (20 bytes)
            uint256(1000e18), // amount (32 bytes)
            false        // usePrevHookAmount (1 byte)
        );
        leaves[0] = keccak256(bytes.concat(keccak256(abi.encode(depositHook, depositArgs))));
        
        // Leaf 2: Redeem hook with mock vault + owner + shares args  
        // Based on Redeem4626VaultHook data structure: yieldSourceOracleId(32) + yieldSource(20) + owner(20) + shares(32) + usePrevHookAmount(1)
        bytes memory redeemArgs = abi.encodePacked(
            bytes32(0), // yieldSourceOracleId placeholder
            mockVault,   // yieldSource (20 bytes)
            mockToken,   // owner (20 bytes) - using mockToken address as owner for simplicity
            uint256(500e18), // shares (32 bytes)
            false        // usePrevHookAmount (1 byte)
        );
        leaves[1] = keccak256(bytes.concat(keccak256(abi.encode(redeemHook, redeemArgs))));
        
        // Sort leaves to match standard Merkle tree ordering
        if (leaves[0] > leaves[1]) {
            (leaves[0], leaves[1]) = (leaves[1], leaves[0]);
        }
        
        // For a 2-leaf tree, root is hash of the sorted leaves
        root = keccak256(abi.encodePacked(leaves[0], leaves[1]));
        
        // Generate proofs for each leaf
        proofs = new bytes32[][](2);
        proofs[0] = new bytes32[](1); // Proof for first leaf
        proofs[1] = new bytes32[](1); // Proof for second leaf
        
        // In a 2-leaf tree, each leaf's proof is just its sibling
        if (leaves[0] == keccak256(bytes.concat(keccak256(abi.encode(depositHook, depositArgs))))) {
            // depositHook is first leaf
            proofs[0][0] = leaves[1]; // Sibling of deposit leaf
            proofs[1][0] = leaves[0]; // Sibling of redeem leaf
        } else {
            // redeemHook is first leaf  
            proofs[0][0] = leaves[0]; // Sibling of deposit leaf
            proofs[1][0] = leaves[1]; // Sibling of redeem leaf
        }
        
        return (root, proofs);
    }
    
    /// @notice Generate encoded hook arguments for Deposit4626VaultHook
    /// @param yieldSource Address of the yield source vault
    /// @param amount Amount to deposit
    /// @param usePrevHookAmount Whether to use previous hook amount
    /// @return Encoded hook arguments
    function encodeDepositHookArgs(
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount
    ) public pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), // yieldSourceOracleId placeholder
            yieldSource,
            amount,
            usePrevHookAmount
        );
    }
    
    /// @notice Generate encoded hook arguments for Redeem4626VaultHook
    /// @param yieldSource Address of the yield source vault
    /// @param owner Address of the owner
    /// @param shares Number of shares to redeem
    /// @param usePrevHookAmount Whether to use previous hook amount
    /// @return Encoded hook arguments
    function encodeRedeemHookArgs(
        address yieldSource,
        address owner,
        uint256 shares,
        bool usePrevHookAmount
    ) public pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), // yieldSourceOracleId placeholder
            yieldSource,
            owner,
            shares,
            usePrevHookAmount
        );
    }
    
    /// @notice Create a leaf hash for a specific hook and arguments
    /// @param hookAddress Address of the hook contract
    /// @param hookArgs Encoded hook arguments
    /// @return leaf The leaf hash
    function createLeaf(address hookAddress, bytes memory hookArgs) public pure returns (bytes32 leaf) {
        return keccak256(bytes.concat(keccak256(abi.encode(hookAddress, hookArgs))));
    }
    
    /// @notice Verify a Merkle proof against a root
    /// @param proof Array of proof elements
    /// @param root Merkle root
    /// @param leaf Leaf to verify
    /// @return True if proof is valid
    function verifyProof(bytes32[] memory proof, bytes32 root, bytes32 leaf) public pure returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }
}