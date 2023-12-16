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
    event DepositCreated(address spender, uint256 tokenId);
    event WithdrawLP(address owner, uint256 token0, uint256 token1);
    event WithdrawAllLP(address treasury, uint256 balance);

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
        bool withdrawable;
    }

    mapping(uint256 => Deposit) public deposits;
    mapping(address => uint256[]) public tokensOf;

    constructor(
        address _balancerVault,
        ISwapRouter _swapRouter,
        IWETH _weth,
        IERC20 _gmx,
        address _treasury
    ) {
        transferOwnership(msg.sender);
        balancerVault = _balancerVault;
        swapRouter = _swapRouter;
        WETH = address(_weth);
        GMX = address(_gmx);
        treasury = _treasury;
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

        // Swap WETH -> GMX
        uint256 amountWETHSwapped = msg.value / 2;
        uint256 amountGMX = _swapWETH2GMX(amountWETHSwapped);

        // Range tick, current tick
        (int24 tickLower, int24 tickUpper, , ) = _getTicks();

        // Make sure the order of token
        address token0 = uniswapPool.token0();
        address token1 = uniswapPool.token1();

        // uint256 amountWETHRemain = msg.value - amountWETHSwapped;

        // amounts token
        uint256 amount0ToMint = WETH == token0
            ? (msg.value - amountWETHSwapped)
            : amountGMX;
        uint256 amount1ToMint = WETH == token0
            ? amountGMX
            : (msg.value - amountWETHSwapped);

        // Approve the position manager
        TransferHelper.safeApprove(
            token0,
            address(nonfungiblePositionManager),
            amount0ToMint
        );
        TransferHelper.safeApprove(
            token1,
            address(nonfungiblePositionManager),
            amount1ToMint
        );

        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager
            .mint(
                INonfungiblePositionManager.MintParams({
                    token0: token0,
                    token1: token1,
                    fee: poolFee,
                    tickLower: tickLower, // Set to your desired value
                    tickUpper: tickUpper, // Set to your desired value
                    amount0Desired: amount0ToMint,
                    amount1Desired: amount1ToMint,
                    amount0Min: 0, // No use in production
                    amount1Min: 0, // No use in production
                    recipient: address(this), // Transfer to smart contracts
                    deadline: block.timestamp
                })
            );

        // TODO: Emit event deposit successful
        emit DepositCreated(msg.sender, tokenId);
        _createDeposit(msg.sender, tokenId);

        // Remove allowance and refund in both assets to msg.sender
        if (amount0 < amount0ToMint) {
            TransferHelper.safeApprove(
                token0,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund0 = amount0ToMint - amount0;
            TransferHelper.safeTransfer(token0, msg.sender, refund0);
        }

        if (amount1 < amount1ToMint) {
            TransferHelper.safeApprove(
                token1,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund1 = amount1ToMint - amount1;
            TransferHelper.safeTransfer(token1, msg.sender, refund1);
        }
    }

    function withdrawLP(
        uint256 _tokenId
    ) external returns (uint256 amount0, uint256 amount1) {
        // Require owner
        // caller must be the owner of the NFT
        require(
            msg.sender == deposits[_tokenId].owner,
            "Ownable: you are not the owner"
        );

        uint128 liquidity = deposits[_tokenId].liquidity;

        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: _tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        nonfungiblePositionManager.decreaseLiquidity(
            params
        );
        emit WithdrawLP(deposits[_tokenId].owner, amount0, amount1);

        (amount0, amount1) = nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // TODO: Fix bug here, execution revert: ST
        _sendToOwner(_tokenId, amount0, amount1);

        delete deposits[_tokenId];
    }

    /// TODO: Optimize, DOS
    function emergencyWithdraw() external onlyOwner {
        // TODO: Transfer with length
        // require(_length <= balances, "Length invalid");
        // uint256 length = _length == 0 ? balances : _length;

        address owner = address(this);
        uint256 balances = nonfungiblePositionManager.balanceOf(owner);
        // TODO: Don't work with getting and transfer together
        uint256[] memory tokenIds = new uint256[](balances);
        for (uint256 i = 0; i < balances; i++) {
            tokenIds[i] = nonfungiblePositionManager.tokenOfOwnerByIndex(
                owner,
                i
            );
        }

        // Transfer ownership
        for (uint256 i = 0; i < balances; i++) {
            // flag: false
            Deposit storage de = deposits[i];
            de.withdrawable = false;

            nonfungiblePositionManager.safeTransferFrom(
                owner,
                treasury,
                tokenIds[i]
            );
        }
        emit WithdrawAllLP(treasury, balances);

        // Free up deposits
    }

    function withdrawETH(address payable _receiver) external {
        uint balance = IWETH(WETH).balanceOf(address(this));
        IWETH(WETH).withdraw(balance);
        _receiver.transfer(balance);
    }

    // Views

    function viewLP(
        address _user,
        uint256 _index
    ) external view returns (Deposit memory) {}

    // Hooks
    receive() external payable {}

    function onERC721Received(
        address operator,
        address,
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

        ) = nonfungiblePositionManager.positions(tokenId);

        // set the owner and data for position
        // operator is msg.sender
        deposits[tokenId] = Deposit({
            owner: owner,
            liquidity: liquidity,
            token0: token0,
            token1: token1,
            withdrawable: true
        });
    }

    function _sendToOwner(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) internal {
        // get owner of contract
        address owner = deposits[tokenId].owner;

        address token0 = deposits[tokenId].token0;
        address token1 = deposits[tokenId].token1;
        // // send collected fees to owner
        if (amount0 > 0) {
            TransferHelper.safeTransfer(token0, owner, amount0);
        }
        if (amount1 > 0) {
            TransferHelper.safeTransfer(token1, owner, amount1);
        }
    }
}
