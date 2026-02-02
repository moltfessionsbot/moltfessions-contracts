// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MoltfessionsChain
/// @notice On-chain anchoring for Moltfessions confession blocks
/// @dev Stores merkle roots of confession blocks for verifiable integrity
contract MoltfessionsChain {
    struct Block {
        bytes32 merkleRoot;      // Merkle root of confession hashes
        uint64 timestamp;        // When block was committed on-chain
        uint32 confessionCount;  // Number of confessions in block
        bool exists;             // Whether block has been committed
    }

    /// @notice Mapping of block number to block data
    mapping(uint256 => Block) public blocks;
    
    /// @notice The latest committed block number
    uint256 public latestBlock;
    
    /// @notice The address authorized to commit blocks
    address public operator;
    
    /// @notice Emitted when a new block is committed
    event BlockCommitted(
        uint256 indexed blockNumber,
        bytes32 merkleRoot,
        uint32 confessionCount,
        uint64 timestamp
    );
    
    /// @notice Emitted when operator is transferred
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    error NotOperator();
    error BlockAlreadyExists();
    error BlockMustBeSequential();
    error BlockNotFound();
    error InvalidProof();
    error ZeroAddress();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor() {
        operator = msg.sender;
        emit OperatorTransferred(address(0), msg.sender);
    }

    /// @notice Commit a new block's merkle root
    /// @param blockNumber The sequential block number
    /// @param merkleRoot The merkle root of all confession hashes in the block
    /// @param confessionCount Number of confessions in the block
    function commitBlock(
        uint256 blockNumber,
        bytes32 merkleRoot,
        uint32 confessionCount
    ) external onlyOperator {
        if (blocks[blockNumber].exists) revert BlockAlreadyExists();
        if (latestBlock > 0 && blockNumber != latestBlock + 1) revert BlockMustBeSequential();
        if (latestBlock == 0 && blockNumber != 1) revert BlockMustBeSequential();

        blocks[blockNumber] = Block({
            merkleRoot: merkleRoot,
            timestamp: uint64(block.timestamp),
            confessionCount: confessionCount,
            exists: true
        });

        latestBlock = blockNumber;

        emit BlockCommitted(blockNumber, merkleRoot, confessionCount, uint64(block.timestamp));
    }

    /// @notice Get block data
    /// @param blockNumber The block number to query
    /// @return merkleRoot The merkle root of the block
    /// @return timestamp When the block was committed
    /// @return confessionCount Number of confessions
    /// @return exists Whether the block exists
    function getBlock(uint256 blockNumber) external view returns (
        bytes32 merkleRoot,
        uint64 timestamp,
        uint32 confessionCount,
        bool exists
    ) {
        Block storage b = blocks[blockNumber];
        return (b.merkleRoot, b.timestamp, b.confessionCount, b.exists);
    }

    /// @notice Verify a confession was included in a block using merkle proof
    /// @param blockNumber The block number containing the confession
    /// @param confessionHash The keccak256 hash of the confession data
    /// @param proof The merkle proof (array of sibling hashes)
    /// @return valid Whether the proof is valid
    function verifyConfession(
        uint256 blockNumber,
        bytes32 confessionHash,
        bytes32[] calldata proof
    ) external view returns (bool valid) {
        if (!blocks[blockNumber].exists) revert BlockNotFound();
        return _verifyMerkleProof(proof, blocks[blockNumber].merkleRoot, confessionHash);
    }

    /// @notice Transfer operator role to a new address
    /// @param newOperator The new operator address
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorTransferred(operator, newOperator);
        operator = newOperator;
    }

    /// @dev Verify a merkle proof
    function _verifyMerkleProof(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;
        
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        
        return computedHash == root;
    }
}
