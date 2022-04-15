// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
 * Bleem NFT Platform Revenue Management
 * It requires the specific number of confirmations to execute a transaction (usually the settlement)
 * Approver addresses and number of confirmations must be specified in being contructing of the contract
 * For example, 3 approvers and 2 confirmations
 */
contract BMRevenueManager is Ownable {
    event Deposit(address indexed sender, uint256 amount, uint256 balance, string indexed from);
    event SubmitTransaction(address indexed authorizer, uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
    event TransactionStatus(address indexed authorizer, uint256 indexed txIndex, string indexed _t);

    address[] public authorizers;
    mapping(address => bool) public isAuthorizer;
    uint256 public immutable numConfirmationsRequired;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    // mapping from tx index => authorizer => bool
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    constructor(address[] memory _authorizers, uint256 _numConfirmationsRequired) {
        require(_authorizers.length > 0, "Err: authorizers required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _authorizers.length, "Err: invalid number of required confirmations");

        for (uint256 i = 0; i < _authorizers.length; i++) {
            address authorizer = _authorizers[i];

            require(authorizer != address(0), "Err: invalid authorizer addresss");
            require(!isAuthorizer[authorizer], "Err: authorizer not unique");

            isAuthorizer[authorizer] = true;
            authorizers.push(authorizer);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    modifier onlyAuthorizer() {
        require(isAuthorizer[msg.sender], "Err: not authorizer");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Err: tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Err: tx already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "Err: tx already confirmed");
        _;
    }

    function submitTransaction(address _to, uint256 _value, bytes memory _data) public onlyAuthorizer {
        uint256 txIndex = transactions.length;
        transactions.push(Transaction({to: _to, value: _value, data: _data, executed: false, numConfirmations: 0}));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex) public onlyAuthorizer txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit TransactionStatus(msg.sender, _txIndex, "confirm");
    }

    function executeTransaction(uint256 _txIndex) public onlyAuthorizer txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "Err: cannot execute tx"
        );

        transaction.executed = true;

        (bool success, bytes memory data) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Err: tx failed");

        emit TransactionStatus(msg.sender, _txIndex, "execute");
    }

    function revokeConfirmation(uint256 _txIndex) public onlyAuthorizer txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "Err: tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit TransactionStatus(msg.sender, _txIndex, "revoke");
    }

    function getAuthorizers() public view returns (address[] memory) {
        return authorizers;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txIndex) public view returns (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations) {
        Transaction storage transaction = transactions[_txIndex];
        return (transaction.to, transaction.value, transaction.data, transaction.executed, transaction.numConfirmations);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance, "receive");
    }

    // Fallback function is called when msg.data is not empty
    fallback() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance, "fallback");
    }

    function queryEthRevenues() public view returns (uint256 _balance) {
        _balance = address(this).balance;
    }

    function queryTokenRevenues(address tokenAddr) public view onlyAuthorizer returns (uint256 _balance) {
        _balance = IERC20(tokenAddr).balanceOf(address(this));
    }
}
