// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./BMAuctionBase.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./signs/SignMessage.sol";

contract BMNFTAuctionExchange is BMAuctionBase, ReentrancyGuard {
    function makeOffer(FuncParams.NFTModel memory param, address previousOfferer) public payable whenNotPaused nonReentrant isInBlacklist {
        require(!_hasExpired(param.deadline), "Err: Auction has expired");

        uint256 _offerPrice = 0;
        if (compareStrings(param.currency, "ETH")) {
            require(msg.value > 0, "Err: Offer Price Zero");
            _offerPrice = msg.value;
        } else {
            require(erc20Contracts[param.currency] != address(0), "Err: Currency Not Recognized");
            require(param.offerPrice > 0 && msg.value == 0, "Err: Offer Price Zero");
            _offerPrice = param.offerPrice;
        }

        address offerer = _legalMsgSender();
        require(param.seller != offerer, "Err: Offerer and seller both must not be the same one");
        require(_offerPrice >= param.salePrice, "Err: Offerred price must be greater than or equal to sale price");
        require(offerer == param.offerer, "Err: Offerer is not right");

        // 1.Verify
        _verifyTheSignatures(param, _offerPrice);

        // 2.Check approval
        require(checkSellerApproval(param.seller, param.nftContract), "Err: Seller has disapproved the NFT selling on the platform");

        FuncParams.NFTModel memory previousOffer = _data.getSaleOffer(param.nftContract, param.tokenId, param.seller, isErc721(param.nftContract) ? address(0) : previousOfferer);
        require(_offerPrice > previousOffer.offerPrice, "Err: Your offerred price is less than preceding offered");

        // 3.Deposit and Refund
        _depositFundWhenMakingOffer(offerer, param.currency, _offerPrice);
        // Refund to the previous offerer when new offerer deposited
        if (previousOffer.offerer != address(0) && previousOffer.offerPrice > 0) {
            // Delete offer first
            require(_data.deleteSaleOffer(previousOffer.nftContract, previousOffer.tokenId, previousOffer.seller, previousOffer.offerer), "Err: Delete previous offer failure");

            _refundToPreviousOfferer(previousOffer.offerer, param.currency, previousOffer.offerPrice);
        }
        // Cache offer
        param.offerer = offerer;
        param.offerPrice = _offerPrice;
        require(_data.setSaleOffer(param.nftContract, param.tokenId, param, isErc721(param.nftContract) ? address(0) : offerer), "Err: Set sale offer failure!");

        _logger.emitLog("makeOffer", param, _msgSender());
    }

    function _refundToPreviousOfferer(address offerer, string memory currency, uint256 offerPrice) private {
        // Refund to the previous offerer if new offerer deposits
        if (compareStrings(currency, "ETH")) { 
            _sendValue(offerer, offerPrice, "Err: unable to refund ETH");
        } else {
            _transferToken(currency, offerer, offerPrice, "Err: Unable to refund token to previous offerer");
        }
    }

    function _depositFundWhenMakingOffer(address offerer, string memory currency, uint256 offerPrice) private {
        if (!compareStrings(currency, "ETH")) {
            safeTransferFrom(erc20Contracts[currency], offerer, address(this), offerPrice, "Err: unable to deposit token");
        }
    }

    function acceptOffer(address nftContract, uint256 tokenId, address seller, address offerer, bytes memory sellerSignature) public whenNotPaused nonReentrant isInBlacklist {
        require(!_data.getInvalidSignature(sellerSignature), "Err: Seller signature invalid");

        address userAddr = isErc721(nftContract) ? address(0) : offerer;
        FuncParams.NFTModel memory model = _data.getSaleOffer(nftContract, tokenId, seller, userAddr);

        if (_hasExpired(model.deadline)) {
            // For the case of business requirements, when the deadline is reached,
            // the seller and buyer both are eligible to execute the accept-offer after verified signature successfully
            require(_legalMsgSender() == model.seller || _legalMsgSender() == model.offerer, "Err: You do not have permission to execute the action");
        } else {
            // Otherwise, only seller has the rights to execute the offer acceptance
            require(_legalMsgSender() == model.seller, "Err: Caller must be the seller");
        }

        require(!_data.getInvalidSignature(model.offerSignature), "Err: Offer signature invalid");
        require(offerer == model.offerer, "Err: Offerer is not right");

        _verifyTheSignatures(model, model.offerPrice);

        // 2.Delete offer
        require(_data.deleteSaleOffer(nftContract, tokenId, seller, userAddr), "Err: Delete sale offer failure");

        _addInvalidSigns(nftContract, sellerSignature, true);
        _addInvalidSigns(nftContract, model.offerSignature, false);

        // 3.Transfer/Mint NFT to buyer
        FuncParams.TransferNFTParams memory nftParam;
        nftParam.nftContract = nftContract;
        nftParam.tokenId = tokenId;
        nftParam.amount = model.amount;
        nftParam.tokenCID = model.tokenCID;
        nftParam.buyer = offerer;
        nftParam.seller = seller;
        nftParam.royalties = model.royalties;
        nftParam.message = model.message;
        _transferOrMintNFTToBuyer(nftParam);

        // 4.Distribute ETH/WETH/USDT to creator, platform, and seller
        FuncParams.DistributeRevenueParams memory dParam;
        dParam.nftContract = nftContract;
        dParam.currency = model.currency;
        dParam.seller = seller;
        dParam.tokenId = tokenId;
        dParam.offerPrice = model.offerPrice;
        dParam.royalties = model.royalties;
        _distributeRevenues(dParam);

        _logger.emitLog("acceptOffer", model, _msgSender());
    }

    // Seller starts the transaction
    function cancelListing(address nftContract, uint256 tokenId, address offerer) public whenNotPaused nonReentrant isInBlacklist {
        require(_enabledCancelListing, "Err: Cancel Listing Not Allowed");
        address seller = _legalMsgSender();
        _cancelNFT(nftContract, tokenId, seller, offerer, "cancelListing");
    }

    // Offerer starts the transaction
    // Cancel my offer and get my fund returns if the NFT holder has sold the NFT out in third parties NFT marketplaces
    function cancelMyOffer(address nftContract, uint256 tokenId, address seller) public whenNotPaused nonReentrant isInBlacklist {
        require(_enabledCancelMyOffer, "Err: Cancel My Offer Not Allowed");
        // uint256 balance = 0;
        // if (isErc721(nftContract)) {
        //     balance = IERC721(nftContract).ownerOf(tokenId) == offerer ? 1 : 0;
        // } else {
        //     balance = IERC1155(nftContract).balanceOf(seller, tokenId);
        // }
        // require(balance == 0, "Err: Seller still has the token id at present");
        address offerer = _legalMsgSender();
        _cancelNFT(nftContract, tokenId, seller, offerer, "cancelMyOffer");
    }

    function _cancelNFT(address nftContract, uint256 tokenId, address seller, address offerer, string memory _t) private {
        address userAddr = isErc721(nftContract) ? address(0) : offerer;
        FuncParams.NFTModel memory model = _data.getSaleOffer(nftContract, tokenId, seller, userAddr);

        require(!(_data.getInvalidSignature(model.sellerSignature)), "Err: Seller signature invalid");
        require(model.tokenId > 0 && model.salePrice > 0 && model.offerPrice > 0, "Err: Wrong offer order");
        require(seller == model.seller, "Err: Caller must be the seller");
        require(offerer == model.offerer, "Err: Offerer is not right");
        require(nftContract == model.nftContract && tokenId == model.tokenId, "Err: Wrong order");

        _verifyTheSignatures(model, model.offerPrice);

        if (compareStrings(_t, "cancelListing")) { 
            _data.setInvalidSignature(model.sellerSignature, true);
        } else if (compareStrings(_t, "cancelMyOffer")) {
            require(!(_data.getInvalidSignature(model.offerSignature)), "Err: Offerer signature invalid");
        }
        _addInvalidSigns(nftContract, model.offerSignature, false);

        // 2.Delete offer
        require(_data.deleteSaleOffer(nftContract, tokenId, seller, userAddr), "Err: delete offer failure");

        // 3.Refund
        _refundToPreviousOfferer(offerer, model.currency, model.offerPrice);

        _logger.emitLog(_t, model, _msgSender());
    }

    /*
     * Buyer starts the transaction
     * Buyer offers the buyout price in the auction progress to gain the NFT directly
     **/
    function buyoutDeal(FuncParams.NFTModel memory p, address previousOfferer) public payable whenNotPaused nonReentrant isInBlacklist {
        _buyDirect(p, previousOfferer, "buyoutDeal");
    }

    /**
     * Buy with Fixed Price Sale
     */
    function buyWithFixedPrice(FuncParams.NFTModel memory p) public payable whenNotPaused nonReentrant isInBlacklist {
        _buyDirect(p, address(0), "buyWithFixedPrice");
    }

    function _buyDirect(FuncParams.NFTModel memory p, address previousOfferer, string memory _t) private {
        require(!_hasExpired(p.deadline), "Err: Auction has expired");
        require(!_data.getInvalidSignature(p.sellerSignature), "Err: Seller signature invalid");

        uint256 _offerPrice = 0;
        if (compareStrings(p.currency, "ETH")) {
            require(msg.value > 0, "Err: Zero offer price");
            _offerPrice = msg.value;
        } else {
            require(erc20Contracts[p.currency] != address(0), "Err: Currency Not Recognized");
            require(p.offerPrice > 0 && msg.value == 0, "Err: Offer price zero");
            _offerPrice = p.offerPrice;
        }

        address buyer = _legalMsgSender();
        require(p.seller != buyer, "Err: Buyer and seller both must not be the same one");
        require(_offerPrice >= p.salePrice, "Err: Offer price must be greater than sale price");
        if (p.saleType == 2 || p.saleType == 3) {
            require(_offerPrice >= p.finalPrice, "Err: Offer price must be higher than final price"); 
        }

        // 1.Verify the seller
        SignMessage.Model memory _messageModel = FuncParams.setSellerMessage(p);
        bool s0 = _verifier.isValidSignature(p.seller, _messageModel, p.sellerSignature, p.deadline);
        require(s0, "Err: Invalid seller signature");

        // Check approval
        require(checkSellerApproval(p.seller, p.nftContract), "Err: Seller has disapproved the NFT selling on the platform");

        _depositFundWhenMakingOffer(buyer, p.currency, _offerPrice);

        _addInvalidSigns(p.nftContract, p.sellerSignature, true);

        if (compareStrings(_t, "buyoutDeal")) {
            // If the buyer has submitted an offer prior to the current Buyout dealing, then we need to refund the ETH or token to him.
            FuncParams.NFTModel memory pOfferredModel = _data.getSaleOffer(p.nftContract, p.tokenId, p.seller, isErc721(p.nftContract) ? address(0) : previousOfferer);
            if (pOfferredModel.offerPrice > 0) {
                uint256 price_ = pOfferredModel.offerPrice;
                pOfferredModel.offerPrice = 0; // In case of re-entrance
                _refundToPreviousOfferer(pOfferredModel.offerer, pOfferredModel.currency, price_);
            }
        }

        // 2.Transfers/Mints NFT to buyer
        FuncParams.TransferNFTParams memory nftParam;
        nftParam.nftContract = p.nftContract;
        nftParam.tokenId = p.tokenId;
        nftParam.amount = p.amount;
        nftParam.tokenCID = p.tokenCID;
        nftParam.buyer = buyer;
        nftParam.seller = p.seller;
        nftParam.royalties = p.royalties;
        nftParam.message = p.message;
        _transferOrMintNFTToBuyer(nftParam);

        // 3.Distribute ether to creator, platform, and seller
        FuncParams.DistributeRevenueParams memory dParam;
        dParam.nftContract = p.nftContract;
        dParam.currency = p.currency;
        dParam.seller = p.seller;
        dParam.tokenId = p.tokenId;
        dParam.offerPrice = _offerPrice;
        dParam.royalties = p.royalties;
        _distributeRevenues(dParam);

        _logger.emitLog(_t, p, _msgSender());
    }

    function _verifyTheSignatures(FuncParams.NFTModel memory model, uint256 offerPrice) private view returns (SignMessage.Model memory mSeller) {
        // Verify the seller
        mSeller = FuncParams.setSellerMessage(model);
        bool s0 = _verifier.isValidSignature(model.seller, mSeller, model.sellerSignature, model.deadline);
        require(s0, "Err: Invalid seller signature");

        // Verify the offerer
        mSeller.to = model.offerer;
        mSeller.salePrice = offerPrice;
        mSeller.nonce = model.offerNonce;
        bool s1 = _verifier.isValidSignature(model.offerer, mSeller, model.offerSignature, model.deadline);
        require(s1, "Err: Invalid offerer signature");
    }

    function _addInvalidSigns(address nftContract, bytes memory signs, bool isSeller) private {
        if (isErc721(nftContract)) {
            require(_data.setInvalidSignature(signs, true), "Err: Unable to invalidate signature");
        } else if (!isSeller) {
            require(_data.setInvalidSignature(signs, true), "Err: Failed to invalidate signature");
        }
    }
}
