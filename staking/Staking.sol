// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import './interfaces/IStaking.sol';
import '../wat/interfaces/IvWAT.sol';

import "./libraries/Array.sol";

contract Staking is IStaking, Ownable, ReentrancyGuard {

    uint private constant DUST = 1000;

    uint256 public constant PRECISION = 1e12;

    using SafeERC20 for IERC20;

    IERC20 public immutable WAT;
    IvWAT public immutable ivWAT;

    uint public totalStaked;
    uint public totalShares;
    uint public totalEarned;
    uint public rewardPerSecond;
    uint public latestPeriodEndTime;
    uint public latestPeriodStartTime;
    uint public nowtillRewards;

    address[] public userList;
    mapping(address => UserStakingInfo) public userStakingInfos;

    constructor(address _WAT, address _vWAT) {

        WAT = IERC20(_WAT);
        ivWAT = IvWAT(_vWAT);
    }

    function deposit(uint amount) external nonReentrant {
        // _compound();
        _claim();
        WAT.safeTransferFrom(msg.sender, address(this), amount);

        uint deltaShares = 0;
        if (totalShares == 0) {
            deltaShares = amount;
        } else {
            deltaShares = (amount * totalShares) / getTotalStakeReward();
        }

        userStakingInfos[msg.sender].shares += deltaShares;
        userStakingInfos[msg.sender].staked += amount;
        userStakingInfos[msg.sender].updatedAt = block.timestamp;
        totalStaked += amount;
        totalShares += deltaShares;
        userList.push(msg.sender);
        emit Deposited(msg.sender, amount);

        ivWAT.mint(msg.sender, amount);
    }

    function getTotalStakeReward() public view returns(uint){
        uint256 remainingReward;
        if(latestPeriodStartTime == 0 || latestPeriodEndTime == 0){
            return 0;
        }
        else{
            uint currentTime = block.timestamp;

            if(latestPeriodEndTime > currentTime){
                remainingReward = ((currentTime - latestPeriodStartTime) * rewardPerSecond) / PRECISION;
            } else{
                remainingReward = ((latestPeriodEndTime - latestPeriodStartTime) * rewardPerSecond) / PRECISION;
            }

            return totalStaked + remainingReward - totalEarned + nowtillRewards;
        }

    }

    function earned(address user) external view returns (uint) {
        return _earned(user);
    }

    function _earned(address user) internal view returns (uint) {

        if(userStakingInfos[user].staked == 0){
            return 0;
        }
        else{
            uint totalStakeReward = getTotalStakeReward();
            if(totalStakeReward == 0){
                return 0;
            }
            else{
                if((totalStakeReward * userStakingInfos[user].shares) / totalShares >= userStakingInfos[user].staked){
                    return ((totalStakeReward * userStakingInfos[user].shares) / totalShares) - userStakingInfos[user].staked;
                }
                else{
                    return 0;
                }
            }
        }

    }

    function claim() external nonReentrant {
        _claim();
    }

    function _claim() internal {
        uint amount = _earned(msg.sender);
        if(amount != 0){

            uint deltaAmount = Math.min((amount * totalShares) / getTotalStakeReward(), userStakingInfos[msg.sender].shares);

            totalShares -= deltaAmount;
            userStakingInfos[msg.sender].shares -= deltaAmount;
            totalEarned += amount;
            
            WAT.safeTransfer(msg.sender, amount);
            userStakingInfos[msg.sender].claimed += amount;
            userStakingInfos[msg.sender].updatedAt = block.timestamp;
            emit Claimed(msg.sender, amount);
        }

        _cleanupIfDustShares();
    }

    function withdraw() external nonReentrant {
        require(userStakingInfos[msg.sender].withdrawRequestAt != 0, 'withdraw request first');
        require(withdrawRemainingTime(msg.sender) <= 0, 'withdraw lockup exists');
        _claim();
        WAT.safeTransfer(msg.sender, userStakingInfos[msg.sender].withdrawRequestAmount);
        userStakingInfos[msg.sender].withdrawRequestAmount = 0;
        userStakingInfos[msg.sender].withdrawRequestAt = 0;
        emit Withdrawn(msg.sender, userStakingInfos[msg.sender].withdrawRequestAmount);

        if(userStakingInfos[msg.sender].staked == 0){
            Array.removeArray(userList, msg.sender);
        }
    }

    function withdrawRequest(uint amount) external nonReentrant {
        amount = Math.min(withdrawOf(msg.sender), amount);
        _claim();

        uint balance = (getTotalStakeReward() * userStakingInfos[msg.sender].shares) / totalShares;
        uint deltaShares = amount * userStakingInfos[msg.sender].shares / balance;

        totalShares -= deltaShares;
        userStakingInfos[msg.sender].shares -= deltaShares;
        userStakingInfos[msg.sender].withdrawRequestAt = block.timestamp;
        userStakingInfos[msg.sender].staked -= amount;
        totalStaked -= amount;
        userStakingInfos[msg.sender].withdrawRequestAmount += amount;

        emit WithdrawnRequest(msg.sender, amount);

    }

    function withdrawOf(address user) public view returns (uint){
        return userStakingInfos[user].staked;
    }

    function withdrawRemainingTime(address user) public view returns (int){
        return int(userStakingInfos[user].withdrawRequestAt + 7 days) - int(block.timestamp);
    }

    function _cleanupIfDustShares() internal {
        uint shares = userStakingInfos[msg.sender].shares;
        if (shares > 0 && shares < DUST) {
            totalShares -= shares;
            userStakingInfos[msg.sender].shares = 0;
        }
    }

    function setReward(uint256 _amount, uint256 _duration) external onlyOwner {

        WAT.safeTransferFrom(msg.sender, address(this), _amount);

        uint256 currentTime = block.timestamp;
        uint256 endTime = currentTime + _duration;
        uint256 remainingReward;

        if(latestPeriodEndTime > currentTime){
            remainingReward = ((currentTime - latestPeriodStartTime) * rewardPerSecond) / PRECISION;
        }
        else{
            remainingReward = ((latestPeriodEndTime - latestPeriodStartTime) * rewardPerSecond) / PRECISION;
        }
        nowtillRewards += remainingReward;
        rewardPerSecond = (_amount * PRECISION) / _duration;

        latestPeriodStartTime = currentTime;
        latestPeriodEndTime = endTime;

        emit SetReward(rewardPerSecond, latestPeriodStartTime, latestPeriodEndTime);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}