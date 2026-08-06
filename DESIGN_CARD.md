# Discovery Box design card

## Outcome

Discovery Box is a market mechanism for openable assets. A holder can trade an asset unopened or burn whole units for its declared application outcome.

The canonical hackathon asset is a fixed 30-day membership bundle. Opening is irreversible. It burns one `BOX`, extends the holder's bundle expiry and increments the public opening count.

The hook depends only on the generic opening count. Ticket and deterministic collectible contracts demonstrate other outcomes without changing hook accounting.

## Pool

The launch creates one canonical Uniswap v4 `BOX/ETH` pool on Ethereum.

The pool uses a dynamic LP fee. Buying costs 0.30%. Selling starts at 1.00% and falls to 0.30% after 40 boxes open.

## Trade behaviour

The hook reads the irreversible opened-box count before each swap. It uses that count to set the directional LP fee.

The fee is a market-maturity signal. It is not presented as the main reason to open a box.

All 4 direction and exactness modes must work. When ETH is unspecified, the fee uses the executed amount. When ETH is specified, a partial core fill reverts because the hook cannot charge an unexecuted request.

## Value flow

Programmable receives exactly 10 basis points of executed gross ETH-side volume. This is the complete hook-owned charge. The project receives no hook-owned swap fee.

LP fees belong to liquidity providers. The raw initial position is permanently owned by `DiscoveryLaunchFactory`; its caller-bound launch derives a unique BOX salt, stores that caller as the immutable per-pool fee recipient and permits fee-only collection without principal removal. Direct child deployment is restricted to the launch factory, so copied or predeploying transactions cannot take that entitlement. Third-party positions retain their ordinary ownership and exits.

Opening burns `BOX`. It does not create a cash claim, refund or random reward.

## Fixed launch choices

The prototype uses:

- 100 whole boxes represented with 18 decimal places
- a 30-day membership duration per opened box
- a maturity target of 40 opened boxes
- a 0.30% buy LP fee
- a 1.00% to 0.30% sell LP fee
- no project hook-owned fee

We selected the 40-box target using the [economic model](ECONOMIC_MODEL.md). A changed target creates a new preflight revision.

## Authority

Nobody can mint more boxes, pause transfers, blacklist wallets, confiscate tokens, upgrade contracts or change the economics.

The hook accepts callbacks only from the pinned PoolManager and only for the registered canonical PoolKey.

Only Programmable's immutable owner can claim its liability. The owner can select the destination for each claim.

## Dependencies

The contracts depend on the pinned Uniswap v4 PoolManager and the bound BOX, HookMiner and atomic launch factories recorded in the launch specification.

The model uses no oracle, keeper, randomness, bridge, governance or user identity in hook callbacks.

When configured, the website reads the latest BOX opening count and hook sell fee directly from Ethereum mainnet and can submit `open(1)`. Its buy flow, membership cards and reference applications remain labelled local simulations. It supplies no router or indexer.

## Failure behaviour

An invalid pool, caller, settlement state or fee calculation reverts the complete action.

An alternative pool receives none of the canonical pool's behaviour by implication.

An app can stop providing its service. The onchain expiry proves entitlement, not service availability or use.

## Product surfaces

The canonical prototype deploys 3 reusable launch factories plus one BOX asset and one mined hook per launch, together with one demonstration website.

The source also contains a generic interface, an abstract fixed-supply base and 2 reference applications. These are not extra canonical launch assets.

The website shows the canonical pool, current fees, a buy, an opening, 3 membership cards and the resulting lower sell fee.

The project does not claim deployment, routing, listing, audit, approval or availability before there is separate evidence.

## Features not used

The prototype has no:

- random economic value
- token transfer tax
- project hook fee
- app-specific registry contracts
- a mutable runtime module registry
- app fee-split vault
- external merchant onboarding
- transferable activated membership
- oracle, keeper or indexer dependency
- custom swap curve or hook-owned liquidity position
- random or concealed onchain outcomes

## Decision record

On 2 August 2026, the builder delegated the remaining launch-parameter decision to the agent. The agent selected 100 boxes and a 40-box maturity target using the documented 20,000-path model and product-design judgement.
