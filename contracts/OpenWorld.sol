// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

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
    uint24 public constant poolFee = 3000;
    int24 public constant liquidityRange = 10; // in percentage

    address public WETH;
    address public GMX;
    address public balancerVault;
    address public treasury;

    ISwapRouter public immutable swapRouter;
    IUniswapV3Pool public uniswapPool;
    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    IUniswapV3Factory public factory =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    mapping(uint256 => Deposit) public deposits;
    mapping(address => uint256[]) public tokensOf;


    constructor(
        address _balancerVault,
        ISwapRouter _swapRouter,
        IWETH _weth,
        IERC20 _gmx
    ) {
        transferOwnership(msg.sender);
        balancerVault = _balancerVault;
        swapRouter = _swapRouter;
        WETH = address(_weth);
        GMX = address(_gmx);
        uniswapPool = IUniswapV3Pool(factory.getPool(WETH, GMX, poolFee));
    }

    function deposit()
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
        // Get half amount to swap GMX
        uint256 amountSwappedWETH = msg.value / 2;

        // Swap WETH -> GMX
        uint256 amountGMX = _swapWETH2GMX(amountSwappedWETH);

        // // current price
        (int24 tickLower, int24 tickUpper, , ) = _getTicks();

        // Cal range tick, current tick

        // amounts token
        uint256 amount0ToMint = amountGMX;
        uint256 amount1ToMint = msg.value - amountSwappedWETH;

        // Approve the position manager
        TransferHelper.safeApprove(
            GMX,
            address(nonfungiblePositionManager),
            amount0ToMint
        );
        TransferHelper.safeApprove(
            WETH,
            address(nonfungiblePositionManager),
            amount1ToMint
        );

        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager
            .mint(
                INonfungiblePositionManager.MintParams({
                    token0: GMX,
                    token1: WETH,
                    fee: poolFee,
                    tickLower: tickLower, // Set to your desired value
                    tickUpper: tickUpper, // Set to your desired value
                    amount0Desired: amount0ToMint,
                    amount1Desired: amount1ToMint,
                    amount0Min: 0, // No use in production
                    amount1Min: 0, // No use in production
                    recipient: address(this), // Transfer to smart contracts
                    deadline: block.timestamp + 600
                })
            );
            
        // TODO: Emit event deposit successful

        // Remove allowance and refund in both assets to msg.sender
        if (amount0 < amount0ToMint) {
            TransferHelper.safeApprove(
                GMX,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund0 = amount0ToMint - amount0;
            TransferHelper.safeTransfer(GMX, msg.sender, refund0);
        }

        if (amount1 < amount1ToMint) {
            TransferHelper.safeApprove(
                WETH,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund1 = amount1ToMint - amount1;
            TransferHelper.safeTransfer(WETH, msg.sender, refund1);
        }
    }

    function withdraw(uint256 _tokenId) external returns(uint256 amount0, uint256 amount1) {
        // Require owner
        // caller must be the owner of the NFT
        require(msg.sender == deposits[_tokenId].owner, 'Not the owner');

        uint128 liquidity = deposits[_tokenId].liquidity;

        INonfungiblePositionManager.DecreaseLiquidityParams memory params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: _tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(params);
        _sendToOwner(_tokenId, amount0, amount1);
    }

    function emergencyWithdraw(uint256 _length) external onlyOwner {
        // TODO: Transfer all Position NFT to treasury
        
        address owner = address(this);
        uint256 balances = nonfungiblePositionManager.balanceOf(owner);
        require(_length <= balances, "Length invalid");

        uint256 length = _length == 0 ? balances : _length;

        for(uint256 index = 0; index < length; index++) {
            // Get token id by owner & index
            uint256 tokenId = nonfungiblePositionManager.tokenOfOwnerByIndex(owner, index);

            // Transfer owner
            nonfungiblePositionManager.safeTransferFrom(owner, treasury, tokenId);
        }
        
        // Free up deposits
    }

    function withdrawETH(address payable _receiver) external {
        uint balance = IWETH(WETH).balanceOf(address(this));
        IWETH(WETH).withdraw(balance);
        _receiver.transfer(balance);
    }

    // Views

    function viewLP(address _user, uint256 _index) external view returns(Deposit memory) {
        
    }

    // Hooks
    receive() external payable {}

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        // TODO: Handle insert position LP
        _createDeposit(operator, tokenId);
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

    function _getTicks()
        internal
        view
        returns (
            int24 tickLower,
            int24 tickUpper,
            int24 tickCurrent,
            int24 tickSpacing
        )
    {
        // Get ticks
        (, tickCurrent, , , , , ) = uniswapPool.slot0();
        tickSpacing = uniswapPool.tickSpacing();

        // TODO: Handle cal price range +-10%
        int24 percentageChange = (tickSpacing * liquidityRange) / 100;
        tickLower = tickCurrent - (tickCurrent % tickSpacing);
        tickUpper = tickLower + tickSpacing;

        // Round ticks to the nearest tickSpacing
        // tickLower = tickLower - (tickLower % tickSpacing);
        // tickUpper = tickUpper + (tickSpacing - (tickUpper % tickSpacing));
    }

    // Internal functions
    function _transferInETH() internal {
        if (msg.value != 0) {
            IWETH(WETH).deposit{value: msg.value}();
        }
    }

    function _createDeposit(address owner, uint256 tokenId) internal {
       tokensOf[owner].push(tokenId);

       (, , address token0, address token1, , , , uint128 liquidity, , , , ) =
            nonfungiblePositionManager.positions(tokenId);

        // set the owner and data for position
        // operator is msg.sender
        deposits[tokenId] = Deposit({owner: owner, liquidity: liquidity, token0: token0, token1: token1});
    }

    function _sendToOwner(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) internal {
        // get owner of contract
        // address owner = deposits[tokenId].owner;

        address token0 = deposits[tokenId].token0;
        address token1 = deposits[tokenId].token1;
        // // send collected fees to owner
        // TransferHelper.safeTransfer(token0, owner, amount0);
        // TransferHelper.safeTransfer(token1, owner, amount1);

        TransferHelper.safeTransfer(token0, msg.sender, amount0);
        TransferHelper.safeTransfer(token1, msg.sender, amount1);
    }
}
