// SPDX-License-Identifier: MIT



pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../core/TimeLocker.sol";
import "./FilDeposit.sol";


contract MultiSignature is AccessControl {

  bytes32 public constant SIGNER_ROLE = keccak256("MULTI_SIGNATURE_SIGNER");

  FilDeposit public filDeposit;
  TimeLocker public timeLocker;

  mapping(bytes32 => bool) public transactions;
  mapping(bytes32 => uint) public signatureNum;
  mapping(bytes32 => mapping(address => bool)) signatureRecord;
  uint256 public immutable SIGNATURE_MIN_NUM;

  event NewTimeLocker(address oldTimeLocker, address newTimeLocker);

  event ApplyLend(address requester, address borrower, uint amount, uint requestAt, uint expireAt, bytes32 salt, bytes32 hash);
  event AcceptLend(address requester, address borrower, uint amount, uint requestAt, uint expireAt, bytes32 salt, address acceptor, uint currentNum);

  event ApplyTogglePause(address requester, uint requestAt, uint expireAt, bytes32 salt);
  event AcceptTogglePause(address requester, uint requestAt, uint expireAt, bytes32 salt, address acceptor, uint currentNum);

  event ApplyAddWhiteList(address requester, address account, uint requestAt, uint expireAt, bytes32 salt);
  event AcceptAddWhiteList(address requester, address account, uint requestAt, uint expireAt, bytes32 salt, address acceptor, uint currentNum);

  event ApplyRemoveWhiteList(address requester, address account, uint requestAt, uint expireAt, bytes32 salt);
  event AcceptRemoveWhiteList(address requester, address account, uint requestAt, uint expireAt, bytes32 salt, address acceptor, uint currentNum);

  event ApplySetFixedDepositLimit(address requester, uint newLimitAmount, uint requestAt, uint expireAt, bytes32 salt);
  event AcceptSetFixedDepositLimit(address requester, uint newLimitAmount, uint requestAt, uint expireAt, bytes32 salt, address acceptor, uint currentNum);

  event ApplySetDemandDepositLimit(address requester, uint newLimitAmount, uint requestAt, uint expireAt, bytes32 salt);
  event AcceptSetDemandDepositLimit(address requester, uint newLimitAmount, uint requestAt, uint expireAt, bytes32 salt, address acceptor, uint currentNum);


  constructor(FilDeposit _filDeposit, address[] memory _signers, uint _minNum) {
        require(address(_filDeposit) != address(0), "illegal filDeposit address");
        filDeposit = _filDeposit;
        for (uint256 i = 0; i < _signers.length; ++i) {
            require(!hasRole(SIGNER_ROLE, _signers[i]), "address already signer");
            _setupRole(SIGNER_ROLE, _signers[i]);
        }
        require(_minNum > 0 && _minNum <= _signers.length, "illegal minNum");
        SIGNATURE_MIN_NUM = _minNum;
    }

    function setTimeLocker(TimeLocker _timeLocker) external {
        require(address(timeLocker) == address(0), "already be set");
        timeLocker = _timeLocker;
        emit NewTimeLocker(address(0), address(timeLocker));
    }

    function setSigner(address _newSigner) external {
        require(hasRole(SIGNER_ROLE, _msgSender()), "caller is not a signer");
        require(!hasRole(SIGNER_ROLE, _newSigner), "new signer is already a signer");
        renounceRole(SIGNER_ROLE, _msgSender());
        _setupRole(SIGNER_ROLE, _newSigner);
    }

    //lend

    function applyLend(address borrower, uint amount, uint expireAt, bytes32 salt) external {
        bytes32 hash = keccak256(abi.encode(_msgSender(), borrower, amount, block.timestamp, expireAt, salt));
        require(!transactions[hash], "apply already request");
        transactions[hash] = true;
        signatureNum[hash] = 0;
        emit ApplyLend(msg.sender, borrower, amount, block.timestamp, expireAt, salt, hash);
    }

    function acceptLend(address _requester, address _borrower, uint _amount, uint _requestAt, uint _expireAt, bytes32 _salt) external {
        require(block.timestamp >= _requestAt && block.timestamp <= _expireAt, "illegal time");
        require(hasRole(SIGNER_ROLE, _msgSender()), "caller is not a signer");
        bytes32 hash = keccak256(abi.encode(_requester, _borrower, _amount, _requestAt, _expireAt, _salt));
        require(transactions[hash], "apply not exists");
        require(!signatureRecord[hash][_msgSender()], "signer already accepted");
        signatureNum[hash] = signatureNum[hash] + 1;
        signatureRecord[hash][_msgSender()] = true;
        emit AcceptLend(_requester, _borrower, _amount, _requestAt, _expireAt, _salt, _msgSender(), signatureNum[hash]);
        if (signatureNum[hash] >= SIGNATURE_MIN_NUM) {
            timeLocker.schedule(address(filDeposit), 0, abi.encodeWithSignature("lend(address,uint256)", _borrower, _amount), bytes32(0), _salt, timeLocker.getMinDelay());
        }
    }

    function executeLend(address _borrower, uint _amount,  bytes32 _salt) external {
        timeLocker.execute(address(filDeposit), 0, abi.encodeWithSignature("lend(address,uint256)", _borrower, _amount), bytes32(0), _salt); 
    }

    //togglePause

    function applyTogglePause(uint expireAt, bytes32 salt) external {
        bytes32 hash = keccak256(abi.encode(_msgSender(), block.timestamp, expireAt, salt));
        require(!transactions[hash], "apply already request");
        transactions[hash] = true;
        signatureNum[hash] = 0;
        emit ApplyTogglePause(msg.sender, block.timestamp, expireAt, salt);
    }

    function acceptTogglePause(address _requester, uint _requestAt, uint _expireAt, bytes32 _salt) external {
        require(block.timestamp >= _requestAt && block.timestamp <= _expireAt, "illegal time");
        require(hasRole(SIGNER_ROLE, _msgSender()), "caller is not a signer");
        bytes32 hash = keccak256(abi.encode(_requester, _requestAt, _expireAt, _salt));
        require(transactions[hash], "apply not exists");
        require(!signatureRecord[hash][_msgSender()], "signer already accepted");
        signatureNum[hash] = signatureNum[hash] + 1;
        signatureRecord[hash][_msgSender()] = true;
        emit AcceptTogglePause(_requester, _requestAt, _expireAt, _salt, _msgSender(), signatureNum[hash]);
        if (signatureNum[hash] >= SIGNATURE_MIN_NUM) {
            //with 0 delay
            timeLocker.schedule(address(filDeposit), 0, abi.encodeWithSignature("togglePause()"), bytes32(0), _salt, 0);
        }
    }

    function executePause(bytes32 _salt) external {
        timeLocker.execute(address(filDeposit), 0, abi.encodeWithSignature("togglePause()"), bytes32(0), _salt); 
    }

    //add whitelist

    function applyAddWhiteList(address account, uint expireAt, bytes32 salt) external {
        bytes32 hash = keccak256(abi.encode(_msgSender(), account, block.timestamp, expireAt, salt));
        require(!transactions[hash], "apply already request");
        transactions[hash] = true;
        signatureNum[hash] = 0;
        emit ApplyAddWhiteList(msg.sender, account, block.timestamp, expireAt, salt);
    }

    function acceptAddWhiteList(address _requester, address _account, uint _requestAt, uint _expireAt, bytes32 _salt) external {
        require(block.timestamp >= _requestAt && block.timestamp <= _expireAt, "illegal time");
        require(hasRole(SIGNER_ROLE, _msgSender()), "caller is not a signer");
        bytes32 hash = keccak256(abi.encode(_requester, _account, _requestAt, _expireAt, _salt));
        require(transactions[hash], "apply not exists");
        require(!signatureRecord[hash][_msgSender()], "signer already accepted");
        signatureNum[hash] = signatureNum[hash] + 1;
        signatureRecord[hash][_msgSender()] = true;
        emit AcceptAddWhiteList(_requester, _account, _requestAt, _expireAt, _salt, _msgSender(), signatureNum[hash]);
        if (signatureNum[hash] >= SIGNATURE_MIN_NUM) {
            timeLocker.schedule(address(filDeposit), 0, abi.encodeWithSignature("addWhiteList(address)", _account), bytes32(0), _salt, timeLocker.getMinDelay());
        }
    }

    function executeAddWhiteList(address _account,  bytes32 _salt) external {
        timeLocker.execute(address(filDeposit), 0, abi.encodeWithSignature("addWhiteList(address)", _account), bytes32(0), _salt); 
    }

     //remove whitelist

    function applyRemoveWhiteList(address account, uint expireAt, bytes32 salt) external {
        bytes32 hash = keccak256(abi.encode(_msgSender(), account, block.timestamp, expireAt, salt));
        require(!transactions[hash], "apply already request");
        transactions[hash] = true;
        signatureNum[hash] = 0;
        emit ApplyRemoveWhiteList(msg.sender, account, block.timestamp, expireAt, salt);
    }

    function acceptRemoveWhiteList(address _requester, address _account, uint _requestAt, uint _expireAt, bytes32 _salt) external {
        require(block.timestamp >= _requestAt && block.timestamp <= _expireAt, "illegal time");
        require(hasRole(SIGNER_ROLE, _msgSender()), "caller is not a signer");
        bytes32 hash = keccak256(abi.encode(_requester, _account, _requestAt, _expireAt, _salt));
        require(transactions[hash], "apply not exists");
        require(!signatureRecord[hash][_msgSender()], "signer already accepted");
        signatureNum[hash] = signatureNum[hash] + 1;
        signatureRecord[hash][_msgSender()] = true;
        emit AcceptRemoveWhiteList(_requester, _account, _requestAt, _expireAt, _salt, _msgSender(), signatureNum[hash]);
        if (signatureNum[hash] >= SIGNATURE_MIN_NUM) {
            timeLocker.schedule(address(filDeposit), 0, abi.encodeWithSignature("removeWhiteList(address)", _account), bytes32(0), _salt, timeLocker.getMinDelay());
        }
    }

    function executeRemoveWhiteList(address _account,  bytes32 _salt) external {
        timeLocker.execute(address(filDeposit), 0, abi.encodeWithSignature("removeWhiteList(address)", _account), bytes32(0), _salt); 
    }

    //set new fixedDeposit limit

    function applySetFixedDepositLimit(uint newLimitAmount, uint expireAt, bytes32 salt) external {
        bytes32 hash = keccak256(abi.encode(_msgSender(), newLimitAmount, block.timestamp, expireAt, salt));
        require(!transactions[hash], "apply already request");
        transactions[hash] = true;
        signatureNum[hash] = 0;
        emit ApplySetFixedDepositLimit(msg.sender, newLimitAmount, block.timestamp, expireAt, salt);
    }

    function acceptSetFixedDepositLimit(address _requester, uint _newLimitAmount, uint _requestAt, uint _expireAt, bytes32 _salt) external {
        require(block.timestamp >= _requestAt && block.timestamp <= _expireAt, "illegal time");
        require(hasRole(SIGNER_ROLE, _msgSender()), "caller is not a signer");
        bytes32 hash = keccak256(abi.encode(_requester, _newLimitAmount, _requestAt, _expireAt, _salt));
        require(transactions[hash], "apply not exists");
        require(!signatureRecord[hash][_msgSender()], "signer already accepted");
        signatureNum[hash] = signatureNum[hash] + 1;
        signatureRecord[hash][_msgSender()] = true;
        emit AcceptSetFixedDepositLimit(_requester, _newLimitAmount, _requestAt, _expireAt, _salt, _msgSender(), signatureNum[hash]);
        if (signatureNum[hash] >= SIGNATURE_MIN_NUM) {
            timeLocker.schedule(address(filDeposit), 0, abi.encodeWithSignature("setFixedDepositLimit(uint256)", _newLimitAmount), bytes32(0), _salt, timeLocker.getMinDelay());
        }
    }

    function executeSetFixedDepositLimit(uint _newLimitAmount,  bytes32 _salt) external {
        timeLocker.execute(address(filDeposit), 0, abi.encodeWithSignature("setFixedDepositLimit(uint256)", _newLimitAmount), bytes32(0), _salt); 
    }

    //set new demandDeposit limit

    function applySetDemandDepositLimit(uint newLimitAmount, uint expireAt, bytes32 salt) external {
        bytes32 hash = keccak256(abi.encode(_msgSender(), newLimitAmount, block.timestamp, expireAt, salt));
        require(!transactions[hash], "apply already request");
        transactions[hash] = true;
        signatureNum[hash] = 0;
        emit ApplySetDemandDepositLimit(msg.sender, newLimitAmount, block.timestamp, expireAt, salt);
    }

    function acceptSetDemandDepositLimit(address _requester, uint _newLimitAmount, uint _requestAt, uint _expireAt, bytes32 _salt) external {
        require(block.timestamp >= _requestAt && block.timestamp <= _expireAt, "illegal time");
        require(hasRole(SIGNER_ROLE, _msgSender()), "caller is not a signer");
        bytes32 hash = keccak256(abi.encode(_requester, _newLimitAmount, _requestAt, _expireAt, _salt));
        require(transactions[hash], "apply not exists");
        require(!signatureRecord[hash][_msgSender()], "signer already accepted");
        signatureNum[hash] = signatureNum[hash] + 1;
        signatureRecord[hash][_msgSender()] = true;
        emit AcceptSetDemandDepositLimit(_requester, _newLimitAmount, _requestAt, _expireAt, _salt, _msgSender(), signatureNum[hash]);
        if (signatureNum[hash] >= SIGNATURE_MIN_NUM) {
            timeLocker.schedule(address(filDeposit), 0, abi.encodeWithSignature("setDemandDepositLimit(uint256)", _newLimitAmount), bytes32(0), _salt, timeLocker.getMinDelay());
        }
    }

    function executeSetDemandDepositLimit(uint _newLimitAmount,  bytes32 _salt) external {
        timeLocker.execute(address(filDeposit), 0, abi.encodeWithSignature("setDemandDepositLimit(uint256)", _newLimitAmount), bytes32(0), _salt); 
    }

    

}