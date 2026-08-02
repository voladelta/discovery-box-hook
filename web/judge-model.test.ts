import { describe, expect, test } from "bun:test";
import {
  attackCases,
  getAttackCase,
  collectibleAssignment,
  collectibleBalances,
  initialJudgeState,
  judgeReducer,
  modelResults,
  ticketAdmissionBalance,
  xrayMaximumStep,
} from "./judge-model";

describe("judge-mode model", () => {
  test("preserves the documented maturity results and locked target", () => {
    expect(modelResults.map((result) => result.maturityProbability)).toEqual([90.7, 72.9, 47.2, 23.3]);
    expect(modelResults.find((result) => result.target === 40)?.assessment).toBe("Locked prototype target");
  });

  test("bounds exploratory openings without changing the canonical target", () => {
    const high = judgeReducer(initialJudgeState, { type: "maturity-openings-set", openings: 90 });
    const low = judgeReducer(high, { type: "maturity-openings-set", openings: -10 });

    expect(high.maturityOpenings).toBe(60);
    expect(low.maturityOpenings).toBe(0);
  });

  test("maps every attack control to a source and test invariant", () => {
    expect(attackCases).toHaveLength(4);
    for (const attack of attackCases) {
      expect(attack.source.length).toBeGreaterThan(10);
      expect(attack.test.length).toBeGreaterThan(10);
      expect(getAttackCase(attack.id)).toEqual(attack);
    }
  });

  test("exposes only trace steps that have occurred", () => {
    expect(xrayMaximumStep(false, false)).toBe(0);
    expect(xrayMaximumStep(true, false)).toBe(3);
    expect(xrayMaximumStep(true, true)).toBe(5);
  });

  test("opens one ticket box for three admissions and consumes exactly one", () => {
    const opened = judgeReducer(initialJudgeState, { type: "ticket-opened" });
    const consumed = judgeReducer(opened, { type: "ticket-consumed" });

    expect(ticketAdmissionBalance(opened.ticketStage)).toBe(3);
    expect(ticketAdmissionBalance(consumed.ticketStage)).toBe(2);
  });

  test("an unauthorized ticket consumer leaves the balance unchanged", () => {
    const opened = judgeReducer(initialJudgeState, { type: "ticket-opened" });
    const attacked = judgeReducer(opened, { type: "ticket-unauthorized-attempted" });

    expect(attacked.ticketUnauthorizedAttempted).toBe(true);
    expect(ticketAdmissionBalance(attacked.ticketStage)).toBe(3);
  });

  test("assigns four deterministic collectible serials with ERC-1155 balances 2, 1, 1", () => {
    const opened = judgeReducer(initialJudgeState, { type: "collectibles-opened" });

    expect(opened.collectibleOpened).toBe(true);
    expect(collectibleAssignment).toEqual([1, 2, 3, 1]);
    expect(collectibleBalances).toEqual({ 1: 2, 2: 1, 3: 1 });
  });
});
