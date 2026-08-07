# Discovery Box evidence

This ledger binds the applicant-owned evidence for one strict Programmable standard 1.5 source revision. It is not an audit, deployment receipt, routing approval, maintainer acceptance or availability claim.

## Review identity

| Item | Value |
| --- | --- |
| Solidity evidence-origin source commit | `b1a1734001355f670a42ac263b6dc81aa6fae19d` |
| Review-bundle evidence-origin commit | `dc784be9ab6a493fad7e2ef7326abd605ffb73e3` |
| Unchanged web/economic evidence origin | `46608fd0aec1baa217b20c13d3cb04365e981db2` |
| Previous reviewed source target | `3853ff76e7a07d347b858a413eda9a6894d1a267` |
| Source baseline before original repair | `2435073e4f950058d535438da4979f58fc95d0c9` |
| Standard | `1.5.0` only |
| Programmable fee policy | `programmable-volume-fee-v1` policy `1.1.0` |
| Builder source | seven-file admission branch commit `ae64016097784aae2ee70c0574765f427ebd54ad` |
| Builder result | structural preflight passed; closure `complete`; implementation remains `IN_PROGRESS`; design review required |
| Reproducible build manifest | `submissions/discovery-box/review-build-manifest.json`; applicant-generated review input, not an independent decision |
| Hook permission mask | `0x10cc` |
| Target chain | Ethereum mainnet, chain id 1 |
| PoolManager | `0x000000000004444c5dc75cB358380D2e3dE08A90` |
| PoolManager runtime hash | `0x785f1014552b7ce7d5fb7d0c970ca60edee94fd00425d7ca21609acac7ce1293` |
| Deployment | none claimed |
| Availability | not claimed |

The Solidity evidence-origin commit intentionally precedes the review-bundle and evidence-only packaging commits. It disables Foundry auto-remapping discovery but changes no Solidity, test, pinned dependency, launch specification or deployable bytecode. Every regenerated Solidity result below names or is hash-bound to that origin. The later review-bundle commit changes only the manifest generator, manifest and review-scope prose; its clean-build and source-cleanliness records are regenerated separately. The web and economic-model sources are byte-identical to their separately named evidence origin, so their existing records remain applicable. The final evidence commit changes only evidence records and hashes; it does not carry test results across a code change.

## Toolchain

- Foundry `1.7.1-Homebrew`, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`
- Solidity `0.8.26`, Cancun EVM, optimizer enabled with 20,000 runs, no CBOR metadata
- Node `24.18.0`
- Bun `1.3.14`
- uv `0.12.0`
- Slither `0.11.6`, executed through Python 3.13 with the package version pinned in the command
- Git `2.50.1 (Apple Git-155)`

The exact tool output and complete Foundry configuration are in `evidence/raw/tool-versions.txt` and are hash-bound by `evidence-index.json`.

## Completed applicant evidence

### Compatibility and source binding

The strict 1.5 compatibility check passed with no blocker diagnostics and complete repository closure. Its four warnings route return-delta accounting and the declared novel project/token behavior to human architecture review; they are not represented as acceptance. The recorded structured submission hash is `sha256:c092cff0cdd87414add8a8a2278048725e32bd4c220c2d5f9fba3c5c92de7799`.

The source-cleanliness record proves that the implementation, tests, Foundry configuration, dependency declaration, canonical source topology, launch graph, structured submission, review-build manifest, generator, scope and witness workflow matched review-bundle commit `dc784be9ab6a493fad7e2ef7326abd605ffb73e3`. The Solidity test, invariant, fork, gas and Slither records remain bound to compiler-configuration commit `b1a1734001355f670a42ac263b6dc81aa6fae19d`; the intervening diff changes no compiled input or test.

Foundry automatic remapping discovery is disabled. The resolved build now contains only the six repository-pinned remappings, so ignored local dependency directories cannot alter the compiler input or build-info relative to a clean checkout.

### Solidity format, build and size

`forge fmt --check` and `forge build --sizes` passed with no compiler warning. Relevant contract sizes were:

| Contract | Runtime bytes | Initcode bytes |
| --- | ---: | ---: |
| `DiscoveryHook` | 13,332 | 14,593 |
| `DiscoveryHookFactory` | 15,827 | 15,855 |
| `DiscoveryLaunchFactory` | 10,258 | 10,633 |

All recorded project contracts remain below the EVM runtime and initcode limits. The raw build table contains the complete result.

### Unit, integration, fuzz and invariant tests

The ordinary Foundry run completed with 55 passed, 0 failed and 1 intentionally skipped fork test. The fork test skips when the local chain id is not 1 and is executed separately against both fork fixtures below.

The suite covers:

- exact callback authentication, return selectors, mask `0x10cc`, canonical PoolKey admission and one-shot initialization
- atomic token, hook, pool and locked-liquidity launch; CREATE2 occupancy/front-running controls; LP-fee collection without principal removal
- all four direction and exactness quadrants, specified-native partial-fill rollback and actual-delta charging when native ETH is unspecified
- strict minimum gross quote in all four quadrants: zero execution is fee-free, positive gross 1 through 999 reverts before accounting, and 1,000 succeeds
- exact 10-basis-point cumulative platform fee with a lifetime remainder, zero project rate, claim timing independence and no cross-pool netting
- PoolManager ERC-6909 backing, owner-only partial/full claim, owner-selected destination, failed-destination rollback and first-buy liveness
- fixed whole-unit opening, membership expiry, ticket and deterministic collectible applications, malformed input and receiver re-entry

The dedicated invariant run passed five properties at 256 runs and depth 64, or 16,384 handler calls per property, with zero handler reverts. In that run, exact-output buy and sell handlers executed 2,804 and 2,662 calls respectively, so exact-output coverage is non-vacuous. The invariants cover liability backing, cumulative fee/remainder accounting, remainder bounds, supply conservation and accrual-minus-claims reconciliation.

### Fork evidence

Both fork runs deployed the local launch system against the real Mainnet PoolManager, verified its runtime code hash, mined the required hook permission address, executed the atomic launch, exercised all four swap quadrants, reconciled liability to ERC-6909 backing, and completed an owner claim.

| Run | Block | RPC class | Result |
| --- | ---: | --- | --- |
| Pinned regression | 23,000,000 | public unauthenticated archive RPC | 1 passed, 0 failed |
| Current-head snapshot | 25,706,470 | public unauthenticated current-head RPC | 1 passed, 0 failed |

These are simulations, not deployment transactions or live fee-collection evidence.

### Gas

The targeted local report recorded a maximum of 3,974,223 gas for `DiscoveryLaunchFactory.launch` across five cases and 114,120 gas for `collectFees` across two cases. These are local test measurements, not production transaction estimates.

### Web model

The pinned Bun run passed 11 model tests with 0 failures. `tsc -b && vite build` passed and produced the production bundle. The swap action remains explicitly a local simulation because no reviewed production router is supplied. The web evidence does not prove wallet-provider compatibility, routing, deployment or product availability.

### Reduced-form economic model

The fixed-seed 20,000-run model completed. At the declared 40-box target it reported a 72.9% reach probability, median 48 openings, a 30-to-67 10th-to-90th percentile range and 0.02 mean fee-induced openings. This is a threshold-choice stress model, not a forecast or v4 liquidity simulation.

## Slither result and disposition

Slither `0.11.6` analyzed 59 contracts with 102 detectors and exited `255` after reporting 5 findings. The run is classified as `completed-with-findings`, not scanner-clean.

| Raw detector result | Count | Disposition |
| --- | ---: | --- |
| `timestamp` in `DiscoveryBox` | 2 | Intentional expiry comparisons. Membership starts or extends from the later of current expiry and block time, and active membership requires expiry after block time. A few seconds of timestamp influence does not materially change a fixed 30-day duration. |
| `reentrancy-balance` in `DiscoveryLaunchFactory.launch` | 2 | The launch entry point uses `ReentrancyGuardTransient.nonReentrant`; the child factories authenticate the exact registrar; the PoolManager callback binds an active context hash; and the fixed BOX implementation has no transfer receiver callback. Launch, direct-child, front-running, invalid-salt and nested callback tests exercise these boundaries. |
| `reentrancy-benign` in `DiscoveryLaunchFactory.launch` | 1 | Same guarded atomic launch path. State written after the bound external calls cannot be reached through an unguarded recursive launch, and any failure reverts the complete launch. |

The raw result must remain attached to any review. The disposition does not replace an independent return-delta, custody or launch review.

## Independent review preparation

`submissions/discovery-box/review-build-manifest.json` binds the literal solc input for 126 source and dependency files, the resolved Solidity 0.8.26 compiler settings, the exact Foundry build-info digest, and five deployable artifacts: the three release factories and the two internal children. Its principal commitments are:

| Commitment | Digest |
| --- | --- |
| Normalized compiler input | `sha256:644081184b3a9c8d970a38ab501e902ba219f8f5a0be9d7b2d0536184d39f6bf` |
| Resolved compiler settings | `sha256:ae25513f52eeb903fdc15f1bb7dddec10f332988224e078a128f4848ddba9c1e` |
| Source and dependency closure | `sha256:32859e1c39a97c90ef1572603a92e7c51325ec5ba4bfdf6ba96d649d26faf932` |
| Normalized build-info | `sha256:4efd7d57b3d9f0b245c9358cfa67d49ea7717480b845a2f56ff81e31aa9688a9` |
| Compiler output | `sha256:89c582ffd7f4742d41a88a5f512dfe8384fa1a22cf324d7baea1e705d888d83d` |
| Deployable artifact set | `sha256:803cbde1dbc0780cc533aa2095925309faa5873ea2b93cb25e21d20a804f5f36` |

Foundry places the absolute checkout root in `basePath`, `allowPaths` and `includePaths`, and derives a host-specific local build-info ID. Manifest V2 normalizes only those path values. It remains exact over all source bytes, resolved settings, source IDs, compiler output, artifact JSON, ABIs and bytecodes. The workflow preserves the raw build-info from each run with its own SHA-256 witness.

The pinned GitHub Actions workflow reproduces the manifest, complete tests, dedicated invariants, pinned Mainnet fork witness and known non-clean Slither output from one exact pull-request head. `INDEPENDENT_REVIEW_SCOPE.md` states the minimum semantic coverage and finding-disposition contract.

These files prepare an immutable review target. They do not complete the gate. A reviewer independent of the applicant must still publish an attributable record for the exact final source commit and its successful reproduction run.

## Locked fee policy

- Canonical quote asset: native ETH as `currency0`.
- Selected and effective fee: 1,000 hundredths of a basis point, exactly 10 basis points.
- Platform allocation: 1,000 hundredths of a basis point to immutable owner `0x4957f49620AFf3Adbbe8195a4f633E49cc93376c`.
- Project allocation: exactly zero, exposed as constant `PROJECT_FEE`; the project stream is inert.
- Basis: executed gross native quote-side volume in all four swap quadrants.
- Minimum: zero execution is fee-free; every positive executed gross quote below 1,000 native base units reverts before remainder, liability or backing changes.
- Remainder: canonical-pool lifetime; claims do not reset it; fragmentation behavior is independent of prior claim timing.
- Liability: `(poolId, native currency, owner)` with no cross-pool netting.
- Backing: a PoolManager ERC-6909 native-currency claim held by the hook.
- Events: `ProgrammableFeeAccrued` and `ProgrammableFeeClaimed`.
- Same-pool hook-initiated swap: forbidden.

## Ownership boundary and remaining gates

Applicant-owned work completed in this revision: strict 1.5 manifest migration, policy 1.1 minimum/remainder semantics, local source/tests, pinned and current-head fork smoke, raw build/test/invariant/web evidence, pinned Slither output and technical disposition.

Independent-reviewer work before candidate status:

- reproduce the exact source commit and artifact manifest through the public witness workflow
- review all four return-delta quadrants, partial fills, lifetime remainder and claims, ERC-6909 backing, PoolManager authentication, mask `0x10cc`, atomic factory launch and permanent LP custody/fee exit
- publish an attributable record with every material finding fixed or objectively dispositioned

Platform or maintainer-owned work after applicant evidence and independent review:

- run the trusted-main validator against strict standard 1.5 and the required seven-file intake contract after resubmission
- generate the final seven-file central package from this evidence revision and bind every central digest to the same public source/package revision
- select and release the supported production router/adapter, then prove quote/execution parity for the supported paths
- implement and review registry, UI, API and indexer integration, including reorg, backfill, freshness and direct-read reconciliation
- authorize deployment, verify runtime/source/configuration, execute lifecycle checks, enable monitoring and make any availability decision
- verify the independent accounting and security record before any manual signature or later launch authority

No production router, indexer or deployment is supplied here. Those omissions are explicit ownership boundaries, not passing local gates.

## Artifact integrity

`submissions/discovery-box/evidence-index.json` contains the SHA-256 digest, exact command, tool version, result, scope and evidence-origin commit for this ledger and every raw artifact. Regenerate that index after any evidence edit. Any code, test, configuration, submission or evidence change creates a new package revision and requires the affected checks and hashes to be regenerated.
