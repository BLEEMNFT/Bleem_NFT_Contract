// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../BMBase.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./BMERC1155URIStorage.sol";

// For Bleem NFT Marketplace only
contract BMERC1155 is BMBase, BMERC1155URIStorage, Pausable, ReentrancyGuard, IERC2981 {
    string private _name;
    string private _symbol;

    constructor(string memory uri_) ERC1155(uri_) {
        _name = "Bleem NFT 1155";
        _symbol = "BLEEMNFT";

        _burnNFTEnabled = false;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function mint(address to, uint256 tokenId, uint256 amount, string memory cid, bytes memory data) public isExchange nonReentrant returns (bool) {
        require(amount > 0, "BleemNFTERC1155:mint: Token amount cannot be zero!");
        require(!exists(tokenId), "Err: Token Id exists and cannot mint repeatedly");

        _mint(to, tokenId, amount, data);
        _setTokenCID(tokenId, cid);

        return true;
    }

    // For future use case
    function mintBatch(address to, uint256[] memory tokenIds, uint256[] memory amounts, bytes memory data) public isExchange returns (bool) {
        require(tokenIds.length == amounts.length, "BleemNFTERC1155:mintBatch: tokenIds and amounts not match");

        _mintBatch(to, tokenIds, amounts, data);

        return true;
    }

    // For future use case
    function burn(uint256 id, uint256 amount) public canBurnNFT {
        _burn(_msgSender(), id, amount);
    }

    // For future use case
    function burnBatch(uint256[] memory ids, uint256[] memory amounts) public canBurnNFT {
        require(ids.length == amounts.length, "BleemNFTERC1155:burnBatch: Amount id list and token id list are inequal!");
        _burnBatch(_msgSender(), ids, amounts);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal override whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
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
    function setRoyaltiesContract(address royaltiesContract_) external onlyOwner isValidContract(royaltiesContract_)  {
        _royaltiesContract = royaltiesContract_;
    }
}
