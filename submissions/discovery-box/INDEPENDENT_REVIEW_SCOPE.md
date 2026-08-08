# Independent accounting and security review scope

This is a review request, not a completed review, audit, approval, deployment authorization or security guarantee.

The reviewer must be independent of the Discovery Box author and must publish an attributable record for one exact public source commit. A branch name, moving tag, applicant-authored disposition or local success claim is not an independent record.

## Immutable subject

The record must identify:

- the full `voladelta/discovery-box-hook` commit and Git tree object reviewed
- the exact GitHub reviewer identity and review date
- the GitHub Actions run used for independent reproduction
- `submissions/discovery-box/review-build-manifest.json` and its SHA-256 digest
- the source-closure, normalized compiler-input, resolved-settings, normalized build-info, compiler-output and deployable-artifact-set digests from that manifest
- the raw host-specific build-info filename, SHA-256 digest and artifact-witness digest from the independent run
- the exact Foundry, Solidity and Slither versions used by the reviewer

The repository workflow `Independent accounting and security review witness` runs on a source pull request and can also accept the full source commit as a manual input after the workflow is present on the default branch. It checks out the exact pull-request head or dispatched commit, rebuilds the project, verifies the committed build manifest, preserves the raw build-info and deployable artifact JSON, runs the complete Foundry suite and dedicated stateful invariants, executes the pinned Mainnet PoolManager fork witness, and records Slither's non-clean output. Foundry embeds the absolute checkout root in three compiler-input path fields and derives its local build-info ID from that input. Manifest V2 normalizes only those repository-root paths; it remains exact over every source byte, resolved compiler setting, compiler output, ABI and bytecode. A successful run proves reproduction only; it does not supply the required semantic review.

## Minimum semantic coverage

The independent record must expressly cover:

1. All four native-ETH swap quadrants, including specified and unspecified ETH, exact input and exact output, return-delta signs, zero execution and partial-fill behavior.
2. Lifetime fee remainders, the 1,000-unit strict minimum gross quote, claim timing independence, owner-only partial and full claims, and atomic rollback on failed claims.
3. ERC-6909 backing for every liability, PoolManager delta closure, no cross-pool netting and first-buy liveness when the PoolManager starts without native ETH reserves.
4. Exact PoolManager callback authentication, canonical PoolKey binding, the `0x10cc` permission mask and disabled callback surface.
5. The caller-bound `DiscoveryBoxFactory` and `DiscoveryHookFactory` chain, HookMiner salt validation, atomic registration and initialization, and rollback of every failed launch phase.
6. Permanent custody of the initial LP position, the absence of a principal-removal path, immutable per-launch LP-fee custody and the permitted fee exit path.
7. The complete Solidity dependency closure, Solidity 0.8.26 Cancun settings with 20,000 optimizer runs and no CBOR metadata, the emitted build-info, and all three release targets plus both internal child artifacts.

## Required finding disposition

For every material finding, the record must give severity, affected path and line or symbol, impact, reproduction or reasoning, and one of:

- fixed in a named later commit and re-reviewed
- accepted as a documented residual risk by an identified decision owner
- false positive or not applicable, with objective technical reasoning

The review must retain and address the known Slither timestamp and reentrancy candidates. It must not describe the current Slither result as clean. A new executable source, test, dependency, compiler-setting, launch-specification or artifact-manifest commit is a new review target.
