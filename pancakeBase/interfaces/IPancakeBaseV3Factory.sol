// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IPancakeBaseV3Factory {

    event VaultCreated(address vault, uint256 npmId, address npm, address pool, address chef, address WKLAY, address RKLAY, address swapRouter, address watVaultRewards);

    function createVault(uint256 npmId, address npm, address pool, address chef, address WKLAY, address RKLAY, address swapRouter, address watVaultRewards) external returns (address vault);

    function factoryOwner() external view returns (address);

    function vaultsLength() external view returns (uint);
}