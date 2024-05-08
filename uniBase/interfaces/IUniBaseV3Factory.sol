// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IUniBaseV3Factory {

    event VaultCreated(address vault, uint256 npmId, address npm, address pool, address WKLAY, address swapRouter, address watVaultRewards);

    function createVault(uint256 npmId, address npm, address pool, address WKLAY, address swapRouter, address watVaultRewards) external returns (address vault);

    function factoryOwner() external view returns (address);

    function vaultsLength() external view returns (uint);

}