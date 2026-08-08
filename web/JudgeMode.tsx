import { useReducer, type Dispatch } from "react";
import { formatEther } from "viem";
import { FluidButton } from "./components/FluidButton";
import { FluidSlider } from "./components/FluidSlider";
import {
  DEMO_BUY_WEI,
  MATURITY_TARGET,
  deriveDemo,
  formatLpFee,
  sellLpFeePips,
} from "./demo-model";
import {
  applicationFrontier,
  attackCases,
  collectibleAssignment,
  collectibleBalances,
  getAttackCase,
  initialJudgeState,
  judgeReducer,
  modelResults,
  ticketAdmissionBalance,
  xrayMaximumStep,
  type ApplicationKind,
  type JudgeAction,
  type JudgeState,
} from "./judge-model";

type DemoDerived = ReturnType<typeof deriveDemo>;

interface JudgeModeProps {
  demo: DemoDerived;
}

const applicationTabs: Array<{ id: ApplicationKind; label: string; status: string }> = [
  { id: "membership", label: "Membership", status: "Canonical" },
  { id: "ticket", label: "Ticket", status: "Reference" },
  { id: "collectible", label: "Collectible", status: "Reference" },
];

function TraceIcon({ kind }: { kind: "derived" | "simulated" }) {
  return <span className={`trace-icon trace-icon--${kind}`} aria-hidden="true" />;
}

function MarketXray({ demo, cursor, onCursorChange }: {
  demo: DemoDerived;
  cursor: number | null;
  onCursorChange: (cursor: number | null) => void;
}) {
  const maximumStep = xrayMaximumStep(demo.hasBought, demo.hasOpened);
  const visibleCursor = cursor ?? maximumStep;
  const liability = Number(formatEther(demo.programmableLiabilityWei)).toFixed(6);
  const steps = [
    {
      actor: "DiscoveryHook",
      action: "Read openedCount()",
      value: "0 openings → 1.0000% sell LP fee",
      kind: "derived" as const,
      note: "Fee formula and target are immutable contract values.",
    },
    {
      actor: "Demo trader",
      action: "Request exact-input buy",
      value: `${Number(formatEther(DEMO_BUY_WEI)).toFixed(3)} ETH gross input`,
      kind: "simulated" as const,
      note: "No reviewed buy router is configured for this path.",
    },
    {
      actor: "PoolManager + hook",
      action: "Execute swap callbacks",
      value: "beforeSwap → core swap → afterSwap",
      kind: "simulated" as const,
      note: "Sequence mirrors the tested Uniswap v4 callback path.",
    },
    {
      actor: "DiscoveryHook",
      action: "Accrue Programmable liability",
      value: `${liability} ETH · 10 bps of gross volume`,
      kind: "derived" as const,
      note: "Exact integer result from PROGRAMMABLE_FEE / FEE_DENOMINATOR.",
    },
    {
      actor: "DiscoveryBox",
      action: "Burn open(1)",
      value: "supply 100 → 99 · openedCount 0 → 1",
      kind: "simulated" as const,
      note: "The local reducer mirrors the atomic burn and counter update.",
    },
    {
      actor: "DiscoveryHook",
      action: "Price the next sell",
      value: `openedCount = 1 → ${formatLpFee(sellLpFeePips(1))} sell LP fee`,
      kind: "derived" as const,
      note: "10,000 − floor(1 × 7,000 / 40) = 9,825 fee pips.",
    },
  ];

  return (
    <section id="proof-market-xray" className="judge-section xray-section" aria-labelledby="xray-heading">
      <div className="judge-heading">
        <div>
          <p className="eyebrow">Proof 1 of 5 · Market X-ray</p>
          <h2 id="xray-heading">See the hook’s value path, callback by callback.</h2>
        </div>
        <div className="trace-legend" aria-label="Trace source legend">
          <span><TraceIcon kind="simulated" />Simulated action</span>
          <span><TraceIcon kind="derived" />Derived from contract constants</span>
        </div>
      </div>

      <div className="xray-workbench">
        <ol className="trace-list">
          {steps.map((step, index) => {
            const occurred = index <= maximumStep;
            const selected = index === visibleCursor;
            return (
              <li key={step.action} className={`${occurred ? "trace-step trace-step--occurred" : "trace-step"} ${selected ? "trace-step--selected" : ""}`}>
                <button type="button" onClick={() => occurred && onCursorChange(index)} disabled={!occurred} aria-current={selected ? "step" : undefined}>
                  <span className="trace-index">{String(index + 1).padStart(2, "0")}</span>
                  <span className="trace-main"><small>{step.actor}</small><strong>{step.action}</strong></span>
                  <span className="trace-value">{occurred ? step.value : "Waiting for the demo action"}</span>
                  <TraceIcon kind={step.kind} />
                </button>
                <p>{selected ? step.note : ""}</p>
              </li>
            );
          })}
        </ol>

        <div className="trace-console" aria-live="polite">
          <div className="console-topline">
            <span>LOCAL TRACE / {String(visibleCursor + 1).padStart(2, "0")}</span>
            <span>{cursor === null ? "Following demo" : "Replay paused"}</span>
          </div>
          <div className="console-reading">
            <span>{steps[visibleCursor].actor}</span>
            <strong>{steps[visibleCursor].action}</strong>
            <code>{steps[visibleCursor].value}</code>
            <p>{steps[visibleCursor].note}</p>
          </div>
          <div className="console-controls">
            <FluidButton variant="secondary" onClick={() => onCursorChange(0)}>Replay trace</FluidButton>
            <FluidButton
              variant="secondary"
              disabled={visibleCursor >= maximumStep}
              onClick={() => onCursorChange(Math.min(visibleCursor + 1, maximumStep))}
            >
              Next callback
            </FluidButton>
            {cursor !== null ? <button type="button" className="text-control" onClick={() => onCursorChange(null)}>Follow current state</button> : null}
          </div>
          <p className="console-disclaimer">This is a deterministic UI replay. No callback or transaction ran onchain.</p>
        </div>
      </div>
    </section>
  );
}

function MembershipGate({ active }: { active: boolean }) {
  return (
    <section id="proof-membership-gate" className="judge-section gate-section" aria-labelledby="gate-heading">
      <div className="gate-context">
        <p className="eyebrow">Proof 2 of 5 · Membership gate</p>
        <h2 id="gate-heading">Access should become useful the moment the box opens.</h2>
        <p>
          This local proof gates a research artifact with the demo’s membership state. It is not server authorization.
          A production service must verify the configured contract and wallet independently.
        </p>
        <div className={`gate-verdict ${active ? "gate-verdict--active" : ""}`} aria-live="polite">
          <span aria-hidden="true">{active ? "✓" : "×"}</span>
          <div>
            <strong>{active ? "Local membership check: active" : "Local membership check: denied"}</strong>
            <small>{active ? "Demo expiry: 30 days remaining" : "Open one whole $BOX to continue"}</small>
          </div>
        </div>
      </div>

      <article className={`premium-artifact ${active ? "premium-artifact--open" : "premium-artifact--locked"}`}>
        <div className="artifact-masthead">
          <span>FIELDNOTES / RESEARCH 004</span>
          <span>{active ? "MEMBER COPY" : "LOCKED"}</span>
        </div>
        {active ? (
          <div key="active" className="artifact-content">
            <p className="artifact-kicker">Market maturity note</p>
            <h3>Utility, not fee pressure, is the reason to open.</h3>
            <p>
              The fixed-seed model estimates that the fee curve adds only 0.02 openings on average.
              The mechanism reads better as a public maturity signal than as a redemption incentive.
            </p>
            <dl>
              <div><dt>Locked target</dt><dd>40 boxes</dd></div>
              <div><dt>Balanced paths matured</dt><dd>72.9%</dd></div>
              <div><dt>Sell LP fee at maturity</dt><dd>0.30%</dd></div>
            </dl>
            <p className="artifact-source">Local artifact · figures from ECONOMIC_MODEL.md</p>
          </div>
        ) : (
          <div key="locked" className="artifact-lock">
            <span className="keyhole" aria-hidden="true" />
            <strong>Membership required</strong>
            <p>The artifact stays hidden until this demo opens a $BOX.</p>
            <a href="#top">Open a $BOX above</a>
          </div>
        )}
      </article>
    </section>
  );
}

function ApplicationOutcome({ state, dispatch }: { state: JudgeState; dispatch: Dispatch<JudgeAction> }) {
  if (state.application === "ticket") {
    const admissionBalance = ticketAdmissionBalance(state.ticketStage);
    const hasAdmissions = state.ticketStage !== "sealed";
    return (
      <div className="application-outcome ticket-outcome">
        <div className="reference-demo">
          <div className="demo-status-line">
            <span>Local simulation</span>
            <strong className="demo-status-value" key={admissionBalance}>admissionBalance = {admissionBalance}</strong>
          </div>
          <div className="admission-stack" aria-label={`${admissionBalance} ticket admissions remaining`}>
            {[1, 2, 3].map((admission) => (
              <span
                className={!hasAdmissions ? "admission admission--sealed" : admission > admissionBalance ? "admission admission--consumed" : "admission"}
                key={admission}
              >
                <small>{admission > admissionBalance && hasAdmissions ? "USED" : "ADMISSION"}</small>
                <strong>0{admission}</strong><i />
              </span>
            ))}
          </div>
          <div className="reference-actions">
            {state.ticketStage === "sealed" ? (
              <FluidButton variant="secondary" onClick={() => dispatch({ type: "ticket-opened" })}>Open one ticket box</FluidButton>
            ) : state.ticketStage === "opened" ? (
              <FluidButton variant="secondary" onClick={() => dispatch({ type: "ticket-consumed" })}>Gate consumes one · 3 → 2</FluidButton>
            ) : (
              <FluidButton variant="secondary" onClick={() => dispatch({ type: "ticket-reset" })}>Reset ticket demo</FluidButton>
            )}
            <button type="button" className="proof-button" disabled={!hasAdmissions} onClick={() => dispatch({ type: "ticket-unauthorized-attempted" })}>
              Try unauthorized consumer
            </button>
          </div>
          {state.ticketUnauthorizedAttempted ? (
            <div className="ticket-revert" role="status">
              <strong>Expected revert · UnauthorizedGate</strong>
              <span>Balance stays {admissionBalance}. No chain call ran.</span>
            </div>
          ) : null}
        </div>
        <div className="outcome-copy">
          <span className="reference-label">Tested reference application</span>
          <h3>One box creates three non-transferable admissions.</h3>
          <p>Mirrors `TicketBox` and `test_ticketOpeningCreatesAndConsumesAdmissions` as a tested reference.</p>
          <code>admissionBalance[beneficiary] += boxCount × 3</code>
        </div>
      </div>
    );
  }

  if (state.application === "collectible") {
    return (
      <div className="application-outcome collectible-outcome">
        <div className="reference-demo">
          <div className="demo-status-line"><span>Local simulation</span><strong>{state.collectibleOpened ? "4 boxes opened" : "4 boxes sealed"}</strong></div>
          <div className={state.collectibleOpened ? "style-cycle style-cycle--assigned" : "style-cycle"} aria-label="Deterministic collectible style assignments">
            {collectibleAssignment.map((style, index) => (
              <span className={`style-tile style-tile--${style}`} key={`${style}-${index}`}>
                <small>Serial {index + 1}</small><strong>{state.collectibleOpened ? `Style ${style}` : "Sealed"}</strong>
              </span>
            ))}
          </div>
          <div className="reference-actions">
            <FluidButton variant="secondary" onClick={() => dispatch({ type: state.collectibleOpened ? "collectibles-reset" : "collectibles-opened" })}>
              {state.collectibleOpened ? "Reset assignment demo" : "Open four boxes"}
            </FluidButton>
          </div>
          {state.collectibleOpened ? (
            <dl className="collectible-balances" aria-label="Resulting ERC-1155 balances">
              {Object.entries(collectibleBalances).map(([style, balance]) => (
                <div key={style}><dt>Style {style}</dt><dd>{balance}</dd></div>
              ))}
            </dl>
          ) : null}
        </div>
        <div className="outcome-copy">
          <span className="reference-label">Tested reference application</span>
          <h3>Four opened boxes receive deterministic ERC-1155 styles.</h3>
          <p>There is no randomness. This mirrors `test_collectibleOpeningMintsDeterministicSeries`: assignments are 1 → 2 → 3 → 1 and balances are 2 / 1 / 1.</p>
          <code>style = (serial − 1) % styleCount + 1</code>
        </div>
      </div>
    );
  }

  return (
    <div className="application-outcome membership-outcome">
      <div className="membership-mini-bundle" aria-label="Three membership services sharing one expiry">
        <span><small>ATLAS API</small><strong>30d</strong></span>
        <span><small>FIELDNOTES</small><strong>30d</strong></span>
        <span><small>RIFT PASS</small><strong>30d</strong></span>
      </div>
      <div className="outcome-copy">
        <span className="canonical-label">Canonical hackathon application</span>
        <h3>One box extends one wallet expiry by 30 days.</h3>
        <p>All three interface passes read the same non-transferable membership expiry. They are not separate tokens.</p>
        <code>newExpiry = max(expiry, block.timestamp) + 30 days</code>
      </div>
    </div>
  );
}

function ApplicationSwitcher({ state, dispatch }: { state: JudgeState; dispatch: Dispatch<JudgeAction> }) {
  const application = state.application;
  return (
    <section id="proof-openable-applications" className="judge-section application-section" aria-labelledby="application-heading">
      <div className="judge-heading">
        <div>
          <p className="eyebrow">Proof 3 of 5 · Openable applications</p>
          <h2 id="application-heading">One narrow market boundary. Different declared outcomes.</h2>
        </div>
        <p className="judge-aside">
          Same hook code, separate immutable deployments. A deployed hook cannot switch its selected openable asset at runtime.
        </p>
      </div>

      <div className="boundary-ribbon" aria-label="IOpenableAsset market boundary">
        <strong>IOpenableAsset</strong>
        <span>openedCount()</span>
        <span>maturityTarget()</span>
        <span>open(count, data)</span>
        <i aria-hidden="true">→</i>
        <em>DiscoveryHook reads only the count and pinned target</em>
      </div>

      <div className="application-tabs" role="group" aria-label="Openable application">
        {applicationTabs.map((tab) => (
          <button
            type="button"
            aria-pressed={application === tab.id}
            className={application === tab.id ? "application-tab application-tab--active" : "application-tab"}
            onClick={() => dispatch({ type: "application-selected", application: tab.id })}
            key={tab.id}
          >
            <span>{tab.label}</span><small>{tab.status}</small>
          </button>
        ))}
      </div>
      <div id="application-panel" aria-live="polite">
        <ApplicationOutcome key={application} state={state} dispatch={dispatch} />
      </div>

      <div className="frontier" aria-labelledby="frontier-heading">
        <div className="frontier-intro">
          <span>Application frontier</span>
          <h3 id="frontier-heading">Possible extensions beyond membership, tickets, and deterministic collectibles.</h3>
          <p>Each would need its own security and operational boundary before becoming a real application.</p>
        </div>
        <div className="frontier-list">
          {applicationFrontier.map((item) => (
            <article key={item.module}>
              <div><strong>{item.module}</strong></div>
              <p>{item.possibility}</p>
              <small>{item.missingBoundary}</small>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

function AttackLaboratory({ selected, onSelect }: {
  selected: Parameters<typeof getAttackCase>[0];
  onSelect: (attack: Parameters<typeof getAttackCase>[0]) => void;
}) {
  const attack = getAttackCase(selected);
  return (
    <section id="proof-attack-laboratory" className="judge-section attack-section" aria-labelledby="attack-heading">
      <div className="judge-heading">
        <div>
          <p className="eyebrow">Proof 4 of 5 · Attack laboratory</p>
          <h2 id="attack-heading">Try the shortcuts the contracts refuse.</h2>
        </div>
        <p className="judge-aside">Every result below is a simulated expected revert mapped to an existing test. No chain call runs.</p>
      </div>

      <div className="attack-workbench">
        <div className="attack-list" role="group" aria-label="Simulated attack cases">
          {attackCases.map((item, index) => (
            <button
              type="button"
              className={item.id === selected ? "attack-button attack-button--selected" : "attack-button"}
              onClick={() => onSelect(item.id)}
              key={item.id}
            >
              <span>{String(index + 1).padStart(2, "0")}</span>
              <strong>{item.label}</strong>
              <small>Inspect expected revert</small>
            </button>
          ))}
        </div>

        <div className="revert-terminal" aria-live="polite">
          <div className="terminal-bar"><span>EXPECTED REVERT</span><span>NO CHAIN CALL</span></div>
          <div className="revert-result" key={attack.id}>
            <code>&gt; {attack.attempt}</code>
            <strong>{attack.expectedResult}</strong>
            <p>{attack.explanation}</p>
            <dl>
              <div><dt>Protected invariant</dt><dd>{attack.invariant}</dd></div>
              <div><dt>Contract source</dt><dd>{attack.source}</dd></div>
              <div><dt>Test evidence</dt><dd>{attack.test}</dd></div>
            </dl>
            <a href={`#${attack.invariantId}`}>Read the exact invariant ↓</a>
          </div>
        </div>
      </div>

      <div className="invariant-ledger" aria-label="Attack invariant references">
        {attackCases.map((item) => (
          <article id={item.invariantId} key={item.invariantId}>
            <span>{item.source}</span>
            <strong>{item.invariant}</strong>
            <p>{item.explanation}</p>
            <code>{item.test}</code>
          </article>
        ))}
      </div>
    </section>
  );
}

function MaturityLaboratory({ demo, openingsOverride, onOpeningsChange }: {
  demo: DemoDerived;
  openingsOverride: number | null;
  onOpeningsChange: (openings: number | null) => void;
}) {
  const openings = openingsOverride ?? demo.openedCount;
  const feePips = sellLpFeePips(openings);
  const markerX = 20 + (openings / 60) * 560;
  const markerY = 20 + ((10_000 - feePips) / 7_000) * 130;
  const maturity = Math.min(openings / MATURITY_TARGET, 1) * 100;

  return (
    <section id="proof-maturity-laboratory" className="judge-section maturity-lab" aria-labelledby="maturity-lab-heading">
      <div className="judge-heading">
        <div>
          <p className="eyebrow">Proof 5 of 5 · Maturity laboratory</p>
          <h2 id="maturity-lab-heading">Explore the curve without changing the contract.</h2>
        </div>
        <p className="judge-aside">The canonical target is immutably pinned to 40. This control changes only a local opening-count input.</p>
      </div>

      <div className="maturity-lab-layout">
        <div className="curve-lab">
          <div className="curve-readout">
            <span>Explored openings <strong>{openings}</strong></span>
            <span>Resulting sell LP fee <strong>{formatLpFee(feePips)}</strong></span>
            <span className="locked-target">Target 40 · locked</span>
          </div>
          <svg className="fee-chart" viewBox="0 0 600 188" role="img" aria-label={`At ${openings} openings, the sell LP fee is ${formatLpFee(feePips)}`}>
            <line x1="20" y1="20" x2="20" y2="150" className="chart-axis" />
            <line x1="20" y1="150" x2="580" y2="150" className="chart-axis" />
            <line x1="393.33" y1="16" x2="393.33" y2="154" className="chart-target" />
            <path d="M20 20 L393.33 150 L580 150" className="chart-curve" />
            <circle cx={markerX} cy={markerY} r="7" className="chart-marker" />
            <text x="20" y="174">0 openings</text>
            <text x="393.33" y="174" textAnchor="middle">40 target</text>
            <text x="580" y="174" textAnchor="end">60</text>
            <text x="28" y="15">1.00%</text>
            <text x="572" y="142" textAnchor="end">0.30%</text>
          </svg>
          <FluidSlider
            label="Opening count"
            min={0}
            max={60}
            step={1}
            value={openings}
            onChange={onOpeningsChange}
          />
          <div className="maturity-progress"><span style={{ transform: `scaleX(${maturity / 100})` }} /></div>
          <div className="curve-formula">
            <code>sellFee = 10,000 − min(opened, 40) × 7,000 / 40</code>
            {openingsOverride !== null ? <button type="button" onClick={() => onOpeningsChange(null)}>Follow demo count</button> : null}
          </div>
        </div>

        <div className="model-table">
          <div className="model-caption">
            <strong>Fixed-seed model results</strong>
            <span>20,000 balanced paths per target</span>
          </div>
          {modelResults.map((result) => (
            <div className={result.target === 40 ? "model-row model-row--locked" : "model-row"} key={result.target}>
              <span>Target {result.target}</span>
              <strong>{result.maturityProbability}%</strong>
              <small>{result.assessment}</small>
            </div>
          ))}
          <p>Model result, not forecast. One campaign experiences one path, not the average of thousands of launches.</p>
        </div>
      </div>
    </section>
  );
}

export function JudgeMode({ demo }: JudgeModeProps) {
  const [state, dispatch] = useReducer(judgeReducer, initialJudgeState);

  return (
    <div className="judge-mode">
      <MarketXray
        demo={demo}
        cursor={state.xrayCursor}
        onCursorChange={(cursor) => dispatch({ type: "xray-cursor-set", cursor })}
      />
      <MembershipGate active={demo.hasOpened} />
      <ApplicationSwitcher state={state} dispatch={dispatch} />
      <AttackLaboratory
        selected={state.selectedAttack}
        onSelect={(attack) => dispatch({ type: "attack-selected", attack })}
      />
      <MaturityLaboratory
        demo={demo}
        openingsOverride={state.maturityOpenings}
        onOpeningsChange={(openings) => dispatch({ type: "maturity-openings-set", openings })}
      />
    </div>
  );
}
