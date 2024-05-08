// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import './interfaces/IUniBaseV3VaultDeployer.sol';

import './UniBaseV3Vault.sol';

contract UniBaseV3VaultDeployer is IUniBaseV3VaultDeployer, Ownable {

    address public factoryAddress;

    event SetFactoryAddress(address indexed factory);

    modifier onlyFactory() {
        require(msg.sender == factoryAddress, "only factory can call deploy");
        _;
    }

    function deploy(address factory, uint256 npmId, address npm, address pool, address WKLAY, address swapRouter, address watVaultRewards) external override onlyFactory returns (address vault){
        vault = address(new UniBaseV3Vault(factory, npmId, npm, pool, WKLAY, swapRouter, watVaultRewards));
    }

    function setFactoryAddress(address _factoryAddress) external onlyOwner {
        require(factoryAddress == address(0), "already initialized");

        factoryAddress = _factoryAddress;

        emit SetFactoryAddress(_factoryAddress);
    }
}