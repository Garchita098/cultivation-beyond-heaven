#!/usr/bin/env python3
"""Run economy simulations, write reports + chart."""
from __future__ import annotations
import json
import os
import sys
from typing import Dict, List, Tuple

sys.path.insert(0, os.path.dirname(__file__))
from economy import Economy, GameState
from bots import ALL_BOTS, BestROI, OfflineHeavy, GreedyCheapest, RushBreakthrough, RebirthEarly, RebirthLate

REPORT_DIR = os.path.join(os.path.dirname(__file__), "reports")
os.makedirs(REPORT_DIR, exist_ok=True)


def fmt_time(sec: float) -> str:
    if sec < 0:
        return "—"
    if sec < 60:
        return f"{sec:.1f}s"
    if sec < 3600:
        return f"{sec/60:.1f}m"
    return f"{sec/3600:.2f}h"


def detect_walls(state: GameState, eco: Economy) -> List[dict]:
    walls_cfg = eco.balance["walls"]
    # Reconstruct approximate waits from milestones chronology
    events = []
    for k, t in state.milestones.items():
        if k.startswith("rank:") or k.startswith("upgrade:") or k.startswith("rebirth:"):
            events.append((t, k))
    events.sort()
    walls = []
    prev_t = 0.0
    for t, k in events:
        gap = t - prev_t
        # determine phase by rank at that time — approximate via milestone name
        rank_idx = state.highest_rank_index
        for r in eco.ranks:
            mid = f"rank:{r['id']}"
            if mid in state.milestones and state.milestones[mid] <= t:
                rank_idx = r["index"]
        if rank_idx < walls_cfg["early_until_rank_index"]:
            thr = walls_cfg["early_game_max_idle_sec"]
            phase = "early"
        elif rank_idx < walls_cfg["mid_until_rank_index"]:
            thr = walls_cfg["mid_game_max_idle_sec"]
            phase = "mid"
        else:
            thr = walls_cfg["late_game_max_idle_sec"]
            phase = "late"
        if gap >= thr:
            walls.append({"from": prev_t, "to": t, "gap_sec": gap, "phase": phase, "threshold": thr, "next_event": k})
        prev_t = t
    return walls


def longest_wait(state: GameState) -> Tuple[float, str, str]:
    events = sorted((t, k) for k, t in state.milestones.items() if k.startswith(("rank:", "upgrade:", "rebirth:", "first_")))
    if not events:
        return 0.0, "", ""
    prev = 0.0
    best = (0.0, "start", events[0][1])
    for t, k in events:
        gap = t - prev
        if gap > best[0]:
            best = (gap, "prev", k)
        prev = t
    return best[0], best[1], best[2]


def run_active(eco: Economy, bot, max_sec: float, decide_every: float = 0.5) -> GameState:
    state = GameState()
    state.unlocked.add("upgrades_basic")
    dt = float(eco.balance["tick_seconds"])
    acc = 0.0
    while state.time_sec < max_sec:
        eco.tick(state, dt)
        acc += dt
        if acc >= decide_every:
            acc = 0.0
            bot.decide(eco, state)
        # stop early if beyond stage-2 soft goal and have rebirth
        if state.time_sec > 5400 and state.rebirth_count >= 1 and state.rank_index >= 8:
            break
    # final decide
    bot.decide(eco, state)
    return state


def run_offline_heavy(eco: Economy, max_sec: float = 48 * 3600) -> GameState:
    """3 check-ins/day: 10 min active, then 8h offline, repeat."""
    bot = OfflineHeavy()
    state = GameState()
    state.unlocked.add("upgrades_basic")
    dt = float(eco.balance["tick_seconds"])
    cycle_active = 10 * 60
    cycle_offline = 8 * 3600
    while state.time_sec < max_sec:
        # active
        end_active = state.time_sec + cycle_active
        acc = 0.0
        while state.time_sec < end_active and state.time_sec < max_sec:
            eco.tick(state, dt)
            acc += dt
            if acc >= 0.5:
                acc = 0.0
                bot.decide(eco, state)
        if state.time_sec >= max_sec:
            break
        # offline
        eco.apply_offline(state, cycle_offline)
        bot.decide(eco, state)
        if state.rebirth_count >= 2:
            break
    return state


def milestone_table(state: GameState, eco: Economy) -> List[dict]:
    keys = [
        "first_upgrade",
        "first_breakthrough",
        "rank:qi_early",
        "rank:foundation_early",
        "rank:core_early",
        "rank:core_peak",
        "rebirth_unlocked",
        "first_rebirth",
        "rank:nascent_early",
    ]
    rows = []
    for k in keys:
        t = state.milestones.get(k)
        rows.append({"milestone": k, "time_sec": t, "time": fmt_time(t) if t is not None else "not reached"})
    # also all ranks reached
    for r in eco.ranks:
        mid = f"rank:{r['id']}"
        if mid in state.milestones and mid not in keys:
            rows.append({"milestone": mid, "time_sec": state.milestones[mid], "time": fmt_time(state.milestones[mid])})
    return rows


def magnitude_ok(state: GameState) -> List[str]:
    issues = []
    import math
    for name, val in [("qi", state.qi), ("lifetime_qi", state.lifetime_qi), ("prod", 0)]:
        pass
    if not math.isfinite(state.qi) or not math.isfinite(state.lifetime_qi):
        issues.append("NaN/Inf detected in qi")
    if state.qi < 0:
        issues.append("negative qi")
    return issues


def pacing_check(state: GameState, eco: Economy) -> List[str]:
    t = eco.balance["pacing_targets_sec"]
    issues = []
    fu = state.milestones.get("first_upgrade")
    if fu is None or fu > t["first_upgrade"]:
        issues.append(f"first_upgrade slow/missing: {fu} target<={t['first_upgrade']}")
    fb = state.milestones.get("first_breakthrough")
    if fb is None or fb > t["first_breakthrough"]:
        issues.append(f"first_breakthrough slow/missing: {fb} target<={t['first_breakthrough']}")
    elif fb < t.get("first_breakthrough_min", 90):
        issues.append(f"first_breakthrough too fast: {fb}")
    fr = state.milestones.get("first_rebirth")
    if fr is None:
        issues.append("first_rebirth not reached in sim window")
    elif fr > t["first_rebirth"]:
        issues.append(f"first_rebirth slow: {fr} target<={t['first_rebirth']}")
    elif fr < t.get("first_rebirth_min", 1800):
        issues.append(f"first_rebirth too fast: {fr} (want ~30-60min)")
    return issues


def write_chart(results: Dict[str, GameState], path: str) -> None:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        # PIL fallback: skip detailed chart
        return
    fig, ax = plt.subplots(figsize=(10, 5))
    for name, st in results.items():
        if not st.history:
            continue
        xs = [h[0] / 60.0 for h in st.history]
        ys = [max(h[1], 1e-9) for h in st.history]
        ax.plot(xs, ys, label=name)
    ax.set_yscale("log")
    ax.set_xlabel("Time (minutes)")
    ax.set_ylabel("Qi / sec (log)")
    ax.set_title("Cultivation: Beyond Heaven — Production over time")
    ax.legend(fontsize=8)
    ax.grid(True, which="both", alpha=0.3)
    fig.tight_layout()
    fig.savefig(path, dpi=120)
    plt.close(fig)


def main():
    eco = Economy()
    max_sec = 2 * 3600  # 2h active window for pacing stage 1-2
    results = {}
    reports = {}

    bots_active = [GreedyCheapest(), BestROI(), RushBreakthrough(), RebirthEarly(), RebirthLate()]
    for bot in bots_active:
        st = run_active(eco, bot, max_sec=max_sec)
        results[bot.name] = st
        walls = detect_walls(st, eco)
        lw, _, lk = longest_wait(st)
        reports[bot.name] = {
            "milestones": milestone_table(st, eco),
            "longest_wait_sec": lw,
            "longest_wait_until": lk,
            "walls": walls,
            "magnitude_issues": magnitude_ok(st),
            "pacing_issues": pacing_check(st, eco),
            "final": {
                "time": st.time_sec,
                "qi": st.qi,
                "prod": eco.production(st),
                "rank": eco.rank(st)["id"],
                "rank_index": st.rank_index,
                "rebirths": st.rebirth_count,
                "karma": st.karma_shards,
                "lifetime_qi": st.lifetime_qi,
            },
        }
        print(f"=== {bot.name} ===")
        print(f"  final rank={eco.rank(st)['id']} rebirths={st.rebirth_count} t={fmt_time(st.time_sec)}")
        for row in reports[bot.name]["milestones"][:9]:
            print(f"  {row['milestone']}: {row['time']}")
        print(f"  longest_wait={fmt_time(lw)} walls={len(walls)} pacing={reports[bot.name]['pacing_issues']}")

    # offline heavy — longer calendar time
    st = run_offline_heavy(eco, max_sec=72 * 3600)
    results["offline_heavy"] = st
    walls = detect_walls(st, eco)
    lw, _, lk = longest_wait(st)
    reports["offline_heavy"] = {
        "milestones": milestone_table(st, eco),
        "longest_wait_sec": lw,
        "longest_wait_until": lk,
        "walls": walls,
        "magnitude_issues": magnitude_ok(st),
        "pacing_issues": pacing_check(st, eco),
        "final": {
            "time": st.time_sec,
            "qi": st.qi,
            "prod": eco.production(st),
            "rank": eco.rank(st)["id"],
            "rank_index": st.rank_index,
            "rebirths": st.rebirth_count,
            "karma": st.karma_shards,
            "lifetime_qi": st.lifetime_qi,
        },
    }
    print(f"=== offline_heavy ===")
    print(f"  final rank={eco.rank(st)['id']} rebirths={st.rebirth_count} t={fmt_time(st.time_sec)}")
    for row in reports["offline_heavy"]["milestones"][:9]:
        print(f"  {row['milestone']}: {row['time']}")

    # pick best by first_rebirth then rank
    def score(name):
        st = results[name]
        fr = st.milestones.get("first_rebirth", 1e18)
        return (0 if fr < 1e17 else 1, fr, -st.highest_rank_index)

    best_name = min([n for n in results if n != "offline_heavy"], key=score)
    summary = {
        "best_strategy": best_name,
        "targets": eco.balance["pacing_targets_sec"],
        "reports": reports,
    }
    out_json = os.path.join(REPORT_DIR, "sim_report.json")
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)

    # markdown summary
    md = ["# Simulation Report — Cultivation: Beyond Heaven", ""]
    md.append(f"**Best strategy (active):** `{best_name}`")
    md.append("")
    md.append("## Milestone times (best strategy)")
    md.append("")
    md.append("| Milestone | Time |")
    md.append("|-----------|------|")
    for row in reports[best_name]["milestones"][:12]:
        md.append(f"| {row['milestone']} | {row['time']} |")
    md.append("")
    md.append("## All strategies — key milestones")
    md.append("")
    md.append("| Strategy | First upgrade | First BT | Qi Early | Core Peak | First Rebirth | Walls |")
    md.append("|----------|---------------|----------|----------|-----------|---------------|-------|")
    for name, rep in reports.items():
        def gt(key):
            for r in rep["milestones"]:
                if r["milestone"] == key:
                    return r["time"]
            return "—"
        md.append(
            f"| {name} | {gt('first_upgrade')} | {gt('first_breakthrough')} | {gt('rank:qi_early')} | {gt('rank:core_peak')} | {gt('first_rebirth')} | {len(rep['walls'])} |"
        )
    md.append("")
    md.append(f"## Pacing issues ({best_name})")
    for iss in reports[best_name]["pacing_issues"] or ["none"]:
        md.append(f"- {iss}")
    md.append("")
    md.append(f"Longest wait: {fmt_time(reports[best_name]['longest_wait_sec'])} until `{reports[best_name]['longest_wait_until']}`")
    md_path = os.path.join(REPORT_DIR, "sim_report.md")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("\n".join(md) + "\n")

    chart_path = os.path.join(REPORT_DIR, "progress_chart.png")
    write_chart(results, chart_path)
    print(f"Wrote {out_json}")
    print(f"Wrote {md_path}")
    print(f"Chart: {chart_path} exists={os.path.exists(chart_path)}")
    print(f"BEST={best_name}")


if __name__ == "__main__":
    main()
