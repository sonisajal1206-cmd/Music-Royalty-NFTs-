// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Music Royalty NFTs - Revenue sharing for music creators
 *
 * Project Description:
 * This project introduces a decentralized platform for music creators to tokenize their music rights as NFTs,
 * enabling transparent revenue sharing between creators and stakeholders. The smart contract allows creators
 * to mint NFTs representing their music and distribute revenues (from streams, sales, or licenses) fairly
 * among NFT holders and creators.
 *
 * Project Vision:
 * Our vision is to empower music creators by leveraging blockchain technology to automate royalty payments
 * and revenue sharing. This transparent and immutable system ensures artists receive fair compensation while
 * engaging their community through NFTs.
 *
 * Key Features:
 * - NFT Minting: Music creators can create NFTs representing their music rights.
 * - Revenue Sharing: Automatically distribute streaming or sales revenue between creators and NFT holders.
 * - Withdrawal Mechanism: Both creators and holders can securely withdraw their entitled share of revenues.
 * - Transparent & Trustless: Blockchain ensures all transactions and distributions are immutable and publicly verifiable.
 *
 * Future Scope:
 * - Integration with ERC721 or ERC1155 token standards for full NFT interoperability.
 * - Adding metadata and IPFS storage for music files and associated content.
 * - Support for multiple creators per NFT.
 * - Integration with streaming platforms for automated revenue feeds.
 * - On-chain governance for community decisions on revenue splits.
 * - Incorporation of royalties on secondary sales.
 */

contract MusicRoyaltyNFT {

    // NFT structure representing music rights
    struct NFT {
        address creator;
        uint256 totalRevenue;
        uint256 royaltyPercentage; // Percentage of revenue creator takes (rest shared among holders)
        uint256 totalShares;
        mapping(address => uint256) shares; // share per NFT holder
        mapping(address => uint256) revenueWithdrawn;
        bool exists;
    }

    uint256 public nftCount;
    mapping(uint256 => NFT) public nfts;

    // Events
    event NFTCreated(uint256 indexed nftId, address indexed creator, uint256 royaltyPercentage, uint256 totalShares);
    event RevenueReceived(uint256 indexed nftId, uint256 amount);
    event RevenueWithdrawn(uint256 indexed nftId, address indexed holder, uint256 amount);

    /// @notice Create a new NFT with a specified royalty and share distribution
    /// @param _royaltyPercentage The percentage of revenue that the creator receives
    /// @param _shareHolders Addresses of holders who will share revenue (excluding creator)
    /// @param _shares Number of shares corresponding to each holder (length must match _shareHolders)
    function createNFT(
        uint256 _royaltyPercentage,
        address[] memory _shareHolders,
        uint256[] memory _shares
    ) external {
        require(_royaltyPercentage <= 100, "Royalty must be <= 100");
        require(_shareHolders.length == _shares.length, "Holders and shares length mismatch");

        nftCount++;
        NFT storage nft = nfts[nftCount];
        nft.creator = msg.sender;
        nft.royaltyPercentage = _royaltyPercentage;
        nft.exists = true;

        uint256 totalShares = 0;
        for (uint i = 0; i < _shareHolders.length; i++) {
            nft.shares[_shareHolders[i]] = _shares[i];
            totalShares += _shares[i];
        }
        nft.totalShares = totalShares;

        emit NFTCreated(nftCount, msg.sender, _royaltyPercentage, totalShares);
    }

    /// @notice Distribute revenue to an NFT by sending Ether to contract
    /// @param _nftId The ID of the NFT
    function distributeRevenue(uint256 _nftId) external payable {
        NFT storage nft = nfts[_nftId];
        require(nft.exists, "NFT does not exist");
        require(msg.value > 0, "No revenue sent");

        nft.totalRevenue += msg.value;

        emit RevenueReceived(_nftId, msg.value);
    }

    /// @notice Withdraw accumulated revenue for a holder or creator
    /// @param _nftId The ID of the NFT
    function withdrawRevenue(uint256 _nftId) external {
        NFT storage nft = nfts[_nftId];
        require(nft.exists, "NFT does not exist");

        uint256 totalRevenue = nft.totalRevenue;
        uint256 amount;

        if (msg.sender == nft.creator) {
            // Creator's cut
            amount = (totalRevenue * nft.royaltyPercentage) / 100;
        } else {
            // Holder's cut proportional to shares
            uint256 holdersRevenue = totalRevenue - (totalRevenue * nft.royaltyPercentage) / 100;
            uint256 holderShares = nft.shares[msg.sender];
            require(holderShares > 0, "No shares for caller");

            amount = (holdersRevenue * holderShares) / nft.totalShares;
        }

        uint256 withdrawn = nft.revenueWithdrawn[msg.sender];
        uint256 payableAmount = amount - withdrawn;
        require(payableAmount > 0, "No revenue to withdraw");

        nft.revenueWithdrawn[msg.sender] = amount;

        payable(msg.sender).transfer(payableAmount);

        emit RevenueWithdrawn(_nftId, msg.sender, payableAmount);
    }
}
