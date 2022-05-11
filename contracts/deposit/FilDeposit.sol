// SPDX-License-Identifier: MIT



pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../core/SafeOwnable.sol";


contract FilDeposit is SafeOwnable, Pausable {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  struct FixedDepositDetail {
        address user;
        uint amount;
        uint term;
        uint requestAt;
        uint index;
        uint status;
    }

  IERC20 public depositToken;
  uint public fixedDepositLimit;
  uint public demandDepositLimit;
  uint public fixedTotalAmount;
  uint public demandTotalAmount;
  int public lendAmount;
  FixedDepositDetail[] public _fixedDepositList;
  mapping (address => uint) public _demandDeposit;
  EnumerableSet.AddressSet private _whiteList;

  event FixedDeposit(address user, uint amount, uint requestAt, uint term, uint index);
  event DemandDeposit(address user, uint amount, uint requestAt);
  event FixedWithdraw(address user, uint amount, uint requestAt, uint index);
  event DemandWithdraw(address user, uint amount, uint requestAt);
  event Lend(address borrower, uint amount, uint requestAt);
  event Repay(address repayer, uint amount, uint requestAt);
  event ChangeFixedDepositLimit(uint oldLimitAmount, uint newLimitAmount);
  event ChangeDemandDepositLimit(uint oldLimitAmount, uint newLimitAmount);

  constructor(IERC20 _depositToken, uint _fixedDepositLimit, uint _demandDepositLimit) SafeOwnable(msg.sender) {
    require(address(_depositToken) != address(0), "illegal depositToken");
    require(_fixedDepositLimit >= 0, "invalid fixedDepositLimit");
    require(_demandDepositLimit >= 0, "invalid demandDepositLimit");
    fixedDepositLimit = _fixedDepositLimit;
    demandDepositLimit = _demandDepositLimit;
    depositToken = _depositToken;
  }

  function addWhiteList(address account) external onlyOwner {
    require(account != address(0), "illegal account");
    if (!_whiteList.contains(account)) {
        _whiteList.add(account);
    } 
  }

  function removeWhiteList(address account) external onlyOwner {
    require(_whiteList.contains(account), "account not in white list");
      _whiteList.remove(account);
  }
  
  function fixedDeposit(uint amount, uint term) external whenNotPaused {
    require(amount >= 0, "invalid amount");
    require(term >= 0, "invalid term");
    require(amount + fixedTotalAmount <= fixedDepositLimit, "exceed fixedDeposit limit");
    depositToken.safeTransferFrom(address(msg.sender), address(this), amount);
    uint index = _fixedDepositList.length;
    _fixedDepositList.push(FixedDepositDetail({
      user: msg.sender,
      amount: amount,
      term: term,
      requestAt: block.timestamp,
      index: index,
      status: 0
    }));
    fixedTotalAmount += amount;
    emit FixedDeposit(msg.sender, amount, block.timestamp, term, index);
  }

  function demandDeposit(uint amount) external whenNotPaused{
    require(amount >= 0, "invalid amount");
    require(amount + demandTotalAmount <= demandDepositLimit, "exceed demandDeposit limit");
    depositToken.safeTransferFrom(address(msg.sender), address(this), amount);
    _demandDeposit[msg.sender] += amount;
    demandTotalAmount += amount;
    emit DemandDeposit(msg.sender, amount, block.timestamp);
  }

  function fixedWithdraw(uint index) external whenNotPaused {
    require(index >= 0 && index < _fixedDepositList.length, "invalid index");
    FixedDepositDetail storage detail = _fixedDepositList[index];
    require(detail.user == msg.sender, "only owner");
    require(detail.status == 0, "already withdraw");
    require(block.timestamp >= detail.term + detail.requestAt,"cannot withdraw right now");
    uint amount = detail.amount;
    fixedTotalAmount -= amount;
    depositToken.safeTransfer(msg.sender, amount);
    detail.status = 1;
    emit FixedWithdraw(msg.sender, amount, block.timestamp, index);
  }

  function demandWithdraw(uint amount) external whenNotPaused {
    require(amount >= 0, "invalid amount");
    require(_demandDeposit[msg.sender] >= amount, "balance not enough");
    _demandDeposit[msg.sender] -= amount;
    demandTotalAmount -= amount;
    depositToken.safeTransfer(address(msg.sender), amount);
    emit DemandWithdraw(msg.sender, amount, block.timestamp);
  }

  function lend(address borrower, uint amount) external whenNotPaused onlyOwner {
    require(amount >= 0, "invalid amount");
    require(borrower != address(0), "illegal borrower");
    require(_whiteList.contains(borrower), "borrower not in white list");
    require(depositToken.balanceOf(address(this)) >= amount, "balance not enough");
    depositToken.safeTransfer(borrower, amount);
    lendAmount += int(amount);
    emit Lend(borrower, amount, block.timestamp);
  }

  function repay(uint amount) external {
    require(amount >= 0, "invalid amount");
    depositToken.safeTransferFrom(address(msg.sender), address(this), amount);
    lendAmount -= int(amount);
    emit Repay(msg.sender, amount, block.timestamp);
  }

  function setFixedDepositLimit(uint newLimitAmount) external onlyOwner {
      require(newLimitAmount >= 0, "invalid limit amount");
      emit ChangeFixedDepositLimit(fixedDepositLimit, newLimitAmount);
      fixedDepositLimit = newLimitAmount;
  }

  function setDemandDepositLimit(uint newLimitAmount) external onlyOwner {
      require(newLimitAmount >= 0, "invalid limit amount");
      emit ChangeDemandDepositLimit(demandDepositLimit, newLimitAmount);
      demandDepositLimit = newLimitAmount;
  }

  function getWhiteList() view external returns(address[] memory) {
    return _whiteList.values();
  }


  function togglePause() external onlyOwner {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }
}