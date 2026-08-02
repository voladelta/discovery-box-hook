# Discovery Box product vision

## Document status

This document describes the product we may build after the hackathon. It is not the contract for the seven-day submission.

Use [Hackathon scope](HACKATHON_SCOPE.md) to decide what to design, build and test now. If the 2 documents conflict, the hackathon scope takes priority until submission.

Discovery Box is a general openable-asset mechanism. A fixed-supply ERC-20 represents an unopened asset; opening burns whole units, creates an application-specific outcome and advances public market-maturity state used by a Uniswap v4 hook.

The hackathon project proves that mechanism through one narrow launch: opening a fixed-value membership box changes the sell LP fee in its canonical pool. The source also includes tested ticket and deterministic collectible applications. The demo website will focus on membership so judges can understand and exercise the hook without navigating a marketplace. It does not implement the full product vision in this document.

## The proposal

Discovery Box is a reusable Uniswap v4 launch model for assets that can be traded unopened or burned to produce a defined outcome. Digital membership is the first application and the canonical hackathon submission.

Three apps commit a fixed amount of membership access to one campaign. A user can trade an unopened `BOX` or burn it. Burning one `BOX` activates the same membership bundle for every user.

The market charges a higher LP fee when a user sells an unopened box. This fee falls as more users activate their memberships. Fees from the permanently locked launch position go to the participating apps.

Every box has the same economic value. The reveal changes only its appearance.

The main message is:

> Early flipping funds the apps. Activation matures the market.

## The user need

Small apps often have spare service capacity but few new users. People may also avoid paying separately to try several unfamiliar apps.

Discovery Box combines these needs:

- users get one guaranteed bundle of digital memberships
- apps share one launch and receive fees from the initial liquidity position
- holders can trade an unopened bundle before they activate it
- activation creates a public and irreversible record

The contract proves that a wallet activated an entitlement. It does not prove that the person used an app.

## The market mechanism

`BOX` is a fixed-supply token. The launch puts the complete supply into a permanently locked, one-sided `BOX/ETH` position.

The pool uses different LP fees for buying and selling:

| Swap | LP fee |
| --- | ---: |
| buy `BOX` | 0.30% |
| sell `BOX` before any activations | 1.00% |
| sell `BOX` at the maturity target | 0.30% |

The sell fee falls with the number of activated boxes:

```text
progress = min(openedBoxes, maturityTarget) / maturityTarget
sellLpFee = 1.00% - progress * 0.70%
buyLpFee = 0.30%
```

The hook identifies a buy when the trader receives `BOX`. It identifies a sale when the trader sends `BOX`. This rule does not depend on currency address order.

The dynamic LP fee is separate from Programmable's fee. The hook charges Programmable 0.10% of executed gross ETH-side volume on every canonical-pool swap.

The project takes no hook-owned fee. The initial position still earns its share of LP fees.

## The maturity target

The hackathon prototype uses 100 whole boxes and an immutable maturity target of 40 opened boxes.

The reduced-form holder-choice model selects 40 as the largest target reached in about 70% of balanced simulated paths. A target of 30 usually matures too early. Targets of 50 and 60 miss in most paths. The fee curve itself creates little extra opening demand, so the target is a visible market milestone rather than a promise that the fee will make holders open.

Before a real deployment, we will rerun the model with the exact launch position. The target must still meet these conditions:

- users can reach it within the intended part of the launch curve
- unopened boxes remain available after the market matures
- each activation makes a visible but bounded change to the sell fee
- the result works with the chosen tick range, supply and Initial Buy

If that simulation does not reach 40 in about 70% of balanced paths, changing the target requires a new Builder preflight revision.

## The user journey

1. Three demo apps commit 30 membership-days per box.
2. The launch creates `BOX` and its canonical `BOX/ETH` pool.
3. The complete `BOX` supply enters a permanently locked one-sided position.
4. A user buys `BOX` through the canonical pool.
5. The user keeps, sells or opens the box.
6. Opening burns one whole `BOX` and activates all 3 memberships in one transaction.
7. Each demo app reads the membership registry before it provides premium access.
8. Later sales use the lower sell fee produced by the new activation count.

The reveal may show different colours or artwork. These differences provide no extra access, payout or tradeable right.

## The contract design

```text
CampaignFactory
  creates one campaign from fixed launch parameters
  registers the exact canonical PoolKey
  creates the permanent position and fee recipient

BoxToken
  uses a fixed supply
  allows only Redeemer to burn tokens
  has no tax, pause, freeze, blacklist or upgrade

MembershipRegistry
  stores expiry by wallet and app ID
  accepts updates only from Redeemer
  supports a fixed and bounded app list

Redeemer
  burns whole BOX units
  extends every membership in one transaction
  increments openedBoxes once for each burned BOX

DiscoveryHook
  accepts callbacks only from the fixed PoolManager
  accepts only the registered canonical PoolKey
  sets the initial dynamic fee after pool initialization
  applies the directional LP-fee override before each swap
  collects Programmable's required swap charge

LockedPositionFeeForwarder
  holds the initial position permanently
  allows anyone to collect LP fees
  sends collected assets only to AppFeeSplitVault

AppFeeSplitVault
  records 3 fixed app shares
  lets each app claim only its own allocation
  distributes both ETH and BOX without swapping either asset
```

Redemption stays outside the hook. Swap callbacks do not mint memberships or call an app.

## Pool initialization

The launch must complete these steps in one defined lifecycle:

1. The factory creates the fixed-supply token.
2. The factory creates the membership registry and redeemer.
3. The factory deploys the hook at an address with the required permission bits.
4. The factory registers one exact `PoolKey` with the hook.
5. `afterInitialize` accepts only the registered factory and pool configuration, validates the initial price and sets the initial dynamic LP fee once.
6. The launcher deposits the complete supply into the permanent one-sided position.
7. The launcher completes the Initial Buy, if the launch includes one.

The hook rejects a second initialization or a different pool configuration.

## Value flow

```text
Launch:
complete BOX supply -> permanent one-sided v4 position
position NFT -> LockedPositionFeeForwarder

Buy BOX:
user ETH -> pool
pool BOX -> user
0.30% LP fee -> liquidity positions in proportion to liquidity
0.10% hook-owned charge -> Programmable liability

Sell BOX:
user BOX -> pool
pool ETH -> user
1.00% to 0.30% LP fee -> liquidity positions in proportion to liquidity
0.10% hook-owned charge -> Programmable liability

Collect initial-position fees:
any caller -> collectFees
collected ETH and BOX -> AppFeeSplitVault
each app -> claims its fixed share

Open BOX:
user BOX -> permanent burn
MembershipRegistry -> extends all 3 memberships
openedBoxes -> increases by the number of BOX burned
```

Third-party liquidity providers keep the fees earned by their positions. They do not share them with the apps.

## Membership rules

One box adds 30 days to every membership in the campaign.

The registry calculates each new expiry as:

```text
newExpiry = max(currentExpiry, block.timestamp) + boxCount * duration
```

This rule gives every box the same access value. It also lets one wallet open more than one box.

The memberships are not transferable. They do not provide a cash claim or refund.

The prototype has no redemption deadline. This keeps the membership promise attached to every remaining box.

Our team will operate the 3 demo apps. A production campaign would need clear service terms and an availability commitment from each app.

## Fee recipients

The demo uses 3 immutable app shares that total 10,000 basis points:

| App | Share |
| --- | ---: |
| app one | 3,334 |
| app 2 | 3,333 |
| app 3 | 3,333 |

The first app receives the one-basis-point remainder. The campaign records this choice before launch.

The split vault follows these rules:

- no app can change the shares
- no app can claim another app's balance
- no administrator can replace a recipient
- anyone can ask the fee forwarder to collect LP fees
- collection does not remove liquidity
- the vault does not swap ETH or `BOX`

## Authority and trust

The campaign fixes all economic parameters before launch.

The contracts have no:

- upgrade proxy
- liquidity withdrawal path for the initial position
- arbitrary token rescue
- random economic reward
- price oracle
- keeper dependency
- bridge
- wallet allowlist
- user scoring
- governance process

The hook trusts only the pinned Uniswap v4 PoolManager. It does not infer the end user from the callback sender.

The companion apps trust the exact membership registry. They refuse premium access when they cannot confirm the registry state.

An app can still stop operating its service. The onchain registry cannot prevent this. The demo must state this limit.

## Core invariants

```text
Only Redeemer can burn BOX.

openedBoxes + BOX.totalSupply == initialBoxSupply
openedBoxes <= initialBoxSupply

open(n) either:
  burns exactly n whole BOX,
  extends every included membership by exactly n * duration,
  increments openedBoxes by exactly n,
or reverts without changing any of them.

buyLpFee == 0.30%
0.30% <= sellLpFee <= 1.00%
sellLpFee never increases as openedBoxes increases
maturityTarget cannot change after launch

app shares sum to 10,000 basis points
each app can claim only its recorded share
fee collection cannot reduce or transfer the initial position

Programmable liability == exactly 0.10% of executed gross ETH-side
canonical-pool volume, subject to the declared dust rule.

Aggregate liabilities never exceed assets held or redeemable by the hook.
```

## Required tests

### Redemption tests

Test the following cases:

- first, repeated, batched and final box activation
- expired and active membership extension
- whole-token units and fractional-token rejection
- insufficient balance or approval
- failure while updating one membership
- re-entry during redemption
- direct burn attempts from any address other than Redeemer
- the supply and activation-count invariant under stateful fuzzing

### Hook and fee tests

Test the following cases:

- correct permission bits and deployed hook address
- wrong PoolManager, PoolKey, registrar and initializer
- first initialization and blocked re-initialization
- stored initial fee and per-swap override flag
- fixed buy fee in both exact-input and exact-output modes
- bounded and monotonic sell fee in both exactness modes
- fee behaviour before, at and after the maturity target
- both token address orderings in isolated tests
- actual executed gross quote volume for unspecified-ETH partial fills and explicit rejection of specified-ETH partial fills
- repeated use of the hook within one router transaction
- same-pool self-calls are forbidden

### Programmable fee tests

Test the following cases:

- selected totals of zero, below 10 basis points and exactly 10 basis points
- the inclusive `3% = 0.10% Programmable + 2.90% project` example
- both swap directions and exact-input and exact-output modes
- gross ETH-side volume after partial fills
- dust and rounding at small amounts
- owner-only claims to the owner or its chosen destination
- pool, currency and owner liability separation
- alternative pools, routers, LP fees and token transfers cannot satisfy the fee

### Liquidity and split tests

Test the following cases:

- the complete initial supply enters the locked position
- the position cannot transfer or remove liquidity
- anyone can collect fees without changing liquidity
- collected ETH and `BOX` reach the split vault
- shares total 10,000 basis points under every rounding case
- each app receives only its entitlement
- a failed app recipient cannot take or block another app's claim
- no rescue or administrator path can redirect collected fees

### Integration tests

Test the following cases:

- one complete launch, buy, open, authenticated access and sell flow
- one premium API rejects a wallet before activation
- the same API accepts the wallet after activation
- a chain read failure denies premium access without changing membership state
- event replay reconstructs the launch, activation, fees and claims
- runtime and initialization code stay within size limits

## The demo

The demo should take no more than 90 seconds.

1. Show 3 demo apps and one premium API that denies access.
2. Show the permanent position, app split and current buy and sell fees.
3. Buy one `BOX` with ETH through the canonical v4 pool.
4. Open the box in one transaction and show the cosmetic reveal.
5. Call the premium API again and show the new access expiry.
6. Show the lower `BOX` supply and higher activation count.
7. Show that the next sell quote uses a lower LP fee.
8. Collect the locked position's fees and show each app's claim.
9. End with: 'Early flipping funds the apps. Activation matures the market.'

## What the activation count means

The count proves that wallets burned boxes and received membership entitlements.

It does not prove:

- unique people
- app usage
- customer retention
- service quality
- resistance to Sybil behaviour

We may display a first-time-wallet count for context. The hook must not use it to set fees.

## Why this needs Uniswap v4

The hook changes the LP fee for each swap. It uses the swap direction and the irreversible activation count.

The hook also enforces Programmable's fee inside the canonical pool. A router charge could be bypassed.

Without v4, the project would need a trusted router or a new pool to change these rules. The v4 hook keeps them with the pool.

## How the proposal meets the judging criteria

The proposal meets each criterion in a distinct way:

- originality comes from linking membership activation to a directional market fee
- usefulness comes from shared app distribution and fees paid to the participating apps
- security comes from equal utility, fixed authority and no randomness or oracle
- genuine v4 use comes from per-swap fee control and canonical-pool fee enforcement

## Features excluded from the prototype

The prototype will not include:

- random membership value or financially useful rarity
- cash prizes or sell-back promises
- physical goods or shipping
- encrypted coupon databases
- refundable deposits or principal guarantees
- transferable activated memberships
- service providers outside the team's 3 demo apps
- referral rewards
- voting or governance
- hook-owned liquidity
- custom swap curves
- asynchronous swaps
- external price or randomness services

## Decisions to complete before coding the final parameters

We must complete these decisions before we fix the deployment configuration:

1. Simulate the one-sided launch position and set the maturity target.
2. Set the exact `BOX` supply, tick range and Initial Buy.
3. Name the 3 demo apps and define each premium service.
4. Record the 3 app recipient addresses before deployment.
5. Define the dust rule for Programmable's fee and split-vault claims.

## Current project state

We checked this state on 2 August 2026:

- Programmable Builder intake reports `open`
- the protected builder release is `v0.2.1`
- the current public launch integration uses Ethereum Mainnet
- this workspace is not yet a Git repository
- Node.js and GitHub CLI are available
- Foundry is not installed

## Primary sources

Use these sources for implementation and review:

- [Programmable source repository](https://github.com/0xprogrammable/programmable)
- [Programmable Builder programme](https://github.com/0xprogrammable/programmable/blob/main/BUILDER_PROGRAM.md)
- [Programmable Builder skill guide](https://github.com/0xprogrammable/programmable/blob/main/docs/builder/AGENT_SKILL.md)
- [Programmable fee policy](https://github.com/0xprogrammable/programmable/blob/main/skills/programmable-v4-hook-builder/references/programmable-fee-policy.md)
- [Programmable scenario matrix](https://github.com/0xprogrammable/programmable/blob/main/skills/programmable-v4-hook-builder/references/scenario-matrix.md)
- [Programmable Classic model](https://programmable.family/docs/models/classic)
- [Programmable locked-position fee forwarder](https://github.com/0xprogrammable/programmable/blob/main/src/LockedPositionFeeForwarderFactoryV1.sol)
- [Uniswap v4 hook permissions](https://github.com/Uniswap/v4-core/blob/main/src/libraries/Hooks.sol)
- [Hookathon announcement](https://x.com/0xprogrammable/status/2083649493493244012)
- [StonkBrokers documentation](https://www.stonkbrokers.cash/docs)
- [Fake World Assets overview](https://www.fwa.fun/docs/overview)
