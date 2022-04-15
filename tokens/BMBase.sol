// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BMBase is Ownable {

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution. 
        return account.code.length > 0;
    }

    modifier isValidContract(address a) {
        require(a != address(0) && isContract(a), "Err: Not a valid address");
        _;
    }

    modifier isValidAddress(address a) {
        require(a != address(0), "Err: Not a valid address");
        _;
    }

    mapping(address => bool) private _exchanges;

    // Set exchange contract address to current NFT contract in order to mint
    function setExchange(address c, bool flag) external onlyOwner isValidContract(c) {
        _exchanges[c] = flag;
    }

    function getExchange(address contractAddress) public view returns (bool) {
        return _exchanges[contractAddress];
    }

    modifier isExchange() {
        require(_exchanges[_msgSender()], "Err: You do not have permission to behave the action.");
        _;
    }

    bool public _burnNFTEnabled; // defaults to false

    modifier canBurnNFT() {
        require(_burnNFTEnabled, "Err: Burning NFT is restricted!");
        _;
    }

    function enableBurnNFT(bool isEnabled) external onlyOwner {
        _burnNFTEnabled = isEnabled;
    }

    // Use this in case of BNB are sent to the contract by mistake
    event SettleCoinEvent(bool isSuccess, bytes data, address to, uint256 amount);
    function settleCoin(address to) external onlyOwner isValidAddress(to) {
        uint256 total = address(this).balance;
        require(total > 0, "Err: No ETH Balance");
        (bool sent, bytes memory data) = payable(to).call{value: total}("");
        require(sent && (data.length == 0 || abi.decode(data, (bool))), "Err: SettleCoin Failure"); 
        emit SettleCoinEvent(sent, data, to, total);
    }

    // Use this in case of other tokens are sent to the contract by mistake
    event SettleTokenEvent(address tokenAddress, address to, uint256 amount);

    function settleToken(address tokenAddress, address to) external onlyOwner isValidContract(tokenAddress) isValidAddress(to) {
        uint256 total = IERC20(tokenAddress).balanceOf(address(this));
        require(total > 0, "Err: No Token Balance");
        require(IERC20(tokenAddress).transfer(to, total), "Err: SettleAccount Failure");
        emit SettleTokenEvent(tokenAddress, to, total);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}

interface BleemIERC2981 {
    function royaltyInfo(address nftContract, uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount);
}
