import { describe, expect, test } from "bun:test";
import {
  DEMO_BUY_WEI,
  demoReducer,
  deriveDemo,
  initialDemoState,
  programmableFeeFromGrossWei,
  sellLpFeePips,
} from "./demo-model";

describe("Discovery Box demo model", () => {
  test("follows the canonical buy then open sequence", () => {
    const buying = demoReducer(initialDemoState, { type: "buy-started" });
    const owned = demoReducer(buying, { type: "buy-settled" });
    const opening = demoReducer(owned, { type: "open-started" });
    const opened = demoReducer(opening, { type: "open-settled" });

    expect(deriveDemo(owned)).toMatchObject({ walletBoxes: 1, openedCount: 0 });
    expect(deriveDemo(opened)).toMatchObject({
      walletBoxes: 0,
      openedCount: 1,
      totalSupply: 99,
      sellLpFeePips: 9_825,
    });
  });

  test("matches the immutable sell-fee curve at its boundaries", () => {
    expect(sellLpFeePips(0)).toBe(10_000);
    expect(sellLpFeePips(20)).toBe(6_500);
    expect(sellLpFeePips(40)).toBe(3_000);
    expect(sellLpFeePips(99)).toBe(3_000);
  });

  test("charges Programmable 10 basis points of gross ETH volume", () => {
    expect(programmableFeeFromGrossWei(DEMO_BUY_WEI)).toBe(18_000_000_000_000n);
  });

  test("ignores impossible transitions", () => {
    expect(demoReducer(initialDemoState, { type: "open-started" })).toEqual(initialDemoState);
  });
});
