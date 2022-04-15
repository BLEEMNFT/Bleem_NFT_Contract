// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, and extent some functions there
 */
interface BMIERC1155 is IERC1155 {
 
    function exists(uint256 id) external view returns (bool);
    function mint(address to, uint256 tokenId, uint256 amount, string memory cid, bytes memory data) external returns (bool);

}