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
import {IMarket, ListingInfo} from "./interface/IMarket.sol";

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

contract PotatoHook is BaseHook {
    /*,AccessControl, Pausable*/
    using SafeTransferLib for address;

    error PotatoHook__NoStableCoin();
    error PotatoHook__InvalidSwap();
    error PotatoHook__InvalidRecipient();
    error PotatoHook__InsufficientFunds();

    struct PurchaseData {
        uint64 listingId;
        uint96 quantity;
        address recipient;
    }

    IMarket public immutable MARKET;
    address public immutable USDC;

    constructor(IPoolManager _poolManager, IMarket _market, address _usdc) BaseHook(_poolManager) {
        MARKET = _market;
        USDC = _usdc;
        // _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

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

    function _beforeInitialize(address, PoolKey calldata _poolKey, uint160) internal view override returns (bytes4) {
        if (!_isValidStableCoin(_poolKey.currency0) && !_isValidStableCoin(_poolKey.currency1)) {
            revert PotatoHook__NoStableCoin();
        }
        return this.beforeInitialize.selector;
    }

    function _beforeSwap(address, PoolKey calldata _poolKey, SwapParams calldata _params, bytes calldata _hookData)
        internal
        override
        returns (bytes4, BeforeSwapDelta beforeSwapDelta_, uint24)
    {
        if (!_amountSpecifiedIsStableCoin(_poolKey, _params)) {
            revert PotatoHook__InvalidSwap();
        }

        // Validate the hook data to mint things.
        if (_hookData.length > 0) {
            PurchaseData memory data = abi.decode(_hookData, (PurchaseData));
            ListingInfo memory listing = MARKET.getListingInfoExt(data.listingId);

            // Check if the user is minting a product
            if (listing.price != 0 && _amountSpecifiedIsStableCoin(_poolKey, _params)) {
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
        }

        return (this.beforeSwap.selector, beforeSwapDelta_, 0);
    }

    function _afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        override
        returns (bytes4 selector_, int128 delta_)
    {
        // Don't intercept any funds. Let the swap router handle the output.
        return (BaseHook.afterSwap.selector, 0);
    }

    function _isValidStableCoin(Currency _token) internal view returns (bool) {
        return Currency.unwrap(_token) == USDC;
    }

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
