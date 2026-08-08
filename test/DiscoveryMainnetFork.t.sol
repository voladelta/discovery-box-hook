// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { LPFeeLibrary } from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { BalanceDelta, BalanceDeltaLibrary } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { HookMiner } from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import { DiscoveryBox } from "../src/DiscoveryBox.sol";
import { DiscoveryBoxFactory } from "../src/DiscoveryBoxFactory.sol";
import { DiscoveryHook } from "../src/DiscoveryHook.sol";
import { DiscoveryHookFactory } from "../src/DiscoveryHookFactory.sol";
import { DiscoveryLaunchFactory } from "../src/DiscoveryLaunchFactory.sol";

contract DiscoveryMainnetForkTest is Deployers {
    using BalanceDeltaLibrary for BalanceDelta;
    using PoolIdLibrary for PoolKey;

    IPoolManager internal constant MAINNET_POOL_MANAGER = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
    bytes32 internal constant MAINNET_POOL_MANAGER_RUNTIME_HASH =
        0x785f1014552b7ce7d5fb7d0c970ca60edee94fd00425d7ca21609acac7ce1293;

    DiscoveryBoxFactory internal boxFactory;
    DiscoveryHookFactory internal hookFactory;
    DiscoveryLaunchFactory internal launchFactory;

    function setUp() public {
        if (block.chainid != 1) vm.skip(true);
        assertEq(block.chainid, 1);
        manager = MAINNET_POOL_MANAGER;
        assertEq(address(manager).codehash, MAINNET_POOL_MANAGER_RUNTIME_HASH);

        swapRouter = new PoolSwapTest(manager);
        boxFactory = new DiscoveryBoxFactory();
        hookFactory = new DiscoveryHookFactory();
        launchFactory = new DiscoveryLaunchFactory(manager, boxFactory, hookFactory);
        vm.deal(address(this), 100 ether);
    }

    function test_mainnetPoolManagerLaunchFourQuadrantsAndClaimLifecycle() public {
        bytes32 boxSaltSeed = keccak256(abi.encode(block.number, "strict-1.5-fork"));
        address expectedBox = _expectedBox(boxSaltSeed);
        bytes memory hookArgs =
            abi.encode(manager, expectedBox, address(launchFactory), launchFactory.PROGRAMMABLE_OWNER());
        (address expectedHook, bytes32 hookSalt) =
            HookMiner.find(address(hookFactory), hookFactory.HOOK_FLAGS(), type(DiscoveryHook).creationCode, hookArgs);

        (DiscoveryBox box, DiscoveryHook hook) = launchFactory.launch(boxSaltSeed, hookSalt);
        assertEq(address(box), expectedBox);
        assertEq(address(hook), expectedHook);
        assertEq(uint160(address(hook)) & Hooks.ALL_HOOK_MASK, hookFactory.HOOK_FLAGS());

        PoolKey memory poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(address(box)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: launchFactory.TICK_SPACING(),
            hooks: IHooks(address(hook))
        });
        box.approve(address(swapRouter), type(uint256).max);

        BalanceDelta exactInputBuy = _swap(poolKey, true, -int256(1e15), 1e15);
        BalanceDelta exactOutputBuy = _swap(poolKey, true, int256(1e12), 1 ether);
        BalanceDelta exactInputSell = _swap(poolKey, false, -int256(1e12), 0);
        BalanceDelta exactOutputSell = _swap(poolKey, false, int256(1e10), 0);

        assertLt(exactInputBuy.amount0(), 0);
        assertGt(exactOutputBuy.amount1(), 0);
        assertLt(exactInputSell.amount1(), 0);
        assertGt(exactOutputSell.amount0(), 0);

        uint256 liability =
            hook.liability(poolKey.toId(), CurrencyLibrary.ADDRESS_ZERO, launchFactory.PROGRAMMABLE_OWNER());
        assertGt(liability, 0);
        assertEq(manager.balanceOf(address(hook), 0), liability);

        address destination = makeAddr("forkClaimDestination");
        uint256 destinationBefore = destination.balance;
        vm.prank(launchFactory.PROGRAMMABLE_OWNER());
        hook.claimProgrammableFee(liability, destination);

        assertEq(destination.balance - destinationBefore, liability);
        assertEq(hook.liability(poolKey.toId(), CurrencyLibrary.ADDRESS_ZERO, launchFactory.PROGRAMMABLE_OWNER()), 0);
        assertEq(manager.balanceOf(address(hook), 0), 0);
    }

    function _swap(PoolKey memory poolKey, bool zeroForOne, int256 amountSpecified, uint256 value)
        private
        returns (BalanceDelta)
    {
        return swapRouter.swap{ value: value }(
            poolKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ZERO_BYTES
        );
    }

    function _expectedBox(bytes32 boxSaltSeed) private view returns (address) {
        bytes32 boxSalt = keccak256(abi.encode(address(this), boxSaltSeed));
        bytes32 initCodeHash =
            keccak256(abi.encodePacked(type(DiscoveryBox).creationCode, abi.encode(address(launchFactory))));
        return vm.computeCreate2Address(boxSalt, initCodeHash, address(boxFactory));
    }
}
