// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IWATIdo {
    event Received(address, uint);
    event Deposited(address user, uint amount);
    event Claimed(address user, uint amount);
}