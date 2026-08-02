# Animation opportunities

## Part 1 — Opportunities

| # | Location | Today | Purpose | Frequency | Suggested motion |
| --- | --- | --- | --- | --- | --- |
| 1 | `web/JudgeMode.tsx:203` | Switching Membership, Ticket and Collectible replaces the complete outcome with no visual bridge. | State indication; preventing a jarring change | Occasional during a judge demo | On the newly mounted outcome, use `@starting-style { opacity: 0; transform: translateY(6px) }` to `opacity: 1; transform: translateY(0)`, `180ms cubic-bezier(0.2, 0, 0, 1)`. Reduced motion keeps the `180ms` opacity change and removes translation. |
| 2 | `web/JudgeMode.tsx:170` | Opening the canonical box replaces the locked gate with the research artifact instantly. | State indication; preventing a jarring change | Rare success moment | Reveal the mounted artifact content from `opacity: 0; transform: translateY(8px)` to settled in `220ms cubic-bezier(0.2, 0, 0, 1)`. Reduced motion retains opacity and removes translation. No bounce or celebration. |
| 3 | `web/JudgeMode.tsx:203–220` | The ticket reference is static, so consuming an admission would have no acknowledgement. | Feedback; state indication | Occasional | Keep all three admission marks mounted. On consume, move only the consumed mark to `opacity: 0; transform: translateY(-6px)` over `180ms cubic-bezier(0.4, 0, 0.2, 1)`; update the numeric balance with a `140ms` opacity cross-fade. Reduced motion uses opacity only. |
| 4 | `web/JudgeMode.tsx:222–239` | The deterministic style sequence is visible at once and does not demonstrate serial assignment. | Explanation | Rare / first-time | On explicit “Open four” action, show persistent serial tiles with `opacity: 0; transform: translateY(6px)` to settled over `160ms cubic-bezier(0.2, 0, 0, 1)`, staggered by `35ms` (total under `300ms`). Reduced motion keeps the opacity stagger and removes translation. |
| 5 | `web/JudgeMode.tsx:335` | Selecting an attack swaps the expected-revert text instantly. | Feedback; state indication | Occasional | Remount the result body by attack id and enter from `opacity: 0; transform: translateY(4px)` to settled in `140ms cubic-bezier(0.2, 0, 0, 1)`. Reduced motion keeps opacity only. |

All five pass the speed gate within 300ms. They animate only `transform` and `opacity`, bridge explicit state changes, and do not move information while the user is reading it.

## Part 2 — Rejected candidates

- `web/JudgeMode.tsx:391–414` — animated fee curve or travelling chart marker. **Rejected: Function.** This is quantitative data controlled continuously by a slider; ornamental motion would hinder reading and rapid input.
- `web/JudgeMode.tsx:103–145` — animate the callback trace rows as the replay cursor advances. **Rejected: Function.** The trace is dense protocol evidence; selection colour is enough and the values should remain spatially stable.
- `web/JudgeMode.tsx:275–299` — sliding tab indicator between application types. **Rejected: Frequency.** Judges may switch repeatedly while comparing semantics; a moving indicator adds latency without explaining the boundary.
- `web/App.tsx:369–416` — stagger all instrumentation ledger values after buy/open. **Rejected: Function.** The user is comparing exact before/after values; movement across the ledger would make that comparison harder.
- Planned application-frontier rows — animate possible modules on hover. **Rejected: Purpose.** Hover movement would be decoration on explanatory content and would add no state or feedback.

## Part 3 — Verdict

This interface already spends its motion budget on the box-opening ritual and maturity feedback. Judge mode needs only short bridges at the five explicit state changes above; everything quantitative should stay still. The highest-leverage addition is the application-outcome entrance because it preserves context while the same interface boundary produces visibly different results. The recipes above are ready for normal implementation work.
