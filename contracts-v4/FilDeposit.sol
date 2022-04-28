// SPDX-License-Identifier: SimPL-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


/**·
* @title For FilCoin Deposit Cliam KiKi
*
* Version v1.1.0
*
*/

contract FilDeposit is Ownable, Pausable, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant LEND_ADMIN_ROLE = keccak256("LEND_ADMIN_ROLE");
    bytes32 public constant LEND_ROLE = keccak256("LEND_ROLE");
    bytes32 public constant REPAYMENT_ROLE = keccak256("REPAYMENT_ROLE");

    struct DepositDetail {
        address user;
        uint256 amount;
        uint256 depositType;
        uint256 period;
        uint256 timestamp;
        uint256 index;
        uint256 status;
    }

    ERC20 public DEPOSIT_TOKEN;

    uint256 public totalRegular;
    uint256 public totalCurrent;
    DepositDetail[] public _depositList;

    mapping (address => uint256) public _deposits;
    mapping (uint256 => uint256) public _depositLimits;

    event Deposit(uint256 index, uint256 amount, uint256 period);
    event Withdraw(uint256 index, uint256 amount, uint256 balance);
    event LendToMiner(uint256 amount, address target, uint256 balance);
    event RepaymentByMiner(uint256 amount, uint256 balance);

    constructor(address token) {
        require(Address.isContract(token), "Token Invalid");
        DEPOSIT_TOKEN = ERC20(token);

        _setupRole(LEND_ADMIN_ROLE, _msgSender());

        _setRoleAdmin(LEND_ROLE, LEND_ADMIN_ROLE);
        _setRoleAdmin(REPAYMENT_ROLE, LEND_ADMIN_ROLE);
    }

    function deposit(
        uint256 amount, uint256 depositType, uint256 period
    ) external whenNotPaused {
        require(amount <= _depositLimits[depositType], "Amount Limit");
        require(amount > 0, "Amount Invalid");
        bool success = DEPOSIT_TOKEN.transferFrom(
            msg.sender, address(this), amount
        );
        require(success, "Transfer Invalid");

        if (depositType == 0) {
            _deposits[msg.sender] = _deposits[msg.sender] + amount;
            totalCurrent = totalCurrent + amount;
            emit Deposit(0, amount, period);
        } else {
            DepositDetail memory detail = DepositDetail(
                msg.sender, amount, depositType, period, block.timestamp,
                _depositList.length, 0
            );

            _depositList.push(detail);
            totalRegular = totalRegular + amount;
            // _deposits[msg.sender] = detail;
        
            emit Deposit(detail.index, amount, period);
        }
    }

    function withdraw(
        uint256 depositType, uint256 index, uint256 amount
    )  external whenNotPaused {
        if (depositType == 0) {
            require(_deposits[msg.sender] >= amount, "Balance Not Enough");
            _deposits[msg.sender] = _deposits[msg.sender] - amount;
            totalCurrent = totalCurrent - amount;

            bool success = DEPOSIT_TOKEN.transfer(msg.sender, amount);
            require(success, "Transfer Invalid");
        } else {
            DepositDetail memory detail = _depositList[index];
            
            require(detail.user == msg.sender, "Only Owner");
            require(detail.status == 0, "Already Withdraw");

            require(
                block.timestamp >= detail.period + detail.timestamp,
                "Cannot Withdraw Right Now"
            );

            amount = detail.amount;

            detail.period = block.timestamp;
            detail.status = 1;
            detail.amount = 0;

            totalRegular = totalRegular - amount;
            bool success = DEPOSIT_TOKEN.transfer(msg.sender, amount);
            require(success, "Transfer Invalid");
        }

        emit Withdraw(index, amount, DEPOSIT_TOKEN.balanceOf(address(this)));
    }

    function lendToMiner(uint256 amount, address target) external onlyRole(LEND_ROLE) {
        require(DEPOSIT_TOKEN.balanceOf(address(this)) >= amount, "Not Enough");
        bool success = DEPOSIT_TOKEN.transfer(target, amount);
        require(success, "Transfer Invalid");

        emit LendToMiner(amount, target, DEPOSIT_TOKEN.balanceOf(address(this)));
    }

    function repaymentByMiner(uint256 amount) external onlyRole(REPAYMENT_ROLE) {
        bool success = DEPOSIT_TOKEN.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer Invalid");

        emit RepaymentByMiner(amount, DEPOSIT_TOKEN.balanceOf(address(this)));
    }

    function gettotalRegular() external view returns (uint256 total, uint256 withdrawed) {
        for (uint256 i = 0; i < _depositList.length; i++) {
            total = total + _depositList[i].amount;
            if (_depositList[i].status == 0) continue;
            withdrawed = withdrawed + _depositList[i].amount;
        }

        total = total + totalRegular;
    }

    function getDepositLimit(uint256 depositType) external view returns (uint256) {
        return _depositLimits[depositType];
    }

    function togglePaused() external onlyOwner {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }
}