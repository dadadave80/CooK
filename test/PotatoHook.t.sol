// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";

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
import {BaseTest} from "./utils/BaseTest.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        PotatoHook.PurchaseData memory data =
            PotatoHook.PurchaseData({listingId: 1, quantity: 20, recipient: recipient});

        bytes memory hookData = abi.encode(data);

        // 3. Swap
        uint256 amountIn = 250e6; // 250 USDC input
        bool zeroForOne = true; // selling USDC (token0) for token1

        // Assuming token0 is USDC because we set usdc = currency0;

        // Approve hook to spend USDC
        // IERC20(usdc).approve(address(hook), type(uint256).max); // Calling from 'this'

        // We need to fund the recipient because the hook pulls from data.recipient
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
        // Recipient should have 20 NFT
        assertEq(IListing(listingAddr).balanceOf(recipient, 1), 20);

        // Market owner (this contract) should receive 10 USDC
        // Wait, market.createListing sets owner to caller (this).
        // Market.purchase transfers USDC to listing owner.
        // So this contract should have received 10 USDC back?
        // We started with lots. It's hard to track exact balance without snapshots.

        // Check event? Or balance change.
        // We spent 100 USDC in swap.
        // 10 USDC was diverted to purchase.
        // 90 USDC was effectively swapped?
        // Let's verify swapDelta.

        // amount0 delta should be -amountIn.
        // User pays 250 total via Router.
        assertEq(int256(swapDelta.amount0()), -int256(amountIn));

        // The user PAID 250 USDC total.
        // 200 went to Listing Owner (via Hook credit).
        // 50 went to Pool.
        // User should get Output of swapping 50 USDC.
    }
}
