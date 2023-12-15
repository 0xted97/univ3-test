// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

interface IWETH {
    function deposit() external payable;

    function withdraw(uint) external;

    function approve(address, uint) external returns (bool);

    function transfer(address, uint) external returns (bool);

    function transferFrom(address, address, uint) external returns (bool);

    function balanceOf(address) external view returns (uint);
}

contract LiquidityProvider is Ownable, IERC721Receiver {
    address public WETH;
    address public GMX;
    address public balancerVault;
    ISwapRouter public immutable swapRouter;
    IUniswapV3Pool public uniswapPool;
    uint160 public liquidityRange = 10; // in percentage

    INonfungiblePositionManager public positionManager;
    uint24 public constant poolFee = 3000;

    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    mapping(uint256 => Deposit) public deposits;

    constructor(
        address _balancerVault,
        IUniswapV3Pool _uniswapPool,
        ISwapRouter _swapRouter,
        INonfungiblePositionManager _positionManager,
        IWETH _weth,
        IERC20 _gmx
    ) {
        transferOwnership(msg.sender);
        balancerVault = _balancerVault;
        swapRouter = _swapRouter;
        uniswapPool = _uniswapPool;
        positionManager = _positionManager;
        WETH = address(_weth);
        GMX = address(_gmx);
    }

    function deposit(
        int24 tickLower,
        int24 tickUpper
    )
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        require(msg.value > 0, "Invalid deposit amount");
        _transferInETH();
        uint256 amountSwappedWETH = msg.value / 2;

        // Swap ETH -> GMX
        uint256 amountGMX = _swapWETH2GMX(amountSwappedWETH);

        // // current price
        // (int24 tickLower, int24 tickUpper, int24 tickCurrent, int24 tickSpacing) = _calPriceRange();

        // Cal range tick, current tick

        // amounts token
        uint256 amount1ToMint = msg.value - amountSwappedWETH;
        uint256 amount0ToMint = amountGMX;

        // Approve the position manager
        TransferHelper.safeApprove(
            WETH,
            address(positionManager),
            amount0ToMint
        );
        TransferHelper.safeApprove(
            GMX,
            address(positionManager),
            amount1ToMint
        );

        positionManager.mint(
                INonfungiblePositionManager.MintParams({
                    token0: GMX,
                    token1: WETH,
                    fee: poolFee,
                    tickLower: TickMath.MIN_TICK, // Set to your desired value
                    tickUpper: TickMath.MAX_TICK, // Set to your desired value
                    amount0Desired: 1000,
                    amount1Desired: 1000,
                    amount0Min: 0, //
                    amount1Min: 0,
                    recipient: msg.sender,
                    deadline: block.timestamp + 600
                })
            );

        // Remove allowance and refund in both assets.
        if (amount0 < amount0ToMint) {
            TransferHelper.safeApprove(WETH, address(positionManager), 0);
            uint256 refund0 = amount0ToMint - amount0;
            TransferHelper.safeTransfer(WETH, msg.sender, refund0);
        }

        if (amount1 < amount1ToMint) {
            TransferHelper.safeApprove(GMX, address(positionManager), 0);
            uint256 refund1 = amount1ToMint - amount1;
            TransferHelper.safeTransfer(GMX, msg.sender, refund1);
        }
    }

    function withdraw() external {}

    function emergencyWithdraw() external onlyOwner {
        // Burn all LP tokens and transfer underlying assets to the owner
    }

    function withdrawETH(address payable _receiver) external {
        uint balance = IWETH(WETH).balanceOf(address(this));
        IWETH(WETH).withdraw(balance);
        _receiver.transfer(balance);
    }

    // Hooks
    receive() external payable {}

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    //
    function _swapWETH2GMX(uint256 amountIn) internal returns (uint256) {
        // TODO: Swap directly by pool
        TransferHelper.safeApprove(WETH, address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: GMX,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        return swapRouter.exactInputSingle(params);
    }

    function _calPriceRange()
        internal
        view
        returns (
            int24 tickLower,
            int24 tickUpper,
            int24 tickCurrent,
            int24 tickSpacing
        )
    {
        (, tickCurrent, , , , , ) = uniswapPool.slot0();
        // Calculate tick range for ±10% price range
        tickSpacing = uniswapPool.tickSpacing();
        tickLower = tickCurrent - (10 * tickSpacing * 2);
        tickUpper = tickCurrent + (10 * tickSpacing * 2);
    }

    // Views
    function _getCurrentPrice() internal view returns (uint160) {
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(uniswapPool)
            .slot0();
        return (sqrtPriceX96 * sqrtPriceX96) >> 192;
    }

    function _getTickAtPrice(uint256 price) internal view returns (int24) {}

    // Internal functions
    function _transferInETH() internal {
        if (msg.value != 0) {
            IWETH(WETH).deposit{value: msg.value}();
        }
    }
}
