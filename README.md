# Discovery Box

Discovery Box is a Uniswap v4 hook prototype for the Programmable Builder programme.

Holders can trade unopened `BOX` tokens or burn one whole token to activate 30 days of membership. Each opening advances an irreversible market-maturity count. The canonical pool uses that count to lower the sell LP fee from 1.00% to 0.30% over the first 40 openings. Buys use a 0.30% LP fee.

The hook also collects Programmable's required 0.10% fee on executed gross native ETH volume. The project takes no hook-owned fee.

See the [Discovery Box pitch](PITCH.md) for the elevator pitch and hackathon PR description.

## Build and test

The project requires Foundry 1.7.1 or a compatible release.

On a clean clone, restore the pinned dependencies:

```sh
./script/bootstrap.sh
```

Then run:

```sh
forge fmt --check
forge build --sizes
forge test -vv
```

Run the economic model with Python 3.14 through `uv`:

```sh
uv run --python 3.14 analysis/economic_model.py --runs 20000
```

## Run the demonstration website

The one-page React demo uses Bun, Vite, wagmi and viem. Its interaction styling follows [Fluid Functionalism](https://www.fluidfunctionalism.com/docs). It starts in a clearly labelled local simulation because this repository does not contain deployed contract addresses.

The guided judge mode includes:

- a callback-by-callback market trace
- a membership gate that changes after opening
- a ticket proof that opens 3 admissions, consumes one through the gate and rejects an unauthorized consumer
- a deterministic collectible proof that assigns styles `1 → 2 → 3 → 1` and accounts for the resulting ERC-1155 balances
- an application frontier that labels NFT reveals, gacha and physical claims as unimplemented and names their missing boundaries
- four simulated attack cases linked to contract and test evidence
- an interactive maturity curve with the fixed-seed model results

```sh
bun install
bun run dev
```

Run the frontend checks with:

```sh
bun run test
bun run build
```

Optional Ethereum mainnet read and `open(1)` support can be enabled with valid deployed addresses. The simulated buy remains separate because the repository does not define a reviewed swap router.

```sh
cp .env.example .env.local
# Add both deployed addresses to .env.local, then run:
bun run dev
```

See [Discovery Box hackathon scope](HACKATHON_SCOPE.md) for the acceptance criteria and [Discovery Box evidence](builder/discovery-box/EVIDENCE.md) for the current verification state.

## Contracts

- `IOpenableAsset` is the stable opening-count boundary used by the hook
- `OpenableERC20` burns whole ERC-20 boxes and calls a compile-time application outcome
- `DiscoveryBox` is the canonical membership application
- `TicketBox` is a reference admission application
- `CollectibleBox` is a deterministic ERC-1155 reference application
- `DiscoveryHook` binds one native ETH and openable-asset PoolKey, applies directional LP fees and accounts for Programmable's fee in all 4 swap modes

The canonical contracts are not upgradeable. There is no owner mint, pause, blacklist, rescue or mutable fee parameter.

See the [openable asset architecture](OPENABLE_ARCHITECTURE.md) for the reusable boundary and its limits.

## Status

This is a local prototype. It does not claim deployment, audit, routing approval, Programmable acceptance or product availability.
