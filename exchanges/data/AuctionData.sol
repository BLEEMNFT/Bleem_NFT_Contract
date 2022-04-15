// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../FuncParams.sol";
import "./IAuctionData.sol";

contract AuctionData is Ownable, IAuctionData {
    // NB: An NFT only got an unique offer, new offerer will replace the previous one

    // ERC721 Path: nftContract => tokenId => NFTSaleModel
    mapping(address => mapping(uint256 => FuncParams.NFTModel)) private _721saleOffers;

    // ERC1155 Path: nftContract => tokenId => seller => offerer => NFTSaleModel
    mapping(address => mapping(uint256 => mapping(address => mapping(address => FuncParams.NFTModel)))) private _1155saleOffers;

    // One valid signature only used for one successful transaction
    mapping(bytes => bool) private _invalidSignature;

    mapping(address => bool) public _exchanges;

    constructor() {}

    function setExchange(address _exchange, bool flag) public onlyOwner {
        _exchanges[_exchange] = flag;
    }

    modifier isExchange() {
        require(_exchanges[_msgSender()], "AuctionData: caller is not exchange");
        _;
    }

    function getSaleOffer(address nftContract, uint256 tokenId, address seller, address offerer) external view override isExchange returns (FuncParams.NFTModel memory) {
        if (offerer == address(0)) {
            return _721saleOffers[nftContract][tokenId];
        }
        return _1155saleOffers[nftContract][tokenId][seller][offerer];
    }

    function setSaleOffer(address nftContract, uint256 tokenId, FuncParams.NFTModel memory model, address offerer) external override isExchange returns (bool) {
        if (offerer == address(0)) {
            _721saleOffers[nftContract][tokenId] = model;
        } else {
            _1155saleOffers[nftContract][tokenId][model.seller][offerer] = model;
        }
        return true;
    }

    function deleteSaleOffer(address nftContract, uint256 tokenId, address seller, address offerer) external override isExchange returns (bool) {
        if (offerer == address(0)) {
            delete _721saleOffers[nftContract][tokenId];
        } else {
            delete _1155saleOffers[nftContract][tokenId][seller][offerer];
        }
        return true;
    }

    function getInvalidSignature(bytes memory signs) external view override isExchange returns (bool) {
        return _invalidSignature[signs];
    }

    function setInvalidSignature(bytes memory signs, bool flag) external override isExchange returns (bool) {
        _invalidSignature[signs] = flag;
        return true;
    }

    // Use this in case of BNB are sent to the contract by mistake
    event SettleCoinEvent(bool isSuccess, bytes data, address to, uint256 amount);

    function settleCoin(address to) public onlyOwner {
        uint256 total = address(this).balance;
        require(total > 0, "Err: No ETH Balance");
        (bool sent, bytes memory data) = payable(to).call{value: total}("");
        // Centric server should listen to this event and notify to some key email receivers for the settlment of ether
        emit SettleCoinEvent(sent, data, to, total);
    }

    // Use this in case of other tokens are sent to the contract by mistake
    event SettleTokenEvent(address tokenAddress, address to, uint256 amount);

    function settleToken(address tokenAddress, address to) public onlyOwner {
        uint256 total = IERC20(tokenAddress).balanceOf(address(this));
        require(total > 0, "Err: No Token Balance");
        require(
            IERC20(tokenAddress).transfer(to, total),
            "Err: SettleAccount Transfer Failure"
        );
        // Centric server should listen to this event and notify to some key email receivers for the settlment of token
        emit SettleTokenEvent(tokenAddress, to, total);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
