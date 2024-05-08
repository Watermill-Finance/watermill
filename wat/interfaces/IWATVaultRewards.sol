// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IWATVaultRewards {

    event SetReward(address vault, uint, uint, uint);
    event ProfitPaid(address vault, address, uint);
    event Deposited(address vault, address user, uint liqudity);
    event Withdrawn(address vault, address, uint);

    struct VaultRewardsInfo {
        // uint totalEarned;
        uint rewardPerSecond;
        uint rewardAmount;
        uint latestPeriodEndTime;
        uint latestPeriodStartTime;
        // uint nowtillRewards;
    }

    struct UserInfo{
        uint liquidity;
        uint updatedCount;
        uint earnd;
    }

    function earnd(address _vault, address user, address token) external view returns(uint);

    function getReward(address _vault, address user, address token) external returns(uint);

    function deposit(address _vault, address user, address token, uint _liquidity) external;

    function withdraw(address _vault, address user, address token, uint _liquidity) external;
    
}