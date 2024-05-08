// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import "./interfaces/IvWAT.sol";

contract vWAT is ERC20, ERC20Permit, Ownable, ERC20Burnable, ERC20Pausable, IvWAT {

    address private staking;
    address private voting;

    constructor()
        ERC20("Watermill Finance Vote Token", "vWAT")
        ERC20Permit("vWAT")
        Ownable()
    {
    }

    modifier onlyStaking() {
        require(msg.sender == staking, "not staking address");
        _;
    }

    function setStaking(address _staking) external onlyOwner{
        staking = _staking;
    }

    function setVoting(address _voting) external onlyOwner {
        voting = _voting;
    }


    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address user, uint amount) public onlyStaking {
        _mint(user, amount);
        emit Mint(user, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        require(from == address(0) || to == address(0) || from == voting || to == voting, "This a Voteing token. It cannot be transferred.");
        super._beforeTokenTransfer(from, to, value);
    }
}