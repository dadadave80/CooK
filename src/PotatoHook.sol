// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// External: OpenZeppelin
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

// External: Uniswap
import {IPoolManager, ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {
    BeforeSwapDelta,
    BeforeSwapDeltaLibrary,
    toBeforeSwapDelta
} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

// External: Solady
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

// Internal
import {IMarket, ListingInfo, PurchaseData} from "./interface/IMarket.sol";

/*
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⡤⣔⢲⡒⢦⡙⡴⣒⣖⡠⣄⣀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡴⡞⡹⢆⣝⣤⣣⡙⢦⣙⡴⡡⢦⡙⣱⠺⣭⣖⠤⡀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⠻⣡⢳⠵⠛⠉⠀⠀⠀⡀⢀⠀⡈⠙⢢⡝⡤⢓⠦⡜⠻⣜⡢⣄
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡴⣛⠬⣣⠋⠁⢀⠠⠐⠈⡀⢁⠀⠂⠠⠐⠀⠄⡿⣐⡟⠉⠉⠳⣌⠳⣜⢢⡀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡞⡸⣤⠟⠀⠀⠌⢀⠀⠂⠐⠀⠄⠈⠄⢁⣄⡬⢞⡱⣡⢛⣤⣐⣀⣼⠳⡌⢧⡱⡄
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡳⢍⡶⠁⠀⠄⠡⢀⣢⠬⡴⢓⡞⢲⠫⡝⢭⠢⡝⢢⡓⠴⣃⢆⡣⡍⢦⠓⡼⢡⠳⣸⡄
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠷⣩⠞⠀⠠⢁⡴⡺⢍⡲⣑⠎⡵⡨⢇⢳⠸⣡⠓⣍⢷⣮⢓⡜⣢⢵⡪⣥⠛⣔⡋⣷⡇⣷
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⢾⠣⡏⡀⠄⣡⡏⢖⡩⢖⡱⢜⢪⠱⣱⢊⠧⣙⡔⢫⡔⢫⡱⢎⠴⣃⠾⣽⣶⣋⢦⡹⢿⡛⣧⡇
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⢮⠣⣝⠳⡴⡚⢧⣘⢣⠜⢦⡙⡬⢎⠵⣂⢏⠲⣅⠺⣡⢎⢣⡜⣊⠶⡑⣎⢹⢺⣻⣮⡝⢦⡙⣷⣻
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡰⢏⠎⣕⢪⣱⢣⡙⢆⠮⡜⢪⡱⢜⢢⣝⢢⡍⢎⡕⡪⢕⡲⢌⡣⢜⢢⢇⡹⢤⢣⠓⣎⣛⠿⢦⢹⣷⡹⡄
⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡴⢫⡙⣬⠚⣌⠦⡹⢟⣻⡿⢶⣍⢣⡜⢪⡱⢏⡣⡜⢎⡴⡙⢦⠱⢎⡱⡩⢖⢪⡑⣎⠲⣍⠲⡌⢞⢢⣻⢞⡵⡇
⠀⠀⠀⠀⠀⠀⠀⣠⡾⢣⢍⡣⡜⠴⡙⢆⡳⢡⠏⡴⢩⣋⠜⣆⡚⢥⢚⡴⡑⢮⡑⢦⡙⢆⠯⣘⠲⣅⠫⢆⠳⣌⠳⣸⣷⣏⢎⡱⣯⡻⣜⡇
⠀⠀⠀⠀⠀⣠⣾⢟⡴⣋⠦⡱⢎⢣⠝⡸⡔⢫⢜⡸⢅⡎⠞⣤⠹⣘⠦⣒⠭⡒⣍⠦⣙⠎⣜⣡⠳⣌⠳⣉⠳⣌⠳⣩⢛⠻⡌⣾⡳⣝⢧⡇
⠀⠀⠀⠀⡴⢟⡹⣻⠿⡎⢖⡱⡩⢎⣚⢱⣮⠇⣎⠖⣩⠜⣱⢊⠵⡡⢞⡰⢣⡙⣤⢋⢦⡙⢆⡖⡱⣊⠵⣉⠶⣡⠓⡥⢎⢳⢸⣷⢫⡽⣺⠅
⠀⠀⢀⢮⡙⣆⢣⠵⡩⢜⠣⣜⣡⠳⣌⠣⣍⡚⡤⢛⡤⢛⢤⡋⡼⡑⣎⠱⢣⡱⢆⢭⠢⡝⠲⢬⡱⢜⡸⢌⠶⣡⢋⢖⡩⢎⡿⣎⢷⡹⣽
⠀⠀⣼⢍⠖⣱⢊⡖⡍⣎⠳⡰⢆⠳⣌⢓⠦⣱⠩⢖⡡⢏⠦⣱⢡⠳⡌⡭⢣⢜⡊⡖⠭⡜⣙⠦⡱⢎⡜⣊⠶⡡⠞⣌⠖⣿⣝⣮⢳⢯⡍
⠀⢸⣻⢜⢪⡑⡎⡴⢓⡌⢇⡓⢎⠳⣌⡚⡜⠴⣙⢬⡚⢬⠲⣅⢎⠳⢬⣑⠣⣎⠜⡜⡥⡙⢆⣧⡓⡼⣐⢣⠎⡵⢩⢆⣿⡻⣼⣎⣟⣞⠃
⠀⣟⣿⡘⣆⢣⡕⢎⡱⢪⡑⢮⠩⡖⣡⠞⣌⠳⡜⣶⣽⣦⣓⢬⢊⡝⢢⠎⡵⡘⢎⡱⡜⣩⢎⢻⠱⡒⡍⢦⢋⡴⢋⣼⣗⣻⣿⣿⡞⡼
⢸⣽⢾⡱⡌⠶⡘⢎⡱⢣⡙⢆⡏⠴⣃⠞⣌⠳⣘⡌⢳⠽⣻⢾⣮⢜⡡⢏⡴⡙⣬⠱⡜⡔⡪⢥⢋⡕⢮⡑⠮⣔⡿⣳⢎⡷⣹⢶⣹⠃
⢸⣞⢧⣷⢉⡞⡩⢮⣵⡣⢎⢣⡜⠳⡌⠞⣌⢣⠕⣊⢇⠮⣑⢫⡙⢦⡙⢆⡖⡍⣆⠳⡜⡸⣑⢎⡱⢊⢦⡙⣼⢞⡳⣝⢾⡱⣏⡞⡏
⠸⣾⣏⠾⣧⣘⠱⢫⡙⣥⢋⢖⣘⢣⠭⣙⢤⡋⡼⢡⢎⠳⣌⢣⡜⢦⡙⡲⠸⡔⢣⡓⣜⣱⣬⠒⡭⣩⢆⣽⢳⢯⡝⣮⢳⡝⣮⡝
⠀⣷⢫⡟⡽⣆⢏⠥⣓⢤⢋⡖⡸⡌⠶⣉⢦⠱⣱⡉⢮⢱⡘⡆⠞⣤⠓⣍⢣⠝⣢⠕⡺⢽⠻⣍⢲⣱⠾⣭⣛⢮⣝⢮⡳⡽⡞
⠀⢸⣻⣜⡳⣝⡻⣔⢣⠎⣖⠸⣱⢘⡣⢕⡪⠕⢦⡙⢆⡇⢞⡸⣉⢦⠹⡌⢎⢎⡱⢎⡱⢎⡱⡼⡾⣭⣛⢶⡹⣞⡼⣣⢟⡝
⠀⠀⢷⣫⠷⣭⢳⣏⢷⢾⣈⡓⠦⣍⡒⠧⡜⣙⠦⡙⢦⣿⡦⢱⢊⢦⢋⡼⣉⠦⡓⣬⣱⢾⡹⣏⢷⣣⢟⣮⢳⡝⣾⣱⠏
⠀⠀⠈⢯⣟⡼⣳⢎⡟⣮⢯⡽⣳⢦⣙⡜⡜⡢⢝⡘⢦⡙⡴⢋⡜⣢⢍⢲⣡⠾⣵⢫⡞⣧⢻⡼⣿⣿⡾⣜⢧⡻⣶⠋
⠀⠀⠀⠈⢿⢾⡵⣛⠾⣵⣿⣾⣭⢯⡝⣾⣹⢳⡟⣞⢦⡳⣜⡳⣞⢶⣫⢟⡼⣻⣼⣳⢻⣼⣣⠿⣽⣛⢷⡹⣮⠟⠁
⠀⠀⠀⠀⠀⠻⣽⣯⣟⣿⣿⡿⣏⢾⡹⢶⣭⢳⡝⣮⢳⡝⣧⢻⡜⣧⣛⢮⣳⢳⢾⣻⢟⣾⣽⣛⡶⣹⢮⠿⠋
⠀⠀⠀⠀⠀⠀⠈⠻⣿⣷⣹⢞⡽⢮⣝⡳⣎⢷⡹⣎⢷⡹⣎⢷⣿⣧⣟⢮⣳⣛⡾⣝⡻⣞⣽⢿⡽⠟⠁
⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⢻⡿⣼⡳⣎⢷⡹⣎⢷⡹⣎⢷⡹⣾⣿⣿⢿⣫⣿⣿⡜⣧⢟⡾⠜⠋
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠓⠿⣹⡞⡵⢯⡞⣵⣫⣞⣵⣳⡞⣼⢣⡷⣻⡼⠽⠚⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠑⠛⠒⠛⠚⠓⠓⠛⠊⠉⠉⠀⠁
*/

/// @title PotatoHook
/// @author David Dada (https://github.com/dadadave80)
/// @notice This hook allows users to purchase listings from the Market contract using USDC.
contract PotatoHook is BaseHook {
    /*,AccessControl, Pausable*/
    using SafeTransferLib for address;

    /// @dev Error messages
    error PotatoHook__NoStableCoin();
    error PotatoHook__InvalidSwap();
    error PotatoHook__InvalidRecipient();
    error PotatoHook__InsufficientFunds();

    IMarket public immutable MARKET;
    address public immutable USDC;

    /// @param _poolManager The PoolManager contract
    /// @param _market The Market contract
    /// @param _usdc The USDC token address
    constructor(IPoolManager _poolManager, IMarket _market, address _usdc) BaseHook(_poolManager) {
        MARKET = _market;
        USDC = _usdc;
        // _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /// @inheritdoc BaseHook
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @inheritdoc BaseHook
    function _beforeInitialize(address, PoolKey calldata _poolKey, uint160) internal view override returns (bytes4) {
        if (!_isValidStableCoin(_poolKey.currency0) && !_isValidStableCoin(_poolKey.currency1)) {
            revert PotatoHook__NoStableCoin();
        }
        return this.beforeInitialize.selector;
    }

    /// @inheritdoc BaseHook
    function _beforeSwap(address, PoolKey calldata _poolKey, SwapParams calldata _params, bytes calldata _hookData)
        internal
        override
        returns (bytes4, BeforeSwapDelta beforeSwapDelta_, uint24)
    {
        bool isStableSpecified = _amountSpecifiedIsStableCoin(_poolKey, _params);
        bool isScenario2 = !isStableSpecified && _outputIsStableCoin(_poolKey, _params);

        if (!isStableSpecified && !isScenario2) {
            revert PotatoHook__InvalidSwap();
        }

        // Validate the hook data to mint things.
        if (_hookData.length > 0) {
            PurchaseData memory data = abi.decode(_hookData, (PurchaseData));
            ListingInfo memory listing = MARKET.getListingInfoExt(data.listingId);

            // SCENARIO 1: User provides USDC directly
            if (listing.price != 0 && isStableSpecified) {
                // If we have a zero address recipient, we can't mint
                if (data.recipient == address(0)) {
                    revert PotatoHook__InvalidRecipient();
                }

                // Validate that the user has provided enough stable coins to buy the product
                // params.amountSpecified is negative for exactInput (amount user provides)
                int256 amountAvailable =
                    _params.amountSpecified < 0 ? -_params.amountSpecified : _params.amountSpecified;

                uint256 totalCost = listing.price * data.quantity;

                if (uint256(amountAvailable) < totalCost) {
                    revert PotatoHook__InsufficientFunds();
                }

                // We will now need to take the cost of the product away from the PoolManager
                // Pull funds from the user (recipient) to the hook
                poolManager.take(
                    _isValidStableCoin(_poolKey.currency0) ? _poolKey.currency0 : _poolKey.currency1,
                    address(this),
                    listing.price * data.quantity
                );

                // Approve Market to spend USDC
                USDC.safeApprove(address(MARKET), listing.price * data.quantity);

                // Buy the product
                MARKET.purchase(data.listingId, data.quantity, data.recipient);

                bool isToken0Stable = _isValidStableCoin(_poolKey.currency0);
                // If stable is token0, and we are swapping exactInput (negative),
                // we want to offset it by +cost.

                int128 deltaAmount = int128(int256(uint256(totalCost)));

                if (isToken0Stable) {
                    beforeSwapDelta_ = toBeforeSwapDelta(deltaAmount, 0);
                } else {
                    beforeSwapDelta_ = toBeforeSwapDelta(0, deltaAmount);
                }
            }
            // SCENARIO 2: Swap Token -> USDC, then purchase in afterSwap.
            // In beforeSwap, we do nothing but allow the swap.
        }

        return (this.beforeSwap.selector, beforeSwapDelta_, 0);
    }

    /// @inheritdoc BaseHook
    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4 selector_, int128 delta_) {
        // Check for Scenario 2
        bool isStableSpecified = _amountSpecifiedIsStableCoin(key, params);
        // If specified is NOT stable, but output IS stable, and we have hook data.
        if (!isStableSpecified && _outputIsStableCoin(key, params) && hookData.length > 0) {
            PurchaseData memory data = abi.decode(hookData, (PurchaseData));
            ListingInfo memory listing = MARKET.getListingInfoExt(data.listingId);

            if (listing.price != 0) {
                if (data.recipient == address(0)) {
                    revert PotatoHook__InvalidRecipient();
                }

                uint256 totalCost = listing.price * data.quantity;

                // Identify USDC delta received
                // This is the UNSPECIFIED delta (output of swap)
                int128 hookDeltaUnspecified = params.zeroForOne ? delta.amount1() : delta.amount0();

                // hookDeltaUnspecified should be POSITIVE (Pool -> User)
                // We want to verify we received enough
                if (uint128(hookDeltaUnspecified) < totalCost) {
                    revert PotatoHook__InsufficientFunds();
                }

                // Take USDC from PoolManager
                poolManager.take(
                    params.zeroForOne ? key.currency1 : key.currency0, // Output currency (stable)
                    address(this),
                    totalCost
                );

                // Approve Market
                USDC.safeApprove(address(MARKET), totalCost);

                // Purchase
                MARKET.purchase(data.listingId, data.quantity, data.recipient);

                // Return delta (positive) for the stablecoin (unspecified)
                // This tells PM "Hook took totalCost".
                // PM will apply totalCost to Hook's balance. Hook net 0.
                // Router sees `swapDelta - hookDelta`.
                // e.g. User gets 250 (swap). Hook takes 200. Router sees 250 - 200 = 50.
                return (BaseHook.afterSwap.selector, int128(int256(totalCost)));
            }
        }

        return (BaseHook.afterSwap.selector, 0);
    }

    /// @notice Helper function to determine if the output of the swap is a stable coin
    /// @param _poolKey The pool key
    /// @param _params The swap parameters
    /// @return True if the output of the swap is a stable coin
    function _outputIsStableCoin(PoolKey calldata _poolKey, SwapParams calldata _params) internal view returns (bool) {
        // If zeroForOne=true, Input=0, Output=1. If amountSpecified<0, Input is specified.
        // We want to check the *other* token.
        // If zeroForOne && ExactInput -> Output is 1. Check if 1 is Stable.
        Currency outputCurrency = _params.zeroForOne ? _poolKey.currency1 : _poolKey.currency0;
        return _isValidStableCoin(outputCurrency);
    }

    /// @notice Helper function to determine if a token is a stable coin
    /// @param _token The token to check
    /// @return True if the token is a stable coin
    function _isValidStableCoin(Currency _token) internal view returns (bool) {
        return Currency.unwrap(_token) == USDC;
    }

    /// @notice Helper function to determine if the amount specified is a stable coin
    /// @param _poolKey The pool key
    /// @param _params The swap parameters
    /// @return True if the amount specified is a stable coin
    function _amountSpecifiedIsStableCoin(PoolKey calldata _poolKey, SwapParams calldata _params)
        internal
        view
        returns (bool)
    {
        return _isValidStableCoin(
            _params.zeroForOne == _params.amountSpecified < 0 ? _poolKey.currency0 : _poolKey.currency1
        );
    }
}
