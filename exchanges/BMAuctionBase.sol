// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./data/IAuctionData.sol";
import "../tokens/ERC721/BMIERC721.sol";
import "../tokens/ERC1155/BMIERC1155.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC2981/BMIERC2981.sol";
import "./signs/ERC191.sol";
import "./FuncParams.sol";
import "./log/Logger.sol";


contract BMAuctionBase is Ownable, Pausable {

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution. 
        return account.code.length > 0;
    }

    function _legalMsgSender() internal view returns (address) {
        require(!(isContract(_msgSender())), "Err: Caller cannot be from a contract");
        return _msgSender();
    }
    
    modifier isValidContract(address a) {
        require(a != address(0) && isContract(a), "Err: Not a valid address");
        _;
    }

    modifier isValidAddress(address a) {
        require(a != address(0), "Err: Not a valid address");
        _;
    }

    mapping(address => bool) public _blacklist;

    modifier isInBlacklist() {
        require(!_blacklist[msg.sender], "Err: Caller is restricted");
        _;
    }

    function setBlacklist(address addr_, bool flag) external onlyOwner isValidAddress(addr_) {
        _blacklist[addr_] = flag;
    }

    Logger internal _logger; 
    // function setLogger(address log) external onlyOwner isValidContract(log) {
    //     _logger = Logger(log);
    // }
 
    IAuctionData internal _data; 
    // function setDataContract(address c) external onlyOwner isValidContract(c) {
    //     _data = IAuctionData(c);
    // }

    function setPaused() external onlyOwner {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }

    bool public _enabledCancelListing; // Defaults to false
    function setEnabledCancelListing(bool flag) external onlyOwner {
        _enabledCancelListing = flag;
    }

    bool public _enabledCancelMyOffer; // Defaults to false
    function setEnabledCancelMyOffer(bool flag) external onlyOwner {
        _enabledCancelMyOffer = flag;
    }

    ERC191 internal _verifier;
    // function setVerifierContract(address c) external onlyOwner isValidContract(c) {
    //     _verifier = ERC191(c);
    // }

    address public _royaltiesContract;
    function setRoyaltiesContract(address c) external onlyOwner isValidContract(c) {
        _royaltiesContract = c;
    }

    uint256 public _platformRevenueRate; // Defaults to 2.5% which amplified 1e18 times.
    function setPlatformRevenueRate(uint256 rate) external onlyOwner {
        uint minRate = 0; // 0%
        uint maxRate = 150000000000000000; // 15% denotes 0.15 * 1e18
        require(rate >= minRate && rate <= maxRate, "Err: The value of rate range must be from 0% to 10%");
        _platformRevenueRate = rate;
    }

    // Platform revenue manager contract
    address public _revenueManager;
    function setRevenueContract(address c) external onlyOwner isValidContract(c) { 
        _revenueManager = c;
    }

    // Symbol => Address
    mapping(string => address) public erc20Contracts;

    // Address => enabled
    mapping(address => bool) public erc721Contracts;

    // Address => enabled
    mapping(address => bool) public erc1155Contracts;

    function setERC20Contract(string memory symbol, address c) external onlyOwner isValidContract(c) { 
        erc20Contracts[symbol] = c;
    }

    function setERC721Contract(address c, uint256 tokenId) external isInBlacklist isValidContract(c) { 
        require(owner() == _msgSender() || IERC721(c).ownerOf(tokenId) == _msgSender(), "Err: You are not allowed to set ERC721 contract"); 
        erc721Contracts[c] = true;
    }

    function setERC1155Contract(address c, uint256 tokenId) external isInBlacklist isValidContract(c) { 
        require(owner() == _msgSender() || IERC1155(c).balanceOf(_msgSender(), tokenId) > 0, "Err: You are not allowed to set ERC1155 contract"); 
        erc1155Contracts[c] = true;
    }

    address public bleemNFTERC721;
    address public bleemNFTERC1155;

    function setBleemNFTContract(address erc721Address, address erc1155Address, address verifierAddress, address dataAddress, address logAddress) external onlyOwner {
        bleemNFTERC721 = erc721Address;
        bleemNFTERC1155 = erc1155Address;
        _verifier = ERC191(verifierAddress);
        _data = IAuctionData(dataAddress);
        _logger = Logger(logAddress);
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    } 

    function _hasExpired(uint256 deadline) internal view returns (bool) {
        uint256 _extra = 15 * 1000;
        uint256 curTs = block.timestamp * 1000 + _extra;
        if (deadline < curTs) {
            return true;
        }
        return false;
    }

    function checkSellerApproval(address seller, address nftContract) internal view returns (bool isApproved) {
        if (isErc721(nftContract)) {
            isApproved = IERC721(nftContract).isApprovedForAll(seller, address(this));
        } else {
            isApproved = IERC1155(nftContract).isApprovedForAll(seller, address(this));
        }
    }

    function isErc721(address nftContract) public view returns (bool) {
        if (nftContract == bleemNFTERC721 || erc721Contracts[nftContract]) {
            return true;
        } else if (nftContract == bleemNFTERC1155 || erc1155Contracts[nftContract]) {
            return false;
        }
        return false;
    }

    // Transfer/Mint NFT to buyer
    function _transferOrMintNFTToBuyer(FuncParams.TransferNFTParams memory param) internal {
        uint256 tokenId_ = param.tokenId;
        if (param.nftContract == bleemNFTERC721) {
            if (!BMIERC721(bleemNFTERC721).exists(tokenId_)) {
                require(BMIERC721(bleemNFTERC721).mint(param.seller, tokenId_, param.tokenCID), "Err: mint bleem erc721 failure");
                // Set royalties to the original creactor
                require(BMIERC2981(_royaltiesContract).setRoyalties(param.nftContract, tokenId_, param.seller, param.royalties), "Err: Set royalty failure");
            }
            BMIERC721(bleemNFTERC721).safeTransferFrom(param.seller, param.buyer, tokenId_, param.message);
        } else if (param.nftContract == bleemNFTERC1155) {
            if (!BMIERC1155(bleemNFTERC1155).exists(tokenId_)) {
                require(BMIERC1155(bleemNFTERC1155).mint(param.seller, tokenId_, param.amount, param.tokenCID, param.message), "Err: mint bleem erc1155 failure");
                // Set royalties to the original creactor
                require(BMIERC2981(_royaltiesContract).setRoyalties(param.nftContract, tokenId_, param.seller, param.royalties), "Err: Set royalty failure");
            }
            BMIERC1155(bleemNFTERC1155).safeTransferFrom(param.seller, param.buyer, tokenId_, 1, param.message);
        }
        // Third Contracts: ERC721/ERC1155 Transfers  NFT to buyer
        else if (erc721Contracts[param.nftContract]) {
            BMIERC721(param.nftContract).safeTransferFrom(param.seller, param.buyer, tokenId_, param.message);
        } else if (erc1155Contracts[param.nftContract]) {
            BMIERC1155(param.nftContract).safeTransferFrom(param.seller, param.buyer, tokenId_, 1, param.message);
        } else {
            revert("Err: You are not allowed to execute this flow path.");
        }
    }

    // Distribute ETH/WETH/USDT to creator, platform, and seller
    function _distributeRevenues(FuncParams.DistributeRevenueParams memory param) internal {
        (address royaltyReceiver, uint256 royaltyAmount) = BMIERC2981(_royaltiesContract).royaltyInfo(param.nftContract, param.tokenId, param.offerPrice);

        uint256 _platformRevenueAmount = param.offerPrice * _platformRevenueRate / 1e18; 
        uint256 _sellerIncomes = param.offerPrice - _platformRevenueAmount - royaltyAmount;

        if (compareStrings(param.currency, "ETH")) {
            _sendValue(_revenueManager, _platformRevenueAmount, "Err: unable to send ether to platformRevenue");
            _sendValue(royaltyReceiver, royaltyAmount, "Err: unable to send ether to NFT creator");
            _sendValue(param.seller, _sellerIncomes, "Err: unable to send ether to seller");
        } else {
            _transferToken(param.currency, _revenueManager, _platformRevenueAmount, "Err: Unable to transfer token to platformRevenue");
            _transferToken(param.currency, royaltyReceiver, royaltyAmount, "Err: Unable to transfer token to NFT creator");
            _transferToken(param.currency, param.seller, _sellerIncomes, "Err: Unable to transfer token to seller");
        }
    }

    function _sendValue(address to, uint256 amount, string memory err) internal {
        if (to != address(0) && amount > 0) {
            (bool success, bytes memory data) = to.call{value: amount}("");
            require(success && (data.length == 0 || abi.decode(data, (bool))), err); 
        }
    }

    function _transferToken(string memory currency, address to, uint256 amount, string memory err) internal {
        address c = erc20Contracts[currency];
        if (to != address(0) && amount > 0 && c != address(0)) {
            // bytes4(keccak256(bytes('transfer(address,uint256)')));
            (bool success, bytes memory data) = c.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), err);
        }
    }

    function safeTransferFrom(address token, address from, address to, uint256 value, string memory err) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), err);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
