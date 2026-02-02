// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MoltfessionsChain} from "../src/MoltfessionsChain.sol";

contract MoltfessionsChainTest is Test {
    MoltfessionsChain public chain;
    address public operator;
    address public user;

    function setUp() public {
        operator = address(this);
        user = address(0x1234);
        chain = new MoltfessionsChain();
    }

    function test_InitialState() public view {
        assertEq(chain.operator(), operator);
        assertEq(chain.latestBlock(), 0);
    }

    function test_CommitFirstBlock() public {
        bytes32 merkleRoot = keccak256("test root");
        uint32 count = 5;

        chain.commitBlock(1, merkleRoot, count);

        (bytes32 root, uint64 timestamp, uint32 confCount, bool exists) = chain.getBlock(1);
        
        assertEq(root, merkleRoot);
        assertEq(confCount, count);
        assertTrue(exists);
        assertEq(chain.latestBlock(), 1);
    }

    function test_CommitSequentialBlocks() public {
        chain.commitBlock(1, keccak256("root1"), 3);
        chain.commitBlock(2, keccak256("root2"), 5);
        chain.commitBlock(3, keccak256("root3"), 2);

        assertEq(chain.latestBlock(), 3);
        
        (, , uint32 count1, ) = chain.getBlock(1);
        (, , uint32 count2, ) = chain.getBlock(2);
        (, , uint32 count3, ) = chain.getBlock(3);
        
        assertEq(count1, 3);
        assertEq(count2, 5);
        assertEq(count3, 2);
    }

    function test_RevertNonOperator() public {
        vm.prank(user);
        vm.expectRevert(MoltfessionsChain.NotOperator.selector);
        chain.commitBlock(1, keccak256("test"), 1);
    }

    function test_RevertDuplicateBlock() public {
        chain.commitBlock(1, keccak256("root1"), 1);
        
        vm.expectRevert(MoltfessionsChain.BlockAlreadyExists.selector);
        chain.commitBlock(1, keccak256("root2"), 2);
    }

    function test_RevertNonSequentialBlock() public {
        chain.commitBlock(1, keccak256("root1"), 1);
        
        vm.expectRevert(MoltfessionsChain.BlockMustBeSequential.selector);
        chain.commitBlock(3, keccak256("root3"), 1);
    }

    function test_RevertFirstBlockNotOne() public {
        vm.expectRevert(MoltfessionsChain.BlockMustBeSequential.selector);
        chain.commitBlock(5, keccak256("root"), 1);
    }

    function test_TransferOperator() public {
        chain.transferOperator(user);
        assertEq(chain.operator(), user);

        // Old operator can't commit anymore
        vm.expectRevert(MoltfessionsChain.NotOperator.selector);
        chain.commitBlock(1, keccak256("test"), 1);

        // New operator can commit
        vm.prank(user);
        chain.commitBlock(1, keccak256("test"), 1);
    }

    function test_RevertTransferToZeroAddress() public {
        vm.expectRevert(MoltfessionsChain.ZeroAddress.selector);
        chain.transferOperator(address(0));
    }

    function test_MerkleProofVerification() public {
        // Build a simple merkle tree with 4 leaves
        bytes32 leaf1 = keccak256("confession1");
        bytes32 leaf2 = keccak256("confession2");
        bytes32 leaf3 = keccak256("confession3");
        bytes32 leaf4 = keccak256("confession4");

        // Level 1: hash pairs (sorted)
        bytes32 node1 = _hashPair(leaf1, leaf2);
        bytes32 node2 = _hashPair(leaf3, leaf4);

        // Root
        bytes32 root = _hashPair(node1, node2);

        // Commit block with this root
        chain.commitBlock(1, root, 4);

        // Verify leaf1 with proof [leaf2, node2]
        bytes32[] memory proof1 = new bytes32[](2);
        proof1[0] = leaf2;
        proof1[1] = node2;
        assertTrue(chain.verifyConfession(1, leaf1, proof1));

        // Verify leaf3 with proof [leaf4, node1]
        bytes32[] memory proof3 = new bytes32[](2);
        proof3[0] = leaf4;
        proof3[1] = node1;
        assertTrue(chain.verifyConfession(1, leaf3, proof3));

        // Invalid proof should fail
        bytes32[] memory badProof = new bytes32[](2);
        badProof[0] = keccak256("wrong");
        badProof[1] = node2;
        assertFalse(chain.verifyConfession(1, leaf1, badProof));
    }

    function test_RevertVerifyNonexistentBlock() public {
        bytes32[] memory proof = new bytes32[](0);
        vm.expectRevert(MoltfessionsChain.BlockNotFound.selector);
        chain.verifyConfession(999, keccak256("test"), proof);
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        if (a <= b) {
            return keccak256(abi.encodePacked(a, b));
        } else {
            return keccak256(abi.encodePacked(b, a));
        }
    }
}
