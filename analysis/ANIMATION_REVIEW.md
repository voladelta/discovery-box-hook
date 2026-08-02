# Animation review

## Part 1 — Findings

| Before | After | Why |
| --- | --- | --- |
| `ApplicationOutcome` and gate branches reused the same unkeyed React host element | Added state-specific keys to the gate branches and application outcome | `@starting-style` now runs on insertion, so each intended state bridge has a reliable trigger. |
| `.box-object` transitioned `filter` | Limited its transition properties to `transform, opacity` | The hero transition is compositor-friendly; blur and drop-shadow state changes now snap. |
| Membership passes started at `scale(.72)` | Raised the entrance origin to `scale(.94)` | The passes retain a clear entrance without appearing from an implausibly small origin. |
| Headline and flow status changes added colour/background transitions | Removed both transitions | Neither was a surviving opportunity, and exact comparison values are clearer when the status colour changes immediately. |

## Part 2 — Verdict

All four blocking findings are resolved. The new state-bridge transitions use only transform and opacity, custom curves, and durations at or below 220ms; the pre-existing hero transition is capped at 280ms. Reduced-motion rules retain opacity and colour feedback while removing movement. The scan found no `transition: all`, zero-scale entrances, `ease-in`, layout-property transitions, or active keyframe animations.

**Decision: Approve**
