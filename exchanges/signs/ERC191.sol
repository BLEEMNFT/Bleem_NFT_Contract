// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./SignMessage.sol"; 

contract ERC191 {
    function getMessageHash(SignMessage.Model memory params, uint256 deadline) public view returns (bytes32) {
        uint256 chainid = block.chainid;
        bytes memory m = abi.encodePacked(params.to, params.nftContract, params.tokenId, params.tokenCID, params.amount, params.currency, params.saleType, params.salePrice, params.finalPrice, params.reservePrice);
        uint256 secretKey = 0x12ff9aee899db712439a5e19cfdbf9d7ccd2b8324fe984cff8f22070a575f1ee;
        uint256 _message = secretKey + deadline;
        bytes memory n = abi.encodePacked(chainid, params.startTime, params.nonce, _message, params.royalties, params.salt);
        return keccak256(abi.encodePacked(m, n));
    }

    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        Note: \x means 0x19
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    function isValidSignature(address _signer, SignMessage.Model memory params, bytes memory signature, uint256 deadline) public view returns (bool) {
        bytes32 messageHash = getMessageHash(params, deadline);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
