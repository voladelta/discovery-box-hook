// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { LPFeeLibrary } from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { HookMiner } from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import { DiscoveryBox } from "../src/DiscoveryBox.sol";
import { DiscoveryHook } from "../src/DiscoveryHook.sol";

contract DiscoveryHookInvariantTest is StdInvariant, Test {
    DiscoveryHookInvariantHandler internal handler;

    function setUp() public {
        handler = new DiscoveryHookInvariantHandler();
        targetContract(address(handler));
    }

    function invariant_swapFeesRemainBacked() public view {
        assertEq(handler.liabilityAmount(), handler.backingAmount());
    }

    function invariant_feeRemainderIsBounded() public view {
        assertLt(handler.remainderAmount(), 999_000_000);
    }

    function invariant_openableSupplyIsConserved() public view {
        assertEq(handler.totalSupplyAmount() + handler.openedCount() * 1 ether, 100 ether);
    }
}

contract DiscoveryHookInvariantHandler is Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    uint160 internal constant HOOK_FLAGS = Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
    address internal constant PROGRAMMABLE_OWNER = 0x4957f49620AFf3Adbbe8195a4f633E49cc93376c;

    DiscoveryBox public box;
    DiscoveryHook public hook;
    PoolId public poolId;

    constructor() {
        deployFreshManagerAndRouters();
        vm.deal(address(this), 100 ether);

        box = new DiscoveryBox(address(this));
        bytes memory constructorArgs = abi.encode(manager, box, address(this), PROGRAMMABLE_OWNER);
        (, bytes32 salt) = HookMiner.find(address(this), HOOK_FLAGS, type(DiscoveryHook).creationCode, constructorArgs);
        hook = new DiscoveryHook{ salt: salt }(manager, box, address(this), PROGRAMMABLE_OWNER);

        key = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(address(box)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        poolId = key.toId();

        hook.registerPool(key, SQRT_PRICE_1_1);
        manager.initialize(key, SQRT_PRICE_1_1);

        box.approve(address(modifyLiquidityRouter), type(uint256).max);
        box.approve(address(swapRouter), type(uint256).max);
        modifyLiquidityRouter.modifyLiquidity{ value: 1 ether }(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function buy(uint96 rawAmount) external {
        uint256 amount = bound(uint256(rawAmount), 1_000_000, 1e12);
        try swapRouter.swap{ value: amount }(
            key,
            SwapParams({ zeroForOne: true, amountSpecified: -int256(amount), sqrtPriceLimitX96: MIN_PRICE_LIMIT }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ZERO_BYTES
        ) { }
            catch { }
    }

    function sell(uint96 rawAmount) external {
        uint256 balance = box.balanceOf(address(this));
        if (balance < 1_000_000) return;
        uint256 amount = bound(uint256(rawAmount), 1_000_000, balance);
        try swapRouter.swap(
            key,
            SwapParams({ zeroForOne: false, amountSpecified: -int256(amount), sqrtPriceLimitX96: MAX_PRICE_LIMIT }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ZERO_BYTES
        ) { }
            catch { }
    }

    function openBoxes(uint8 rawCount) external {
        uint256 available = box.balanceOf(address(this)) / 1 ether;
        if (available == 0) return;
        uint256 count = bound(uint256(rawCount), 1, available);
        try box.open(count) { } catch { }
    }

    function claim(uint96 rawAmount) external {
        uint256 available = liabilityAmount();
        if (available == 0) return;
        uint256 amount = bound(uint256(rawAmount), 1, available);
        vm.prank(PROGRAMMABLE_OWNER);
        try hook.claimProgrammableFee(amount, PROGRAMMABLE_OWNER) { } catch { }
    }

    function liabilityAmount() public view returns (uint256) {
        return hook.liability(poolId, CurrencyLibrary.ADDRESS_ZERO, PROGRAMMABLE_OWNER);
    }

    function backingAmount() public view returns (uint256) {
        return manager.balanceOf(address(hook), 0);
    }

    function remainderAmount() public view returns (uint256) {
        return hook.feeRemainder(poolId, CurrencyLibrary.ADDRESS_ZERO, PROGRAMMABLE_OWNER);
    }

    function boxBalance() public view returns (uint256) {
        return box.balanceOf(address(this));
    }

    function totalSupplyAmount() public view returns (uint256) {
        return box.totalSupply();
    }

    function openedCount() public view returns (uint256) {
        return box.openedCount();
    }
}
