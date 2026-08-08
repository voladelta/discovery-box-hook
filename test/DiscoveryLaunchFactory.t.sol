// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { LPFeeLibrary } from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import { StateLibrary } from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { HookMiner } from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import { DiscoveryBox } from "../src/DiscoveryBox.sol";
import { DiscoveryBoxFactory } from "../src/DiscoveryBoxFactory.sol";
import { DiscoveryHook } from "../src/DiscoveryHook.sol";
import { DiscoveryHookFactory } from "../src/DiscoveryHookFactory.sol";
import { DiscoveryLaunchFactory } from "../src/DiscoveryLaunchFactory.sol";

contract DiscoveryLaunchFactoryTest is Deployers {
    using PoolIdLibrary for PoolKey;

    DiscoveryLaunchFactory internal factory;
    DiscoveryBoxFactory internal boxFactory;
    DiscoveryHookFactory internal hookFactory;

    function setUp() public {
        deployFreshManagerAndRouters();
        boxFactory = new DiscoveryBoxFactory();
        hookFactory = new DiscoveryHookFactory();
        factory = new DiscoveryLaunchFactory(manager, boxFactory, hookFactory);
        vm.deal(address(this), 1 ether);
    }

    function test_launchAtomicallyDeploysRegistersInitializesAndLocksLiquidity() public {
        bytes32 boxSaltSeed = bytes32(uint256(1));
        address expectedBox = _expectedBox(address(this), boxSaltSeed);
        bytes memory hookArgs = abi.encode(manager, expectedBox, address(factory), factory.PROGRAMMABLE_OWNER());
        (address expectedHook, bytes32 hookSalt) =
            HookMiner.find(address(hookFactory), hookFactory.HOOK_FLAGS(), type(DiscoveryHook).creationCode, hookArgs);

        (DiscoveryBox box, DiscoveryHook hook) = factory.launch(boxSaltSeed, hookSalt);

        assertEq(address(box), expectedBox);
        assertEq(address(hook), expectedHook);
        assertEq(address(hook.poolManager()), address(manager));
        assertEq(address(hook.openableAsset()), address(box));
        assertEq(hook.registrar(), address(factory));
        assertEq(hook.programmableOwner(), factory.PROGRAMMABLE_OWNER());
        assertTrue(hook.poolRegistered());
        assertTrue(hook.poolInitialized());
        assertEq(uint160(address(hook)) & Hooks.ALL_HOOK_MASK, hookFactory.HOOK_FLAGS());

        PoolKey memory key = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(address(box)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: factory.TICK_SPACING(),
            hooks: IHooks(address(hook))
        });
        PoolId poolId = key.toId();
        assertEq(PoolId.unwrap(hook.registeredPoolId()), PoolId.unwrap(poolId));
        assertEq(hook.expectedSqrtPriceX96(), factory.INITIAL_SQRT_PRICE_X96());
        assertEq(factory.feeRecipient(poolId), address(this));

        (uint128 positionLiquidity,,) = StateLibrary.getPositionInfo(
            manager, poolId, address(factory), factory.INITIAL_TICK_LOWER(), factory.INITIAL_TICK_UPPER(), bytes32(0)
        );
        assertGt(positionLiquidity, 0);
        assertEq(box.balanceOf(address(factory)), 0);
        assertEq(box.balanceOf(address(this)) + box.balanceOf(address(manager)), box.totalSupply());
        assertEq(box.totalSupply(), box.INITIAL_SUPPLY());
    }

    function test_launchRecipientCanCollectFeesButCannotRemovePrincipal() public {
        bytes32 boxSaltSeed = bytes32(uint256(3));
        address expectedBox = _expectedBox(address(this), boxSaltSeed);
        bytes memory hookArgs = abi.encode(manager, expectedBox, address(factory), factory.PROGRAMMABLE_OWNER());
        (, bytes32 hookSalt) =
            HookMiner.find(address(hookFactory), hookFactory.HOOK_FLAGS(), type(DiscoveryHook).creationCode, hookArgs);
        (DiscoveryBox box, DiscoveryHook hook) = factory.launch(boxSaltSeed, hookSalt);

        PoolKey memory key = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(address(box)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: factory.TICK_SPACING(),
            hooks: IHooks(address(hook))
        });
        PoolId poolId = key.toId();
        (uint128 liquidityBefore,,) = StateLibrary.getPositionInfo(
            manager, poolId, address(factory), factory.INITIAL_TICK_LOWER(), factory.INITIAL_TICK_UPPER(), bytes32(0)
        );

        swapRouter.swap{ value: 1e12 }(
            key,
            SwapParams({ zeroForOne: true, amountSpecified: -int256(1e12), sqrtPriceLimitX96: MIN_PRICE_LIMIT }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ZERO_BYTES
        );

        address other = makeAddr("notFeeRecipient");
        vm.prank(other);
        vm.expectRevert(DiscoveryLaunchFactory.UnauthorizedFeeRecipient.selector);
        factory.collectFees(key, other);

        uint256 ethBefore = address(this).balance;
        (uint256 amount0, uint256 amount1) = factory.collectFees(key, address(this));
        assertGt(amount0, 0);
        assertEq(amount1, 0);
        assertEq(address(this).balance - ethBefore, amount0);

        (uint128 liquidityAfter,,) = StateLibrary.getPositionInfo(
            manager, poolId, address(factory), factory.INITIAL_TICK_LOWER(), factory.INITIAL_TICK_UPPER(), bytes32(0)
        );
        assertEq(liquidityAfter, liquidityBefore);
    }

    function test_invalidHookSaltRevertsTheEntireLaunch() public {
        bytes32 boxSaltSeed = bytes32(uint256(2));
        address expectedBox = _expectedBox(address(this), boxSaltSeed);

        vm.expectRevert(DiscoveryHookFactory.InvalidHookAddress.selector);
        factory.launch(boxSaltSeed, bytes32(0));

        assertEq(expectedBox.code.length, 0);
    }

    function test_frontRunnerCannotPredeployOrHijackLaunch() public {
        address beneficiary = makeAddr("beneficiary");
        address frontRunner = makeAddr("frontRunner");
        bytes32 boxSaltSeed = bytes32(uint256(4));
        bytes32 beneficiaryBoxSalt = keccak256(abi.encode(beneficiary, boxSaltSeed));
        address expectedBox = _expectedBox(beneficiary, boxSaltSeed);
        bytes memory hookArgs = abi.encode(manager, expectedBox, address(factory), factory.PROGRAMMABLE_OWNER());
        (address expectedHook, bytes32 hookSalt) =
            HookMiner.find(address(hookFactory), hookFactory.HOOK_FLAGS(), type(DiscoveryHook).creationCode, hookArgs);

        vm.prank(frontRunner);
        vm.expectRevert(DiscoveryBoxFactory.UnauthorizedDeployer.selector);
        boxFactory.deploy(beneficiaryBoxSalt, address(factory));

        vm.prank(frontRunner);
        vm.expectRevert(DiscoveryHookFactory.UnauthorizedDeployer.selector);
        hookFactory.deploy(hookSalt, manager, DiscoveryBox(expectedBox), address(factory));

        vm.prank(frontRunner);
        try factory.launch(boxSaltSeed, hookSalt) returns (DiscoveryBox copiedBox, DiscoveryHook copiedHook) {
            assertNotEq(address(copiedBox), expectedBox);
            assertNotEq(address(copiedHook), expectedHook);
        } catch { }
        assertEq(expectedBox.code.length, 0);
        assertEq(expectedHook.code.length, 0);

        vm.prank(beneficiary);
        (DiscoveryBox box, DiscoveryHook hook) = factory.launch(boxSaltSeed, hookSalt);
        assertEq(address(box), expectedBox);
        assertEq(address(hook), expectedHook);

        PoolKey memory key = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(address(box)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: factory.TICK_SPACING(),
            hooks: IHooks(address(hook))
        });
        assertEq(factory.feeRecipient(key.toId()), beneficiary);
    }

    function test_unlockCallbackRejectsDirectCaller() public {
        vm.expectRevert(DiscoveryLaunchFactory.InvalidLaunchCallback.selector);
        factory.unlockCallback(bytes(""));
    }

    function _expectedBox(address beneficiary, bytes32 boxSaltSeed) private view returns (address) {
        bytes32 boxSalt = keccak256(abi.encode(beneficiary, boxSaltSeed));
        bytes32 initCodeHash =
            keccak256(abi.encodePacked(type(DiscoveryBox).creationCode, abi.encode(address(factory))));
        return vm.computeCreate2Address(boxSalt, initCodeHash, address(boxFactory));
    }
}
