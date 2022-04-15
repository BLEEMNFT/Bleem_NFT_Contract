// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";


contract BMUpgradeableProxy is TransparentUpgradeableProxy { 

    constructor(address _logic, address admin_) TransparentUpgradeableProxy(_logic, admin_, "") { }

    function getImpl() public view returns (address) {
        return _implementation();
    }

}
