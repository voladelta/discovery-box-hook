export type ApplicationKind = "membership" | "ticket" | "collectible";
export type AttackKind = "fractional-open" | "wrong-pool-key" | "unauthorized-claim" | "alternative-pool";

export interface JudgeState {
  application: ApplicationKind;
  selectedAttack: AttackKind;
  xrayCursor: number | null;
  maturityOpenings: number | null;
  ticketStage: "sealed" | "opened" | "consumed";
  ticketUnauthorizedAttempted: boolean;
  collectibleOpened: boolean;
}

export type JudgeAction =
  | { type: "application-selected"; application: ApplicationKind }
  | { type: "attack-selected"; attack: AttackKind }
  | { type: "xray-cursor-set"; cursor: number | null }
  | { type: "maturity-openings-set"; openings: number | null }
  | { type: "ticket-opened" }
  | { type: "ticket-consumed" }
  | { type: "ticket-unauthorized-attempted" }
  | { type: "ticket-reset" }
  | { type: "collectibles-opened" }
  | { type: "collectibles-reset" };

export const initialJudgeState: JudgeState = {
  application: "membership",
  selectedAttack: "fractional-open",
  xrayCursor: null,
  maturityOpenings: null,
  ticketStage: "sealed",
  ticketUnauthorizedAttempted: false,
  collectibleOpened: false,
};

export function judgeReducer(state: JudgeState, action: JudgeAction): JudgeState {
  switch (action.type) {
    case "application-selected":
      return { ...state, application: action.application };
    case "attack-selected":
      return { ...state, selectedAttack: action.attack };
    case "xray-cursor-set":
      return {
        ...state,
        xrayCursor: action.cursor === null ? null : Math.max(0, Math.min(5, Math.trunc(action.cursor))),
      };
    case "maturity-openings-set":
      return {
        ...state,
        maturityOpenings:
          action.openings === null ? null : Math.max(0, Math.min(60, Math.trunc(action.openings))),
      };
    case "ticket-opened":
      return state.ticketStage === "sealed"
        ? { ...state, ticketStage: "opened", ticketUnauthorizedAttempted: false }
        : state;
    case "ticket-consumed":
      return state.ticketStage === "opened" ? { ...state, ticketStage: "consumed" } : state;
    case "ticket-unauthorized-attempted":
      return state.ticketStage === "sealed" ? state : { ...state, ticketUnauthorizedAttempted: true };
    case "ticket-reset":
      return { ...state, ticketStage: "sealed", ticketUnauthorizedAttempted: false };
    case "collectibles-opened":
      return state.collectibleOpened ? state : { ...state, collectibleOpened: true };
    case "collectibles-reset":
      return { ...state, collectibleOpened: false };
  }
}

export function ticketAdmissionBalance(stage: JudgeState["ticketStage"]): number {
  if (stage === "opened") return 3;
  if (stage === "consumed") return 2;
  return 0;
}

export const collectibleAssignment = [1, 2, 3, 1] as const;
export const collectibleBalances = { 1: 2, 2: 1, 3: 1 } as const;

export const applicationFrontier = [
  {
    module: "NFT reveals",
    possibility: "Burn a fungible unopened asset to mint or reveal a committed NFT outcome.",
    missingBoundary: "Needs metadata commitment, reveal fairness and receiver/re-entry review.",
  },
  {
    module: "Gacha or loot",
    possibility: "Open into a weighted item outcome while the market reads only aggregate openings.",
    missingBoundary: "Needs verifiable randomness, published odds, economic review and jurisdiction checks.",
  },
  {
    module: "Physical claims",
    possibility: "Burn an unopened claim token to request offchain fulfilment of a physical item.",
    missingBoundary: "Needs custody, identity/privacy, fulfilment, dispute and refund operations.",
  },
] as const;

export const modelResults = [
  { target: 30, maturityProbability: 90.7, assessment: "Usually matures too early" },
  { target: 40, maturityProbability: 72.9, assessment: "Locked prototype target" },
  { target: 50, maturityProbability: 47.2, assessment: "Misses in most paths" },
  { target: 60, maturityProbability: 23.3, assessment: "Rarely matures" },
] as const;

export interface AttackCase {
  id: AttackKind;
  label: string;
  attempt: string;
  expectedResult: string;
  explanation: string;
  invariant: string;
  source: string;
  test: string;
  invariantId: string;
}

export const attackCases: readonly AttackCase[] = [
  {
    id: "fractional-open",
    label: "Fractional balance open",
    attempt: "balance = 0.999999999999999999 BOX; open(1)",
    expectedResult: "Expected revert: insufficient ERC-20 balance",
    explanation: "Opening burns exactly 1e18 units per box. The burn fails before openedCount or membership expiry can change.",
    invariant: "Whole-unit opening is atomic",
    source: "OpenableERC20.sol:58–67",
    test: "DiscoveryBox.t.sol:101–111",
    invariantId: "invariant-whole-unit",
  },
  {
    id: "wrong-pool-key",
    label: "Wrong PoolKey initialization",
    attempt: "initialize(canonical key with tickSpacing = 120)",
    expectedResult: "Expected revert: InvalidPoolKey",
    explanation: "The hook is registered for one exact PoolId. A changed tick spacing produces a different key and is rejected.",
    invariant: "One registered PoolKey",
    source: "DiscoveryHook.sol:104–120, 248–251",
    test: "DiscoveryHook.t.sol:104–110",
    invariantId: "invariant-pool-key",
  },
  {
    id: "unauthorized-claim",
    label: "Unauthorized Programmable claim",
    attempt: "nonOwner.claimProgrammableFee(liability, nonOwner)",
    expectedResult: "Expected revert: UnauthorizedProgrammableOwner",
    explanation: "Only the immutable Programmable owner can reduce and claim the backed liability.",
    invariant: "Claim owner is immutable",
    source: "DiscoveryHook.sol:142–160",
    test: "DiscoveryHook.t.sol:265–270",
    invariantId: "invariant-claim-owner",
  },
  {
    id: "alternative-pool",
    label: "Alternative pool callback",
    attempt: "beforeSwap(alternative PoolKey, sell BOX)",
    expectedResult: "Expected revert: InvalidPoolKey",
    explanation: "A different pool does not inherit this hook's LP-fee curve or satisfy its Programmable liability policy.",
    invariant: "Policy belongs to the canonical pool",
    source: "DiscoveryHook.sol:196–216, 248–255",
    test: "DiscoveryHook.t.sol:104–110; TEST_PLAN.md:91",
    invariantId: "invariant-alternative-pool",
  },
] as const;

export function getAttackCase(id: AttackKind): AttackCase {
  return attackCases.find((attack) => attack.id === id) ?? attackCases[0];
}

export function xrayMaximumStep(hasBought: boolean, hasOpened: boolean): number {
  if (hasOpened) return 5;
  if (hasBought) return 3;
  return 0;
}
