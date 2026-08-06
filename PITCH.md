# Discovery Box pitch

## One sentence

Discovery Box is a Uniswap v4 mechanism where users trade assets unopened or consume them for utility, while openings update the market's maturity state.

## Elevator pitch

Discovery Box gives an asset 2 useful states: unopened and tradable, or opened and consumed for its promised utility.

Each opening creates a permanent public signal. A Uniswap v4 hook can use that signal to change how the market behaves as more people use the product.

Our first version applies the mechanism to memberships. A user can trade `BOX` unopened or burn one whole box for 30 days of access. Each of the first 40 openings lowers the pool's sell LP fee from 1.00% towards 0.30%.

The hook enforces the fee rule in all 4 swap modes and collects Programmable's fee. The membership prototype has a fixed supply, no random payout and no mutable admin controls.

The same mechanism could support blind-box collectibles, game items, NFT reveals, tickets, vouchers and regulated certificates. Each version can define what opening means without changing the core market pattern.

## 30-second version

Discovery Box is a Uniswap v4 mechanism for assets that are worth something different after opening. Users can trade the unopened asset or consume it for its promised utility.

The first prototype uses memberships. Users trade `BOX` or burn one whole box for 30 days of access. Each of the first 40 openings lowers the pool's sell fee from 1.00% towards 0.30%.

The hook enforces this rule inside PoolManager and collects Programmable's fee.

The pattern can later support collectibles, game items, NFT reveals, vouchers and other redeemable products.

## Judge summary

Discovery Box gives an openable asset 2 clear states:

- unopened and tradable
- opened and consumed for its declared use

The Uniswap v4 hook connects product use to market state. It reads an irreversible opening count before each swap. A launch can use that count to change fees or another declared market rule.

The first version uses a fixed membership bundle. Opening burns one `BOX` and activates 30 days of access. Buys use a 0.30% LP fee. Sells start at 1.00% and fall to 0.30% after 40 of the 100 boxes open.

The hook also collects exactly 0.10% of executed gross native ETH volume for Programmable. The project takes no hook-owned swap fee.

The reveal can look playful, but it does not change economic value. Every box provides the same access. This avoids paid randomness while keeping the anticipation of opening a box.

## Possible applications

The broader mechanism can support:

- membership and subscription bundles that become active when opened
- blind-box collectibles, including Labubu-style digital or physical releases
- game loot that becomes usable after opening
- NFT gacha and reveal mechanics
- tickets and vouchers that become redeemed or active
- product certificates that reveal or confirm a specific item
- regulated ownership certificates, including tokenized stock claims where the law allows them

The canonical launch and demo use fixed membership. The repository also includes tested ticket and deterministic collectible reference applications.

Some versions need extra controls. Random outcomes need verifiable randomness and legal review. Physical goods need fulfilment. Financial certificates need transfer restrictions and legal approval.

## Hackathon PR title

Add Discovery Box openable-asset market with membership prototype

## Hackathon PR description

### Summary

Discovery Box is a Uniswap v4 mechanism for openable assets. A holder can trade an asset unopened or consume it for its declared utility.

This PR implements the first use case: a fixed membership bundle. A holder can trade `BOX` or burn one whole box to activate 30 days of access.

Each opening permanently advances a public maturity count. The canonical Uniswap v4 pool reads this count and lowers its sell LP fee from 1.00% to 0.30% over the first 40 openings. Buys use a fixed 0.30% LP fee.

### Broader mechanism

The mechanism separates the market from the opened outcome:

- the unopened asset remains liquid and tradable
- opening consumes the asset or changes its state
- the opened outcome provides the promised utility
- the aggregate opening count can change a declared market rule

The hook depends only on a small `IOpenableAsset` boundary. Application outcomes are fixed in each asset contract at compile time. There is no mutable module registry, upgrade or `delegatecall` path.

Possible applications include memberships, blind-box collectibles, game items, NFT reveals, tickets, vouchers and certificates.

This PR does not implement random rewards, physical fulfilment or financial claims. Those versions would need separate contracts, tests and legal review.

### Why this needs Uniswap v4

The custom hook applies 2 atomic swap rules:

- a directional LP-fee override based on the irreversible opening count
- Programmable's 0.10% fee on executed gross native ETH volume

The hook covers exact-input and exact-output swaps in both directions. A token transfer tax or website fee could not apply the LP-fee rule inside PoolManager and would be easier to bypass.

### User outcome

A holder can:

- keep or trade an unopened box
- burn a whole box for 30 days of membership
- verify the membership expiry onchain
- see each of the first 40 openings reduce the next sell LP fee

Every box provides the same membership. Cosmetic reveals do not create different payouts, rights or economic value.

### Economic choices

The prototype fixes:

- 100 whole boxes
- a maturity target of 40 openings
- a 0.30% buy LP fee
- a sell LP fee that falls from 1.00% to 0.30%
- no project hook-owned swap fee

A fixed-seed model ran 20,000 paths per scenario. The 40-box target matured in 72.9% of balanced paths. A 30-box target matured too easily at 90.7%. A 50-box target matured in only 47.2%.

The model found that the fee curve creates only 0.02 extra openings on average. We therefore describe it as a market-maturity signal. Membership value remains the reason to open a box.

### Security boundary

The contracts have:

- a fixed token supply with no later mint
- one registered native ETH and `BOX` PoolKey
- a mined hook permission mask of `0x10cc`
- PoolManager-only callback authentication
- exact Programmable fee liabilities backed by ERC-6909 claims
- owner-only fee claims with re-entry protection
- no pause, blacklist, upgrade, rescue or mutable fee parameter

Specified-ETH swaps reject partial core fills. Unspecified-ETH swaps charge only the amount that executed. Failed swaps and claims revert without leaving a partial liability.

### Evidence

The local prototype currently has:

- 55 passing Foundry tests
- coverage of all 4 swap modes against the real v4 PoolManager
- 5 stateful invariants at 256 runs and depth 64, including non-vacuous exact-output coverage and the cumulative gross-volume fee identity
- caller-bound atomic launch and registrar-only CREATE2 child deployment regressions
- an end-to-end proof that ticket openings move the same hook fee curve through `IOpenableAsset`
- a passing first-buy test from a `BOX`-only pool with no starting native ETH
- a responsive Bun and Vite demo for the complete buy, open, membership and fee-change story
- wagmi and viem contract reads plus an optional configured `open(1)` write, with no deployment claim
- 3 fuzz properties with 1,000 runs each
- Slither analysis with 5 accepted findings: 2 intentional membership timestamp comparisons and 3 transient-guarded launch heuristics
- a `PROTOTYPE_READY` Builder result with 0 blockers

This PR does not claim deployment, audit, routing approval, acceptance or product availability.

### Review focus

Please focus review on:

- before-swap and after-swap return-delta signs
- gross-volume fee rounding in exact-output swaps
- ERC-6909 backing and claim redemption
- rejection of specified-ETH partial fills
- the link between irreversible openings and the directional LP fee
