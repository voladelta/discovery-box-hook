# Discovery Box economic model

## Use 40 openings as the prototype target

Use a supply of 100 whole boxes and a maturity target of 40 for the prototype design.

This is not a universal optimum. It is the best prototype choice under the balanced scenario we tested. We must rerun the model with the exact Uniswap v4 launch position before deployment. Any change requires a new Builder preflight revision.

The balanced scenario produced these results:

| Target | Chance of reaching target | Median opened | 10% to 90% range |
| ---: | ---: | ---: | ---: |
| 30 | 90.7% | 48 | 30 to 67 |
| 40 | 72.9% | 48 | 30 to 67 |
| 50 | 47.2% | 48 | 30 to 67 |
| 60 | 23.3% | 48 | 30 to 67 |

A target of 30 would usually mature too early. A target of 50 would mature in fewer than half of the simulated paths.

A target of 40 gives us a useful middle case. Each opening lowers the sell LP fee by 1.75 basis points until maturity.

## The fee is a signal rather than the main incentive

The current sell LP fee falls from 1.00% to 0.30%. On a $10 box, the complete change is only 7 cents.

The simulation found that this fee range caused almost no extra openings. The average increase was 0.02 boxes at a target of 40.

Even a starting sell LP fee of 10% caused only 1.27 extra openings at a target of 60. A high fee would also make selling look punitive.

We should therefore make this claim:

> Opening boxes is a public maturity signal. The pool responds by lowering the sell LP fee.

We should not claim that the fee makes rational holders open boxes. Membership value does most of that work.

## The holder decision has a threshold equilibrium

A holder compares the value of opening with the value of selling.

The model opens a box when:

```text
membership value - opening cost
>=
box price * (1 - sell LP fee - Programmable fee) - selling cost
```

For an opened count `q`, the model calculates opening demand `D(q)`. It then finds the closest discrete fixed point:

```text
q = D(q)
```

This is a Nash-style threshold equilibrium. Each holder treats the market state as given and chooses their higher payoff.

The mechanism creates negative feedback. More openings lower the sell fee. A lower sell fee makes selling slightly more attractive. This makes the threshold stable under the model.

The feedback is weak because the fee range is small compared with membership-value uncertainty.

## Perceived value controls the outcome

List price does not equal user value. A bundle advertised as worth $50 may be worth much less to someone who does not know the apps.

At a target of 30, the model produced these results:

| Median perceived value | Chance of reaching target | Median opened |
| ---: | ---: | ---: |
| $7 | 35.1% | 25 |
| $10 | 90.9% | 49 |
| $15 | 99.9% | 76 |
| $30 | 100% | 98 |
| $50 | 100% | 100 |

If users truly value the bundle at $50 while the box costs $10, almost every box opens. The market should then reprice the unopened box towards its membership value.

This means we cannot derive the final target from the advertised retail value. We need a measured distribution of perceived value.

## Path testing is more useful than an average

Ergodicity does not select a maturity target for us. One campaign experiences one path, not the average of thousands of launches.

We use repeated random paths to inspect downside ranges and the chance of maturity. This avoids choosing a target from the average opening count alone.

The provisional rule is:

```text
choose the largest target reached in about 70% of balanced paths
```

Under the current assumptions, that rule selects 40 openings.

## Current assumptions

The simulation uses:

- 100 whole boxes
- a median box price of $10
- a median perceived membership value of $10 in the balanced case
- lognormal differences between holders and market paths
- a 1.00% to 0.30% sell LP fee
- a 0.10% Programmable fee
- a $0.50 opening transaction cost
- a $0.25 selling transaction cost
- a choice between opening now and selling now

The model does not yet include:

- the exact v4 liquidity range
- Initial Buy size
- price movement caused by pool trades
- holding and later resale
- changing membership value over time
- strategic coordination or multiple boxes per holder
- measured user-value data

These limits prevent us from calling 40 a final deployment parameter.

## Reproduce the result

Run:

```bash
uv run --python 3.14 analysis/economic_model.py --runs 20000
```

The script uses a fixed random seed. It uses only the Python standard library.

## Complete the final simulation

After the Builder preflight accepts the architecture:

1. Select the exact official launch components.
2. Fix the supply, tick range, starting price and Initial Buy.
3. Replace the random price approximation with exact v4 swap calculations.
4. Stress-test different perceived-value distributions and gas costs.
5. Keep 40 only if the exact model still reaches maturity in about 70% of balanced paths.
6. Rerun the Builder preflight if the maturity target changes.
