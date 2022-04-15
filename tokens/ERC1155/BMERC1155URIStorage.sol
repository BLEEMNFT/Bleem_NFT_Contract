// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * ERC1155 token with storage based token URI management.
 */
abstract contract BMERC1155URIStorage is ERC1155Supply, Ownable {
    using Strings for uint256;

    // Optional mapping for token CIDs, the term `CID` which can be referred to IPFS official docs
    mapping(uint256 => string) private _tokenCIDs;

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        if (!exists(tokenId)) {
            return "";
        }

        string memory _tokenCID = _tokenCIDs[tokenId];
        string memory base = uri(0);

        // If there is no baseURI, return the token CID.
        if (bytes(base).length == 0) {
            return _tokenCID;
        }
        // If both are set, concatenate the base uri and tokenCID (via abi.encodePacked).
        if (bytes(_tokenCID).length > 0) {
            return string(abi.encodePacked(base, _tokenCID));
        }

        return "";
    }

    /**
     * @dev Sets `setTokenCID` as the tokenCID of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenCID(uint256 tokenId, string memory _cid) internal virtual {
        require(exists(tokenId), "ERC1155URIStorage: URI query for nonexistent token");
        _tokenCIDs[tokenId] = _cid;
    }

    /**
     * @dev Destroys `tokenId`.
     * Only the contract owner can burn the CID because of there may be more than 1 owner for the ERC1155 NFT
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) public onlyOwner {
        if (bytes(_tokenCIDs[tokenId]).length != 0) {
            delete _tokenCIDs[tokenId];
        }
    }
}
