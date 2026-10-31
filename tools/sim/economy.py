"""Economy engine — mirrors docs/FORMULAS.md and data/*.json."""
from __future__ import annotations
import json
import math
import os
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

# Simulator lives in tools/sim/; JSON SSOT is the repo-root data/ directory.
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data")


def load_json(name: str) -> dict:
    with open(os.path.join(DATA_DIR, name), "r", encoding="utf-8") as f:
        return json.load(f)


@dataclass
class GameState:
    qi: float = 0.0
    lifetime_qi: float = 0.0
    rank_index: int = 0
    highest_rank_index: int = 0
    upgrade_levels: Dict[str, int] = field(default_factory=dict)
    karma_shards: float = 0.0
    rebirth_count: int = 0
    unlocked: set = field(default_factory=set)
    time_sec: float = 0.0
    last_purchase_or_unlock_time: float = 0.0
    milestones: Dict[str, float] = field(default_factory=dict)
    history: List[Tuple[float, float, int]] = field(default_factory=list)  # t, qi/s, rank
    shop_mult: float = 1.0
    starting_qi_bonus: float = 0.0
    offline_eff_bonus: float = 0.0
    path_id: Optional[str] = None
    # stage-1 keeps path/talent/artifact at 1.0


class Economy:
    def __init__(self):
        self.balance = load_json("balance.json")
        self.ranks = load_json("ranks.json")["ranks"]
        self.upgrades = {u["id"]: u for u in load_json("upgrades.json")["upgrades"]}
        self.rebirth = load_json("rebirth.json")
        self.ranks_by_id = {r["id"]: r for r in self.ranks}

    def rank(self, state: GameState) -> dict:
        return self.ranks[state.rank_index]

    def unlocked_upgrades(self, state: GameState) -> List[dict]:
        rid = self.rank(state)["id"]
        ridx = state.rank_index
        out = []
        for u in self.upgrades.values():
            ureq = self.ranks_by_id[u["unlock_rank"]]["index"]
            if ridx >= ureq:
                out.append(u)
        return out

    def cost_reduction(self, state: GameState) -> float:
        total = 0.0
        for u in self.upgrades.values():
            if u["effect_type"] != "cost_reduction":
                continue
            lvl = state.upgrade_levels.get(u["id"], 0)
            total += u["effect_value"] * lvl
        return min(0.8, total)

    def upgrade_cost(self, state: GameState, uid: str) -> float:
        u = self.upgrades[uid]
        lvl = state.upgrade_levels.get(uid, 0)
        raw = u["base_cost"] * (u["growth"] ** lvl)
        return raw * (1.0 - self.cost_reduction(state))

    def production(self, state: GameState) -> float:
        base = float(self.balance["base_qi_per_sec"])
        flat_sum = 0.0
        mult_add = 0.0  # additive pool: total mult = 1 + mult_add
        speed_mult = 1.0
        for u in self.upgrades.values():
            lvl = state.upgrade_levels.get(u["id"], 0)
            if lvl <= 0:
                continue
            et = u["effect_type"]
            ev = u["effect_value"]
            if et == "flat_prod":
                flat_sum += ev * lvl
            elif et == "mult_prod":
                mult_add += ev * lvl
            elif et == "speed_mult":
                speed_mult += ev * lvl
        rank_mult = float(self.rank(state)["prod_mult"])
        perm = float(self.rebirth["tiers"][0]["perm_mult_per_karma"])
        karma_mult = 1.0 + state.karma_shards * perm
        return (
            base
            * (1.0 + flat_sum)
            * (1.0 + mult_add)
            * rank_mult
            * karma_mult
            * state.shop_mult
            * speed_mult
        )

    def can_buy_upgrade(self, state: GameState, uid: str) -> bool:
        u = self.upgrades[uid]
        if state.rank_index < self.ranks_by_id[u["unlock_rank"]]["index"]:
            return False
        lvl = state.upgrade_levels.get(uid, 0)
        mx = u.get("max_level") or 0
        if mx > 0 and lvl >= mx:
            return False
        return state.qi >= self.upgrade_cost(state, uid)

    def buy_upgrade(self, state: GameState, uid: str) -> bool:
        if not self.can_buy_upgrade(state, uid):
            return False
        cost = self.upgrade_cost(state, uid)
        state.qi -= cost
        state.upgrade_levels[uid] = state.upgrade_levels.get(uid, 0) + 1
        state.last_purchase_or_unlock_time = state.time_sec
        key = f"upgrade:{uid}:L{state.upgrade_levels[uid]}"
        if key not in state.milestones:
            state.milestones[key] = state.time_sec
        if "first_upgrade" not in state.milestones:
            state.milestones["first_upgrade"] = state.time_sec
        return True

    def can_breakthrough(self, state: GameState) -> bool:
        if state.rank_index + 1 >= len(self.ranks):
            return False
        nxt = self.ranks[state.rank_index + 1]
        return state.qi >= float(nxt["cost_qi"])

    def breakthrough(self, state: GameState) -> bool:
        if not self.can_breakthrough(state):
            return False
        nxt = self.ranks[state.rank_index + 1]
        state.qi -= float(nxt["cost_qi"])
        state.rank_index += 1
        state.highest_rank_index = max(state.highest_rank_index, state.rank_index)
        state.last_purchase_or_unlock_time = state.time_sec
        for u in nxt.get("unlocks") or []:
            state.unlocked.add(u)
        mid = f"rank:{nxt['id']}"
        if mid not in state.milestones:
            state.milestones[mid] = state.time_sec
        if state.rank_index == 1 and "first_breakthrough" not in state.milestones:
            state.milestones["first_breakthrough"] = state.time_sec
        if "rebirth_unlock" in (nxt.get("unlocks") or []) and "rebirth_unlocked" not in state.milestones:
            state.milestones["rebirth_unlocked"] = state.time_sec
        return True

    def karma_gain(self, state: GameState) -> int:
        f = self.rebirth["formula"]
        lq = max(1.0, state.lifetime_qi)
        return int(
            math.floor(
                f["base"]
                + math.log10(lq) / f["from_lifetime_qi_log10_div"]
                + state.highest_rank_index * f["from_highest_rank_index"]
            )
        )

    def can_rebirth(self, state: GameState) -> bool:
        return state.rank_index >= int(self.rebirth["min_rank_index_to_rebirth"])

    def do_rebirth(self, state: GameState) -> bool:
        if not self.can_rebirth(state):
            return False
        gain = self.karma_gain(state)
        state.karma_shards += gain
        state.rebirth_count += 1
        state.qi = state.starting_qi_bonus
        state.upgrade_levels = {}
        state.rank_index = 0
        # start rank boost from tiers
        for t in self.rebirth["tiers"]:
            if state.rebirth_count >= t["min_rebirths"] and t.get("start_rank_bonus"):
                state.rank_index = min(t["start_rank_bonus"], len(self.ranks) - 1)
        state.last_purchase_or_unlock_time = state.time_sec
        state.milestones[f"rebirth:{state.rebirth_count}"] = state.time_sec
        if "first_rebirth" not in state.milestones:
            state.milestones["first_rebirth"] = state.time_sec
        return True

    def tick(self, state: GameState, dt: float) -> None:
        prod = self.production(state)
        gained = prod * dt
        state.qi += gained
        state.lifetime_qi += gained
        state.time_sec += dt
        # sample history every ~5s
        if not state.history or state.time_sec - state.history[-1][0] >= 5.0:
            state.history.append((state.time_sec, prod, state.rank_index))

    def apply_offline(self, state: GameState, absent_sec: float) -> float:
        off = self.balance["offline"]
        eff = float(off["efficiency"]) + state.offline_eff_bonus
        eff = min(1.0, eff)
        soft = float(off["soft_cap_hours"]) * 3600
        hard = float(off["hard_cap_hours"]) * 3600
        absent_sec = min(absent_sec, hard)
        prod = self.production(state)
        if absent_sec <= soft:
            gained = prod * absent_sec * eff
        else:
            full = prod * soft * eff
            rest = absent_sec - soft
            gained = full + prod * rest * eff * 0.5
        state.qi += gained
        state.lifetime_qi += gained
        state.time_sec += absent_sec  # wall-clock progress for bots that model offline
        return gained
