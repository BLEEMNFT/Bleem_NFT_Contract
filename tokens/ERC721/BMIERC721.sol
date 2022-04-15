// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev Required interface of an ERC721 compliant contract, and extent some functions there
 */
interface BMIERC721 is IERC721 {

    function exists(uint256 tokenId) external view returns (bool);
    function mint(address recipient, uint256 tokenId, string memory tokenCID) external returns (bool);

}