// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface BMIERC2981 is IERC165 {
    // ERC165
    // royaltyInfo(uint256,uint256) => 0x2a55205a
    // IERC2981 => 0x2a55205a

    // @notice Called with the sale price to determine how much royalty
    //  is owed and to whom.
    // @param _tokenId - the NFT asset queried for royalty information
    // @param _salePrice - the sale price of the NFT asset specified by _tokenId
    // @return receiver - address of who should be sent the royalty payment
    // @return royaltyAmount - the royalty payment amount for _salePrice
    // ERC165 datum royaltyInfo(uint256,uint256) => 0x2a55205a
    function royaltyInfo(address nftContract, uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount);

    function getRoyalty(address nftContract, uint256 tokenId) external view returns (address, uint256);

    function setRoyalties(address nftContract, uint256 _tokenId, address _receiver, uint256 _percentage) external returns (bool);
}
