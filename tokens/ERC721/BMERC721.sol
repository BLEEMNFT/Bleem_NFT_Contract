// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../BMBase.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./BMERC721URIStorage.sol";

// For Bleem NFT Marketplace uses only
contract BMERC721 is BMBase, BMERC721URIStorage, Pausable, ReentrancyGuard, IERC2981 {
    
    constructor() ERC721("Bleem NFT", "BLEEMNFT") {
        _burnNFTEnabled = false;
    }

    function setBaseUri(string memory baseUri) public onlyOwner {
        _baseUri = baseUri;
    }

    function mint(address recipient, uint256 tokenId, string memory tokenCID) public isExchange nonReentrant returns (bool) {
        require(!exists(tokenId), "Err: Token Id exists and cannot mint repeatedly");

        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, tokenCID);

        return true;
    }

    function burn(uint256 id) public canBurnNFT {
        require(ERC721.ownerOf(id) == _msgSender(), "Err: You do not own the NFT!");
        _burn(id);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function setPaused() public onlyOwner {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
        (receiver, royaltyAmount) = BleemIERC2981(_royaltiesContract).royaltyInfo(address(this), _tokenId, _salePrice);
    }

    address public _royaltiesContract;
    function setRoyaltiesContract(address royaltiesContract_) external onlyOwner isValidContract(royaltiesContract_) { 
        _royaltiesContract = royaltiesContract_;
    }
}
