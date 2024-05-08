// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import './interfaces/IWATIdo.sol';

contract WATIdo is IWATIdo, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public WAT;
    IERC20 public USDT;

    uint public targetAmount;

    uint public vestingStartTime;
    uint public vestingDuration;

    uint public idoStartTime;
    uint public idoDuration;

    uint public totalAllocation;
    uint public totalDeposit;

    address[] public userDepositList;
    mapping(address => uint) public userDeposit;
    mapping(address => uint) public userClaim;

    bool public isFinish = false;

    modifier notFinish() {
        require(!isFinish);
        _;
    }

    function setIdo(address USDT_, uint targetAmount_, uint idoStartTime_, uint idoDuration_) external nonReentrant onlyOwner {
        USDT = IERC20(USDT_);

        idoStartTime = idoStartTime_;
        idoDuration = idoDuration_;
        
        targetAmount = targetAmount_;
    }

    function setVesting(address WAT_, uint allocation_, uint vestingStartTime_, uint vestingDuration_) external nonReentrant onlyOwner {
        require(block.timestamp > idoStartTime + idoDuration, "IDO: It's not over");

        WAT = IERC20(WAT_);

        vestingStartTime = vestingStartTime_;
        vestingDuration = vestingDuration_;

        totalAllocation = allocation_;

        WAT.safeTransferFrom(msg.sender, address(this), allocation_);
    }

    function deposit(uint amount) external nonReentrant notFinish {
        require(block.timestamp > idoStartTime, "IDO: has not started");
        require(block.timestamp < idoStartTime + idoDuration, "IDO: finished");

        USDT.safeTransferFrom(msg.sender, address(this), amount);

        if(targetAmount < totalDeposit + amount){
            //목표량 채우면 바로 끝내야될듯
            isFinish = true;
            uint deltaAmount = totalDeposit + amount - targetAmount;
            amount -= deltaAmount;
            USDT.safeTransfer(msg.sender, deltaAmount);
        }

        userDepositList.push(msg.sender);
        userDeposit[msg.sender] += amount;
        totalDeposit += amount;
        emit Deposited(msg.sender, amount);

    }

    function claim() external nonReentrant {
        require(block.timestamp >= vestingStartTime, "Vesting: has not started");
        uint amount = _available(msg.sender);
        userClaim[msg.sender] += amount;

        WAT.safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }

    function available(address address_) external view returns (uint) {
        return _available(address_);
    }

    function released(address address_) external view returns (uint) {
        return _released(address_);
    }

    function outstanding(address address_) external view returns (uint) {
        uint allocation = userDeposit[address_] * totalAllocation / totalDeposit;
        return allocation - _released(address_);
    }

    function _available(address address_) internal view returns (uint) {
        return _released(address_) - userClaim[address_];
    }

    function _released(address address_) internal view returns (uint) {
        if (block.timestamp < vestingStartTime) {
            return 0;
        } else {
            uint allocation = userDeposit[address_] * totalAllocation / totalDeposit;
            if (block.timestamp > vestingStartTime + vestingDuration) {
                return allocation;
            } else {
                return (allocation * (block.timestamp - vestingStartTime)) / vestingDuration;
            }
        }
    }

    function ownerRefund() external nonReentrant onlyOwner {
        for(uint i = 0; i < userDepositList.length; i++){
            USDT.safeTransfer(userDepositList[i], userDeposit[userDepositList[i]]);
        }
    }

    function ownerClaim() external nonReentrant onlyOwner {
        USDT.safeTransfer(owner(), totalDeposit);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

}