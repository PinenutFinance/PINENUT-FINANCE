// SPDX-License-Identifier: SimPL-2.0

pragma solidity ^0.8.0;

import "./FilDeposit.sol";
import "./Timelock.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
* @title For FilCoin Deposit Cliam KiKi
*
* Version v1.1.0
*
*/

contract FilLoan is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    ERC20 public filToken;
    FilDeposit public depositPool;
    EnumerableSet.AddressSet private _whiteList;
    
    mapping (address => uint256) public _amounts;

    event AddWhiteList(address account, uint256 amount);
    event RemoveWhiteList(address account);
    event Lend(address account, uint256 amount, uint256 balance);
    event Repayment(uint256 amount, uint256 poolBalance);

    constructor(address _depositPool, address _filToken) {
        require(Address.isContract(_depositPool), "Pool Invalid");
        depositPool = FilDeposit(_depositPool);
        require(Address.isContract(_filToken), "Token Invalid");
        filToken = ERC20(_filToken);
    }

    function addWhiteList(address account, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount Invalid");
        
        if (!_whiteList.contains(account)) _whiteList.add(account);
        _amounts[account] = amount;

        emit AddWhiteList(account, amount);
    }

    function removeWhiteList(address account) external onlyOwner {
        _whiteList.remove(account);
        delete _amounts[account];

        emit RemoveWhiteList(account);
    }

    function lend(address account, uint256 amount) external onlyOwner {
        require(_whiteList.contains(account), "Not In White List");
        require(amount <= _amounts[account], "Lend Balance Not Enough");

        _amounts[account] = _amounts[account] - amount;
        depositPool.lendToMiner(amount, account);

        emit Lend(account, amount, _amounts[account]);
    }

    function repayment(uint256 amount) external {
        filToken.approve(address(depositPool), amount);
        depositPool.repaymentByMiner(amount);

        emit Repayment(amount, filToken.balanceOf(address(depositPool)));
    }
}