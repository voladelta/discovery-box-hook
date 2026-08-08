import { useReducer } from "react";
import { formatEther, zeroAddress } from "viem";
import {
  useAccount,
  useConnect,
  useDisconnect,
  useReadContracts,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";
import { FluidButton } from "./components/FluidButton";
import { JudgeMode } from "./JudgeMode";
import {
  deployment,
  discoveryBoxAbi,
  discoveryHookAbi,
  hasConfiguredDeployment,
} from "./contracts";
import {
  BUY_LP_FEE_PIPS,
  DEMO_BUY_WEI,
  deriveDemo,
  demoReducer,
  formatLpFee,
  initialDemoState,
  MATURITY_TARGET,
  PROGRAMMABLE_FEE_PIPS,
} from "./demo-model";

const wait = (milliseconds: number) =>
  new Promise<void>((resolve) => window.setTimeout(resolve, milliseconds));

const memberships = [
  { code: "A", name: "Atlas API", detail: "Premium requests", className: "pass-atlas" },
  { code: "F", name: "Fieldnotes", detail: "Research archive", className: "pass-fieldnotes" },
  { code: "R", name: "Rift", detail: "Season game pass", className: "pass-rift" },
];

function BrandMark() {
  return (
    <span className="brand-mark" aria-hidden="true">
      <span />
      <span />
      <span />
    </span>
  );
}

function ArrowIcon() {
  return (
    <svg aria-hidden="true" viewBox="0 0 20 20" width="18" height="18">
      <path d="M4 10h11M11 6l4 4-4 4" fill="none" stroke="currentColor" strokeWidth="1.7" />
    </svg>
  );
}

function WalletControl() {
  const { address, isConnected } = useAccount();
  const { connectors, connect, error, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const connector = connectors[0];

  if (isConnected && address) {
    return (
      <FluidButton variant="secondary" onClick={() => disconnect()} aria-label="Disconnect wallet">
        {`${address.slice(0, 5)}…${address.slice(-4)}`}
      </FluidButton>
    );
  }

  return (
    <div className="wallet-control">
      <FluidButton
        variant="secondary"
        onClick={() => connector && connect({ connector })}
        disabled={!connector}
        loading={isPending}
      >
        Connect wallet
      </FluidButton>
      {error ? <span className="wallet-error">Wallet connection was not completed.</span> : null}
    </div>
  );
}

function OnchainStatus() {
  const account = useAccount();
  const write = useWriteContract();
  const receipt = useWaitForTransactionReceipt({
    hash: write.data,
    query: { enabled: Boolean(write.data) },
  });
  const boxAddress = deployment.boxAddress ?? zeroAddress;
  const hookAddress = deployment.hookAddress ?? zeroAddress;

  const reads = useReadContracts({
    contracts: [
      { address: boxAddress, abi: discoveryBoxAbi, functionName: "openedCount" },
      { address: hookAddress, abi: discoveryHookAbi, functionName: "currentSellLpFee" },
    ],
    query: { enabled: hasConfiguredDeployment, refetchInterval: 12_000 },
  });

  const opened = reads.data?.[0]?.result;
  const sellFee = reads.data?.[1]?.result;
  const isLiveRead = typeof opened === "bigint" && typeof sellFee === "bigint";

  let label = "No deployment configured";
  let detail = "This page runs a labelled local simulation. It does not submit transactions.";
  let tone = "neutral";

  if (deployment.hadConfiguration && !hasConfiguredDeployment) {
    label = "Address configuration is incomplete";
    detail = "Set valid VITE_DISCOVERY_BOX_ADDRESS and VITE_DISCOVERY_HOOK_ADDRESS values.";
    tone = "warning";
  } else if (hasConfiguredDeployment && reads.isPending) {
    label = "Reading configured contracts";
    detail = "Ethereum mainnet read-only connection in progress.";
    tone = "active";
  } else if (hasConfiguredDeployment && reads.isError) {
    label = "Configured contracts could not be read";
    detail = "Check that both addresses are contracts on Ethereum mainnet.";
    tone = "warning";
  } else if (isLiveRead) {
    label = "Configured contract reads";
    detail = `${opened.toString()} opened · ${formatLpFee(Number(sellFee))} current sell LP fee`;
    tone = "active";
  }

  const canOpenOnchain = hasConfiguredDeployment && account.isConnected && account.chainId === 1;

  function openConfiguredBox() {
    if (!deployment.boxAddress || !canOpenOnchain) return;
    write.writeContract({
      address: deployment.boxAddress,
      abi: discoveryBoxAbi,
      functionName: "open",
      args: [1n],
    });
  }

  return (
    <div className="deployment-panel">
      <div className={`chain-status chain-status--${tone}`}>
        <span className="status-light" aria-hidden="true" />
        <div>
          <strong>{label}</strong>
          <span>{detail}</span>
        </div>
      </div>
      {hasConfiguredDeployment ? (
        <div className="onchain-action">
          <div>
            <strong>Open one $BOX onchain</strong>
            <span>
              {receipt.isSuccess
                ? "Transaction confirmed on Ethereum mainnet."
                : write.error
                  ? "The wallet rejected the transaction or the contract reverted."
                  : account.isConnected && account.chainId !== 1
                    ? "Switch the connected wallet to Ethereum mainnet."
                    : account.isConnected
                      ? "This submits open(1) to the configured DiscoBox contract."
                      : "Connect a wallet to enable this real transaction."}
            </span>
          </div>
          <FluidButton
            variant="secondary"
            disabled={!canOpenOnchain || receipt.isLoading || receipt.isSuccess}
            loading={write.isPending || receipt.isLoading}
            onClick={openConfiguredBox}
          >
            {receipt.isSuccess ? "Opened" : "Open onchain"}
          </FluidButton>
        </div>
      ) : null}
    </div>
  );
}

function MembershipPasses({ active }: { active: boolean }) {
  return (
    <div className={`passes ${active ? "passes--active" : ""}`} aria-label="Membership bundle">
      {memberships.map((membership) => (
        <article className={`membership-pass ${membership.className}`} key={membership.name}>
          <div className="pass-topline">
            <span className="pass-monogram" aria-hidden="true">{membership.code}</span>
            <span className="pass-state">{active ? "Active" : "Sealed"}</span>
          </div>
          <div>
            <h3>{membership.name}</h3>
            <p>{membership.detail}</p>
          </div>
          <span className="pass-duration">{active ? "30 days" : "Inside $BOX"}</span>
        </article>
      ))}
    </div>
  );
}

function BoxObject({ stage, pending }: { stage: string; pending: string | null }) {
  const opened = stage === "opened";
  return (
    <div className={`box-scene stage-${stage} ${pending ? `is-${pending}` : ""}`}>
      <div className="box-shadow" aria-hidden="true" />
      <div className="box-object" aria-hidden="true">
        <div className="box-lid">
          <div className="box-lid-face">
            <BrandMark />
            <span>DISCOBOX</span>
          </div>
        </div>
        <div className="box-base">
          <span className="box-label">$BOX / 001</span>
          <strong>30 days × 3</strong>
          <span className="box-caption">OPENABLE MEMBERSHIP ASSET</span>
        </div>
      </div>
      <MembershipPasses active={opened} />
    </div>
  );
}

export function App() {
  const [state, dispatch] = useReducer(demoReducer, initialDemoState);
  const demo = deriveDemo(state);
  const isBusy = state.pending !== null;
  const sellFee = formatLpFee(demo.sellLpFeePips);
  const liability = Number(formatEther(demo.programmableLiabilityWei)).toFixed(6);

  async function runPrimaryAction() {
    if (isBusy) return;

    if (state.stage === "ready") {
      dispatch({ type: "buy-started" });
      await wait(260);
      dispatch({ type: "buy-settled" });
      return;
    }

    if (state.stage === "owned") {
      dispatch({ type: "open-started" });
      await wait(280);
      dispatch({ type: "open-settled" });
    }
  }

  const actionCopy = state.pending === "buy"
    ? "Simulating pool swap"
    : state.pending === "open"
      ? "Opening $BOX"
      : state.stage === "ready"
        ? "Buy one $BOX · 0.018 ETH"
        : state.stage === "owned"
          ? "Open $BOX for memberships"
          : "Membership bundle active";

  const announcement = state.pending === "buy"
    ? "The local pool swap is being simulated."
    : state.pending === "open"
      ? "The local box opening is being simulated."
      : state.stage === "owned"
        ? "One simulated box was bought. It is ready to open."
        : state.stage === "opened"
          ? "The box was opened. Three memberships are active and the sell fee is lower."
          : "The simulation is ready.";

  return (
    <div className="app-shell">
      <header className="site-header">
        <a className="brand" href="#top" aria-label="DiscoBox home">
          <BrandMark />
          <span>DiscoBox</span>
        </a>
        <div className="header-actions">
          <span className="mode-badge">
            <span aria-hidden="true" />
            <span className="mode-label mode-label--long">Local simulation</span>
            <span className="mode-label mode-label--short">Local demo</span>
          </span>
          <WalletControl />
        </div>
      </header>

      <main id="top">
        <section className="hero" aria-labelledby="hero-heading">
          <div className="hero-copy">
            <p className="eyebrow">DiscoBox · $BOX · Uniswap v4</p>
            <h1 id="hero-heading">
              <span>Trade it unopened.</span>
              <span>Open it for utility.</span>
            </h1>
            <p className="hero-intro">
              Trade DiscoBox unopened, then burn one whole $BOX for 30 days across three memberships.
              Every opening permanently lowers the next sell LP fee.
            </p>

            <dl className="headline-metrics" aria-label="Current simulated market state">
              <div>
                <dt>Next sell LP fee</dt>
                <dd className={demo.hasOpened ? "value-changed" : ""}>{sellFee}</dd>
                <span>{demo.hasOpened ? "Down from 1.00%" : "Starts at 1.00%"}</span>
              </div>
              <div>
                <dt>Market maturity</dt>
                <dd>{demo.openedCount}<small> / {MATURITY_TARGET}</small></dd>
                <span>Irreversible openings</span>
              </div>
              <div>
                <dt>Buy LP fee</dt>
                <dd>{formatLpFee(BUY_LP_FEE_PIPS)}</dd>
                <span>Fixed by the hook</span>
              </div>
            </dl>

            <div className="thesis-note">
              <span className="note-rule" aria-hidden="true" />
              <p>Early flipping funds discovery. Opening matures the market.</p>
            </div>
          </div>

          <div className="ritual-panel">
            <div className="panel-meta">
              <div>
                <span className="step-count">Demo step {state.stage === "ready" ? "1" : state.stage === "owned" ? "2" : "3"} of 3</span>
                <strong>{state.stage === "ready" ? "Acquire the unopened asset" : state.stage === "owned" ? "Choose access over liquidity" : "Access is active"}</strong>
              </div>
              <span className="demo-price">1 $BOX</span>
            </div>

            <BoxObject stage={state.stage} pending={state.pending} />

            <div className="action-well">
              <FluidButton
                className="primary-action"
                onClick={runPrimaryAction}
                loading={isBusy}
                disabled={state.stage === "opened"}
              >
                <span>{actionCopy}</span>
                {!isBusy && state.stage !== "opened" ? <ArrowIcon /> : null}
              </FluidButton>
              <p className="action-note">
                {state.stage === "ready"
                  ? "Demo action only · no wallet signature"
                  : state.stage === "owned"
                    ? "Burns one whole $BOX in the contract design"
                    : "One expiry activates all three interface passes"}
              </p>
              {state.stage === "opened" ? (
                <button className="reset-link" type="button" onClick={() => dispatch({ type: "reset" })}>
                  Replay the demo
                </button>
              ) : null}
            </div>
            <p className="sr-only" aria-live="polite">{announcement}</p>
          </div>
        </section>

        <section className="instrumentation" aria-labelledby="instrumentation-heading">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Hook instrumentation</p>
              <h2 id="instrumentation-heading">One opening changes the next market rule.</h2>
            </div>
            <p>The UI mirrors immutable constants and view functions in the repository. Demo values are simulated locally.</p>
          </div>

          <div className="maturity-module">
            <div className="rail-labels">
              <span>Sell fee <strong>{sellFee}</strong></span>
              <span>Opened <strong>{demo.openedCount} of {MATURITY_TARGET}</strong></span>
            </div>
            <div className="maturity-rail" aria-label={`${demo.openedCount} of ${MATURITY_TARGET} boxes opened`}>
              <span className="rail-fill" style={{ transform: `scaleX(${Math.max(demo.maturityPercent / 100, 0.012)})` }} />
              <span className="rail-marker rail-marker--start"><i />0</span>
              <span className="rail-marker rail-marker--mid"><i />20</span>
              <span className="rail-marker rail-marker--end"><i />40</span>
              <span className="rail-current" style={{ left: `${demo.maturityPercent}%` }} />
            </div>
            <div className="fee-ends">
              <span>1.00% early sell fee</span>
              <span>0.30% mature sell fee</span>
            </div>
          </div>

          <dl className="state-ledger">
            <div>
              <dt>Total $BOX supply</dt>
              <dd>{demo.totalSupply}.00</dd>
              <span>{demo.hasOpened ? "−1.00 burned" : "Fixed initial supply: 100"}</span>
            </div>
            <div>
              <dt>Your unopened $BOX</dt>
              <dd>{demo.walletBoxes}.00</dd>
              <span>{demo.hasOpened ? "Consumed for access" : demo.hasBought ? "Ready to open" : "Buy from the pool"}</span>
            </div>
            <div>
              <dt>Bundle membership</dt>
              <dd className={demo.hasOpened ? "value-changed" : ""}>{demo.hasOpened ? "Active" : "Inactive"}</dd>
              <span>{demo.hasOpened ? "30 days remaining" : "One shared expiry"}</span>
            </div>
            <div>
              <dt>Programmable liability</dt>
              <dd>{liability} ETH</dd>
              <span>10 bps of {Number(formatEther(DEMO_BUY_WEI)).toFixed(3)} ETH gross volume</span>
            </div>
          </dl>

          <div className="flow-log" aria-label="Canonical demonstration sequence">
            {[
              ["Buy", demo.hasBought],
              ["Open", demo.hasOpened],
              ["3 memberships", demo.hasOpened],
              ["Lower sell fee", demo.hasOpened],
              ["10 bps liability", demo.hasBought],
            ].map(([label, done], index) => (
              <div className={done ? "flow-step flow-step--done" : "flow-step"} key={String(label)}>
                <span>{done ? "✓" : index + 1}</span>
                <strong>{label}</strong>
              </div>
            ))}
          </div>
        </section>

        <nav className="judge-walkthrough" aria-labelledby="judge-walkthrough-heading">
          <div>
            <p className="eyebrow">Presentation map</p>
            <h2 id="judge-walkthrough-heading">Judge walkthrough</h2>
          </div>
          <ol>
            {[
              ["proof-market-xray", "Proof 1", "Market X-ray"],
              ["proof-membership-gate", "Proof 2", "Membership gate"],
              ["proof-openable-applications", "Proof 3", "Openable applications"],
              ["proof-attack-laboratory", "Proof 4", "Attack laboratory"],
              ["proof-maturity-laboratory", "Proof 5", "Maturity laboratory"],
            ].map(([id, step, label]) => (
              <li key={id}>
                <a href={`#${id}`}>
                  <span>{step}</span>
                  <strong>{label}</strong>
                </a>
              </li>
            ))}
          </ol>
        </nav>

        <JudgeMode demo={demo} />

        <section className="connection-section" aria-labelledby="connection-heading">
          <div>
            <p className="eyebrow">Deployment boundary</p>
            <h2 id="connection-heading">Truthful by default.</h2>
          </div>
          <OnchainStatus />
        </section>
      </main>

      <footer>
        <a className="brand" href="#top"><BrandMark /><span>DiscoBox</span></a>
        <p>Local prototype · No deployment, audit or routing approval claimed.</p>
        <span>{formatLpFee(PROGRAMMABLE_FEE_PIPS)} Programmable fee on gross ETH volume</span>
      </footer>
    </div>
  );
}
