// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import './interfaces/IPancakeBaseV3VaultDeployer.sol';

import './PancakeBaseV3Vault.sol';

contract PancakeBaseV3VaultDeployer is IPancakeBaseV3VaultDeployer, Ownable {

    address public factoryAddress;

    event SetFactoryAddress(address indexed factory);

    modifier onlyFactory() {
        require(msg.sender == factoryAddress, "only factory can call deploy");
        _;
    }

    function deploy(address factory, uint256 npmId, address npm, address pool, address chef, address WKLAY, address RKLAY, address swapRouter, address watVaultRewards) external override onlyFactory returns (address vault){
        vault = address(new PancakeBaseV3Vault(factory, npmId, npm, pool, chef, WKLAY, RKLAY, swapRouter, watVaultRewards));
    }

    function setFactoryAddress(address _factoryAddress) external onlyOwner {
        require(factoryAddress == address(0), "already initialized");

        factoryAddress = _factoryAddress;

        emit SetFactoryAddress(_factoryAddress);
    }
}