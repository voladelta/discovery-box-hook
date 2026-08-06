# Discovery Box evidence

This ledger separates completed local checks from planned prototype, candidate and release work. It was regenerated for the repaired source revision. Reviewers should bind their review to the exact public `main` commit and the central package's source binding rather than rely on a self-referential hash embedded in that commit.

## Current identity

| Item | Value |
| --- | --- |
| Builder skill | `programmable-v4-builder-v0.2.1` |
| Builder skill commit | `0f2a2704` |
| Standard | 1.3.0 |
| Submission stage | proposal |
| Hook permission mask | `0x10cc` |
| Risk score | 18, high |
| Foundry | 1.7.1, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8` |
| Repository target | `main`; resolve the exact review target with `git rev-parse HEAD` |
| Deployment | none claimed |
| Maintainer review | changes requested on the prior revision; exact-revision re-review required |
| Availability | not claimed |

## Completed local checks

### Deterministic compatibility preflight

Status: passed on 6 August 2026

```text
node /Users/mbp/.codex/skills/programmable-v4-hook-builder/scripts/cli.mjs check \
  submissions/discovery-box/submission.json \
  --write-report submissions/discovery-box/compatibility-report.json \
  --repository-root /Users/mbp/Codehub/discovery-box
```

- Node: 24.18.0
- Decision: `PROTOTYPE_READY`
- Blockers: 0
- Warnings: 4
- Report version: 2
- Structured submission hash reported by checker: `sha256:64d53f0767e37e094a7529b328f64348a81fdc01c79dbaae7d29b19842e215cc`
- File SHA-256, `submission.json`: `40722054dbc515d37fbff1399ac5390bc1b32aa6e83dbd208a9f963727ff772a`
- File SHA-256, `launch.json`: `7946227c494dcbb297aed18e525e9bf3b69a4b622bd4d3eae23cb4e4f0a52d62`

The warnings require review of `beforeSwapReturnDelta`, the novel project category, the irreversible-redemption capability and the token behaviour. The checker does not prove the equations, source or deployment.

### Reduced-form economic model

Status: passed on 6 August 2026

```text
uv run --python 3.14 analysis/economic_model.py --runs 20000
```

- uv: 0.12.0
- Python: 3.14.4
- Fixed-seed paths: 20,000 per scenario
- Balanced 40-box maturity probability: 72.9%
- Median balanced openings: 48
- 10th to 90th percentile: 30 to 67
- Mean openings induced by the 1.00% to 0.30% sell-fee curve: 0.02
- Script SHA-256: `3b8651af46ab4543016a72edc048f1e28a5bcbfaded5d32dc657558994f4f0e6`

This is a threshold-choice stress model, not a demand forecast or exact v4 liquidity simulation.

### Solidity build and tests

Status: passed on 6 August 2026

```text
forge fmt --check
forge build --sizes
forge test -vv
forge test --gas-report --match-contract DiscoveryLaunchFactoryTest
```

- Solidity: 0.8.26
- EVM target: Cancun
- Build warnings: 0
- Test result: 55 passed, 0 failed, 0 skipped
- Stateful invariant result: 5 invariant properties passed at 256 runs and depth 64; 16,384 calls per property; 0 handler reverts
- Exact-output invariant calls: more than 2,600 handler calls in each direction in the final report; successful exact-output buys and sells are asserted nonzero and attempts equal successes plus caught inner reverts
- Fuzz runs: 1,000 for each of 3 fuzz properties
- `DiscoveryBox` runtime: 4,015 bytes; initcode: 5,392 bytes
- `DiscoveryBoxFactory` runtime: 5,818 bytes; initcode: 5,846 bytes
- `DiscoveryHook` runtime: 13,246 bytes; initcode: 14,507 bytes
- `DiscoveryHookFactory` runtime: 15,741 bytes; initcode: 15,769 bytes
- `DiscoveryLaunchFactory` runtime: 10,258 bytes; initcode: 10,633 bytes
- `DiscoveryLaunchFactory.launch` measured maximum: 3,956,865 gas in the targeted local report
- `DiscoveryLaunchFactory.collectFees` measured maximum: 114,120 gas in the targeted local report
- `TicketBox` runtime: 4,563 bytes; initcode: 6,045 bytes
- `CollectibleBox` runtime: 9,469 bytes; initcode: 11,031 bytes
- `IOpenableAsset.sol` SHA-256: `e4f2f5a93ba30259d6a334474630b7aa2613605927e4d143ad2f3a1f14cfa352`
- `OpenableERC20.sol` SHA-256: `0b34080e99e27060aa8e5008c8024ff190f76f91c024b7f4f480730b08e2477a`
- `DiscoveryBox.sol` SHA-256: `78d27b65215d410155ac6ca02b733bfb0ce649b12439f228b7ec7f280f611df6`
- `DiscoveryBoxFactory.sol` SHA-256: `dbd1a5b532cfd88eb6f3412738c44e852b1c0e305efa003dc788985e50a71b74`
- `DiscoveryHook.sol` SHA-256: `17b6febf869ea367df2008b1de18007843e43c81ae1702daaf19e95fea657ec3`
- `DiscoveryHookFactory.sol` SHA-256: `4050c131cd6dc55b447157d37ead2472c6b5f93cbdbdb6a9027f511c02f0f5d1`
- `DiscoveryLaunchFactory.sol` SHA-256: `abda631409b964bb185e6d6d2abc10d0f3cca378814c4e5bf9ef65a7b2ac0011`
- `TicketBox.sol` SHA-256: `4ee0567224fca1d7e71e7d064abcd8e33472f62a0b7ad4a349265128b945f099`
- `CollectibleBox.sol` SHA-256: `367d9d797fa6b25fe675fe18ca53678b9549bfae481993c4a4c859b237eb807b`
- `DiscoveryBox.t.sol` SHA-256: `8cc7be0de771f3a864a01175b6622dca9590cdbfb0fb513640a68fc159fd5b28`
- `DiscoveryHook.t.sol` SHA-256: `1ad1cb07de5fa627446b8d3ed1021c8ebbfe7f5ee5ab0a727d4d4b80ae53c1c4`
- `DiscoveryLaunchFactory.t.sol` SHA-256: `6fa2449570f7727491d42d6895c00821c29dbf0983b2dcae44a693d7c530ed9c`
- `DiscoveryHookInvariant.t.sol` SHA-256: `14cf7a1921a7594c02682d41364a480afa12c2eb31c1efe3e526bb36f3c62dba`
- `OpenableApplications.t.sol` SHA-256: `3b1ab926a772d197258d25e9cd55c2163707334fab70289966054e2787cae61f`

The tests use the real v4 PoolManager and test routers. They cover all 4 swap modes, the exact 999-wei then 1-wei zero-core regression, the dynamic LP-fee milestones, gross-up fuzzing, specified-ETH partial-fill rejection, exact-owner enforcement, split micro-swaps in both quote modes (including mixed modes), claim authorization and rollback, full-supply opening and the first buy from a BOX-only pool with a zero native ETH PoolManager balance. The stateful handler records exact-input and exact-output buys and sells, openings and partial claims while checking non-vacuous exact-output execution, liability backing, the sub-1,000,000 remainder bound, the exact cumulative-gross fee identity and supply conservation. The launch tests bind separate BOX and HookMiner factories, caller-bound BOX salts, registrar-only child deployment, copied-calldata front-running failure, constructor configuration, permission bits, atomic registration, initialization, one-sided locked liquidity, immutable LP-fee recipient collection without principal removal, invalid-salt rollback and callback authentication. The suite also proves that the same hook boundary accepts the ticket application and covers application-data validation, atomic rollback, ticket consumption, deterministic ERC-1155 outcomes and receiver re-entry rejection.

### Demonstration website

Status: passed local build, interaction and responsive checks on 2 August 2026

```text
bun install
bun run test
bun run build
```

- Bun: 1.3.14
- Frontend tests: 11 passed, 0 failed
- TypeScript build: passed
- Vite production build: passed
- Production CSS: 46.20 kB, 9.94 kB gzip
- Production JavaScript entry: 355.06 kB, 108.01 kB gzip
- State model: React reducer plus wagmi and TanStack Query; no `useEffect`
- Wallet boundary: Ethereum mainnet reads and `open(1)` are enabled only when both contract addresses are valid and a wallet is connected on chain 1
- Swap boundary: the buy action is explicitly labelled as a local simulation because no reviewed router is configured
- Browser checks: 1,440 by 1,000 desktop, 390 by 844 mobile and 320 by 700 narrow mobile
- Mobile trust boundary: the header keeps the `Local demo` label beside the wallet control at both checked mobile widths
- Judge walkthrough: 5 proof anchors are visible before judge mode, while the primary flow uses separate `Demo step 1 of 3` language
- Readability and access: evidence text is at least 12px, the proof eyebrow is 11px, no named visible control was below a 44px by 44px touch target and no checked viewport had horizontal document overflow
- Interaction check: buy, open, 3 active memberships, 1 of 40 openings, 0.98% displayed sell fee and 10-basis-point liability
- Judge-mode checks: callback trace progression, locked and active membership-gate states, all 4 expected-revert cases and the maturity slider at 40 openings and 0.30%
- Ticket proof: one local opening creates 3 admissions, the unauthorized consumer preserves 3, and the gate alone consumes one to leave 2
- Ticket consumption state: the consumed third admission remains visible, struck through and marked `USED`
- Collectible proof: 4 local openings deterministically assign styles 1, 2, 3, 1 and produce ERC-1155 balances 2, 1, 1
- Application frontier: NFT reveals, gacha or loot and physical claims are labelled possible and unimplemented, with their missing boundaries displayed
- Motion review: 5 state-change opportunities accepted, 5 decorative or data-motion candidates rejected, 4 blocking findings fixed and final decision `Approve`
- Browser console: 0 errors and 0 warnings during the checked flow
- `package.json` SHA-256: `e6724e012411be3086e156e07272a1cba57afc37cb4870b5d2a3d12a3524c8fb`
- `bun.lock` SHA-256: `a930c6aabaebf08af2d140ad0dd895f3a951811c6919db8ccba53236e982e4b3`
- `web/App.tsx` SHA-256: `ee2e87ebe9da9b7a526334fa821993f28c85991590e42010f8cb57ce649db4d9`
- `web/JudgeMode.tsx` SHA-256: `9bca6db318110fdf364cc9ca3aaf8f33691c50ac8927d85a68cf0b5d4f779e71`
- `web/styles.css` SHA-256: `fd4c4cd81b65bb9a67035aa39f8d23f10305950b5efd7c088a58be63ec7d80f4`
- `web/demo-model.ts` SHA-256: `2be64cacb6102027769d0c56cc77135b1f46b4ac8ba694320888c793ebd2d625`
- `web/demo-model.test.ts` SHA-256: `9387856b0cfc2b9d6123d742fbecdd5f68b9137dcf4f1ed4fe23d086c0c938cb`
- `web/judge-model.ts` SHA-256: `b943c958ed91f652a79422e805def6c421a06a5115ccfff0ea1470e6e01971a1`
- `web/judge-model.test.ts` SHA-256: `00c23d4c38cc29bfc23204f79b9aa57549c0eb0865686d406c5c3505903bda68`
- `analysis/ANIMATION_OPPORTUNITIES.md` SHA-256: `7d596252e21d464d52064ea82fd060c67581b24be947b77ccc8d6064f1ccdf8d`
- `analysis/ANIMATION_REVIEW.md` SHA-256: `a9caa74018962452fbc1e945b8269561c05ed1ba51f5234b671c1c064052dc22`

The visual checks confirmed the first-screen hierarchy, responsive reflow, mobile demo labelling, judge walkthrough, readable evidence text, 44px recovery controls, persistent used-ticket state, ticket and collectible state transitions, application-frontier boundaries, active membership reveal, application switching, attack-case switching, maturity exploration, disabled completed action, replay control, truthful no-deployment state and no horizontal document overflow. Reduced-motion CSS retains opacity feedback while removing movement. Reduced-transparency and increased-contrast media queries replace translucent surfaces and strengthen contrast. These rules were statically inspected, while the available browser surface used the system accessibility preferences. These checks do not prove wallet-provider compatibility, a live pool route or deployment. Reference-application and attack results are labelled simulations backed by the cited local Foundry tests; the browser did not execute them onchain.

### Static analysis

Status: completed with 5 accepted findings on 6 August 2026

```text
uvx --python 3.13 --from slither-analyzer slither . \
  --filter-paths 'lib|test' \
  --exclude-dependencies
```

- Slither: 0.11.6
- Contracts analysed: 59
- Detectors run: 102
- Findings: 2 timestamp comparisons in `DiscoveryBox`; 2 balance-read reentrancy heuristics and 1 benign-reentrancy heuristic in `DiscoveryLaunchFactory`

The timestamp comparisons are intentional: membership starts or extends from the later of the current expiry and block time, and active membership is defined by expiry after block time. Validator control over a few seconds does not create a material advantage against a fixed 30-day duration. The three launch findings are false-positive heuristics against a function protected by `ReentrancyGuardTransient.nonReentrant`: the external factories and BOX are exact bound implementations, both child factories authenticate the launch registrar, the PoolManager callback additionally requires the active context hash, and the fixed BOX transfer has no receiver callback. The launch tests cover front-running, direct child deployment, direct callback rejection, invalid-salt rollback and the complete nested PoolManager path. Slither reported no ignored return, uninitialised local or fee-accounting finding.

### Gross-up arithmetic identity

Status: passed on 2 August 2026

```text
uv run --python 3.14 python -c '<enumerate 10,000 boundary-adjacent and 200,000 random uint127 values>'
```

For `F=floor(N*1000/999000)` and `G=N+F`, all 210,000 cases satisfied `F=floor(G*1000/1000000)` and `F<G` for nonzero gross amounts. This checks the integer identity used by both exact-output gross-up paths. It does not replace Solidity fuzzing or signed-delta integration tests.

## Locked fee policy

- Canonical quote asset: native ETH, `currency0`.
- Selected and effective hook fee: 1,000 hundredths of a basis point.
- Programmable allocation: 1,000 hundredths of a basis point.
- Project allocation: zero.
- Basis: executed gross native ETH-side volume.
- Modes: both directions and both exactness modes.
- Paths: before swap when ETH is specified; after swap when ETH is unspecified.
- Owner and sole claim authority: `0x4957f49620AFf3Adbbe8195a4f633E49cc93376c`.
- Liability: `(poolId, native ETH, owner)` with no cross-pool netting.
- Accrual: claimable liability backed by a PoolManager ERC-6909 native-currency claim minted to the hook. The shared remainder is below 1,000,000 and satisfies `accruedFee * 1,000,000 + remainder = cumulativeGrossVolume * 1000` across gross and fee-on-top modes.
- Collection event: `ProgrammableFeeAccrued`.
- Claim event: `ProgrammableFeeClaimed`.
- Same-pool hook-initiated swap: forbidden.

The exact source and test paths are bound in `submission.json`. Dependencies are pinned in `DEPENDENCIES.md` and restored by `script/bootstrap.sh`.

## Planned prototype evidence

| Gate | State | Required evidence |
| --- | --- | --- |
| Compiler and dependency closure | passed locally | One committed dependency closure, pinned revisions, clean bootstrap no-op, compatibility closure `complete` and clean local build; compiler build information remains a maintainer evidence input |
| Permission address | partial | Local CREATE2 mining and all 14 flag checks pass; release salt, initcode hash and deployment remain |
| Unit tests | passed | Generic opening, membership, tickets, collectibles, initialization, fee curve, claims and failures |
| 4-quadrant fee tests | passed | Exact amounts, rounding, gross-up, final caller deltas and PoolManager execution |
| Fuzz tests | passed | 1,000 runs each for gross-up identity, fee monotonicity and supply conservation |
| Stateful invariants | passed locally | Five properties pass at 256 runs and depth 64 with exact-input/output swaps in both directions, non-vacuity counters, claims and opening sequences |
| Fork tests | planned | Exact deployment records, pinned block and current-head smoke |
| Static analysis | passed | Slither 0.11.6 produced 5 accepted findings: 2 intentional timestamp comparisons and 3 transient-guarded launcher reentrancy heuristics |
| Gas and code size | passed | All canonical and reference contracts are below runtime and initcode limits; targeted launch and fee-collection maxima are recorded above |
| Router parity | planned | Select and bind a reviewed production route, then prove quote and execution parity across all 4 modes; no swap client is supplied here |
| Demo app | planned | Real confirmed membership gate plus stale and wrong-chain states |
| Internal accounting review | passed | Return-delta signs, gross basis, first-buy liveness, ERC-6909 custody and claims reviewed against v4 core source |
| Independent accounting review | required | An external reviewer must repeat the accounting review before candidate status |
| Independent security review | required | At least one before candidate status and a second before high-risk release |

## Release gate ledger

| Decision | Owner | State | Blocker |
| --- | --- | --- | --- |
| Programmable maintainer acceptance | Programmable maintainers | not requested | Complete prototype and independent review |
| Platform UI, registry, indexer and test review | Programmable maintainers | not requested | Accepted model and bound integration paths |
| Deployment authorization | Builder and maintainers | not requested | Exact chain configuration and release evidence |
| Runtime and source verification | Independent verifier | not started | No deployment exists |
| Hooklist or routing support | Each external provider | not submitted | Provider-specific review and live canary |
| Product availability | Product owner | not claimed | Deployment, monitoring and all preceding decisions |

Local compatibility and simulation results do not complete any release row.
