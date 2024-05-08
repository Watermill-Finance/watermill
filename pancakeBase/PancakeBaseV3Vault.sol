// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../wat/interfaces/IWATVaultRewards.sol";
import "./interfaces/IPancakeBaseV3Factory.sol";
import "./interfaces/IPancakeBaseV3Vault.sol";
import "./pancake/interfaces/INonfungiblePositionManager.sol";
import "./pancake/interfaces/IMasterChefV3.sol";
import "./pancake/interfaces/IRKLAY.sol";
import "./pancake/interfaces/ISwapRouter.sol";
import "./pancake/interfaces/IPancakeV3PoolState.sol";
import "./libraries/Abs.sol";
import "./libraries/PathEncode.sol";
import "./libraries/Array.sol";
import "./libraries/TransferHelper.sol";

contract PancakeBaseV3Vault is IPancakeBaseV3Vault, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint24 private vaultsFee = 10000;

    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;
    int24 public immutable tickLower;
    int24 public immutable tickUpper;


    address factoryOwner;
    uint256 public npmId;
    address public pool;
    address WKLAY;

    address[] public swapPossibleList;
    mapping(address => SwapPossible) public swapPossible;

    bool public isFinish = false;

    address[] public userList;
    mapping(address => mapping(address => UserInfo)) public userInfos;
    mapping(address => address[]) public userSwapTokens;

    IWATVaultRewards private _iWATVaultRewards;
    INonfungiblePositionManager private _inpm;
    IMasterChefV3 private _ichef;
    IRKLAY private _irklay;
    ISwapRouter private _irouter;

    bytes[] token0path;
    bytes[] token1path;

    uint public asRoundCount = 0;
    mapping(address => AsRound[10000000]) public asRounds;
    uint public latestHarvestedTime;

    modifier onlyFactoryOwner() {
        require(msg.sender == factoryOwner);
        _;
    }

    modifier notFinish() {
        require(!isFinish);
        _;
    }

    modifier inPossibleArray(address swapToken) {
        require(Array.inArray(swapPossibleList, swapToken));
        _;
    }

    constructor(
        address _factory,
        uint256 _npmId,
        address _npm,
        address _pool,
        address _chef,
        address _WKLAY,
        address _RKLAY,
        address _swapRouter,
        address _actVaultRewards
    ) {
        factoryOwner = IPancakeBaseV3Factory(_factory).factoryOwner();
        npmId = _npmId;
        pool = _pool;
        WKLAY = _WKLAY;

        _irklay = IRKLAY(_RKLAY);
        _irouter = ISwapRouter(_swapRouter);
        _ichef = IMasterChefV3(_chef);
        _inpm = INonfungiblePositionManager(_npm);
        _iWATVaultRewards = IWATVaultRewards(_actVaultRewards);

        uint128 liquidity;
        (
            ,
            ,
            token0,
            token1,
            fee,
            tickLower,
            tickUpper,
            liquidity,
            ,
            ,
            ,

        ) = _inpm.positions(npmId);

        IERC20(token0).approve(_chef, type(uint256).max);
        IERC20(token1).approve(_chef, type(uint256).max);
        IERC20(token0).approve(_swapRouter, type(uint256).max);
        IERC20(token1).approve(_swapRouter, type(uint256).max);

        swapPossibleList.push(pool);

        _deposit(factoryOwner, liquidity, pool);
    }

    function chefStakingERC721() external notFinish onlyFactoryOwner {
        _inpm.safeTransferFrom(address(this), address(_ichef), npmId);
    }

    function totalLiquidity() public view returns (uint128 liquidity) {
        (, , , , , , , liquidity, , , , ) = _inpm.positions(npmId);
    }


    function userListLength() external view returns (uint) {
        return userList.length;
    }

    function userSwapTokensLength(address user) external view returns (uint) {
        return userSwapTokens[user].length;
    }

    function swapPossibleListLength() external view returns (uint) {
        return swapPossibleList.length;
    }


    function pushPossibleSwapToken(
        address _token,
        address[] memory pathList,
        uint24[] memory feeList
    ) external onlyFactoryOwner {

        if (_token == WKLAY) {
            swapPossibleList.push(_token);
        } else {
            require(pathList[0] == WKLAY);

            swapPossibleList.push(_token);
            swapPossible[_token].path = new bytes(0);
            swapPossible[_token].path = PathEncode.pathEncode(
                pathList,
                feeList
            );
        }

    }


    function setToken0Path(
        address[] calldata pathList,
        uint24[] calldata feeList
    ) external onlyFactoryOwner {
        token0path = [
            PathEncode.pathEncode(pathList, feeList),
            PathEncode.pathEncodeReverse(pathList, feeList)
        ];
    }

    function setToken1Path(
        address[] calldata pathList,
        uint24[] calldata feeList
    ) external onlyFactoryOwner {
        token1path = [
            PathEncode.pathEncode(pathList, feeList),
            PathEncode.pathEncodeReverse(pathList, feeList)
        ];
    }

    function setIsFinish(bool value) external onlyFactoryOwner {
        isFinish = value;
    }

    function setVaultsFee(uint24 value) external onlyFactoryOwner {
        vaultsFee = value;
    }

    function deposit(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address swapToken
    )
        external
        payable
        notFinish
        nonReentrant
        inPossibleArray(swapToken)
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        pay(token0, amount0Desired);
        pay(token1, amount1Desired);

        if (token0 != WKLAY && token1 != WKLAY && msg.value > 0) revert();

        (liquidity, amount0, amount1) = _increase(
            IMasterChefV3.IncreaseLiquidityParams(
                npmId,
                amount0Desired,
                amount1Desired,
                amount0Min,
                amount1Min,
                block.timestamp + 60
            ),
            msg.value
        );

        uint256 token0Left = amount0Desired - amount0;
        uint256 token1Left = amount1Desired - amount1;
        if (token0Left > 0) {
            refund(msg.sender, token0, token0Left);
        }
        if (token1Left > 0) {
            refund(msg.sender, token1, token1Left);
        }

        _getReward(swapToken);

        _deposit(msg.sender, liquidity, swapToken);
    }

    function harvest() external notFinish nonReentrant {
        _harvest();
        uint256 amountTotal = address(this).balance;
        require(amountTotal > 1e12);
        uint128 total = totalLiquidity();

        for (uint i = 0; i < swapPossibleList.length; i++) {
            address token = swapPossibleList[i];

            uint spLiquidity = swapPossible[token].totalLiquidity;

            if (spLiquidity == 0) continue;
            if (spLiquidity * amountTotal < total) continue;

            uint amount = (spLiquidity * amountTotal) / total;

            if (token == pool) {
                _autoCompound(amount);
            } else {
                _autoSwap(amount, token);
            }
        }

        asRoundCount++;
        latestHarvestedTime = block.timestamp;
    }

    function balanceOf(
        address account,
        address token
    ) public view returns (uint) {
        if (swapPossible[token].totalShares == 0) return 0;
        return
            (swapPossible[token].totalLiquidity *
                userInfos[account][token].shares) /
            swapPossible[token].totalShares;
    }

    function earned(
        address account,
        address token
    ) public view inPossibleArray(token) returns (uint profit, uint rewardWAT) {
        if(token == pool){
            uint balance = balanceOf(account, token);
            if (balance >= userInfos[account][token].liquidity + 1000) {
                profit = balance - userInfos[account][token].liquidity;
            } else {
                profit = 0;
            }
        }
        else{
            for(uint i = userInfos[account][token].asUpdatedRound; i < asRoundCount; i++){
                if(asRounds[token][i].roundTotalHarvestAmount == 0 || asRounds[token][i].roundTotalLiquidity == 0){
                    profit += 0;
                }
                else{
                    profit += (userInfos[account][token].liquidity * asRounds[token][i].roundTotalHarvestAmount / asRounds[token][i].roundTotalLiquidity);
                }
            }
        }


        if (swapPossible[token].totalLiquidity != 0) {
            rewardWAT = _iWATVaultRewards.earnd(
                address(this),
                account,
                token
            );
        } else {
            rewardWAT = 0;
        }
    }

    function getReward(
        address token
    )
        external
        notFinish
        nonReentrant
        inPossibleArray(token)
        returns (uint profit, uint rewardWAT)
    {
        (profit, rewardWAT) = _getReward(token);
    }

    function _getReward(
        address token
    ) internal returns (uint profit, uint rewardWAT) {
        (profit, rewardWAT) = earned(msg.sender, token);

        if (swapPossible[token].totalLiquidity != 0 && rewardWAT != 0) {
            rewardWAT = _iWATVaultRewards.getReward(
                address(this),
                msg.sender,
                token
            );
        }

        if (profit != 0) {
            uint performanceFee = (profit * vaultsFee) / 1000000;

            if (token == pool) {
                uint deltaFee = Math.min(
                    (performanceFee * swapPossible[token].totalShares) /
                        swapPossible[token].totalLiquidity,
                    userInfos[msg.sender][token].shares
                );
                swapPossible[token].totalShares -= deltaFee;
                userInfos[msg.sender][token].shares -= deltaFee;
                swapPossible[token].totalLiquidity -= performanceFee;

                _deposit(factoryOwner, performanceFee, pool);

                (uint liquidity, ) = earned(msg.sender, token);

                _iWATVaultRewards.deposit(
                    address(this),
                    msg.sender,
                    token,
                    liquidity
                );

                userInfos[msg.sender][token].liquidity += liquidity;

                emit ProfitPaid(msg.sender, profit, performanceFee);
            } else {

                userInfos[msg.sender][token].asUpdatedRound = asRoundCount;

                profit -= performanceFee;
                refund(factoryOwner, token, performanceFee);

                refund(msg.sender, token, profit);

                emit ProfitPaid(msg.sender, profit, performanceFee);
            }
        }

    }



    function withdraw(
        uint liquidity,
        address token
    ) external payable nonReentrant inPossibleArray(token) {
        _getReward(token);

        uint balance = balanceOf(msg.sender, token);
        liquidity = Math.min(liquidity, balance);

        uint deltaLiquidity = (liquidity *
            userInfos[msg.sender][token].liquidity) / balance;
        uint deltaShares = (liquidity * userInfos[msg.sender][token].shares) /
            balance;

        _iWATVaultRewards.withdraw(
            address(this),
            msg.sender,
            token,
            deltaLiquidity
        );

        swapPossible[token].totalLiquidity -= liquidity;
        swapPossible[token].totalShares -= deltaShares;

        userInfos[msg.sender][token].liquidity -= deltaLiquidity;
        userInfos[msg.sender][token].shares -= deltaShares;

        (uint256 amount0, uint256 amount1) = _decrease(
            IMasterChefV3.DecreaseLiquidityParams(
                npmId,
                uint128(liquidity),
                0,
                0,
                block.timestamp + 60
            )
        );

        uint256 amount0Result;
        uint256 amount1Result;

        if (token0 == WKLAY) {
            (amount0Result, amount1Result) = _collect(
                address(0),
                uint128(amount0),
                uint128(amount1)
            );

            _ichef.unwrapWETH9(amount0Result, address(this));
            _ichef.sweepToken(token1, amount1Result, address(this));
        } else if (token1 == WKLAY) {
            (amount0Result, amount1Result) = _collect(
                address(0),
                uint128(amount0),
                uint128(amount1)
            );

            _ichef.unwrapWETH9(amount1Result, address(this));
            _ichef.sweepToken(token0, amount0Result, address(this));
        } else {
            (amount0Result, amount1Result) = _collect(
                address(this),
                uint128(amount0),
                uint128(amount1)
            );
        }

        refund(msg.sender, token0, amount0Result);
        refund(msg.sender, token1, amount1Result);

        emit Withdrawn(msg.sender, liquidity);
    }

    function _autoCompound(uint256 acAmount) internal notFinish {
        uint256 token0Amount;
        uint256 token1Amount;

        uint128 liquidity;

        (uint ratioAmount0, uint ratioAmount1) = ratioTick(acAmount);

        if (token0 == WKLAY) {
            token0Amount = ratioAmount0;
            token1Amount = _swapFromKlay(ratioAmount1, token1path[1]);

            (liquidity, , ) = _increase(
                IMasterChefV3.IncreaseLiquidityParams(
                    npmId,
                    token0Amount,
                    token1Amount,
                    0,
                    0,
                    block.timestamp + 60
                ),
                token0Amount
            );
           
        } else if (token1 == WKLAY) {
            token1Amount = ratioAmount1;
            token0Amount = _swapFromKlay(ratioAmount0, token0path[1]);

            (liquidity, , ) = _increase(
                IMasterChefV3.IncreaseLiquidityParams(
                    npmId,
                    token0Amount,
                    token1Amount,
                    0,
                    0,
                    block.timestamp + 60
                ),
                token1Amount
            );
          
        } else {
            token0Amount = _swapFromKlay(ratioAmount0, token0path[1]);
            token1Amount = _swapFromKlay(ratioAmount1, token1path[1]);

            (liquidity, , ) = _increase(
                IMasterChefV3.IncreaseLiquidityParams(
                    npmId,
                    token0Amount,
                    token1Amount,
                    0,
                    0,
                    block.timestamp + 60
                ),
                0
            );
            
        }
        swapPossible[pool].totalLiquidity += liquidity;
        emit AutoCompound(liquidity);
    }

    function _autoSwap(uint256 asAmount, address token) internal notFinish {

        uint amountOut;
        if (token == WKLAY) {
            amountOut = asAmount;
        } else {
            amountOut = _swapFromKlay(asAmount, swapPossible[token].path);
        }
        asRounds[token][asRoundCount].roundTotalLiquidity = swapPossible[token].totalLiquidity;
        asRounds[token][asRoundCount].roundTotalHarvestAmount = amountOut;

        emit AutoSwap(amountOut);
    }

    function _deposit(
        address _user,
        uint _liquidity,
        address _swapToken
    ) internal notFinish {

        _iWATVaultRewards.deposit(
            address(this),
            _user,
            _swapToken,
            _liquidity
        );

        uint deltaShares = 0;
        if (swapPossible[_swapToken].totalShares == 0) {
            deltaShares = _liquidity;
        } else {
            deltaShares =
                (_liquidity * swapPossible[_swapToken].totalShares) /
                swapPossible[_swapToken].totalLiquidity;
        }

        swapPossible[_swapToken].totalShares += deltaShares;
        swapPossible[_swapToken].totalLiquidity += _liquidity;

        if (!userInfos[_user][_swapToken].isValid) {
            if (!Array.inArray(userSwapTokens[_user], _swapToken)) {
                userSwapTokens[_user].push(_swapToken);
            }
            if (!Array.inArray(userList, _user)) {
                userList.push(_user);
            }
            userInfos[_user][_swapToken] = UserInfo({
                shares: deltaShares,
                liquidity: _liquidity,
                depositAt: block.timestamp,
                asUpdatedRound : asRoundCount,
                isValid: true
            });
        } else {
            userInfos[_user][_swapToken].shares += deltaShares;
            userInfos[_user][_swapToken].liquidity += _liquidity;
        }

        emit Deposited(_user, _liquidity, _swapToken);
    }

    function _harvest() internal notFinish {
        uint256 amountTotal;

        uint256 reward = _ichef.harvest(npmId, address(this));
        _irklay.withdraw(reward);

        uint256 amount0;
        uint256 amount1;

        if (token0 == WKLAY) {
            (amount0, amount1) = _collect(
                address(0),
                type(uint128).max,
                type(uint128).max
            );

            _ichef.unwrapWETH9(amount0, address(this));
            _ichef.sweepToken(token1, amount1, address(this));

            uint256 amountOut = _swapFromERC20(amount1, token1path[0]);

            _irouter.unwrapWETH9(amountOut, address(this));
            amountTotal = amountOut + amount0 + reward;
        } else if (token1 == WKLAY) {
            (amount0, amount1) = _collect(
                address(0),
                type(uint128).max,
                type(uint128).max
            );

            _ichef.unwrapWETH9(amount1, address(this));
            _ichef.sweepToken(token0, amount0, address(this));

            uint256 amountOut = _swapFromERC20(amount0, token0path[0]);

            _irouter.unwrapWETH9(amountOut, address(this));
            amountTotal = amountOut + amount1 + reward;
        } else {
            (amount0, amount1) = _collect(
                address(this),
                type(uint128).max,
                type(uint128).max
            );

            uint256 amount0Out = _swapFromERC20(amount0, token0path[0]);

            _irouter.unwrapWETH9(amount0Out, address(this));

            uint256 amount1Out = _swapFromERC20(amount1, token1path[0]);

            _irouter.unwrapWETH9(amount1Out, address(this));

            amountTotal = amount0Out + amount1Out + reward;
        }

        emit Harvested(amountTotal);
    }

    function _swapFromKlay(
        uint256 amount,
        bytes memory path
    ) internal notFinish returns (uint256 amountOut) {
        if (amount == 0) {
            amountOut = 0;
        } else {
            amountOut = _irouter.exactInput{value: amount}(
                ISwapRouter.ExactInputParams(path, address(this), amount, 0)
            );
        }
    }

    function _swapFromERC20(
        uint256 amount,
        bytes memory path
    ) internal returns (uint256 amountOut) {
        if (amount == 0) {
            amountOut = 0;
        } else {
            amountOut = _irouter.exactInput(
                ISwapRouter.ExactInputParams(path, address(2), amount, 0)
            );
        }
    }

    function rangeTick()
        public
        view
        returns (int24 lowerRange, int24 upperRange)
    {
        (, int24 currentTick, , , , , ) = IPancakeV3PoolState(pool).slot0();
        lowerRange = tickLower - currentTick;
        upperRange = tickUpper - currentTick;
    }

    function ratioTick(
        uint amount
    ) public view returns (uint amount0, uint amount1) {
        (int lowerRange, int upperRange) = rangeTick();
        if (lowerRange >= 0) {
            amount0 = amount;
            amount1 = 0;
        } else if (upperRange <= 0) {
            amount0 = 0;
            amount1 = amount;
        } else {
            uint256 totalRange = uint(Abs.abs(lowerRange)) +
                uint(Abs.abs(upperRange));
            amount1 = (amount / totalRange) * uint(Abs.abs(lowerRange));
            amount0 = amount - amount1;
        }
    }

    function isActive() external view returns (bool) {
        (int24 lowerRange, int24 upperRange) = rangeTick();

        if (lowerRange >= 0) {
            return false;
        } else if (upperRange <= 0) {
            return false;
        } else {
            return true;
        }
    }

    function _increase(
        IMasterChefV3.IncreaseLiquidityParams memory params,
        uint value
    )
        internal
        notFinish
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        (liquidity, amount0, amount1) = _ichef.increaseLiquidity{value: value}(
            params
        );
    }

    function _decrease(
        IMasterChefV3.DecreaseLiquidityParams memory params
    ) internal notFinish returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _ichef.decreaseLiquidity(params);
    }

    function _collect(
        address recipient,
        uint128 amount0Max,
        uint128 amount1Max
    ) internal returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _ichef.collect(
            IMasterChefV3.CollectParams({
                tokenId: npmId,
                recipient: recipient,
                amount0Max: amount0Max,
                amount1Max: amount1Max
            })
        );
    }

    function pay(address _token, uint256 _amount) internal {
        if (_token == WKLAY && msg.value > 0) {
            if (msg.value != _amount) revert();
        } else {
            TransferHelper.safeTransferFrom(
                _token,
                msg.sender,
                address(this),
                _amount
            );
        }
    }

    function refund(address to, address _token, uint256 _amount) internal {
        if (_token == WKLAY && address(this).balance > 0) {
            TransferHelper.safeTransferETH(to, _amount);
        } else {
            TransferHelper.safeTransfer(_token, to, _amount);
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
