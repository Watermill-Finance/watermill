// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import './interfaces/IPancakeBaseV3Factory.sol';
import './interfaces/IPancakeBaseV3VaultDeployer.sol';

import './pancake/interfaces/INonfungiblePositionManager.sol';

contract PancakeBaseV3Factory is IPancakeBaseV3Factory, Ownable {
    address public immutable poolDeployer;

    address[] public vaults;

    constructor(address _poolDeployer) {
        poolDeployer = _poolDeployer;
    }

    function createVault(uint256 npmId, address npm, address pool, address chef, address WKLAY, address RKLAY, address swapRouter, address watVaultRewards) external onlyOwner returns (address vault) {
        require(npmId != 0);
        require(npm != address(0));

        vault = IPancakeBaseV3VaultDeployer(poolDeployer).deploy(address(this), npmId, npm, pool, chef, WKLAY, RKLAY, swapRouter, watVaultRewards);
        vaults.push(vault);

        INonfungiblePositionManager inpm = INonfungiblePositionManager(npm);
        inpm.safeTransferFrom(msg.sender, address(this), npmId);
        inpm.safeTransferFrom(address(this), vault, npmId);

        emit VaultCreated(vault, npmId, npm, pool, chef, WKLAY, RKLAY, swapRouter, watVaultRewards);
    }

    function vaultsLength() external view returns (uint){
        return vaults.length;
    }

    function factoryOwner() external override view returns (address){
        return owner();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}