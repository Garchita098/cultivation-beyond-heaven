"""Achievements. A zero bonus does not multiply production."""
from __future__ import annotations

import math
from typing import List


def _rows(eco) -> list:
    return list(getattr(eco, "achievements", []) or [])


def sync(eco, state) -> List[str]:
    owned = state.achievements
    fresh: List[str] = []
    for ach in _rows(eco):
        aid = ach["id"]
        if aid in owned:
            continue
        if _met(state, ach):
            owned.add(aid)
            fresh.append(aid)
    if fresh:
        state.fresh_achievements = list(fresh)
    return fresh


def qi_mult(eco, state) -> float:
    if not state.achievements:
        return 1.0
    total = 0.0
    owned = state.achievements
    for ach in _rows(eco):
        if ach["id"] not in owned:
            continue
        if ach.get("bonus_type") == "qi_mult":
            total += float(ach.get("bonus_value", 0.0))
    if total <= 0.0:
        return 1.0
    return 1.0 + total


def offline_bonus(eco, state) -> float:
    if not state.achievements:
        return 0.0
    total = 0.0
    for ach in _rows(eco):
        if ach["id"] not in state.achievements:
            continue
        if ach.get("bonus_type") == "offline":
            total += float(ach.get("bonus_value", 0.0))
    return total


def track_tick(state, dt: float) -> None:
    if dt <= 0.0:
        return
    stats = state.stats
    if state.path_joined and state.path_id:
        path_sec = stats.setdefault("path_sec", {})
        path_sec[state.path_id] = float(path_sec.get(state.path_id, 0.0)) + dt
    worlds = stats.setdefault("worlds", [])
    if state.world_id not in worlds:
        worlds.append(state.world_id)


def on_rebirth(state) -> None:
    start = float(state.stats.get("segment_start", 0.0))
    dur = float(state.time_sec) - start
    best = float(state.stats.get("best_rebirth_sec", 0.0))
    if dur > 1.0 and (best <= 0.0 or dur < best):
        state.stats["best_rebirth_sec"] = dur
    state.stats["segment_start"] = float(state.time_sec)


def on_ascension(state) -> None:
    start = float(state.stats.get("asc_segment_start", 0.0))
    dur = float(state.time_sec) - start
    best = float(state.stats.get("fastest_ascension_sec", 0.0))
    if dur > 1.0 and (best <= 0.0 or dur < best):
        state.stats["fastest_ascension_sec"] = dur
    state.stats["asc_segment_start"] = float(state.time_sec)
    state.stats["segment_start"] = float(state.time_sec)


def on_offline(state, absent: float) -> None:
    if absent <= 0.0:
        return
    state.stats["offline_sec"] = float(state.stats.get("offline_sec", 0.0)) + float(absent)


def _met(state, ach) -> bool:
    if int(ach.get("min_ascension", 0)) > int(state.ascension_count):
        return False
    metric = str(ach.get("metric", ""))
    goal = ach.get("goal", 0)
    if metric == "rank_index":
        return int(state.highest_rank_index) >= int(goal)
    if metric == "rebirths":
        return int(state.rebirth_count) >= int(goal)
    if metric == "ascensions":
        return int(state.ascension_count) >= int(goal)
    if metric == "path":
        return bool(state.path_joined) and str(state.path_id or "") == str(goal)
    if metric == "world":
        worlds = state.stats.get("worlds", [])
        return state.world_id == str(goal) or str(goal) in worlds or ("world:" + str(goal)) in state.unlocked
    if metric == "research":
        return len(state.research_done) >= int(goal)
    if metric == "study":
        return str(goal) in state.research_done
    if metric == "artifacts":
        return len(state.artifacts_owned) >= int(goal)
    if metric == "offline_sec":
        return float(state.stats.get("offline_sec", 0.0)) >= float(goal)
    if metric == "time_sec":
        return float(state.time_sec) >= float(goal)
    if metric == "lifetime_exp":
        return _exp(state.lifetime_qi) >= float(goal)
    if metric == "qi_exp":
        return _exp(state.qi) >= float(goal)
    if metric == "sacrifices":
        return int(state.sacrifice_count) >= int(goal)
    if metric == "tribulations":
        return int(state.tribulation_cycle) >= int(goal)
    return False


def _exp(value) -> float:
    x = float(value)
    if not math.isfinite(x) or x <= 1.0:
        return 0.0
    return math.log(x) / math.log(10.0)
