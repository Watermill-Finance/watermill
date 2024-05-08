// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import './interfaces/IWATVesting.sol';

contract WATVesting is IWATVesting, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public WAT;

    uint public startTime;
    uint public duration;

    uint public allocation;
    uint public claimed;

    function setVesting(address ACT_, uint allocation_, uint startTime_, uint duration_) external onlyOwner {
        WAT = IERC20(ACT_);

        startTime = startTime_;
        duration = duration_;
        allocation = allocation_;

        WAT.safeTransferFrom(msg.sender, address(this), allocation_);
    }

    function claim(address recipient) external onlyOwner nonReentrant {
        require(block.timestamp >= startTime, "LinearVesting: has not started");
        uint amount = _available();
        claimed += amount;
        WAT.safeTransfer(recipient, amount);

        emit Claimed(recipient, amount);
    }

    function available() external view returns (uint) {
        return _available();
    }

    function released() external view returns (uint) {
        return _released();
    }

    function outstanding() external view returns (uint) {
        return allocation - _released();
    }

    function _available() internal view returns (uint) {
        return _released() - claimed;
    }

    function _released() internal view returns (uint) {
        if (block.timestamp < startTime) {
            return 0;
        } else {
            if (block.timestamp > startTime + duration) {
                return allocation;
            } else {
                return (allocation * (block.timestamp - startTime)) / duration;
            }
        }
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

}