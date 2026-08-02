export const MATURITY_TARGET = 40;
export const INITIAL_SUPPLY = 100;
export const BUY_LP_FEE_PIPS = 3_000;
export const INITIAL_SELL_LP_FEE_PIPS = 10_000;
export const PROGRAMMABLE_FEE_PIPS = 1_000;
export const FEE_DENOMINATOR = 1_000_000;
export const DEMO_BUY_WEI = 18_000_000_000_000_000n;

export type DemoStage = "ready" | "owned" | "opened";
export type PendingAction = "buy" | "open" | null;

export interface DemoState {
  stage: DemoStage;
  pending: PendingAction;
}

export type DemoAction =
  | { type: "buy-started" }
  | { type: "buy-settled" }
  | { type: "open-started" }
  | { type: "open-settled" }
  | { type: "reset" };

export const initialDemoState: DemoState = { stage: "ready", pending: null };

export function demoReducer(state: DemoState, action: DemoAction): DemoState {
  switch (action.type) {
    case "buy-started":
      return state.stage === "ready" && state.pending === null
        ? { ...state, pending: "buy" }
        : state;
    case "buy-settled":
      return state.stage === "ready" && state.pending === "buy"
        ? { stage: "owned", pending: null }
        : state;
    case "open-started":
      return state.stage === "owned" && state.pending === null
        ? { ...state, pending: "open" }
        : state;
    case "open-settled":
      return state.stage === "owned" && state.pending === "open"
        ? { stage: "opened", pending: null }
        : state;
    case "reset":
      return initialDemoState;
  }
}

export function sellLpFeePips(openedCount: number): number {
  const capped = Math.min(Math.max(Math.trunc(openedCount), 0), MATURITY_TARGET);
  const range = INITIAL_SELL_LP_FEE_PIPS - BUY_LP_FEE_PIPS;
  return INITIAL_SELL_LP_FEE_PIPS - Math.floor((capped * range) / MATURITY_TARGET);
}

export function programmableFeeFromGrossWei(grossWei: bigint): bigint {
  return (grossWei * BigInt(PROGRAMMABLE_FEE_PIPS)) / BigInt(FEE_DENOMINATOR);
}

export function formatLpFee(pips: number): string {
  return `${(pips / 10_000).toFixed(2)}%`;
}

export function deriveDemo(state: DemoState) {
  const hasBought = state.stage !== "ready";
  const hasOpened = state.stage === "opened";
  const openedCount = hasOpened ? 1 : 0;

  return {
    hasBought,
    hasOpened,
    openedCount,
    walletBoxes: state.stage === "owned" ? 1 : 0,
    totalSupply: INITIAL_SUPPLY - openedCount,
    sellLpFeePips: sellLpFeePips(openedCount),
    programmableLiabilityWei: hasBought ? programmableFeeFromGrossWei(DEMO_BUY_WEI) : 0n,
    maturityPercent: (openedCount / MATURITY_TARGET) * 100,
  };
}
