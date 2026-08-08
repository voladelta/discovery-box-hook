// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { BaseHook } from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { CustomRevert } from "@uniswap/v4-core/src/libraries/CustomRevert.sol";
import { LPFeeLibrary } from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { BalanceDelta, BalanceDeltaLibrary } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { ModifyLiquidityParams, SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { HookMiner } from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import { Vm } from "forge-std/Vm.sol";

import { DiscoveryBox } from "../src/DiscoveryBox.sol";
import { DiscoveryHook } from "../src/DiscoveryHook.sol";
import { TicketBox } from "../src/applications/TicketBox.sol";

contract DiscoveryHookTest is Deployers {
    using SafeCast for uint256;
    using BalanceDeltaLibrary for BalanceDelta;
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    uint160 internal constant HOOK_FLAGS = Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;

    DiscoveryBox internal box;
    DiscoveryHook internal hook;
    address internal constant PROGRAMMABLE_OWNER = 0x4957f49620AFf3Adbbe8195a4f633E49cc93376c;
    address internal programmableOwner = PROGRAMMABLE_OWNER;
    bytes32 internal constant SWAP_EVENT_SIGNATURE =
        keccak256("Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)");

    function setUp() public {
        deployFreshManagerAndRouters();
        vm.deal(address(this), 100 ether);

        box = new DiscoveryBox(address(this));

        bytes memory constructorArgs = abi.encode(manager, box, address(this), programmableOwner);
        (address expectedHookAddress, bytes32 salt) =
            HookMiner.find(address(this), HOOK_FLAGS, type(DiscoveryHook).creationCode, constructorArgs);
        hook = new DiscoveryHook{ salt: salt }(manager, box, address(this), programmableOwner);
        assertEq(address(hook), expectedHookAddress);
        assertEq(uint160(address(hook)) & Hooks.ALL_HOOK_MASK, HOOK_FLAGS);

        key = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(address(box)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        hook.registerPool(key, SQRT_PRICE_1_1);
        manager.initialize(key, SQRT_PRICE_1_1);

        box.approve(address(modifyLiquidityRouter), type(uint256).max);
        box.approve(address(swapRouter), type(uint256).max);
        modifyLiquidityRouter.modifyLiquidity{ value: 1 ether }(
            key,
            ModifyLiquidityParams({ tickLower: -600, tickUpper: 600, liquidityDelta: 10 ether, salt: 0 }),
            ZERO_BYTES
        );
    }

    function test_permissionsAndInitialization() public view {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.afterInitialize);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        assertTrue(permissions.beforeSwapReturnDelta);
        assertTrue(permissions.afterSwapReturnDelta);
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.beforeAddLiquidity);
        assertFalse(permissions.afterAddLiquidity);
        assertTrue(hook.poolRegistered());
        assertTrue(hook.poolInitialized());
        assertEq(PoolId.unwrap(hook.registeredPoolId()), PoolId.unwrap(key.toId()));
        assertEq(hook.programmableOwner(), PROGRAMMABLE_OWNER);
    }

    function test_constructorRejectsWrongProgrammableOwner() public {
        address wrongOwner = makeAddr("wrongProgrammableOwner");
        bytes memory constructorArgs = abi.encode(manager, box, address(this), wrongOwner);
        (, bytes32 salt) = HookMiner.find(address(this), HOOK_FLAGS, type(DiscoveryHook).creationCode, constructorArgs);
        vm.expectRevert(DiscoveryHook.UnauthorizedProgrammableOwner.selector);
        new DiscoveryHook{ salt: salt }(manager, box, address(this), wrongOwner);
    }

    function test_poolRegistrationCannotBeRepeatedOrCalledByAnotherAccount() public {
        vm.expectRevert(DiscoveryHook.PoolAlreadyRegistered.selector);
        hook.registerPool(key, SQRT_PRICE_1_1);

        vm.prank(makeAddr("notRegistrar"));
        vm.expectRevert(DiscoveryHook.UnauthorizedRegistrar.selector);
        hook.registerPool(key, SQRT_PRICE_1_1);
    }

    function test_directCallbacksRejectNonPoolManager() public {
        SwapParams memory params =
            SwapParams({ zeroForOne: true, amountSpecified: -int256(1e12), sqrtPriceLimitX96: MIN_PRICE_LIMIT });

        vm.expectRevert(BaseHook.NotPoolManager.selector);
        hook.beforeSwap(address(this), key, params, ZERO_BYTES);

        vm.expectRevert(BaseHook.NotPoolManager.selector);
        hook.unlockCallback(bytes(""));
    }

    function test_alternativePoolKeyCannotInitializeThroughHook() public {
        PoolKey memory alternativeKey = key;
        alternativeKey.tickSpacing = 120;

        vm.expectRevert();
        manager.initialize(alternativeKey, SQRT_PRICE_1_1);
    }

    function test_sellFeeFallsAtModelledMilestones() public {
        assertEq(hook.currentSellLpFee(), 10_000);

        box.open(1);
        assertEq(hook.currentSellLpFee(), 9_825);

        box.open(19);
        assertEq(hook.currentSellLpFee(), 6_500);

        box.open(19);
        assertEq(hook.currentSellLpFee(), 3_175);

        box.open(1);
        assertEq(hook.currentSellLpFee(), 3_000);

        box.open(59);
        assertEq(hook.currentSellLpFee(), 3_000);
    }

    function test_fuzzSellFeeIsBoundedAndMonotonic(uint8 rawOpened) public {
        uint256 opened = bound(uint256(rawOpened), 0, 99);
        if (opened != 0) box.open(opened);

        uint24 actual = hook.currentSellLpFee();
        uint24 expected = uint24(10_000 - _min(opened, 40) * 7_000 / 40);
        assertEq(actual, expected);
        assertGe(actual, 3_000);
        assertLe(actual, 10_000);
    }

    function test_fuzzGrossUpIdentity(uint128 rawNetQuote) public view {
        uint256 netQuote = bound(uint256(rawNetQuote), 0, uint256(int256(type(int128).max)) - 1);
        uint256 fee = hook.programmableFeeOnTopOfNetQuote(netQuote);
        uint256 grossQuote = netQuote + fee;

        assertEq(fee, hook.programmableFeeFromGrossQuote(grossQuote));
        assertLt(fee, grossQuote + 1);
    }

    function test_feeMathDoesNotMakeSubminimumSwapsAdmissible() public view {
        assertEq(hook.programmableFeeFromGrossQuote(999), 0);
        assertEq(hook.programmableFeeOnTopOfNetQuote(998), 0);
        assertEq(hook.programmableFeeFromGrossQuote(1_000), 1);
        assertEq(hook.programmableFeeOnTopOfNetQuote(999), 1);
        assertEq(hook.MINIMUM_GROSS_QUOTE(), 1_000);
        assertEq(hook.PROJECT_FEE(), 0);
    }

    function test_splitAcceptedSwapsCarryGrossFeeRemainder() public {
        _swap(true, -1_500, 1_500);
        assertEq(_liability(), 1);
        assertEq(hook.feeRemainder(key.toId(), CurrencyLibrary.ADDRESS_ZERO, programmableOwner), 500_000);

        _swap(true, -1_500, 1_500);
        assertEq(_liability(), 3);
        assertEq(hook.feeRemainder(key.toId(), CurrencyLibrary.ADDRESS_ZERO, programmableOwner), 0);
    }

    function test_claimDoesNotResetLifetimeRemainder() public {
        _swap(true, -1_500, 1_500);
        uint256 liabilityBefore = _liability();
        uint256 remainderBefore = hook.feeRemainder(key.toId(), CurrencyLibrary.ADDRESS_ZERO, programmableOwner);

        vm.prank(programmableOwner);
        hook.claimProgrammableFee(liabilityBefore, programmableOwner);

        assertEq(_liability(), 0);
        assertEq(hook.feeRemainder(key.toId(), CurrencyLibrary.ADDRESS_ZERO, programmableOwner), remainderBefore);
        assertEq(manager.balanceOf(address(hook), 0), 0);
    }

    function test_positiveGrossQuoteBelowMinimumRevertsInAllFourSwapQuadrants() public {
        uint256 liabilityBefore = _liability();
        uint256 remainderBefore = hook.feeRemainder(key.toId(), CurrencyLibrary.ADDRESS_ZERO, programmableOwner);
        uint256 backingBefore = manager.balanceOf(address(hook), 0);

        _expectHookMinimumRevert(IHooks.beforeSwap.selector, 999);
        _swap(true, -999, 999);
        _assertFeeState(liabilityBefore, remainderBefore, backingBefore);

        _expectHookMinimumRevert(IHooks.afterSwap.selector, 3);
        _swap(true, 1, 1 ether);
        _assertFeeState(liabilityBefore, remainderBefore, backingBefore);

        _expectHookMinimumRevert(IHooks.afterSwap.selector, 988);
        _swap(false, -999, 0);
        _assertFeeState(liabilityBefore, remainderBefore, backingBefore);

        _expectHookMinimumRevert(IHooks.beforeSwap.selector, 998);
        _swap(false, 998, 0);
        _assertFeeState(liabilityBefore, remainderBefore, backingBefore);

        _swap(true, -1_000, 1_000);
        assertEq(_liability(), 1);
    }

    function test_fuzzSubminimumSpecifiedGrossInputRevertsAtomically(uint16 rawGrossQuote) public {
        uint256 grossQuote = bound(uint256(rawGrossQuote), 1, 999);
        uint256 liabilityBefore = _liability();
        uint256 remainderBefore = hook.feeRemainder(key.toId(), CurrencyLibrary.ADDRESS_ZERO, programmableOwner);
        uint256 backingBefore = manager.balanceOf(address(hook), 0);

        _expectHookMinimumRevert(IHooks.beforeSwap.selector, grossQuote);
        _swap(true, -grossQuote.toInt256(), grossQuote);

        _assertFeeState(liabilityBefore, remainderBefore, backingBefore);
    }

    function test_exactInputBuyChargesGrossSpecifiedEth() public {
        uint256 grossInput = 1e12;
        uint256 liabilityBefore = _liability();

        BalanceDelta result = _swap(true, -grossInput.toInt256(), grossInput);

        uint256 fee = grossInput * 1_000 / 1_000_000;
        assertEq(uint256(-int256(result.amount0())), grossInput);
        assertEq(_liability() - liabilityBefore, fee);
        assertEq(manager.balanceOf(address(hook), 0), _liability());
    }

    function test_exactOutputBuyChargesExecutedGrossEth() public {
        uint256 tokenOutput = 1e12;
        uint256 liabilityBefore = _liability();

        BalanceDelta result = _swap(true, tokenOutput.toInt256(), 1 ether);

        uint256 grossInput = uint256(-int256(result.amount0()));
        uint256 fee = _liability() - liabilityBefore;
        assertEq(fee, grossInput * 1_000 / 1_000_000);
        assertEq(result.amount1(), SafeCast.toInt128(tokenOutput.toInt256()));
        assertEq(manager.balanceOf(address(hook), 0), _liability());
    }

    function test_exactInputSellChargesExecutedGrossEth() public {
        uint256 tokenInput = 1e12;
        uint256 liabilityBefore = _liability();

        BalanceDelta result = _swap(false, -tokenInput.toInt256(), 0);

        uint256 fee = _liability() - liabilityBefore;
        uint256 netOutput = uint256(int256(result.amount0()));
        uint256 grossOutput = netOutput + fee;
        assertEq(fee, grossOutput * 1_000 / 1_000_000);
        assertEq(uint256(-int256(result.amount1())), tokenInput);
        assertEq(manager.balanceOf(address(hook), 0), _liability());
    }

    function test_exactOutputSellChargesOnTopAndReturnsRequestedNetEth() public {
        uint256 netOutput = 1e12;
        uint256 liabilityBefore = _liability();

        BalanceDelta result = _swap(false, netOutput.toInt256(), 0);

        uint256 fee = _liability() - liabilityBefore;
        assertEq(result.amount0(), SafeCast.toInt128(netOutput.toInt256()));
        assertEq(fee, netOutput * 1_000 / 999_000);
        assertEq(fee, (netOutput + fee) * 1_000 / 1_000_000);
        assertEq(manager.balanceOf(address(hook), 0), _liability());
    }

    function test_programmableOwnerCanClaimAllBacking() public {
        _swap(true, -int256(1e12), 1e12);
        uint256 amount = _liability();
        address destination = makeAddr("destination");
        uint256 destinationBefore = destination.balance;

        vm.prank(programmableOwner);
        hook.claimProgrammableFee(amount, destination);

        assertEq(destination.balance - destinationBefore, amount);
        assertEq(_liability(), 0);
        assertEq(manager.balanceOf(address(hook), 0), 0);
    }

    function test_programmableOwnerCanClaimInParts() public {
        _swap(true, -int256(1e12), 1e12);
        uint256 total = _liability();
        uint256 first = total / 3;

        vm.startPrank(programmableOwner);
        hook.claimProgrammableFee(first, programmableOwner);
        hook.claimProgrammableFee(total - first, programmableOwner);
        vm.stopPrank();

        assertEq(_liability(), 0);
        assertEq(manager.balanceOf(address(hook), 0), 0);
    }

    function test_failedDestinationDoesNotReduceLiability() public {
        _swap(true, -int256(1e12), 1e12);
        uint256 amount = _liability();
        RejectEth destination = new RejectEth();

        vm.prank(programmableOwner);
        vm.expectRevert();
        hook.claimProgrammableFee(amount, address(destination));

        assertEq(_liability(), amount);
        assertEq(manager.balanceOf(address(hook), 0), amount);
    }

    function test_zeroAndExcessiveClaimsRevert() public {
        _swap(true, -int256(1e12), 1e12);
        uint256 amount = _liability();

        vm.startPrank(programmableOwner);
        vm.expectRevert(DiscoveryHook.InvalidClaimAmount.selector);
        hook.claimProgrammableFee(0, programmableOwner);
        vm.expectRevert(DiscoveryHook.InvalidClaimAmount.selector);
        hook.claimProgrammableFee(amount + 1, programmableOwner);
        vm.stopPrank();

        assertEq(_liability(), amount);
    }

    function test_nonOwnerCannotClaim() public {
        _swap(true, -int256(1e12), 1e12);
        uint256 amount = _liability();

        vm.expectRevert(DiscoveryHook.UnauthorizedProgrammableOwner.selector);
        hook.claimProgrammableFee(amount, address(this));
    }

    function test_specifiedEthPartialBuyRevertsWithoutAccrual() public {
        uint256 liabilityBefore = _liability();
        uint160 tightLimit = SQRT_PRICE_1_1 - 1;
        SwapParams memory params =
            SwapParams({ zeroForOne: true, amountSpecified: -int256(1 ether), sqrtPriceLimitX96: tightLimit });

        vm.expectRevert();
        swapRouter.swap{ value: 1 ether }(
            key, params, PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }), ZERO_BYTES
        );

        assertEq(_liability(), liabilityBefore);
        assertEq(manager.balanceOf(address(hook), 0), liabilityBefore);
    }

    function test_specifiedEthPartialSellRevertsWithoutAccrual() public {
        uint256 liabilityBefore = _liability();
        uint160 tightLimit = SQRT_PRICE_1_1 + 1;
        SwapParams memory params =
            SwapParams({ zeroForOne: false, amountSpecified: int256(1 ether), sqrtPriceLimitX96: tightLimit });

        vm.expectRevert();
        swapRouter.swap(
            key, params, PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }), ZERO_BYTES
        );

        assertEq(_liability(), liabilityBefore);
        assertEq(manager.balanceOf(address(hook), 0), liabilityBefore);
    }

    function test_swapEventUsesDirectionalLpFeeAndRespondsToOpenings() public {
        vm.recordLogs();
        _swap(true, -int256(1e12), 1e12);
        assertEq(_lastSwapFee(vm.getRecordedLogs()), 3_000);

        vm.recordLogs();
        _swap(false, -int256(1e12), 0);
        assertEq(_lastSwapFee(vm.getRecordedLogs()), 10_000);

        box.open(20);
        vm.recordLogs();
        _swap(false, -int256(1e12), 0);
        assertEq(_lastSwapFee(vm.getRecordedLogs()), 6_500);
    }

    function test_hookTracksTicketApplicationOpeningsAndRejectsWrongInitialPrice() public {
        TicketBox otherBox = new TicketBox(address(this), makeAddr("ticketGate"), 1);
        bytes memory constructorArgs = abi.encode(manager, otherBox, address(this), programmableOwner);
        (address expectedHookAddress, bytes32 salt) =
            HookMiner.find(address(this), HOOK_FLAGS, type(DiscoveryHook).creationCode, constructorArgs);
        DiscoveryHook otherHook = new DiscoveryHook{ salt: salt }(manager, otherBox, address(this), programmableOwner);
        assertEq(address(otherHook), expectedHookAddress);

        PoolKey memory otherKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(address(otherBox)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(otherHook))
        });
        otherHook.registerPool(otherKey, SQRT_PRICE_1_1);

        vm.expectRevert();
        manager.initialize(otherKey, SQRT_PRICE_1_1 + 1);
        assertFalse(otherHook.poolInitialized());

        manager.initialize(otherKey, SQRT_PRICE_1_1);
        assertTrue(otherHook.poolInitialized());
        assertEq(otherHook.currentSellLpFee(), 10_000);

        otherBox.open(20);
        assertEq(otherHook.currentSellLpFee(), 6_500);
    }

    function _swap(bool zeroForOne, int256 amountSpecified, uint256 value) private returns (BalanceDelta) {
        return swapRouter.swap{ value: value }(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ZERO_BYTES
        );
    }

    function _liability() private view returns (uint256) {
        return hook.liability(key.toId(), CurrencyLibrary.ADDRESS_ZERO, programmableOwner);
    }

    function _assertFeeState(uint256 expectedLiability, uint256 expectedRemainder, uint256 expectedBacking)
        private
        view
    {
        assertEq(_liability(), expectedLiability);
        assertEq(hook.feeRemainder(key.toId(), CurrencyLibrary.ADDRESS_ZERO, programmableOwner), expectedRemainder);
        assertEq(manager.balanceOf(address(hook), 0), expectedBacking);
    }

    function _expectHookMinimumRevert(bytes4 callback, uint256 grossQuote) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                callback,
                abi.encodeWithSelector(DiscoveryHook.GrossQuoteBelowMinimum.selector, grossQuote),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
    }

    function _lastSwapFee(Vm.Log[] memory logs) private view returns (uint24 fee) {
        for (uint256 i = logs.length; i > 0; --i) {
            Vm.Log memory entry = logs[i - 1];
            if (
                entry.emitter == address(manager) && entry.topics.length != 0 && entry.topics[0] == SWAP_EVENT_SIGNATURE
            ) {
                (,,,,, fee) = abi.decode(entry.data, (int128, int128, uint160, uint128, int24, uint24));
                return fee;
            }
        }
        revert("swap event not found");
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}

contract RejectEth {
    receive() external payable {
        revert();
    }
}

contract DiscoveryHookFirstBuyTest is Deployers {
    using SafeCast for uint256;

    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    uint160 internal constant HOOK_FLAGS = Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;

    DiscoveryBox internal box;
    DiscoveryHook internal hook;
    address internal constant PROGRAMMABLE_OWNER = 0x4957f49620AFf3Adbbe8195a4f633E49cc93376c;
    address internal programmableOwner = PROGRAMMABLE_OWNER;

    function setUp() public {
        deployFreshManagerAndRouters();
        vm.deal(address(this), 1 ether);
        box = new DiscoveryBox(address(this));

        bytes memory constructorArgs = abi.encode(manager, box, address(this), programmableOwner);
        (address expectedHookAddress, bytes32 salt) =
            HookMiner.find(address(this), HOOK_FLAGS, type(DiscoveryHook).creationCode, constructorArgs);
        hook = new DiscoveryHook{ salt: salt }(manager, box, address(this), programmableOwner);
        assertEq(address(hook), expectedHookAddress);

        key = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(address(box)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        hook.registerPool(key, SQRT_PRICE_1_1);
        manager.initialize(key, SQRT_PRICE_1_1);

        box.approve(address(modifyLiquidityRouter), type(uint256).max);
        box.approve(address(swapRouter), type(uint256).max);

        // The current tick is at this position's upper boundary, so launch liquidity is BOX-only.
        modifyLiquidityRouter.modifyLiquidity(
            key, ModifyLiquidityParams({ tickLower: -600, tickUpper: 0, liquidityDelta: 10 ether, salt: 0 }), ZERO_BYTES
        );
    }

    function test_firstBuyAccruesClaimWhenManagerStartsWithoutEth() public {
        assertEq(address(manager).balance, 0);

        uint256 grossInput = 1e12;
        BalanceDelta result = swapRouter.swap{ value: grossInput }(
            key,
            SwapParams({
                zeroForOne: true, amountSpecified: -grossInput.toInt256(), sqrtPriceLimitX96: MIN_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ZERO_BYTES
        );

        uint256 fee = grossInput * 1_000 / 1_000_000;
        assertEq(uint256(-int256(result.amount0())), grossInput);
        assertEq(hook.liability(key.toId(), CurrencyLibrary.ADDRESS_ZERO, programmableOwner), fee);
        assertEq(manager.balanceOf(address(hook), 0), fee);
        assertEq(address(manager).balance, grossInput);
    }
}
