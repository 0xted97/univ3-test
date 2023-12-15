// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/base/LiquidityManagement.sol";
import "hardhat/console.sol";

contract LiquidityExamples is IERC721Receiver {
    address public constant DAI = 0x6b72D5759D1A15C6A38ce62d52020d725Dd6Ccf5;
    address public constant USDC = 0x710c00D9955e4E6016541B3BA669E4701468C4f1;

    // 0.01% fee
    uint24 public constant poolFee = 3000;

    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    IUniswapV3Factory public factory =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    IUniswapV3Pool public pool;

    /// @notice Represents the deposit of an NFT
    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    /// @dev deposits[tokenId] => Deposit
    mapping(uint => Deposit) public deposits;

    // Store token id used in this example
    uint public tokenId;

    constructor() {
        pool = IUniswapV3Pool(factory.getPool(DAI, USDC, poolFee));
    }

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(
        address operator,
        address,
        uint _tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        _createDeposit(operator, _tokenId);
        return this.onERC721Received.selector;
    }

    function _createDeposit(address owner, uint _tokenId) internal {
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = nonfungiblePositionManager.positions(_tokenId);
        // set the owner and data for position
        // operator is msg.sender
        deposits[_tokenId] = Deposit({
            owner: owner,
            liquidity: liquidity,
            token0: token0,
            token1: token1
        });

        console.log("Token id", _tokenId);
        console.log("Liquidity", liquidity);

        tokenId = _tokenId;
    }

    function mintNewPosition(
        uint amount1ToMint,
        uint amount0ToMint
    )
        external
        returns (uint _tokenId, uint128 liquidity, uint amount0, uint amount1)
    {
        TransferHelper.safeTransferFrom(
            DAI,
            msg.sender,
            address(this),
            amount0ToMint
        );
        TransferHelper.safeTransferFrom(
            USDC,
            msg.sender,
            address(this),
            amount1ToMint
        );

        // Approve the position manager
        TransferHelper.safeApprove(
            DAI,
            address(nonfungiblePositionManager),
            amount0ToMint
        );
        TransferHelper.safeApprove(
            USDC,
            address(nonfungiblePositionManager),
            amount1ToMint
        );

        // Ticks
        ( , int24 tickLower, int24 tickUpper) = _getTicks();

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: DAI,
                token1: USDC,
                fee: poolFee,
                // By using TickMath.MIN_TICK and TickMath.MAX_TICK,
                // we are providing liquidity across the whole range of the pool.
                // Not recommended in production.
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0ToMint,
                amount1Desired: amount1ToMint,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        // Note that the pool defined by DAI/USDC and fee tier 0.01% must
        // already be created and initialized in order to mint
        (_tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager
            .mint(params);

        // Create a deposit
        _createDeposit(msg.sender, _tokenId);

        // Remove allowance and refund in both assets.
        if (amount0 < amount0ToMint) {
            TransferHelper.safeApprove(
                DAI,
                address(nonfungiblePositionManager),
                0
            );
            uint refund0 = amount0ToMint - amount0;
            TransferHelper.safeTransfer(DAI, msg.sender, refund0);
        }

        if (amount1 < amount1ToMint) {
            TransferHelper.safeApprove(
                USDC,
                address(nonfungiblePositionManager),
                0
            );
            uint refund1 = amount1ToMint - amount1;
            TransferHelper.safeTransfer(USDC, msg.sender, refund1);
        }
    }

    function collectAllFees()
        external
        returns (uint256 amount0, uint256 amount1)
    {
        // set amount0Max and amount1Max to uint256.max to collect all fees
        // alternatively can set recipient to msg.sender and avoid another transaction in `sendToOwner`
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = nonfungiblePositionManager.collect(params);

        console.log("fee 0", amount0);
        console.log("fee 1", amount1);
    }

    function increaseLiquidityCurrentRange(
        uint256 amountAdd0,
        uint256 amountAdd1
    ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        TransferHelper.safeTransferFrom(
            DAI,
            msg.sender,
            address(this),
            amountAdd0
        );
        TransferHelper.safeTransferFrom(
            USDC,
            msg.sender,
            address(this),
            amountAdd1
        );

        TransferHelper.safeApprove(
            DAI,
            address(nonfungiblePositionManager),
            amountAdd0
        );
        TransferHelper.safeApprove(
            USDC,
            address(nonfungiblePositionManager),
            amountAdd1
        );

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: amountAdd0,
                    amount1Desired: amountAdd1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (liquidity, amount0, amount1) = nonfungiblePositionManager
            .increaseLiquidity(params);

        console.log("liquidity", liquidity);
        console.log("amount 0", amount0);
        console.log("amount 1", amount1);
    }

    function getLiquidity(uint _tokenId) external view returns (uint128) {
        (, , , , , , , uint128 liquidity, , , , ) = nonfungiblePositionManager
            .positions(_tokenId);
        return liquidity;
    }

    function decreaseLiquidity(
        uint128 liquidity
    ) external returns (uint amount0, uint amount1) {
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(
            params
        );

        console.log("amount 0", amount0);
        console.log("amount 1", amount1);
    }

    function _getTicks()
        internal
        view
        returns (int24 tickCurrent, int24 tickLower, int24 tickUpper)
    {
        // Get ticks
        (, tickCurrent, , , , , ) = pool.slot0();
        int24 tickSpacing = pool.tickSpacing();

        tickLower = tickCurrent - (tickCurrent % tickSpacing);
        tickUpper = tickLower + tickSpacing;
    }
}
