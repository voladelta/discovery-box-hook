// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { HookMiner } from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import { DiscoveryHook } from "./DiscoveryHook.sol";
import { IOpenableAsset } from "./openable/IOpenableAsset.sol";

/// @title Discovery Hook Factory
/// @notice Verifies a HookMiner salt and deploys the permission-address hook with its complete immutable configuration.
contract DiscoveryHookFactory {
    uint160 public constant HOOK_FLAGS = Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
    address public constant PROGRAMMABLE_OWNER = 0x4957f49620AFf3Adbbe8195a4f633E49cc93376c;

    error InvalidAddress();
    error InvalidHookAddress();
    error UnauthorizedDeployer();

    function deploy(bytes32 salt, IPoolManager manager, IOpenableAsset openableAsset, address registrar)
        external
        returns (DiscoveryHook hook)
    {
        if (address(manager) == address(0) || address(openableAsset) == address(0) || registrar == address(0)) {
            revert InvalidAddress();
        }
        if (msg.sender != registrar) revert UnauthorizedDeployer();

        bytes memory constructorArgs = abi.encode(manager, openableAsset, registrar, PROGRAMMABLE_OWNER);
        // The cast preserves the complete bytes32 salt; Slither's digit heuristic misclassifies this expression.
        // slither-disable-next-line too-many-digits
        address expectedHook = HookMiner.computeAddress(
            address(this), uint256(salt), abi.encodePacked(type(DiscoveryHook).creationCode, constructorArgs)
        );
        if (uint160(expectedHook) & Hooks.ALL_HOOK_MASK != HOOK_FLAGS || expectedHook.code.length != 0) {
            revert InvalidHookAddress();
        }

        hook = new DiscoveryHook{ salt: salt }(manager, openableAsset, registrar, PROGRAMMABLE_OWNER);
        if (address(hook) != expectedHook) revert InvalidHookAddress();
    }
}
