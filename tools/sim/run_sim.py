#!/usr/bin/env python3
"""Run economy simulations, write reports + chart."""
from __future__ import annotations

import json
import math
import os
import sys
from typing import Dict, List, Tuple

sys.path.insert(0, os.path.dirname(__file__))
from bots import (  # noqa: E402
    ArtifactFocused,
    BestROI,
    GreedyCheapest,
    OfflineHeavy,
    RebirthEarly,
    RebirthLate,
    RushBreakthrough,
    TalentFocused,
)
from economy import Economy, GameState, fresh_state  # noqa: E402

REPORT_DIR = os.path.join(os.path.dirname(__file__), "reports")
os.makedirs(REPORT_DIR, exist_ok=True)


def fmt_time(sec: float) -> str:
    if sec is None or sec < 0:
        return "—"
    if sec < 60:
        return f"{sec:.1f}s"
    if sec < 3600:
        return f"{sec / 60:.1f}m"
    if sec < 48 * 3600:
        return f"{sec / 3600:.2f}h"
    return f"{sec / 86400:.2f}d"


def detect_walls(state: GameState, eco: Economy) -> List[dict]:
    walls_cfg = eco.balance["walls"]
    events = []
    for k, t in state.milestones.items():
        if k.startswith("rank:") or k.startswith("upgrade:") or k.startswith("rebirth:"):
            events.append((t, k))
    events.sort()
    walls = []
    prev_t = 0.0
    for t, k in events:
        gap = t - prev_t
        rank_idx = 0
        for r in eco.ranks:
            mid = f"rank:{r['id']}"
            if mid in state.milestones and state.milestones[mid] <= t + 1e-9:
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
            walls.append(
                {
                    "from": prev_t,
                    "to": t,
                    "gap_sec": gap,
                    "phase": phase,
                    "threshold": thr,
                    "next_event": k,
                }
            )
        prev_t = t
    return walls


def longest_wait(state: GameState) -> Tuple[float, str]:
    events = sorted(
        (t, k)
        for k, t in state.milestones.items()
        if k.startswith(("rank:", "upgrade:", "rebirth:", "first_"))
    )
    if not events:
        return 0.0, ""
    prev = 0.0
    best = (0.0, events[0][1])
    for t, k in events:
        gap = t - prev
        if gap > best[0]:
            best = (gap, k)
        prev = t
    return best[0], best[1]


def run_active(eco: Economy, bot, max_sec: float, stop_rebirths: int = 0, decide_every: float = 0.5) -> GameState:
    state = fresh_state()
    dt = float(eco.balance["tick_seconds"])
    acc = 0.0
    steps = 0
    limit = int(max_sec / dt) + 5
    while state.time_sec < max_sec and steps < limit:
        eco.tick(state, dt)
        steps += 1
        acc += dt
        if acc >= decide_every - 1e-12:
            acc = 0.0
            bot.decide(eco, state)
        if stop_rebirths and state.rebirth_count >= stop_rebirths:
            # Finish the instant so the rebirth milestone is recorded, then stop.
            break
    bot.decide(eco, state)
    return state


def run_offline_heavy(eco: Economy, max_sec: float = 72 * 3600, goal_rebirths: int = 5) -> GameState:
    """3 check-ins/day: 10 min active, then 8h offline, repeat."""
    bot = OfflineHeavy()
    state = fresh_state()
    dt = float(eco.balance["tick_seconds"])
    cycle_active = 10 * 60
    cycle_offline = 8 * 3600
    sessions = 0
    while state.time_sec < max_sec and state.rebirth_count < goal_rebirths and sessions < 12:
        sessions += 1
        end_active = state.time_sec + cycle_active
        acc = 0.0
        while state.time_sec < end_active and state.time_sec < max_sec:
            eco.tick(state, dt)
            acc += dt
            if acc >= 0.5 - 1e-12:
                acc = 0.0
                bot.decide(eco, state)
            if state.rebirth_count >= goal_rebirths:
                break
        if state.time_sec >= max_sec or state.rebirth_count >= goal_rebirths:
            break
        eco.apply_offline(state, cycle_offline)
        bot.decide(eco, state)
    return state


def rebirth_times(state: GameState) -> List[float]:
    out = []
    for i in range(1, 8):
        key = "rebirth:%d" % i
        if key not in state.milestones:
            break
        out.append(state.milestones[key])
    return out


def milestone_table(state: GameState, eco: Economy) -> List[dict]:
    keys = [
        "first_upgrade",
        "first_breakthrough",
        "rank:qi_early",
        "rank:foundation_early",
        "rank:foundation_late",
        "rank:core_early",
        "rank:core_peak",
        "rebirth_unlocked",
        "first_rebirth",
        "rebirth:2",
        "rebirth:3",
        "rebirth:4",
        "rebirth:5",
        "rank:nascent_early",
        "talent_roll:unlock",
        "artifact:jade_slip",
    ]
    rows = []
    seen = set()
    for k in keys:
        t = state.milestones.get(k)
        rows.append({"milestone": k, "time_sec": t, "time": fmt_time(t) if t is not None else "not reached"})
        seen.add(k)
    for r in eco.ranks:
        mid = f"rank:{r['id']}"
        if mid in state.milestones and mid not in seen:
            rows.append({"milestone": mid, "time_sec": state.milestones[mid], "time": fmt_time(state.milestones[mid])})
    return rows


def magnitude_ok(state: GameState, eco: Economy) -> List[str]:
    issues = []
    prod = eco.production(state)
    for name, val in (("qi", state.qi), ("lifetime_qi", state.lifetime_qi), ("prod", prod), ("karma", state.karma_shards)):
        if not math.isfinite(val):
            issues.append(f"{name} not finite")
        if val < -1e-6:
            issues.append(f"{name} negative")
    if abs(state.qi) > 1e300 or abs(prod) > 1e300:
        issues.append("magnitude exceeds 1e300")
    return issues


def pacing_issues_for(name: str, state: GameState, eco: Economy, walls: list) -> List[str]:
    t = eco.balance["pacing_targets_sec"]
    issues = []
    if name == "offline_heavy":
        r5 = state.milestones.get("rebirth:5")
        if r5 is None:
            issues.append("offline rebirth 5 not reached")
        elif r5 > t["offline_rebirth_5_calendar"]:
            issues.append(f"offline rebirth 5 late: {r5}")
        return issues
    if name not in ("rebirth_early", "best_roi", "talent_focused", "artifact_focused"):
        return issues
    fu = state.milestones.get("first_upgrade")
    if fu is None or fu > t["first_upgrade"]:
        issues.append(f"first_upgrade slow/missing: {fu}")
    fb = state.milestones.get("first_breakthrough")
    if fb is None or fb > t["first_breakthrough"]:
        issues.append(f"first_breakthrough slow/missing: {fb}")
    elif fb < t.get("first_breakthrough_min", 60):
        issues.append(f"first_breakthrough too fast: {fb}")
    if name == "best_roi":
        return issues
    fr = state.milestones.get("first_rebirth")
    if fr is None:
        issues.append("first_rebirth not reached")
    elif fr > t["first_rebirth"]:
        issues.append(f"first_rebirth slow: {fr}")
    elif fr < t["first_rebirth_min"]:
        issues.append(f"first_rebirth too fast: {fr}")
    times = rebirth_times(state)
    if len(times) < 5:
        issues.append(f"only {len(times)} rebirths in window")
    else:
        gaps = [times[0]] + [times[i] - times[i - 1] for i in range(1, 5)]
        for i in range(1, 5):
            if gaps[i] > gaps[i - 1] * 0.97:
                issues.append(
                    f"rebirth {i + 1} gap {gaps[i]:.0f}s not faster than previous {gaps[i - 1]:.0f}s"
                )
        if times[4] > t["rebirth_5_active"]:
            issues.append(f"rebirth 5 late: {times[4]}")
    early_mid = [w for w in walls if w["phase"] in ("early", "mid")]
    if early_mid:
        issues.append(f"walls {len(early_mid)}")
    return issues


def final_blob(eco: Economy, st: GameState) -> dict:
    return {
        "time": st.time_sec,
        "qi": st.qi,
        "prod": eco.production(st),
        "rank": eco.rank(st)["id"],
        "rank_index": st.rank_index,
        "rebirths": st.rebirth_count,
        "karma": st.karma_shards,
        "lifetime_qi": st.lifetime_qi,
        "talents": len(st.talents_owned),
        "artifacts": len(st.artifacts_owned),
        "shop_mult": st.shop_mult,
        "shop_levels": dict(st.shop_levels),
        "rebirth_times": rebirth_times(st),
    }


def write_chart(results: Dict[str, GameState], path: str) -> None:
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
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
    ax.set_title("Cultivation: Beyond Heaven — Stage 2 production")
    ax.legend(fontsize=8)
    ax.grid(True, which="both", alpha=0.3)
    fig.tight_layout()
    fig.savefig(path, dpi=120)
    plt.close(fig)


def main() -> int:
    eco = Economy()
    results = {}
    reports = {}

    active = [
        (GreedyCheapest(), 2 * 3600, 0),
        (BestROI(), 3 * 3600, 0),
        (RushBreakthrough(), 2 * 3600, 0),
        (RebirthEarly(), 5 * 3600, 5),
        (RebirthLate(), 5 * 3600, 5),
        (TalentFocused(), 5 * 3600, 5),
        (ArtifactFocused(), 5 * 3600, 5),
    ]
    for bot, horizon, stop_at in active:
        st = run_active(eco, bot, max_sec=horizon, stop_rebirths=stop_at)
        results[bot.name] = st
        walls = detect_walls(st, eco)
        lw, lk = longest_wait(st)
        issues = pacing_issues_for(bot.name, st, eco, walls) + magnitude_ok(st, eco)
        reports[bot.name] = {
            "milestones": milestone_table(st, eco),
            "longest_wait_sec": lw,
            "longest_wait_until": lk,
            "walls": walls,
            "magnitude_issues": magnitude_ok(st, eco),
            "pacing_issues": issues,
            "final": final_blob(eco, st),
        }
        print(f"=== {bot.name} ===")
        print(
            f"  final rank={eco.rank(st)['id']} rebirths={st.rebirth_count} "
            f"t={fmt_time(st.time_sec)} talents={len(st.talents_owned)} arts={len(st.artifacts_owned)}"
        )
        times = rebirth_times(st)
        if times:
            gaps = [times[0]] + [times[i] - times[i - 1] for i in range(1, len(times))]
            print("  rebirth gaps:", ", ".join(fmt_time(g) for g in gaps))
        for row in reports[bot.name]["milestones"][:8]:
            print(f"  {row['milestone']}: {row['time']}")
        print(f"  longest_wait={fmt_time(lw)} until {lk} walls={len(walls)}")
        if issues:
            print("  ISSUES:", "; ".join(issues))

    st = run_offline_heavy(eco, max_sec=72 * 3600, goal_rebirths=5)
    results["offline_heavy"] = st
    walls = detect_walls(st, eco)
    lw, lk = longest_wait(st)
    issues = pacing_issues_for("offline_heavy", st, eco, walls) + magnitude_ok(st, eco)
    reports["offline_heavy"] = {
        "milestones": milestone_table(st, eco),
        "longest_wait_sec": lw,
        "longest_wait_until": lk,
        "walls": walls,
        "magnitude_issues": magnitude_ok(st, eco),
        "pacing_issues": issues,
        "final": final_blob(eco, st),
        "note": "longest_wait includes 8h offline sleeps; active-player walls are not this bot",
    }
    print("=== offline_heavy ===")
    print(
        f"  final rank={eco.rank(st)['id']} rebirths={st.rebirth_count} t={fmt_time(st.time_sec)} "
        f"talents={len(st.talents_owned)} arts={len(st.artifacts_owned)}"
    )
    times = rebirth_times(st)
    if times:
        print("  rebirth at:", ", ".join(fmt_time(x) for x in times))
    if issues:
        print("  ISSUES:", "; ".join(issues))

    # best_roi mid wait is a stage-1 note: it should land under the configured cap.
    cap = float(eco.balance["pacing_targets_sec"]["best_roi_mid_wait_max"])
    if reports["best_roi"]["longest_wait_sec"] > cap:
        reports["best_roi"]["pacing_issues"].append(
            f"best_roi longest wait {reports['best_roi']['longest_wait_sec']:.0f}s > {cap:.0f}s"
        )
        print("  BEST_ROI WAIT TOO LONG", reports["best_roi"]["longest_wait_sec"])

    def score(name: str):
        st = results[name]
        fr = st.milestones.get("first_rebirth", 1e18)
        return (0 if fr < 1e17 else 1, fr, -st.rebirth_count)

    best_name = min([n for n in results if n != "offline_heavy"], key=score)
    summary = {
        "best_strategy": best_name,
        "targets": eco.balance["pacing_targets_sec"],
        "reports": reports,
    }
    out_json = os.path.join(REPORT_DIR, "sim_report.json")
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)

    md = ["# Simulation Report — Cultivation: Beyond Heaven (Stage 2)", ""]
    md.append(f"**Best strategy (active):** `{best_name}`")
    md.append("")
    md.append("## Milestone times (best strategy)")
    md.append("")
    md.append("| Milestone | Time |")
    md.append("|-----------|------|")
    for row in reports[best_name]["milestones"]:
        if row["time"] == "not reached" and row["milestone"].startswith("rank:"):
            continue
        md.append(f"| {row['milestone']} | {row['time']} |")
    md.append("")
    md.append("## Rebirth gaps")
    md.append("")
    md.append("| Strategy | R1 | R2 | R3 | R4 | R5 | Walls | Longest wait |")
    md.append("|----------|----|----|----|----|----|-------|--------------|")
    for name, rep in reports.items():
        times = rep["final"].get("rebirth_times") or []
        gaps = []
        if times:
            gaps = [times[0]] + [times[i] - times[i - 1] for i in range(1, len(times))]
        cells = [fmt_time(gaps[i]) if i < len(gaps) else "—" for i in range(5)]
        md.append(
            f"| {name} | {cells[0]} | {cells[1]} | {cells[2]} | {cells[3]} | {cells[4]} | {len(rep['walls'])} | {fmt_time(rep['longest_wait_sec'])} |"
        )
    md.append("")
    md.append("## Key milestones")
    md.append("")
    md.append("| Strategy | First upgrade | First BT | Core Peak | First Rebirth | Rebirth 5 |")
    md.append("|----------|---------------|----------|-----------|---------------|-----------|")
    for name, rep in reports.items():

        def gt(key, rep=rep):
            for r in rep["milestones"]:
                if r["milestone"] == key:
                    return r["time"]
            return "—"

        md.append(
            f"| {name} | {gt('first_upgrade')} | {gt('first_breakthrough')} | {gt('rank:core_peak')} | {gt('first_rebirth')} | {gt('rebirth:5')} |"
        )
    md.append("")
    md.append(f"## Pacing issues ({best_name})")
    focus = reports.get("rebirth_early", reports[best_name])
    for iss in focus["pacing_issues"] or ["none"]:
        md.append(f"- {iss}")
    md.append("")
    md.append(
        f"best_roi longest wait: {fmt_time(reports['best_roi']['longest_wait_sec'])} "
        f"until `{reports['best_roi']['longest_wait_until']}`"
    )
    md.append("")
    md.append(
        f"offline_heavy calendar to last recorded rebirth: {fmt_time(reports['offline_heavy']['final']['time'])} "
        f"rebirths={reports['offline_heavy']['final']['rebirths']}"
    )
    md_path = os.path.join(REPORT_DIR, "sim_report.md")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("\n".join(md) + "\n")

    chart_path = os.path.join(REPORT_DIR, "progress_chart.png")
    write_chart(results, chart_path)
    print(f"Wrote {out_json}")
    print(f"BEST={best_name}")
    failed = []
    for name in ("rebirth_early", "best_roi", "talent_focused", "artifact_focused", "offline_heavy"):
        if reports[name]["pacing_issues"] or reports[name]["magnitude_issues"]:
            failed.append(name)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
