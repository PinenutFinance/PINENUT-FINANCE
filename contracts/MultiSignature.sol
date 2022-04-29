// SPDX-License-Identifier: SimPL-2.0

pragma solidity ^0.8.0;

import "./Timelock.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**·
* @title Timelock
*
* Version v1.1.0
*
*/

contract MultiSignature is Ownable, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;
    bytes32 public constant SIGNER_ROLE = keccak256("MULTI_SIGNATURE_SIGNER");

    Timelock public timelock;

    EnumerableSet.AddressSet private _signers;
    mapping(bytes32 => uint) public _signatureNum;
    mapping(bytes32 => mapping (address => bool)) public _signaturers;

    constructor(address[] memory sinaturers) {
        for (uint256 i = 0; i < sinaturers.length; i++) {
            _setupRole(SIGNER_ROLE, sinaturers[i]);
            _signers.add(sinaturers[i]);
        }
    }

    function _multiSign(bytes32 sign) private returns (bool) {
        require(!_signaturers[sign][msg.sender], "Member Signed");
        _signaturers[sign][msg.sender] = true;
        _signatureNum[sign] = _signatureNum[sign] + 1;
        
        return _signatureNum[sign] < (_signers.length() / 2) + 1;
    }

    function setTimelock(address payable timeLock) external {
        require(address(timelock) == address(0), "Timelock Already Set");
        timelock = Timelock(timeLock);
    }

    function addSigner(address account) external onlyOwner {
        _setupRole(SIGNER_ROLE, account);
        _signers.add(account);
    }

    function removeSigner(address account) external onlyOwner {
        _revokeRole(SIGNER_ROLE, account);
        _signers.remove(account);
    }

    function applyAddSigner(
        address account, bytes32 salt
    ) external onlyRole(SIGNER_ROLE) {
        bytes32 sign = keccak256(abi.encode(address(this), account, salt));
        if (_multiSign(sign)) return;

        uint256 delay = timelock.getMinDelay();
        bytes memory data = abi.encodeWithSignature("addSigner(address)", account);
        timelock.schedule(address(this), 0, data, bytes32(0), salt, delay);
    }

    function excuteAddSigner(
        address account, bytes32 salt
    ) external {
        bytes memory data = abi.encodeWithSignature("addSigner(address)", account);
        timelock.execute(address(this), 0, data, bytes32(0), salt);
    }

    function applyRemoveSigner(
        address account, bytes32 salt
    ) external onlyRole(SIGNER_ROLE) {
        bytes32 sign = keccak256(abi.encode(address(this), account, salt));
        if (_multiSign(sign)) return;

        uint256 delay = timelock.getMinDelay();
        bytes memory data = abi.encodeWithSignature("removeSigner(address)", account);
        timelock.schedule(address(this), 0, data, bytes32(0), salt, delay);
    }

    function excuteRemoveSigner(
        address account, bytes32 salt
    ) external {
        bytes memory data = abi.encodeWithSignature("removeSigner(address)", account);
        timelock.execute(address(this), 0, data, bytes32(0), salt);
    }

    function applyAddWhiteList(
        address target, address account, uint256 amount, bytes32 salt
    ) external onlyRole(SIGNER_ROLE) {
        bytes32 sign = keccak256(abi.encode(target, account, amount, salt));
        if (_multiSign(sign)) return;

        uint256 delay = timelock.getMinDelay();
        bytes memory data = abi.encodeWithSignature("addWhiteList(address,uint256)", account, amount);
        timelock.schedule(target, 0, data, bytes32(0), salt, delay);
    }

    function excuteAddWhiteList(
        address target, address account, uint256 amount, bytes32 salt
    ) external {
        bytes memory data = abi.encodeWithSignature("addWhiteList(address,uint256)", account, amount);
        timelock.execute(target, 0, data, bytes32(0), salt);
    }

    function applyRemoveWhiteList(
        address target, address account, bytes32 salt
    ) external onlyRole(SIGNER_ROLE) {
        bytes32 sign = keccak256(abi.encode(target, account, salt));
        if (_multiSign(sign)) return;

        uint256 delay = timelock.getMinDelay();
        bytes memory data = abi.encodeWithSignature("removeWhiteList(address)", account);
        timelock.schedule(target, 0, data, bytes32(0), salt, delay);
    }

    function excuteRemoveWhiteList(
        address target, address account, bytes32 salt
    ) external {
        bytes memory data = abi.encodeWithSignature("removeWhiteList(address)", account);
        timelock.execute(target, 0, data, bytes32(0), salt);
    }

    function applyLend(
        address target, address account, uint256 amount, bytes32 salt
    ) external onlyRole(SIGNER_ROLE) {
        bytes32 sign = keccak256(abi.encode(target, account, amount, salt));
        if (_multiSign(sign)) return;

        uint256 delay = timelock.getMinDelay();
        bytes memory data = abi.encodeWithSignature("lend(address,uint256)", account, amount);
        timelock.schedule(target, 0, data, bytes32(0), salt, delay);
    }

    function excuteLend(
        address target, address account, uint256 amount, bytes32 salt
    ) external {
        bytes memory data = abi.encodeWithSignature("lend(address,uint256)", account, amount);
        timelock.execute(target, 0, data, bytes32(0), salt);
    }

    function applyGrantRole(
        address target, bytes32 role, address account, bytes32 salt
    ) external onlyRole(SIGNER_ROLE) {
        bytes32 sign = keccak256(abi.encode(target, role, account, salt));
        if (_multiSign(sign)) return;

        uint256 delay = timelock.getMinDelay();
        bytes memory data = abi.encodeWithSignature("grantRole(bytes32,address)", role, account);
        timelock.schedule(target, 0, data, bytes32(0), salt, delay);
    }

    function executeGrantRole(
        address target, bytes32 role, address account, bytes32 salt
    ) external {
        bytes memory data = abi.encodeWithSignature("grantRole(bytes32,address)", role, account);
        timelock.execute(target, 0, data, bytes32(0), salt);
    }

    function applyRevokeRole(
        address target, bytes32 role, address account, bytes32 salt
    ) external onlyRole(SIGNER_ROLE) {
        bytes32 sign = keccak256(abi.encode(target, role, account, salt));
        if (_multiSign(sign)) return;

        uint256 delay = timelock.getMinDelay();
        bytes memory data = abi.encodeWithSignature("revokeRole(bytes32,address)", role, account);
        timelock.schedule(target, 0, data, bytes32(0), salt, delay);
    }

    function executeRevokeRole(
        address target, bytes32 role, address account, bytes32 salt
    ) external {
        bytes memory data = abi.encodeWithSignature("revokeRole(bytes32,address)", role, account);
        timelock.execute(target, 0, data, bytes32(0), salt);
    }
}