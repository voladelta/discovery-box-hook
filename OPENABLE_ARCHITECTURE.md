# Openable asset architecture

## Use one market boundary for many opening outcomes

Discovery Box separates 2 concerns:

- the v4 hook reads market maturity
- the openable asset defines what the holder receives after opening

The hook depends only on `IOpenableAsset.openedCount()` and one maturity target fixed during hook construction. It does not know about memberships, tickets, collectibles or application data.

This keeps the swap accounting unchanged when a new opening outcome is added.

## Keep opening logic in concrete assets

`OpenableERC20` provides the shared lifecycle:

1. The holder owns a transferable ERC-20 box.
2. The holder opens one or more whole boxes.
3. The contract burns the matching ERC-20 units.
4. The contract advances the irreversible opening count.
5. The concrete asset creates its application outcome.
6. Any failure reverts the burn, counter and outcome together.

Concrete assets extend this lifecycle at compile time. The system has no runtime plug-in registry, delegate call, upgrade or mutable module address.

## Canonical membership application

`DiscoveryBox` is the canonical hackathon asset. Each opened box adds 30 days to one membership bundle.

This remains the deployment and demonstration target. It provides the smallest complete proof of the market mechanism.

## Reference applications

The repository includes 2 additional implementations:

- `TicketBox` converts boxes into non-transferable admissions. One immutable gate can consume admissions after providing entry or another declared service
- `CollectibleBox` converts boxes into transferable ERC-1155 styles. Style assignment follows a public serial-number cycle and uses no randomness

These contracts prove that the same hook boundary supports different outcomes. They are not part of the canonical membership launch.

## Applications that need more work

The interface can support more outcomes, but the repository does not claim complete implementations for:

- random loot or NFT gacha, which needs verifiable randomness and legal review
- physical blind boxes, which need inventory and fulfilment
- financial certificates, which need issuer, transfer, redemption and legal controls
- third-party vouchers, which need a clear service and failure contract

Each new application must be reviewed as a new concrete asset. Reusing the interface does not transfer security evidence from one outcome to another.

## Protected invariants

Every `OpenableERC20` application must preserve:

```text
totalSupply + openedCount * 1e18 == initialSupply
openedCount never decreases
0 < maturityTarget <= initial whole-box supply
an outcome failure reverts the burn and counter
```

Every canonical hook deployment must preserve its existing PoolKey, fee, settlement, liability and claim invariants.
