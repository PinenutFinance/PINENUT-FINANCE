// SPDX-License-Identifier: SimPL-2.0

pragma solidity ^0.8.0;

import "./Timelock.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**·
* @title Timelock
*
* Version v1.1.0
*
*/

contract MultiSignature is Ownable, AccessControl {
    uint256 public immutable SINATURE_NUMBER;
    bytes32 public constant SIGNER_ROLE = keccak256("MULTI_SIGNATURE_SIGNER");

    Timelock public timelock;

    mapping(bytes32 => uint) public _signatureNum;
    mapping(bytes32 => mapping (address => bool)) public _signaturers;

    constructor(address[] memory sinaturers, uint256 sinatureNumber) {
        for (uint256 i = 0; i < sinaturers.length; i++) {
            _setupRole(SIGNER_ROLE, sinaturers[i]);
        }

        require(sinatureNumber > 0 && sinatureNumber <= sinaturers.length, "Invalid Number");
        SINATURE_NUMBER = sinatureNumber;
    }

    function setTimelock(address payable timeLock) external {
        require(address(timelock) == address(0), "Timelock Already Set");
        timelock = Timelock(timeLock);
    }

    function addSinatures(address account) external onlyOwner {
        _setupRole(SIGNER_ROLE, account);
    }

    function removeSinatures(address account) external onlyOwner {
        _revokeRole(SIGNER_ROLE, account);
    }

    function applyAddSinatures(
        address account, bytes32 salt
    ) external onlyRole(SIGNER_ROLE) {
        bytes32 sign = keccak256(abi.encode(address(this), account, salt));
        require(!_signaturers[sign][msg.sender], "Membere Signed");
        _signaturers[sign][msg.sender] = true;
        _signatureNum[sign] = _signatureNum[sign] + 1;
        
        if (_signatureNum[sign] <= SINATURE_NUMBER) return;

        uint256 delay = timelock.getMinDelay();
        bytes memory data = abi.encodeWithSignature("addSinatures(address)", account);
        timelock.schedule(address(this), 0, data, bytes32(0), salt, delay);
    }

    function excuteAddSinatures(
        address account, bytes32 salt
    ) external {
        bytes memory data = abi.encodeWithSignature("addSinatures(address)", account);
        timelock.execute(address(this), 0, data, bytes32(0), salt);
    }

    function applyRemoveSinatures(
        address account, bytes32 salt
    ) external onlyRole(SIGNER_ROLE) {
        bytes32 sign = keccak256(abi.encode(address(this), account, salt));
        require(!_signaturers[sign][msg.sender], "Membere Signed");
        _signaturers[sign][msg.sender] = true;
        _signatureNum[sign] = _signatureNum[sign] + 1;
        
        if (_signatureNum[sign] <= SINATURE_NUMBER) return;

        uint256 delay = timelock.getMinDelay();
        bytes memory data = abi.encodeWithSignature("removeSinatures(address)", account);
        timelock.schedule(address(this), 0, data, bytes32(0), salt, delay);
    }

    function excuteRemoveSinatures(
        address account, bytes32 salt
    ) external {
        bytes memory data = abi.encodeWithSignature("removeSinatures(address)", account);
        timelock.execute(address(this), 0, data, bytes32(0), salt);
    }

    function applyAddWhiteList(
        address target, address account, uint256 amount, bytes32 salt
    ) external onlyRole(SIGNER_ROLE) {
        bytes32 sign = keccak256(abi.encode(target, account, amount, salt));
        require(!_signaturers[sign][msg.sender], "Membere Signed");
        _signaturers[sign][msg.sender] = true;
        _signatureNum[sign] = _signatureNum[sign] + 1;
        
        if (_signatureNum[sign] <= SINATURE_NUMBER) return;

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
        require(!_signaturers[sign][msg.sender], "Membere Signed");
        _signaturers[sign][msg.sender] = true;
        _signatureNum[sign] = _signatureNum[sign] + 1;
        
        if (_signatureNum[sign] <= SINATURE_NUMBER) return;

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
        require(!_signaturers[sign][msg.sender], "Membere Signed");
        _signaturers[sign][msg.sender] = true;
        _signatureNum[sign] = _signatureNum[sign] + 1;
        
        if (_signatureNum[sign] <= SINATURE_NUMBER) return;

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
}