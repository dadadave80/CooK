// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import {BaseScript} from "./base/BaseScript.sol";

import {Counter} from "../src/Counter.sol";
import {IMarket, Market} from "../src/Market.sol";
import {PotatoHook} from "../src/PotatoHook.sol";

import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

contract DeployPotatoHookScript is BaseScript {
    address constant MARKET = address(0x95e8136a95eDD41EEE8d2b2Eb9FA4E6216927378);
    address constant USDC = address(0xE1B4C15D27Ae552FAF14A08C3b27DD46E780EA0F);

    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
                | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(poolManager, MARKET, USDC);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_FACTORY, flags, type(PotatoHook).creationCode, constructorArgs);

        // Deploy the hook using CREATE2
        vm.broadcast();
        PotatoHook potatoHook = new PotatoHook{salt: salt}(poolManager, IMarket(MARKET), USDC);

        require(address(potatoHook) == hookAddress, "DeployHookScript: Hook Address Mismatch");
    }
}

/// @notice Mines the address and deploys the Counter.sol Hook contract
contract DeployHookScript is BaseScript {
    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        );

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(poolManager);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_FACTORY, flags, type(Counter).creationCode, constructorArgs);

        // Deploy the hook using CREATE2
        vm.broadcast();
        Counter counter = new Counter{salt: salt}(poolManager);

        require(address(counter) == hookAddress, "DeployHookScript: Hook Address Mismatch");
    }
}
