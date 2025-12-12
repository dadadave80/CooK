// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";

import {EasyPosm} from "./utils/libraries/EasyPosm.sol";

import {Market} from "../src/Market.sol";
import {PotatoHook} from "../src/PotatoHook.sol";
import {IListing} from "../src/interface/IListing.sol";
import {IMarket, PurchaseData, RouterData} from "../src/interface/IMarket.sol";
import {BaseTest} from "./utils/BaseTest.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PathKey} from "hookmate/interfaces/router/PathKey.sol";

contract PotatoHookTest is BaseTest, ERC1155Holder {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Currency currency0;
    Currency currency1;
    address usdc;

    PoolKey poolKey;

    PotatoHook hook;
    Market market;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    address recipient = makeAddr("recipient");

    function setUp() public {
        // Deploys all required artifacts.
        deployArtifactsAndLabel();

        (currency0, currency1) = deployCurrencyPair();

        // Assume currency0 is USDC for simplicity in tests, or we check which one is which.
        // PotatoHook checks against the address passed in constructor.
        // We'll just define one as USDC.
        usdc = Currency.unwrap(currency0);
        vm.label(address(usdc), "USDC");

        // Deploy Market
        market = new Market(usdc);
        vm.label(address(market), "Market");

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
                    | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            ) ^ (0x907470 << 136)
        );

        // Constructor: IPoolManager _poolManager, IMarket _market, address _admin (USDC for logic)
        bytes memory constructorArgs = abi.encode(poolManager, market, usdc);
        deployCodeTo("PotatoHook.sol:PotatoHook", constructorArgs, flags);
        hook = PotatoHook(flags);
        vm.label(address(hook), "PotatoHook");

        // Create the pool
        poolKey = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = poolKey.toId();
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);

        uint128 liquidityAmount = type(uint64).max;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        (tokenId,) = positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            Constants.ZERO_BYTES
        );

        // Grant deployer lots of tokens
        deal(usdc, address(this), type(uint32).max);
        deal(Currency.unwrap(currency1), address(this), type(uint32).max);

        // Approve things
        IERC20(usdc).approve(address(swapRouter), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(swapRouter), type(uint256).max);

        permit2.approve(address(usdc), address(swapRouter), type(uint160).max, type(uint48).max);
        permit2.approve(address(Currency.unwrap(currency1)), address(swapRouter), type(uint160).max, type(uint48).max);
    }

    function testPurchaseDuringSwap() public {
        // 1. Create a listing
        uint128 price = 10e6; // 10 USDC
        address listingAddr = market.createListing(price, "uri", bytes32(0));

        // 2. Prepare purchase data
        PurchaseData memory data = PurchaseData({listingId: 1, quantity: 20, recipient: recipient});

        bytes memory hookData = abi.encode(data);

        // 3. Swap
        uint256 amountIn = 250e6; // 250 USDC input
        bool zeroForOne = true; // selling USDC (token0) for token1

        deal(usdc, recipient, 1000e6);
        vm.prank(recipient);
        IERC20(usdc).approve(address(hook), type(uint256).max);

        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: zeroForOne,
            poolKey: poolKey,
            hookData: hookData,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // 4. Checks
        assertEq(IListing(listingAddr).balanceOf(recipient, 1), 20);
        assertEq(int256(swapDelta.amount0()), -int256(amountIn));
    }

    function testPurchaseWithNonStableSwap() public {
        // 1. Create a listing
        uint128 price = 10e6; // 10 USDC
        address listingAddr = market.createListing(price, "uri", bytes32(0));

        // 2. Prepare purchase data
        PurchaseData memory data = PurchaseData({listingId: 1, quantity: 20, recipient: recipient});

        bytes memory hookData = abi.encode(data);

        // 3. Swap NonStable (currency1) -> Stable (currency0 = USDC)
        deal(Currency.unwrap(currency1), address(this), 1000 ether);
        IERC20(Currency.unwrap(currency1)).approve(address(swapRouter), type(uint256).max);

        uint256 amountIn = 1000 ether;
        bool zeroForOne = false; // Input=Currency1, Output=Currency0(USDC)

        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: zeroForOne,
            poolKey: poolKey,
            hookData: hookData,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // 4. Checks
        assertEq(IListing(listingAddr).balanceOf(recipient, 1), 20);
        assertEq(int256(swapDelta.amount1()), -int256(amountIn));
        assertTrue(swapDelta.amount0() > 0);
    }

    function testPurchaseWithToken() public {
        // 1. Create a listing
        uint128 price = 10e6; // 10 USDC
        address listingAddr = market.createListing(price, "uri", bytes32(0));

        // 2. Fund user with Currency1 (Input)
        uint256 amountIn = 1000 ether;
        deal(Currency.unwrap(currency1), address(this), amountIn);

        // 3. Approve Market to spend User's tokens (Currency1)
        IERC20(Currency.unwrap(currency1)).approve(address(market), amountIn);

        // 4. Construct Path
        PathKey[] memory path = new PathKey[](1);
        path[0] = PathKey({
            intermediateCurrency: currency0, // Output is USDC
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook),
            hookData: "" // Market will fill this
        });

        // 5. Call purchaseWithToken
        market.purchaseWithToken(
            PurchaseData({listingId: 1, quantity: 20, recipient: recipient}),
            RouterData({
                router: address(swapRouter),
                path: path,
                amountIn: amountIn,
                amountOutMin: 0,
                deadline: block.timestamp + 1
            }),
            Currency.unwrap(currency1)
        );

        // 6. Verify Purchase
        assertEq(IListing(listingAddr).balanceOf(recipient, 1), 20);

        // Verify User received change (some USDC)
        uint256 balanceUSDC = IERC20(usdc).balanceOf(recipient);
        assertTrue(balanceUSDC > 0);
    }

    function testPurchaseFailInsufficientOutput() public {
        uint128 price = 1000e6; // 1000 USDC (expensive)
        market.createListing(price, "uri", bytes32(0));

        PurchaseData memory data = PurchaseData({listingId: 1, quantity: 1, recipient: recipient});
        bytes memory hookData = abi.encode(data);

        // Swap small amount of currency1 -> USDC, not enough to cover 1000 USDC
        uint256 amountIn = 100; // tiny

        vm.prank(recipient);
        deal(Currency.unwrap(currency1), recipient, amountIn);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(swapRouter), type(uint256).max);

        // Expect revert due to insufficient funds in hook logic
        vm.expectRevert();
        swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: false,
            poolKey: poolKey,
            hookData: hookData,
            receiver: address(this),
            deadline: block.timestamp + 1
        });
    }

    function testPurchaseFailInvalidListing() public {
        PurchaseData memory data = PurchaseData({listingId: 999, quantity: 1, recipient: recipient});
        bytes memory hookData = abi.encode(data);

        uint256 amountIn = 250e6;
        deal(usdc, recipient, 1000e6);
        vm.prank(recipient);
        IERC20(usdc).approve(address(hook), type(uint256).max);
        IERC20(usdc).approve(address(swapRouter), type(uint256).max);

        // Should NOT revert, but just skip purchase because listing doesn't exist (price=0)
        BalanceDelta delta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: hookData,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Assert swap happened
        assertEq(int256(delta.amount0()), -int256(amountIn));
    }
}
