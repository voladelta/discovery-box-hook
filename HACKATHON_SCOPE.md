# Discovery Box hackathon scope

## Build the hook as the product

Discovery Box is a custom Uniswap v4 hook with one supporting token contract. A small website demonstrates the hook.

The submission must prove this mechanism:

> Buy or trade an unopened box. Open it to activate one fixed membership bundle. Each opened box permanently lowers the sell LP fee.

The hook is the core judged mechanism. The website is evidence that people can understand and use it.

The longer product direction remains in [Discovery Box product vision](PRODUCT_BRIEF.md). It does not define the hackathon acceptance criteria.

## Keep the repository focused

The repository will contain:

- one fixed-supply `DiscoveryBox` token contract
- one `DiscoveryHook` contract for the canonical `BOX/ETH` pool
- one generic openable-asset interface and abstract fixed-supply base
- 2 bounded reference applications for tickets and deterministic collectibles
- the smallest official launch and locked-position integration that Programmable requires
- focused unit, fuzz, invariant and pool integration tests
- one website for the 90-second demonstration
- the builder evidence and submission files

The project will not contain 3 separate apps, companion repositories or a reusable campaign platform.

The reference applications prove code reuse. They do not create extra canonical pools or expand the membership demonstration.

## Contract one is DiscoveryBox

`DiscoveryBox` is a fixed-supply ERC-20 token. Users can trade fractional tokens but can only open whole boxes.

It provides:

- a fixed initial supply with no later mint
- `open(boxCount)` to burn `boxCount * 1e18` token units
- `openedBoxes` as the total number of whole boxes burned
- one membership expiry for each wallet
- a fixed membership duration per opened box

Opening a box extends the wallet's bundle expiry by this rule:

```text
newExpiry = max(currentExpiry, block.timestamp) + boxCount * duration
```

All 3 membership cards in the demo read the same bundle expiry. We do not need a registry contract for each app.

The token has no:

- owner mint
- transfer tax
- pause, blacklist or confiscation control
- random reward
- upgrade path
- arbitrary burn function

The supply invariant is:

```text
totalSupply + openedBoxes * 1e18 == initialSupply
```

## Contract 2 is DiscoveryHook

`DiscoveryHook` serves one canonical native ETH and openable-asset PoolKey. The membership launch uses `BOX`.

It provides 2 independent fee mechanisms:

- a dynamic directional LP fee
- Programmable's mandatory hook-owned volume fee

The LP fee works as follows:

| Swap | LP fee |
| --- | ---: |
| buy `BOX` | 0.30% |
| sell `BOX` before any boxes open | 1.00% |
| sell `BOX` at or after the maturity target | 0.30% |

The sell fee falls linearly as `DiscoveryBox.openedBoxes()` rises:

```text
progress = min(openedBoxes, maturityTarget) / maturityTarget
sellLpFee = 1.00% - progress * 0.70%
```

The prototype uses an immutable target of 40 opened boxes from a supply of 100. The reduced-form model supports this choice. A changed target requires a new Builder preflight revision.

See [Economic model](ECONOMIC_MODEL.md) for the assumptions, results and limits.

The hook must:

- trust only the pinned PoolManager
- accept only its registered canonical PoolKey
- identify buys and sells from token flow, not currency address order
- set an explicit initial dynamic LP fee
- apply the correct per-swap LP fee override
- forbid hook-initiated same-pool swaps
- expose enough state and events to reconstruct fee changes

The hook reads only `IOpenableAsset.openedCount()`. It pins the asset's maturity target during construction. Application-specific outcome logic cannot change swap accounting.

## Implement the Programmable fee in the same hook

The canonical pool can use only one hook. `DiscoveryHook` must therefore integrate Programmable's fee policy itself.

The hook will charge exactly 10 basis points of executed gross ETH-side volume on every successful canonical-pool swap. The LP fee does not count towards this charge.

The implementation must cover:

- both swap directions
- exact-input and exact-output swaps
- executed-volume fees for unspecified-ETH partial fills and explicit rejection of specified-ETH partial fills
- the required before-swap and after-swap return-delta paths
- liabilities separated by pool, currency and owner
- owner-only claims to the immutable Programmable owner
- no rescue or project claim over Programmable's liability

We will use the released builder skill and its fee policy as the source of truth. We will not recreate the return-delta accounting from memory.

## Reuse the official launch path

We will not build a campaign factory, position manager or fee-split vault for the hackathon.

We will reuse the official launch components where they match this model. The launch will use one immutable campaign recipient for fees earned by the locked initial position.

The future product may split these fees among participating apps. That split is outside this submission.

## Build one demonstration website

The website is one page in the same repository. It is not a separate product build.

It must let a judge:

- connect a wallet
- see the current buy and sell LP fees
- buy one `BOX` from the canonical pool
- open one whole box
- see 3 fixed membership cards become active
- see the supply fall and `openedBoxes` rise
- see the next sell fee fall
- inspect the accrued Programmable fee liability

The 3 cards may represent a premium API, a research membership and a game pass. They all use the same onchain expiry.

A server-enforced premium route is a stretch feature. We will add it only after the contracts, required tests and basic website work.

## Show the mechanism in 90 seconds

The demonstration follows this sequence:

1. Show that the starting sell LP fee is 1.00% and the buy LP fee is 0.30%.
2. Buy one `BOX` through the canonical pool.
3. Open the box and show the 3 memberships become active.
4. Show that total supply fell and `openedBoxes` rose.
5. Show that the next sell uses a lower LP fee.
6. Show Programmable's 10-basis-point liability from the swap.
7. End with: 'Early flipping funds discovery. Opening matures the market.'

The cosmetic reveal can improve the demonstration. It must not delay contract or test work.

## Test what can lose the hackathon

The required tests focus on the hook and its supporting token.

### Token tests

Test:

- first, repeated, batched and final opening
- rejection when a holder has less than one whole box
- insufficient balance
- active and expired membership extension
- supply conservation under stateful fuzzing

### Dynamic LP fee tests

Test:

- exact canonical PoolKey and PoolManager checks
- one-time initialization
- both currency address orderings
- all 4 direction and exactness modes for each supported currency ordering
- starting, intermediate and mature sell fees
- bounded and monotonic fee changes
- correct dynamic-fee override flags

### Programmable fee tests

Use the builder policy's full mandatory evidence list. At minimum, test:

- selected totals below, equal to and above 10 basis points
- both directions and exact-input and exact-output swaps
- quadrant-dependent before and after return deltas
- supported unspecified-ETH partial fills, rejected specified-ETH partial fills and small-amount rounding
- immutable owner-only claims
- liability solvency and separation
- failed bypasses through routers, LP fees, donations and alternative pools

### Integration tests

Test one complete lifecycle:

```text
launch -> buy -> open -> membership active -> lower sell fee -> claim
```

Also test runtime and initialization code size.

## Defer everything else

Do not build these features before submission:

- reusable campaigns
- merchant onboarding
- 3 separate membership apps
- app-specific onchain registries
- a 3-way fee-split vault
- referrals, governance or rarity
- physical goods or shipping
- external price feeds or randomness
- an indexer or production monitoring system
- companion repositories
- deployment to multiple chains

## Use this order of work

1. Install and verify the protected `programmable-v4-hook-builder` release.
2. Generate the design card and confirm the exact hook capabilities.
3. Scaffold the smallest compatible project.
4. Implement `DiscoveryBox` and its invariant tests.
5. Implement `DiscoveryHook` with the dynamic LP fee.
6. Integrate Programmable's fee and complete its scenario matrix.
7. Run pool integration, fuzz, invariant and size tests.
8. Build the one-page website.
9. Record the demonstration and prepare the six-file application package.

## Definition of done

The hackathon build is complete when:

- the 2 project contracts compile from pinned dependencies
- the canonical pool runs the dynamic LP fee in all swap modes
- opening a box irreversibly changes the sell fee input
- the mandatory Programmable fee is exact, solvent and claimable only by its owner
- the required tests pass on the pinned toolchain
- the website demonstrates the complete user journey
- the public repository binds one clean pushed commit
- the builder produces a valid six-file application package

We do not need the full product vision to meet this definition.

## Current builder facts

Checked on 2 August 2026:

- new applications use builder release `v0.2.1`
- the complete project stays in our public repository
- the Programmable pull request contains only the bounded six-file application record
- a launch-ready canonical pool needs one fee-enforcing hook
- a custom hook must integrate the mandatory Programmable fee itself
- the builder says to implement the smallest coherent project

Use these primary sources:

- [Programmable Builder programme](https://github.com/0xprogrammable/programmable/blob/main/BUILDER_PROGRAM.md)
- [Programmable Builder agent guide](https://github.com/0xprogrammable/programmable/blob/main/docs/builder/AGENT_SKILL.md)
- [Programmable v4 Builder skill](https://github.com/0xprogrammable/programmable/blob/main/skills/programmable-v4-hook-builder/SKILL.md)
- [Mandatory Programmable fee policy](https://github.com/0xprogrammable/programmable/blob/main/skills/programmable-v4-hook-builder/references/programmable-fee-policy.md)
- [Programmable scenario matrix](https://github.com/0xprogrammable/programmable/blob/main/skills/programmable-v4-hook-builder/references/scenario-matrix.md)
