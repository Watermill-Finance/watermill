// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IUniBaseV3VaultDeployer {
    function deploy(address factory, uint256 npmId, address npm, address pool, address WKLAY, address swapRouter, address watVaultRewards) external returns (address vault);
}