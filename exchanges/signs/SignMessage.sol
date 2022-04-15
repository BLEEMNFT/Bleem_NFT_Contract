// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

library SignMessage {
    struct Model {
        address to;
        address nftContract;
        uint256 tokenId;
        string tokenCID;
        uint32 amount;
        string currency;
        uint8 saleType;
        uint256 salePrice;
        uint256 finalPrice;
        uint256 reservePrice;
        uint256 royalties;
        uint64 startTime;
        uint64 nonce;
        uint256 salt;
    }
}
