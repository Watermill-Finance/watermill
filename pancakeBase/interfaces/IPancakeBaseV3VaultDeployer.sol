// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IPancakeBaseV3VaultDeployer {
    function deploy(address factory, uint256 npmId, address npm, address pool, address chef, address WKLAY, address RKLAY, address swapRouter, address watVaultRewards) external returns (address vault);
}