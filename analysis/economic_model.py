#!/usr/bin/env python3
"""Stress-test Discovery Box maturity targets.

This is a reduced-form holder-choice model, not a forecast. It compares the
payoff from opening one box with the net proceeds from selling it. The script
then finds the discrete fixed point where the number of holders who prefer to
open matches the opened-box count used by the dynamic fee.

The model deliberately uses only Python's standard library so the result is
easy to reproduce before the Solidity toolchain exists.
"""

from __future__ import annotations

import argparse
from bisect import bisect_left
import math
import random
from dataclasses import dataclass
from statistics import mean, median


@dataclass(frozen=True)
class Model:
    supply: int = 100
    ticket_price: float = 10.0
    price_sigma: float = 0.20
    valuation_sigma: float = 0.55
    open_cost: float = 0.50
    sell_cost: float = 0.25
    platform_fee_bps: float = 10.0
    minimum_sell_lp_fee_bps: float = 30.0
    maximum_sell_lp_fee_bps: float = 100.0


def percentile(values: list[int], p: float) -> float:
    ordered = sorted(values)
    position = (len(ordered) - 1) * p
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return float(ordered[lower])
    weight = position - lower
    return ordered[lower] * (1 - weight) + ordered[upper] * weight


def sell_lp_fee_bps(opened: int, target: int, model: Model) -> float:
    progress = min(opened, target) / target
    spread = model.maximum_sell_lp_fee_bps - model.minimum_sell_lp_fee_bps
    return model.maximum_sell_lp_fee_bps - progress * spread


def equilibrium_openings(
    membership_values: list[float],
    box_price: float,
    target: int,
    model: Model,
) -> int:
    """Return the closest discrete fixed point q = opening_demand(q)."""

    ordered_values = sorted(membership_values)
    candidates: list[tuple[int, int]] = []
    for opened in range(model.supply + 1):
        fee = sell_lp_fee_bps(opened, target, model)
        total_sale_fee = (fee + model.platform_fee_bps) / 10_000
        sell_payoff = box_price * (1 - total_sale_fee) - model.sell_cost
        opening_threshold = sell_payoff + model.open_cost
        demand = model.supply - bisect_left(ordered_values, opening_threshold)
        candidates.append((abs(demand - opened), opened))
    return min(candidates)[1]


def flat_fee_openings(
    membership_values: list[float], box_price: float, model: Model
) -> int:
    total_sale_fee = (
        model.minimum_sell_lp_fee_bps + model.platform_fee_bps
    ) / 10_000
    sell_payoff = box_price * (1 - total_sale_fee) - model.sell_cost
    opening_threshold = sell_payoff + model.open_cost
    ordered_values = sorted(membership_values)
    return model.supply - bisect_left(ordered_values, opening_threshold)


def run_scenario(
    *,
    model: Model,
    membership_median: float,
    target: int,
    runs: int,
    rng: random.Random,
) -> dict[str, float]:
    openings: list[int] = []
    induced: list[int] = []
    equilibrium_fees: list[float] = []

    for _ in range(runs):
        price = rng.lognormvariate(math.log(model.ticket_price), model.price_sigma)
        values = [
            rng.lognormvariate(math.log(membership_median), model.valuation_sigma)
            for _ in range(model.supply)
        ]
        opened = equilibrium_openings(values, price, target, model)
        flat_opened = flat_fee_openings(values, price, model)
        openings.append(opened)
        induced.append(opened - flat_opened)
        equilibrium_fees.append(sell_lp_fee_bps(opened, target, model))

    return {
        "p10_opened": percentile(openings, 0.10),
        "p25_opened": percentile(openings, 0.25),
        "median_opened": median(openings),
        "p75_opened": percentile(openings, 0.75),
        "p90_opened": percentile(openings, 0.90),
        "maturity_probability": mean(value >= target for value in openings),
        "mean_fee_induced_openings": mean(induced),
        "median_equilibrium_fee_bps": median(equilibrium_fees),
    }


def print_target_table(
    *,
    model: Model,
    membership_median: float,
    targets: list[int],
    runs: int,
    seed: int,
) -> None:
    print(f"Balanced perceived membership value: ${membership_median:.2f}")
    print()
    print("| Target | Reach probability | Median opened | 10% to 90% opened | Fee-induced openings | Median sell LP fee |")
    print("| ---: | ---: | ---: | ---: | ---: | ---: |")
    for target in targets:
        result = run_scenario(
            model=model,
            membership_median=membership_median,
            target=target,
            runs=runs,
            rng=random.Random(seed),
        )
        print(
            f"| {target} | {result['maturity_probability']:.1%} "
            f"| {result['median_opened']:.0f} "
            f"| {result['p10_opened']:.0f} to {result['p90_opened']:.0f} "
            f"| {result['mean_fee_induced_openings']:.2f} "
            f"| {result['median_equilibrium_fee_bps']:.1f} bps |"
        )


def print_value_sensitivity(
    *,
    model: Model,
    target: int,
    medians: list[float],
    runs: int,
    seed: int,
) -> None:
    print()
    print(f"Value sensitivity at target {target}")
    print()
    print("| Perceived-value median | Reach probability | Median opened | 25% to 75% opened |")
    print("| ---: | ---: | ---: | ---: |")
    for membership_median in medians:
        result = run_scenario(
            model=model,
            membership_median=membership_median,
            target=target,
            runs=runs,
            rng=random.Random(seed + 10_000),
        )
        print(
            f"| ${membership_median:.2f} "
            f"| {result['maturity_probability']:.1%} "
            f"| {result['median_opened']:.0f} "
            f"| {result['p25_opened']:.0f} to {result['p75_opened']:.0f} |"
        )


def print_fee_sensitivity(
    *,
    target: int,
    membership_median: float,
    maximum_fees: list[float],
    runs: int,
    seed: int,
) -> None:
    print()
    print(f"Fee sensitivity at target {target}")
    print()
    print("| Starting sell LP fee | Reach probability | Median opened | Fee-induced openings |")
    print("| ---: | ---: | ---: | ---: |")
    for maximum_fee in maximum_fees:
        model = Model(maximum_sell_lp_fee_bps=maximum_fee)
        result = run_scenario(
            model=model,
            membership_median=membership_median,
            target=target,
            runs=runs,
            rng=random.Random(seed + 20_000),
        )
        print(
            f"| {maximum_fee:.0f} bps "
            f"| {result['maturity_probability']:.1%} "
            f"| {result['median_opened']:.0f} "
            f"| {result['mean_fee_induced_openings']:.2f} |"
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs", type=int, default=5_000)
    parser.add_argument("--seed", type=int, default=20260802)
    args = parser.parse_args()

    model = Model()
    targets = [20, 30, 40, 50, 60, 70]
    print_target_table(
        model=model,
        membership_median=10.0,
        targets=targets,
        runs=args.runs,
        seed=args.seed,
    )
    print_value_sensitivity(
        model=model,
        target=30,
        medians=[7.0, 10.0, 15.0, 30.0, 50.0],
        runs=args.runs,
        seed=args.seed,
    )
    print_fee_sensitivity(
        target=60,
        membership_median=10.0,
        maximum_fees=[100.0, 300.0, 500.0, 1_000.0],
        runs=args.runs,
        seed=args.seed,
    )
    print()
    print("Assumptions")
    print(f"- supply: {model.supply} boxes")
    print(f"- median market price: ${model.ticket_price:.2f}")
    print(f"- sell LP fee: {model.maximum_sell_lp_fee_bps:.0f} to {model.minimum_sell_lp_fee_bps:.0f} bps")
    print(f"- Programmable fee: {model.platform_fee_bps:.0f} bps")
    print(f"- opening transaction cost: ${model.open_cost:.2f}")
    print(f"- selling transaction cost: ${model.sell_cost:.2f}")
    print("- holders choose between opening now and selling now")
    print("- values and market prices are independent lognormal draws")


if __name__ == "__main__":
    main()
