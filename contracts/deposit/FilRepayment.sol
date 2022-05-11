// SPDX-License-Identifier: MIT



pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./FilDeposit.sol";
import "../core/SafeOwnable.sol";



contract FilRepayment is SafeOwnable {
  using SafeERC20 for IERC20;

  IERC20 public filToken;
  FilDeposit public filDeposit;

  event AdminTokenRecovery(address token, uint amount);

  constructor(address _filToken, address _filDeposit) SafeOwnable(msg.sender) {
    require(address(_filToken) != address(0), "illegal filToken address");
    require(address(_filDeposit) != address(0), "illegal filDeposit address");
    filToken = IERC20(_filToken);
    filDeposit = FilDeposit(_filDeposit);
  }

  function repay(uint amount) external onlyOwner {
    require(amount >= 0, "invalid amount");
    filToken.approve(address(filDeposit), amount);
    filDeposit.repay(amount);
  }

  function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount)
    external
    onlyOwner 
  {
    require(_tokenAddress != address(filToken), "cannot be filToken");
    IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
    emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
  }
}