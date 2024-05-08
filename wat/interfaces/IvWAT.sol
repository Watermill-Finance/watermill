// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IvWAT {

    event Mint(address, uint);

    function mint(address user, uint amount) external;
}