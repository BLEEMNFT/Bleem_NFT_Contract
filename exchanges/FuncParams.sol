// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./signs/SignMessage.sol";

library FuncParams {
    struct NFTModel {
        address nftContract;
        uint256 tokenId;
        string tokenCID;
        uint32 amount;
        string currency;
        uint8 saleType;
        uint256 salePrice; // Seller sets the price on sale
        uint256 finalPrice;
        uint256 reservePrice;
        uint256 royalties;
        uint64 startTime;
        uint256 deadline;
        address seller;
        uint64 sellerNonce;
        bytes sellerSignature;
        /* Order salt, used to prevent duplicate hashes. */
        uint256 salt;
        // For buyer/offerer uses
        address offerer;
        uint64 offerNonce;
        uint256 offerPrice; // Buyer offers the price
        bytes offerSignature;
        bytes message; // Customized message for the tranction
    }

    function setSellerMessage(NFTModel memory param) external pure returns (SignMessage.Model memory) {
        SignMessage.Model memory m;
        m.to = param.seller;
        m.nftContract = param.nftContract;
        m.tokenId = param.tokenId;
        m.tokenCID = param.tokenCID;
        m.amount = param.amount;
        m.currency = param.currency;
        m.saleType = param.saleType;
        m.salePrice = param.salePrice;
        m.finalPrice = param.finalPrice;
        m.reservePrice = param.reservePrice;
        m.royalties = param.royalties;
        m.startTime = param.startTime;
        m.nonce = param.sellerNonce;
        m.salt = param.salt;
        return m;
    }

    struct TransferNFTParams {
        address nftContract;
        uint256 tokenId;
        uint32 amount;
        string tokenCID;
        address buyer;
        address seller;
        uint256 royalties;
        bytes message;
    }

    struct DistributeRevenueParams {
        address nftContract;
        string currency;
        address seller;
        uint256 tokenId;
        uint256 offerPrice;
        uint256 royalties;
    }
}
