// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BaseHook } from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";
import { CurrencySettler } from "@openzeppelin/uniswap-hooks/src/utils/CurrencySettler.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { FullMath } from "@uniswap/v4-core/src/libraries/FullMath.sol";
import { LPFeeLibrary } from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import { SafeCast } from "@uniswap/v4-core/src/libraries/SafeCast.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IUnlockCallback } from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import { BalanceDelta, BalanceDeltaLibrary } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { BeforeSwapDelta, toBeforeSwapDelta } from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";

import { IOpenableAsset } from "./openable/IOpenableAsset.sol";

/// @title Discovery Hook
/// @notice Applies a maturity-based directional LP fee and Programmable's mandatory ETH-volume fee.
contract DiscoveryHook is BaseHook, IUnlockCallback, ReentrancyGuardTransient {
    using BalanceDeltaLibrary for BalanceDelta;
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using PoolIdLibrary for PoolKey;
    using SafeCast for uint256;

    uint24 public constant BUY_LP_FEE = 3_000;
    uint24 public constant INITIAL_SELL_LP_FEE = 10_000;
    uint24 public constant SELL_LP_FEE_RANGE = INITIAL_SELL_LP_FEE - BUY_LP_FEE;
    uint24 public constant PROGRAMMABLE_FEE = 1_000;
    uint24 public constant FEE_DENOMINATOR = 1_000_000;
    uint24 public constant NET_DENOMINATOR = FEE_DENOMINATOR - PROGRAMMABLE_FEE;
    // Least common multiple of the gross and fee-on-top denominators.
    uint256 public constant FEE_REMAINDER_DENOMINATOR = 999_000_000;
    int24 public constant TICK_SPACING = 60;
    address public constant PROGRAMMABLE_OWNER = 0x4957f49620AFf3Adbbe8195a4f633E49cc93376c;

    IOpenableAsset public immutable openableAsset;
    uint256 public immutable maturityTarget;
    address public immutable registrar;
    address public immutable programmableOwner;

    PoolId public registeredPoolId;
    uint160 public expectedSqrtPriceX96;
    bool public poolRegistered;
    bool public poolInitialized;

    mapping(PoolId poolId => mapping(Currency currency => mapping(address beneficiary => uint256 amount))) public
        liability;
    mapping(PoolId poolId => mapping(Currency currency => mapping(address beneficiary => uint256 remainder))) public
        feeRemainder;

    struct PendingSpecifiedSwap {
        PoolId poolId;
        uint256 fee;
        bool active;
    }

    PendingSpecifiedSwap private pendingSpecifiedSwap;

    bool private claimInProgress;
    bytes32 private claimContextHash;

    error InvalidAddress();
    error InvalidMaturityTarget();
    error UnauthorizedRegistrar();
    error UnauthorizedProgrammableOwner();
    error PoolAlreadyRegistered();
    error PoolAlreadyInitialized();
    error PoolNotRegistered();
    error InvalidPoolKey();
    error InvalidInitializer();
    error InvalidInitialPrice();
    error PartialFillUnsupported();
    error InvalidClaimAmount();
    error InsolventLiability();
    error InvalidClaimCallback();
    error InvalidClaimResult();
    error InvalidPendingSwap();

    event DiscoveryPoolRegistered(bytes32 indexed poolId, uint160 expectedSqrtPriceX96);
    event DiscoveryPoolInitialized(
        bytes32 indexed poolId, address indexed token, address indexed hook, uint24 initialLpFee
    );
    event ProgrammableFeeAccrued(bytes32 indexed poolId, address indexed currency, uint256 grossQuote, uint256 fee);
    event ProgrammableFeeClaimed(
        bytes32 indexed poolId, address indexed currency, address indexed destination, uint256 amount
    );

    constructor(IPoolManager manager, IOpenableAsset openableAsset_, address registrar_, address programmableOwner_)
        BaseHook(manager)
    {
        if (address(openableAsset_) == address(0) || registrar_ == address(0)) {
            revert InvalidAddress();
        }
        if (programmableOwner_ != PROGRAMMABLE_OWNER) revert UnauthorizedProgrammableOwner();

        uint256 target = openableAsset_.maturityTarget();
        if (target == 0) revert InvalidMaturityTarget();

        openableAsset = openableAsset_;
        maturityTarget = target;
        registrar = registrar_;
        programmableOwner = PROGRAMMABLE_OWNER;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory permissions) {
        permissions.afterInitialize = true;
        permissions.beforeSwap = true;
        permissions.afterSwap = true;
        permissions.beforeSwapReturnDelta = true;
        permissions.afterSwapReturnDelta = true;
    }

    /// @notice Bind this hook to one exact pool before that pool is initialized.
    function registerPool(PoolKey calldata key, uint160 initialSqrtPriceX96) external {
        if (msg.sender != registrar) revert UnauthorizedRegistrar();
        if (poolRegistered) revert PoolAlreadyRegistered();
        if (
            !key.currency0.isAddressZero() || Currency.unwrap(key.currency1) != address(openableAsset)
                || key.fee != LPFeeLibrary.DYNAMIC_FEE_FLAG || key.tickSpacing != TICK_SPACING
                || address(key.hooks) != address(this) || initialSqrtPriceX96 == 0
        ) revert InvalidPoolKey();

        PoolId poolId = key.toId();
        registeredPoolId = poolId;
        expectedSqrtPriceX96 = initialSqrtPriceX96;
        poolRegistered = true;

        emit DiscoveryPoolRegistered(PoolId.unwrap(poolId), initialSqrtPriceX96);
    }

    function currentSellLpFee() public view returns (uint24) {
        uint256 opened = openableAsset.openedCount();
        uint256 capped = opened < maturityTarget ? opened : maturityTarget;
        // The immutable formula is bounded between 3,000 and 10,000, well inside uint24.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint24(uint256(INITIAL_SELL_LP_FEE) - capped * SELL_LP_FEE_RANGE / maturityTarget);
    }

    function lpFeeForSwap(bool zeroForOne) external view returns (uint24) {
        return zeroForOne ? BUY_LP_FEE : currentSellLpFee();
    }

    function programmableFeeFromGrossQuote(uint256 grossQuote) public pure returns (uint256) {
        return FullMath.mulDiv(grossQuote, PROGRAMMABLE_FEE, FEE_DENOMINATOR);
    }

    function programmableFeeOnTopOfNetQuote(uint256 netQuote) public pure returns (uint256) {
        return FullMath.mulDiv(netQuote, PROGRAMMABLE_FEE, NET_DENOMINATOR);
    }

    function claimProgrammableFee(uint256 amount, address destination) external nonReentrant {
        if (msg.sender != programmableOwner) revert UnauthorizedProgrammableOwner();
        if (destination == address(0)) revert InvalidAddress();

        PoolId poolId = registeredPoolId;
        Currency nativeCurrency = CurrencyLibrary.ADDRESS_ZERO;
        uint256 currentLiability = liability[poolId][nativeCurrency][programmableOwner];
        if (amount == 0 || amount > currentLiability) revert InvalidClaimAmount();
        if (poolManager.balanceOf(address(this), nativeCurrency.toId()) < amount) revert InsolventLiability();

        liability[poolId][nativeCurrency][programmableOwner] = currentLiability - amount;

        bytes memory data = abi.encode(poolId, destination, amount);
        claimInProgress = true;
        claimContextHash = keccak256(data);
        bytes memory result = poolManager.unlock(data);
        if (result.length != 0) revert InvalidClaimResult();

        emit ProgrammableFeeClaimed(PoolId.unwrap(poolId), Currency.unwrap(nativeCurrency), destination, amount);
    }

    function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory) {
        if (!claimInProgress || keccak256(data) != claimContextHash) revert InvalidClaimCallback();

        (PoolId poolId, address destination, uint256 amount) = abi.decode(data, (PoolId, address, uint256));
        if (PoolId.unwrap(poolId) != PoolId.unwrap(registeredPoolId)) revert InvalidClaimCallback();

        claimInProgress = false;
        claimContextHash = bytes32(0);

        Currency nativeCurrency = CurrencyLibrary.ADDRESS_ZERO;
        nativeCurrency.settle(poolManager, address(this), amount, true);
        nativeCurrency.take(poolManager, destination, amount, false);
        return bytes("");
    }

    function _afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24)
        internal
        override
        returns (bytes4)
    {
        _requireRegisteredPool(key);
        if (sender != registrar) revert InvalidInitializer();
        if (poolInitialized) revert PoolAlreadyInitialized();
        if (sqrtPriceX96 != expectedSqrtPriceX96) revert InvalidInitialPrice();

        poolInitialized = true;
        emit DiscoveryPoolInitialized(
            PoolId.unwrap(registeredPoolId), address(openableAsset), address(this), BUY_LP_FEE
        );
        poolManager.updateDynamicLPFee(key, BUY_LP_FEE);
        return IHooks.afterInitialize.selector;
    }

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        _requireInitializedPool(key);

        uint24 lpFee = params.zeroForOne ? BUY_LP_FEE : currentSellLpFee();
        int128 specifiedDelta = 0;

        if (_isEthSpecified(params)) {
            specifiedDelta = _prepareSpecifiedSwap(key, params).toInt128();
        }

        return
            (IHooks.beforeSwap.selector, toBeforeSwapDelta(specifiedDelta, 0), lpFee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        _requireInitializedPool(key);

        int128 coreEthDelta = delta.amount0();
        if (_isEthSpecified(params)) {
            if (!pendingSpecifiedSwap.active || PoolId.unwrap(pendingSpecifiedSwap.poolId) != PoolId.unwrap(key.toId()))
            {
                revert InvalidPendingSwap();
            }

            uint256 specifiedFee = pendingSpecifiedSwap.fee;
            pendingSpecifiedSwap.active = false;
            uint256 requested = _absoluteAmount(params.amountSpecified);
            int128 expectedCoreEthDelta = params.amountSpecified < 0
                ? -(requested - specifiedFee).toInt128()
                : (requested + specifiedFee).toInt128();
            if (coreEthDelta != expectedCoreEthDelta) revert PartialFillUnsupported();
            return (IHooks.afterSwap.selector, 0);
        }

        uint256 coreQuote = _absoluteAmount(coreEthDelta);
        uint256 remainderBefore = feeRemainder[registeredPoolId][CurrencyLibrary.ADDRESS_ZERO][programmableOwner];
        (uint256 fee, uint256 grossQuote, uint256 remainderAfter) = params.amountSpecified < 0
            ? _feeFromGrossQuote(coreQuote, remainderBefore)
            : _feeOnTopOfNetQuote(coreQuote, remainderBefore);
        _accrue(fee, grossQuote, remainderAfter);
        return (IHooks.afterSwap.selector, fee.toInt128());
    }

    function _requireRegisteredPool(PoolKey calldata key) private view {
        if (!poolRegistered) revert PoolNotRegistered();
        if (PoolId.unwrap(key.toId()) != PoolId.unwrap(registeredPoolId)) revert InvalidPoolKey();
    }

    function _prepareSpecifiedSwap(PoolKey calldata key, SwapParams calldata params) private returns (uint256 fee) {
        uint256 quote = _absoluteAmount(params.amountSpecified);
        uint256 remainderBefore = feeRemainder[registeredPoolId][CurrencyLibrary.ADDRESS_ZERO][programmableOwner];
        uint256 feeBasis;
        uint256 remainderAfter;
        if (params.amountSpecified < 0) {
            (fee, feeBasis, remainderAfter) = _feeFromGrossQuote(quote, remainderBefore);
        } else {
            (fee, feeBasis, remainderAfter) = _feeOnTopOfNetQuote(quote, remainderBefore);
        }
        _accrue(fee, feeBasis, remainderAfter);
        pendingSpecifiedSwap = PendingSpecifiedSwap({ poolId: key.toId(), fee: fee, active: true });
    }

    function _requireInitializedPool(PoolKey calldata key) private view {
        _requireRegisteredPool(key);
        if (!poolInitialized) revert PoolNotRegistered();
    }

    function _isEthSpecified(SwapParams calldata params) private pure returns (bool) {
        bool exactInput = params.amountSpecified < 0;
        return params.zeroForOne == exactInput;
    }

    function _accrue(uint256 fee, uint256 grossQuote, uint256 remainderAfter) private {
        feeRemainder[registeredPoolId][CurrencyLibrary.ADDRESS_ZERO][programmableOwner] = remainderAfter;
        if (fee == 0) return;

        Currency nativeCurrency = CurrencyLibrary.ADDRESS_ZERO;
        liability[registeredPoolId][nativeCurrency][programmableOwner] += fee;
        emit ProgrammableFeeAccrued(PoolId.unwrap(registeredPoolId), Currency.unwrap(nativeCurrency), grossQuote, fee);
        nativeCurrency.take(poolManager, address(this), fee, true);
    }

    function _feeFromGrossQuote(uint256 grossQuote, uint256 remainderBefore)
        private
        pure
        returns (uint256 fee, uint256 grossBasis, uint256 remainderAfter)
    {
        uint256 fraction = mulmod(grossQuote, PROGRAMMABLE_FEE, FEE_DENOMINATOR) * 999;
        uint256 combinedFraction = fraction + remainderBefore;
        fee = FullMath.mulDiv(grossQuote, PROGRAMMABLE_FEE, FEE_DENOMINATOR) + combinedFraction
            / FEE_REMAINDER_DENOMINATOR;
        remainderAfter = combinedFraction % FEE_REMAINDER_DENOMINATOR;
        grossBasis = grossQuote;
    }

    function _feeOnTopOfNetQuote(uint256 netQuote, uint256 remainderBefore)
        private
        pure
        returns (uint256 fee, uint256 grossBasis, uint256 remainderAfter)
    {
        uint256 fraction = mulmod(netQuote, PROGRAMMABLE_FEE, NET_DENOMINATOR) * 1_000;
        uint256 combinedFraction = fraction + remainderBefore;
        fee =
            FullMath.mulDiv(netQuote, PROGRAMMABLE_FEE, NET_DENOMINATOR) + combinedFraction / FEE_REMAINDER_DENOMINATOR;
        remainderAfter = combinedFraction % FEE_REMAINDER_DENOMINATOR;
        grossBasis = netQuote + fee;
    }

    function _absoluteAmount(int256 amount) private pure returns (uint256) {
        // PoolManager swap amounts are bounded signed values; either branch is non-negative after the sign operation.
        // forge-lint: disable-next-line(unsafe-typecast)
        return amount < 0 ? uint256(-amount) : uint256(amount);
    }
}
