// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../FuncParams.sol";

interface IAuctionData {
    function getSaleOffer(address nftContract, uint256 tokenId, address seller, address offerer) external view returns (FuncParams.NFTModel memory);

    function setSaleOffer(address nftContract, uint256 tokenId, FuncParams.NFTModel memory model, address offerer) external returns (bool);

    function deleteSaleOffer(address nftContract, uint256 tokenId, address seller, address offerer) external returns (bool);

    function getInvalidSignature(bytes memory signs) external view returns (bool);

    function setInvalidSignature(bytes memory signs, bool flag) external returns (bool);
}
