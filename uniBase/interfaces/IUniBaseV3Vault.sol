// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IUniBaseV3Vault {
    event Received(address, uint);
    event Deposited(address user, uint liqudity, address swapToken);
    event Harvested(uint amountTotal);
    event AutoCompound(uint liquidity);
    event AutoSwap(uint amount);
    event ProfitPaid(address, uint, uint);
    event Withdrawn(address, uint);

    struct UserInfo {
        uint liquidity;
        uint depositAt;
        uint shares;
        uint asUpdatedRound;
        bool isValid;
    }

    struct SwapPossible {
        bytes path;
        uint totalLiquidity;
        uint totalShares;
    }

    struct AsRound {
        uint roundTotalLiquidity;
        uint roundTotalHarvestAmount;
    }
    
}
