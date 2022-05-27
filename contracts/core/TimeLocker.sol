// SPDX-License-Identifier: MIT



pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/governance/TimelockController.sol";
import "./SafeOwnable.sol";

contract TimeLocker is TimelockController {

    constructor(uint minDelay, address[] memory proposers, address[] memory executors) TimelockController(minDelay, proposers, executors) {
    }

    function acceptOwner(SafeOwnable con) external onlyRole(TIMELOCK_ADMIN_ROLE) {
        con.acceptOwner();
    }
}