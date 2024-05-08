// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import './INonfungiblePositionManager.sol';

interface IMasterChefV3 {

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function harvest(uint256 _tokenId, address _to) external returns (uint256 reward);

    function withdraw(uint256 _tokenId, address _to) external returns (uint256 reward);

    function increaseLiquidity(
        IncreaseLiquidityParams memory params
    ) external payable returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function collect(CollectParams memory params) external returns (uint256 amount0, uint256 amount1);

    function unwrapWETH9(uint256 amountMinimum, address recipient) external;

    function sweepToken(address token, uint256 amountMinimum, address recipient) external;
}