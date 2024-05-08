// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IStaking {

    event Received(address, uint);
    event Deposited(address user, uint amount);
    event Claimed(address user, uint amount);
    event Withdrawn(address user, uint amount);
    event WithdrawnRequest(address user, uint amount);
    event SetReward(uint, uint, uint);

    struct UserStakingInfo{
        uint staked;
        uint shares;
        uint updatedAt;
        uint claimed;
        uint withdrawRequestAt;//request
        uint withdrawRequestAmount;
    }
}