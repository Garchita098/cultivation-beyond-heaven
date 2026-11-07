#!/usr/bin/env python3
"""Replay the rebirth_early bot and compare to reports/golden_ticks.json.

The golden file is the parity fixture shared with the Godot headless test.
This script only runs one bot (faster than the full report).
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from bots import RebirthEarly  # noqa: E402
from economy import Economy, GameState  # noqa: E402
from mag import plain_qty  # noqa: E402

HERE = os.path.dirname(__file__)
GOLDEN = os.path.join(HERE, "reports", "golden_ticks.json")

# Relative tolerance for qi / prod. Rank and rebirths must match exactly.
REL = 1e-6
ABS = 1e-4


def run_samples(eco: Economy, max_sec: float) -> dict:
    bot = RebirthEarly()
    state = GameState()
    state.unlocked.add("upgrades_basic")
    dt = float(eco.balance["tick_seconds"])
    acc = 0.0
    samples = []
    while state.time_sec < max_sec - 1e-9:
        eco.tick(state, dt)
        acc += dt
        decided = False
        if acc >= 0.5 - 1e-12:
            acc = 0.0
            bot.decide(eco, state)
            decided = True
        t = state.time_sec
        # Match the fixture: first tick, then every 30s after decisions at that instant.
        if abs(t - dt) < 1e-9 or abs(t % 30.0) < 1e-6 or abs((t % 30.0) - 30.0) < 1e-6:
            if decided or abs(t - dt) < 1e-9:
                samples.append(
                    {
                        "t": t,
                        "qi": plain_qty(state.qi),
                        "prod": eco.production(state),
                        "rank_index": state.rank_index,
                        "rank_id": eco.rank(state)["id"],
                        "rebirths": state.rebirth_count,
                        "karma": state.karma_shards,
                        "talents": len(state.talents_owned),
                        "artifacts": len(state.artifacts_owned),
                        "shop_mult": state.shop_mult,
                    }
                )
    return {"milestones": dict(state.milestones), "samples": samples}


def close(a: float, b: float) -> bool:
    return abs(a - b) <= max(ABS, REL * max(abs(a), abs(b)))


def main() -> int:
    with open(GOLDEN, "r", encoding="utf-8") as f:
        golden = json.load(f)
    eco = Economy()
    last_t = golden["ticks_every_30s"][-1]["t"]
    got = run_samples(eco, last_t + float(eco.balance["tick_seconds"]))
    by_t = {round(s["t"], 4): s for s in got["samples"]}
    fails = 0
    for exp in golden["ticks_every_30s"]:
        key = round(exp["t"], 4)
        g = by_t.get(key)
        if g is None:
            print(f"FAIL missing sample t={exp['t']}")
            fails += 1
            continue
        if g["rank_index"] != exp["rank_index"] or g["rebirths"] != exp["rebirths"] or g["rank_id"] != exp["rank_id"]:
            print(
                f"FAIL t={exp['t']} rank {g['rank_id']}#{g['rank_index']} r{g['rebirths']} "
                f"!= {exp['rank_id']}#{exp['rank_index']} r{exp['rebirths']}"
            )
            fails += 1
            continue
        if g.get("talents") != exp.get("talents") or g.get("artifacts") != exp.get("artifacts"):
            print(
                f"FAIL t={exp['t']} talents/artifacts {g.get('talents')}/{g.get('artifacts')} "
                f"!= {exp.get('talents')}/{exp.get('artifacts')}"
            )
            fails += 1
            continue
        if not close(g["qi"], exp["qi"]) or not close(g["prod"], exp["prod"]):
            print(
                f"FAIL t={exp['t']} qi {g['qi']} != {exp['qi']} prod {g['prod']} != {exp['prod']}"
            )
            fails += 1
            continue
        if "karma" in exp and (not close(g["karma"], exp["karma"]) or not close(g["shop_mult"], exp["shop_mult"])):
            print(f"FAIL t={exp['t']} karma/shop {g['karma']}/{g['shop_mult']} != {exp['karma']}/{exp['shop_mult']}")
            fails += 1
    for key, t in golden["milestones"].items():
        got_t = got["milestones"].get(key)
        if got_t is None or abs(got_t - t) > 1e-6:
            print(f"FAIL milestone {key}: got {got_t} expected {t}")
            fails += 1
    print(f"samples={len(got['samples'])} golden={len(golden['ticks_every_30s'])} fails={fails}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
