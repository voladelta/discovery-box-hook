// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { CurrencySettler } from "@openzeppelin/uniswap-hooks/src/utils/CurrencySettler.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import { LPFeeLibrary } from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IUnlockCallback } from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import { BalanceDelta, BalanceDeltaLibrary } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { ModifyLiquidityParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { LiquidityAmounts } from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";

import { DiscoveryBox } from "./DiscoveryBox.sol";
import { DiscoveryBoxFactory } from "./DiscoveryBoxFactory.sol";
import { DiscoveryHook } from "./DiscoveryHook.sol";
import { DiscoveryHookFactory } from "./DiscoveryHookFactory.sol";

/// @title Discovery Launch Factory
/// @notice Atomically deploys BOX and its mined hook, binds and initializes the pool, and locks one-sided liquidity.
contract DiscoveryLaunchFactory is IUnlockCallback, ReentrancyGuardTransient {
    using BalanceDeltaLibrary for BalanceDelta;
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using PoolIdLibrary for PoolKey;

    uint160 public constant INITIAL_SQRT_PRICE_X96 = 79_228_162_514_264_337_593_543_950_336;
    int24 public constant INITIAL_TICK_LOWER = -600;
    int24 public constant INITIAL_TICK_UPPER = 0;
    int24 public constant TICK_SPACING = 60;
    address public constant PROGRAMMABLE_OWNER = 0x4957f49620AFf3Adbbe8195a4f633E49cc93376c;

    IPoolManager public immutable poolManager;
    DiscoveryBoxFactory public immutable boxFactory;
    DiscoveryHookFactory public immutable hookFactory;

    mapping(PoolId poolId => address recipient) public feeRecipient;

    enum UnlockAction {
        None,
        AddLiquidity,
        CollectFees
    }

    UnlockAction private unlockAction;
    bytes32 private unlockContextHash;

    error InvalidAddress();
    error InvalidLaunchCallback();
    error InvalidLiquidityDelta();
    error InvalidLaunchResult();
    error UnauthorizedFeeRecipient();

    event DiscoveryLaunchCreated(
        bytes32 indexed poolId,
        address indexed token,
        address indexed hook,
        address launcher,
        uint128 liquidity,
        uint256 lockedBoxAmount,
        uint256 boxRemainder
    );
    event LockedLiquidityFeesCollected(
        bytes32 indexed poolId, address indexed recipient, address indexed destination, uint256 amount0, uint256 amount1
    );

    constructor(IPoolManager manager_, DiscoveryBoxFactory boxFactory_, DiscoveryHookFactory hookFactory_) {
        if (
            address(manager_) == address(0) || address(boxFactory_) == address(0) || address(hookFactory_) == address(0)
        ) {
            revert InvalidAddress();
        }
        poolManager = manager_;
        boxFactory = boxFactory_;
        hookFactory = hookFactory_;
    }

    /// @notice Create the complete canonical pool lifecycle in one transaction.
    /// @dev Mine hookSalt against the BOX address derived from keccak256(msg.sender, boxSaltSeed).
    function launch(bytes32 boxSaltSeed, bytes32 hookSalt)
        external
        nonReentrant
        returns (DiscoveryBox box, DiscoveryHook hook)
    {
        bytes32 boxSalt = keccak256(abi.encode(msg.sender, boxSaltSeed));
        box = boxFactory.deploy(boxSalt, address(this));
        hook = hookFactory.deploy(hookSalt, poolManager, box, address(this));
        if (hook.programmableOwner() != PROGRAMMABLE_OWNER) revert InvalidLaunchResult();

        PoolKey memory key = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(address(box)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });
        hook.registerPool(key, INITIAL_SQRT_PRICE_X96);
        int24 initialTick = poolManager.initialize(key, INITIAL_SQRT_PRICE_X96);
        if (initialTick != INITIAL_TICK_UPPER) revert InvalidLaunchResult();
        feeRecipient[key.toId()] = msg.sender;

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtPriceAtTick(INITIAL_TICK_LOWER), INITIAL_SQRT_PRICE_X96, box.balanceOf(address(this))
        );
        bytes memory callbackData = abi.encode(key, liquidity);
        unlockAction = UnlockAction.AddLiquidity;
        unlockContextHash = keccak256(callbackData);
        bytes memory result = poolManager.unlock(callbackData);
        if (result.length != 32) revert InvalidLaunchResult();
        uint256 lockedBoxAmount = abi.decode(result, (uint256));

        uint256 boxRemainder = box.balanceOf(address(this));
        if (boxRemainder != 0 && !box.transfer(msg.sender, boxRemainder)) revert InvalidLaunchResult();

        emit DiscoveryLaunchCreated(
            PoolId.unwrap(key.toId()), address(box), address(hook), msg.sender, liquidity, lockedBoxAmount, boxRemainder
        );
    }

    /// @notice Collect only fees earned by the permanently locked initial position.
    function collectFees(PoolKey calldata key, address destination)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (destination == address(0)) revert InvalidAddress();
        PoolId poolId = key.toId();
        if (msg.sender != feeRecipient[poolId]) revert UnauthorizedFeeRecipient();

        bytes memory callbackData = abi.encode(key, destination);
        unlockAction = UnlockAction.CollectFees;
        unlockContextHash = keccak256(callbackData);
        bytes memory result = poolManager.unlock(callbackData);
        if (result.length != 64) revert InvalidLaunchResult();
        (amount0, amount1) = abi.decode(result, (uint256, uint256));

        emit LockedLiquidityFeesCollected(PoolId.unwrap(poolId), msg.sender, destination, amount0, amount1);
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        UnlockAction action = unlockAction;
        if (msg.sender != address(poolManager) || action == UnlockAction.None || keccak256(data) != unlockContextHash) {
            revert InvalidLaunchCallback();
        }

        unlockAction = UnlockAction.None;
        unlockContextHash = bytes32(0);

        return action == UnlockAction.AddLiquidity ? _addLiquidity(data) : _collectFees(data);
    }

    function _addLiquidity(bytes calldata data) private returns (bytes memory) {
        (PoolKey memory key, uint128 liquidity) = abi.decode(data, (PoolKey, uint128));
        (BalanceDelta delta, BalanceDelta feesAccrued) = poolManager.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: INITIAL_TICK_LOWER,
                tickUpper: INITIAL_TICK_UPPER,
                liquidityDelta: int256(uint256(liquidity)),
                salt: bytes32(0)
            }),
            bytes("")
        );
        if (delta.amount0() != 0 || delta.amount1() >= 0 || feesAccrued.amount0() != 0 || feesAccrued.amount1() != 0) {
            revert InvalidLiquidityDelta();
        }

        uint256 lockedBoxAmount = uint256(int256(-delta.amount1()));
        key.currency1.settle(poolManager, address(this), lockedBoxAmount, false);
        return abi.encode(lockedBoxAmount);
    }

    function _collectFees(bytes calldata data) private returns (bytes memory) {
        (PoolKey memory key, address destination) = abi.decode(data, (PoolKey, address));
        (BalanceDelta delta, BalanceDelta feesAccrued) = poolManager.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: INITIAL_TICK_LOWER, tickUpper: INITIAL_TICK_UPPER, liquidityDelta: 0, salt: bytes32(0)
            }),
            bytes("")
        );
        if (
            delta.amount0() < 0 || delta.amount1() < 0 || delta.amount0() != feesAccrued.amount0()
                || delta.amount1() != feesAccrued.amount1()
        ) revert InvalidLiquidityDelta();

        uint256 amount0 = uint256(int256(delta.amount0()));
        uint256 amount1 = uint256(int256(delta.amount1()));
        key.currency0.take(poolManager, destination, amount0, false);
        key.currency1.take(poolManager, destination, amount1, false);
        return abi.encode(amount0, amount1);
    }
}
