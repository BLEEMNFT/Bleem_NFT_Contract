// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./BMIERC2981.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// For Bleem NFT marketplace uses only
contract ERC2981 is BMIERC2981, Ownable {
    /// bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
    bytes4 internal constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    struct Royalties {
        address receiver;
        // For example, 2.5% is the royalties and the percentage value is 0.025 * 10000 that saved here
        uint256 percentage;
    }

    // nftContract => tokenId => Royalties
    mapping(address => mapping(uint256 => Royalties)) public royalty;

    mapping(address => bool) public _exchanges;

    constructor(address auctionEx) {
        _exchanges[auctionEx] = true;
    }

    modifier isValidContract(address a) {
        require(a != address(0) && a.code.length > 0, "Err: Not a valid address");
        _;
    }

    function setExchange(address _exchange, bool flag) public onlyOwner isValidContract(_exchange) {
        _exchanges[_exchange] = flag;
    }

    modifier isExchange() {
        require(_exchanges[msg.sender], "BMERC2981: caller is not exchange");
        _;
    }

    function setRoyalties(address nftContract, uint256 _tokenId, address _receiver, uint256 _percentage) public isExchange returns (bool) {
        royalty[nftContract][_tokenId] = Royalties(_receiver, _percentage);
        return true;
    }

    function getRoyalty(address nftContract, uint256 tokenId) public view returns (address, uint256) {
        return (royalty[nftContract][tokenId].receiver, royalty[nftContract][tokenId].percentage);
    }

    function royaltyInfo(address nftContract, uint256 _tokenId, uint256 _salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
        receiver = royalty[nftContract][_tokenId].receiver;
        uint256 percentage_ = royalty[nftContract][_tokenId].percentage;

        if (percentage_ == 0) {
            royaltyAmount = 0;
        } else {
            // This sets percentage by salePrice * percentage / 10000
            (bool success, uint256 result) = SafeMath.tryMul(_salePrice, percentage_);
            require(success, "ERC2981: SafeMath.tryMul(a,b) is failed!");
            (bool success1, uint256 result1) = SafeMath.tryDiv(result, 10000);
            require(success1, "ERC2981: SafeMath.tryDiv(a,b) is failed!");

            royaltyAmount = result1;
        }
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }

    function checkRoyalties(address _contract) public view returns (bool) {
        return IERC165(_contract).supportsInterface(_INTERFACE_ID_ERC2981);
    }
}
