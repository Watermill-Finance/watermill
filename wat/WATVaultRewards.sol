// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IWATVaultRewards.sol";

import "./libraries/Array.sol";

contract WATVaultRewards is IWATVaultRewards, Ownable {

    using SafeERC20 for IERC20;


    mapping(address => VaultRewardsInfo) public vaultRewardsInfos;
    address[] public rewardsVault;

    mapping(address => mapping(address => mapping(address => UserInfo))) public userInfos;

    mapping(address => uint) public totalCount;
    mapping(address => uint[]) public totalLiquidityArr;
    mapping(address => uint[]) public totalRewardArr;


    IERC20 public immutable WAT;

    bool public isAirdropEvent = false;
    mapping(address => address[]) public airdropEventUsers;
    mapping(address => mapping(address => uint)) public airdropEventUserLiqudity;

    constructor(address _WAT) {
        WAT = IERC20(_WAT);
    }

    function setAirdropEvent(bool _isAirdropEvent) external onlyOwner {
        isAirdropEvent = _isAirdropEvent;
    }

    function pushRewardsVault(address vault) external onlyOwner {
        rewardsVault.push(vault);
    }

    function rewardsVaultLength() external view returns(uint){
        return rewardsVault.length;
    }

    function setReward(address _vault, uint256 _amount, uint256 _duration) external onlyOwner {


        uint256 currentTime = block.timestamp;
        uint256 endTime = currentTime + _duration;
        uint256 remainingReward;

        if(vaultRewardsInfos[_vault].latestPeriodStartTime > vaultRewardsInfos[_vault].latestPeriodEndTime || vaultRewardsInfos[_vault].latestPeriodStartTime == 0){
            remainingReward = 0;
        }
        else{
            if(vaultRewardsInfos[_vault].latestPeriodEndTime > currentTime){
                remainingReward = ((currentTime - vaultRewardsInfos[_vault].latestPeriodStartTime) * vaultRewardsInfos[_vault].rewardPerSecond);
                uint othersReward = ((vaultRewardsInfos[_vault].latestPeriodEndTime - vaultRewardsInfos[_vault].latestPeriodStartTime) * vaultRewardsInfos[_vault].rewardPerSecond) - remainingReward;
                WAT.safeTransfer(owner(), othersReward);
            }
            else{
                remainingReward = ((vaultRewardsInfos[_vault].latestPeriodEndTime - vaultRewardsInfos[_vault].latestPeriodStartTime) * vaultRewardsInfos[_vault].rewardPerSecond);
            }
        }


        if(totalCount[_vault] != 0){
            totalLiquidityArr[_vault].push(totalLiquidityArr[_vault][totalCount[_vault] - 1]);
            totalRewardArr[_vault].push(remainingReward);
            totalCount[_vault]++;
        }

        WAT.safeTransferFrom(msg.sender, address(this), _amount);

        vaultRewardsInfos[_vault].rewardPerSecond = _amount / _duration;
        vaultRewardsInfos[_vault].rewardAmount = _amount;
        vaultRewardsInfos[_vault].latestPeriodStartTime = currentTime;
        vaultRewardsInfos[_vault].latestPeriodEndTime = endTime;

        emit SetReward(_vault, vaultRewardsInfos[_vault].rewardPerSecond, vaultRewardsInfos[_vault].latestPeriodStartTime, vaultRewardsInfos[_vault].latestPeriodEndTime);

    }

    function _getTotalReward(address _vault) public view returns(uint remainingReward, uint currentTime){
        if(!Array.inArray(rewardsVault, msg.sender)) remainingReward = 0; currentTime = 0;

        if(vaultRewardsInfos[_vault].latestPeriodStartTime == 0 || vaultRewardsInfos[_vault].latestPeriodEndTime == 0 || vaultRewardsInfos[_vault].latestPeriodStartTime > vaultRewardsInfos[_vault].latestPeriodEndTime){
            remainingReward = 0; currentTime = 0;
        }
        else{
            currentTime = block.timestamp;

            if(vaultRewardsInfos[_vault].latestPeriodEndTime > currentTime){
                remainingReward = ((currentTime - vaultRewardsInfos[_vault].latestPeriodStartTime) * vaultRewardsInfos[_vault].rewardPerSecond);
            } else{
                remainingReward = ((vaultRewardsInfos[_vault].latestPeriodEndTime - vaultRewardsInfos[_vault].latestPeriodStartTime) * vaultRewardsInfos[_vault].rewardPerSecond);
            }

        
        }
    }

    function earnd(address _vault, address user, address token) public view returns(uint profit) {
        if(!Array.inArray(rewardsVault, msg.sender)) return 0;

        if(userInfos[_vault][user][token].liquidity == 0){
            profit = 0;
        }else{
            //과거
            for(uint i = userInfos[_vault][user][token].updatedCount; i < totalCount[_vault]; i++){
                uint totalLiquidity = totalLiquidityArr[_vault][i];
                uint totalReward = totalRewardArr[_vault][i];
                profit += (totalReward * userInfos[_vault][user][token].liquidity / totalLiquidity);
            }
            //현재
            (uint remainingReward, ) = _getTotalReward(_vault);
            profit += remainingReward * userInfos[_vault][user][token].liquidity / totalLiquidityArr[_vault][totalCount[_vault] - 1];
            // 받은거 빼줘야할듯?
            profit -= userInfos[_vault][user][token].earnd;
        }

    }

    function deposit(address _vault, address user, address token, uint _liquidity) external {
        if(!Array.inArray(rewardsVault, msg.sender)) return;

        if(totalCount[_vault] == 0){
            totalLiquidityArr[_vault].push(_liquidity);
            (uint totalReward, uint currentTime) = _getTotalReward(_vault);
            vaultRewardsInfos[_vault].latestPeriodStartTime = currentTime;
            totalRewardArr[_vault].push(totalReward);
            totalCount[_vault]++;

            userInfos[_vault][user][token].liquidity += _liquidity;
            userInfos[_vault][user][token].updatedCount = totalCount[_vault];
            userInfos[_vault][user][token].earnd = 0;
        }
        else{
            totalLiquidityArr[_vault].push(totalLiquidityArr[_vault][totalCount[_vault] - 1]);
            (uint totalReward, uint currentTime) = _getTotalReward(_vault);
            vaultRewardsInfos[_vault].latestPeriodStartTime = currentTime;
            totalRewardArr[_vault].push(totalReward);
            totalCount[_vault]++;

            userInfos[_vault][user][token].liquidity += _liquidity;
            userInfos[_vault][user][token].updatedCount = totalCount[_vault];
            userInfos[_vault][user][token].earnd = 0;

            totalLiquidityArr[_vault].push(totalLiquidityArr[_vault][totalCount[_vault] - 1] + _liquidity);
            totalRewardArr[_vault].push(0);
            totalCount[_vault]++;
        }

        emit Deposited(_vault, user, _liquidity);

        if(isAirdropEvent){
            if(!Array.inArray(airdropEventUsers[_vault], user)){
                airdropEventUsers[_vault].push(user);
            }
            airdropEventUserLiqudity[_vault][user] += _liquidity;
        }
    }

    function getReward(address _vault, address user, address token) external returns(uint) {
        if(!Array.inArray(rewardsVault, msg.sender)) return 0;

        uint amount = earnd(_vault, user, token);
        if(amount != 0){

            userInfos[_vault][user][token].earnd += amount;

            WAT.safeTransfer(user, amount);
            emit ProfitPaid(_vault, user, amount);
        }
        return amount;
    }

    function withdraw(address _vault, address user, address token, uint _liquidity) external {
        if(!Array.inArray(rewardsVault, msg.sender)) return;

        totalLiquidityArr[_vault].push(totalLiquidityArr[_vault][totalCount[_vault] - 1]);
        (uint totalReward, uint currentTime) = _getTotalReward(_vault);
        vaultRewardsInfos[_vault].latestPeriodStartTime = currentTime;
        totalRewardArr[_vault].push(totalReward);
        totalCount[_vault]++;

        totalLiquidityArr[_vault].push(totalLiquidityArr[_vault][totalCount[_vault] - 1] - _liquidity);
        totalRewardArr[_vault].push(0);
        totalCount[_vault]++;

        userInfos[_vault][user][token].liquidity -= _liquidity;
        userInfos[_vault][user][token].updatedCount = totalCount[_vault];
        userInfos[_vault][user][token].earnd = 0;
        
        emit Withdrawn(_vault, user, _liquidity);

        if(isAirdropEvent){
            airdropEventUserLiqudity[_vault][user] -= _liquidity;
        }
    }

    function airdropEventSnapshot(address _vault) external view returns(uint snapshotBlock, uint snapshotTimestamp, address[] memory users, uint[] memory liquidity)  {

        snapshotBlock = block.number;
        snapshotTimestamp = block.timestamp;

        address[] memory tempUsers = new address[](airdropEventUsers[_vault].length);
        uint[] memory tempLiqudity = new uint[](airdropEventUsers[_vault].length);

        for(uint i = 0; i < airdropEventUsers[_vault].length; i++){
            tempUsers[i] = airdropEventUsers[_vault][i];
            tempLiqudity[i] = airdropEventUserLiqudity[_vault][airdropEventUsers[_vault][i]];
        }

        users = tempUsers;
        liquidity = tempLiqudity;

    }

}