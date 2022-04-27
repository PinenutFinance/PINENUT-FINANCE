// SPDX-License-Identifier: SimPL-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**·
* @title Timelock
*
* Version v1.1.0
*
*/

contract Timelock is TimelockController {
    constructor(
        uint256 minDelay,
        address[] memory proposers, address[] memory executors
    ) TimelockController(minDelay, proposers, executors) {
        
    }
}