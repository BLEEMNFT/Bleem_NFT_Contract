// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../FuncParams.sol";

contract Logger is Ownable {
    event AuctionExchangeEvent(FuncParams.NFTModel param, address caller, address indexed to, uint256 indexed tokenId, string indexed _type);

    mapping(address => bool) public _exchanges;

    constructor() {}

    function setExchange(address _exchange, bool flag) public onlyOwner {
        require(_exchange != address(0), "Err: Zero exchange contract");
        _exchanges[_exchange] = flag;
    }

    modifier isExchange() {
        require(_exchanges[_msgSender()], "Logger: caller is not exchange");
        _;
    }

    function emitLog(string memory _t, FuncParams.NFTModel memory param, address caller) external isExchange {
        emit AuctionExchangeEvent(param, caller, param.offerer, param.tokenId, _t);
    }
}
