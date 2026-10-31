"""Economy engine — mirrors docs/FORMULAS.md and data/*.json.

Stage 3 adds path rules, worlds, research, and ascension. A run with no joined
path, the mortal world, and no laws still uses the stage-2 formula unchanged.
"""
from __future__ import annotations

import itertools
import json
import math
import os
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Sequence, Tuple

import stage3

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data")

# Ranks with stage <= STAGE_CAP are playable. Later ranks stay on the ladder.
STAGE_CAP = 3

# Path-only artifact effects. Until that path is live they contribute a fraction
# of their value as a production multiplier (see artifacts.stage2_hook_as_mult).
HOOK_EFFECTS = {
    "sacrifice_efficiency",
    "absorb_rate",
    "time_skip_charge",
    "rule_slot",
}

AUTO_ORDER_MAX = 7  # automation steps 1–7 are live in stage 3


def load_json(name: str) -> dict:
    with open(os.path.join(DATA_DIR, name), "r", encoding="utf-8") as f:
        return json.load(f)


def cbh_unit(n: int) -> float:
    """Deterministic [0, 1) shared with GDScript. Stays inside signed 63-bit."""
    n = int(n) & 0x7FFFFFFF
    n = (n * 1103515245 + 12345) & 0x7FFFFFFF
    return n / 2147483648.0


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
    history: List[Tuple[float, float, int]] = field(default_factory=list)
    shop_mult: float = 1.0
    starting_qi_bonus: float = 0.0
    offline_eff_bonus: float = 0.0
    path_id: Optional[str] = None
    talents_owned: List[dict] = field(default_factory=list)
    talents_equipped: List[str] = field(default_factory=list)
    talent_seq: int = 1
    talent_roll_keys: set = field(default_factory=set)
    reroll_count: int = 0
    artifacts_owned: Dict[str, int] = field(default_factory=dict)
    artifacts_equipped: List[str] = field(default_factory=list)
    shop_levels: Dict[str, int] = field(default_factory=dict)
    automation_toggles: Dict[str, bool] = field(default_factory=dict)
    auto_buy_mode: str = "roi"
    auto_rebirth_min_rank: int = 15
    auto_rebirth_min_karma: int = 1
    path_joined: bool = False
    path_currency: float = 0.0
    path_nodes: Dict[str, int] = field(default_factory=dict)
    sword_charge: float = 0.0
    burst_left: float = 0.0
    demon_permanent: float = 0.0
    demon_fed: float = 0.0
    cultivated_hours: float = 0.0
    devour_types: set = field(default_factory=set)
    devour_bonus: float = 0.0
    chrono_charge: float = 0.0
    speed_left: float = 0.0
    banked_sec: float = 0.0
    skip_used_sec: float = 0.0
    world_id: str = "mortal_world"
    world_res: Dict[str, float] = field(default_factory=dict)
    essence_ratio: float = 0.0
    retain_seconds: float = 180.0
    stance: str = "guard"
    tribulation_t: float = 0.0
    tribulation_cycle: int = 0
    boon_left: float = 0.0
    penalty_left: float = 0.0
    chaos_pulse_t: float = 0.0
    slotted_laws: List[str] = field(default_factory=list)
    active_rewrite: str = ""
    research_done: set = field(default_factory=set)
    research_order: List[str] = field(default_factory=list)
    research_progress: float = 0.0
    dao_marks: float = 0.0
    ascension_count: int = 0
    reality_mode: str = "still"
    path_switch_count: int = 0
    sacrifice_count: int = 0
    mechanic_counts: Dict[str, int] = field(default_factory=dict)
    _talent_sig: str = ""


class Economy:
    def __init__(self):
        self.balance = load_json("balance.json")
        self.ranks = load_json("ranks.json")["ranks"]
        loaded_upgrades = load_json("upgrades.json")["upgrades"]
        self.upgrades = {u["id"]: u for u in loaded_upgrades}
        self.upgrade_order = [u["id"] for u in loaded_upgrades]
        self.rebirth = load_json("rebirth.json")
        self.talents = load_json("talents.json")
        self.artifacts_doc = load_json("artifacts.json")
        self.automation = load_json("automation.json")
        self.paths_doc = load_json("paths.json")
        self.paths_by_id = {p["id"]: p for p in self.paths_doc["paths"]}
        self.worlds_doc = load_json("worlds.json")
        self.worlds_by_id = {w["id"]: w for w in self.worlds_doc["worlds"]}
        self.research = load_json("research.json")
        self.ranks_by_id = {r["id"]: r for r in self.ranks}
        self.shop_by_id = {s["id"]: s for s in self.rebirth["shop"]}
        self.roots_by_id = {r["id"]: r for r in self.talents["roots"]}
        self.rarity_by_id = {r["id"]: r for r in self.talents["rarities"]}
        self.artifacts_by_id = {a["id"]: a for a in self.artifacts_doc["artifacts"]}
        self.drop_order = list(self.artifacts_doc["drop_order"])
        defaults = self.automation.get("auto_rebirth_defaults", {})
        self.default_rebirth_rank = int(defaults.get("min_rank_index", 15))
        self.default_rebirth_karma = int(defaults.get("min_karma_gain", 1))

    # ----- ranks -----

    def rank(self, state: GameState) -> dict:
        return self.ranks[state.rank_index]

    def max_playable_index(self) -> int:
        last = 0
        for r in self.ranks:
            if int(r.get("stage", 1)) <= STAGE_CAP:
                last = int(r["index"])
        return last

    def next_rank(self, state: GameState) -> Optional[dict]:
        if state.rank_index + 1 >= len(self.ranks):
            return None
        nxt = self.ranks[state.rank_index + 1]
        if int(nxt.get("stage", 1)) > STAGE_CAP:
            return None
        return nxt

    def unlocked_upgrades(self, state: GameState) -> List[dict]:
        out = []
        for uid in self.upgrade_order:
            u = self.upgrades[uid]
            ureq = self.ranks_by_id[u["unlock_rank"]]["index"]
            if state.rank_index >= ureq:
                out.append(u)
        return out

    # ----- talents / artifacts modifiers -----

    def _talent_value(self, talent: dict) -> float:
        gain = float(self.talents["upgrade"]["effect_gain_per_level"])
        return float(talent["roll"]) + int(talent.get("level", 0)) * gain

    def _path_tags(self, state: GameState) -> set:
        if not state.path_id:
            return set()
        return set(self.talents.get("path_tags", {}).get(state.path_id, []))

    def talent_mods(self, state: GameState, equipped_ids: Optional[Sequence[str]] = None) -> dict:
        if equipped_ids is None:
            equipped_ids = state.talents_equipped
        idset = set(equipped_ids)
        equipped = [t for t in state.talents_owned if t["uid"] in idset]
        mult = 1.0
        flat = 0.0
        speed = 0.0
        cost = 0.0
        offline = 0.0
        elements: List[str] = []
        tags = self._path_tags(state)
        for t in equipped:
            root = self.roots_by_id[t["root_id"]]
            value = self._talent_value(t)
            syn = 0.0
            if tags and any(tag in tags for tag in root.get("synergy_with", [])):
                syn = float(root.get("synergy_bonus", 0.0))
            et = root["effect_type"]
            if et == "mult_prod":
                mult *= 1.0 + value
                if syn:
                    mult *= 1.0 + syn
            elif et == "flat_prod":
                flat += value + syn
            elif et == "speed_mult":
                speed += value + syn
            elif et == "cost_reduction":
                cost += value + syn
            elif et == "offline_bonus":
                offline += value + syn
            elements.append(root["element"])
        for pair in self.talents.get("element_synergies", []):
            if pair["a"] in elements and pair["b"] in elements:
                mult *= 1.0 + float(pair["bonus"])
        return {
            "mult": mult,
            "flat": flat,
            "speed": speed,
            "cost": cost,
            "offline": offline,
        }

    def _artifact_scaled(self, state: GameState, aid: str) -> Tuple[dict, float]:
        art = self.artifacts_by_id[aid]
        level = int(state.artifacts_owned.get(aid, 0))
        frac = float(self.artifacts_doc["upgrade"]["effect_gain_fraction"])
        ev = float(art["effect_value"]) * (1.0 + frac * level)
        if state.path_id and state.path_id == art.get("path_bonus"):
            ev *= float(self.artifacts_doc.get("path_match_effect_scale", 1.5))
        return art, ev

    def artifact_mods(self, state: GameState, equipped: Optional[Sequence[str]] = None) -> dict:
        if equipped is None:
            equipped = state.artifacts_equipped
        mult = 1.0
        flat = 0.0
        speed = 0.0
        offline = 0.0
        discount = 0.0
        hook_frac = float(self.artifacts_doc.get("stage2_hook_as_mult", 0.5))
        for aid in equipped:
            if aid not in state.artifacts_owned:
                continue
            art, ev = self._artifact_scaled(state, aid)
            et = art["effect_type"]
            if et == "mult_prod":
                mult *= 1.0 + ev
            elif et == "flat_prod":
                flat += ev
            elif et == "speed_mult":
                speed += ev
            elif et == "offline_bonus":
                offline += ev
            elif et == "breakthrough_discount":
                discount += ev
            elif et in HOOK_EFFECTS and not stage3.hook_consumed(self, state, et):
                mult *= 1.0 + ev * hook_frac
        return {
            "mult": mult,
            "flat": flat,
            "speed": speed,
            "offline": offline,
            "discount": min(0.5, discount),
        }

    def talent_score(self, state: GameState, ids: Sequence[str]) -> float:
        m = self.talent_mods(state, ids)
        return (
            m["mult"] * 1000.0
            + m["flat"]
            + m["speed"] * 50.0
            + m["offline"] * 20.0
            + m["cost"] * 30.0
        )

    def artifact_score(self, state: GameState, aid: str) -> float:
        if aid not in state.artifacts_owned:
            return -1.0
        art, ev = self._artifact_scaled(state, aid)
        weights = {
            "mult_prod": 3.0,
            "offline_bonus": 2.0,
            "breakthrough_discount": 2.5,
            "flat_prod": 0.15,
            "speed_mult": 2.0,
        }
        w = weights.get(art["effect_type"], 1.0)
        return ev * w

    # ----- production / costs -----

    def refresh_derived(self, state: GameState) -> None:
        prod = self.shop_by_id["karma_prod_1"]
        state.shop_mult = 1.0 + float(prod["value"]) * int(state.shop_levels.get("karma_prod_1", 0))
        start = self.shop_by_id["karma_start_qi"]
        state.starting_qi_bonus = float(start["value"]) * int(state.shop_levels.get("karma_start_qi", 0))

    def offline_bonus(self, state: GameState) -> float:
        bonus = float(state.offline_eff_bonus)
        for tier in self.rebirth["tiers"]:
            if state.rebirth_count >= int(tier["min_rebirths"]):
                bonus += float(tier.get("offline_efficiency_bonus", 0.0))
        item = self.shop_by_id["karma_offline"]
        lvl = int(state.shop_levels.get("karma_offline", 0))
        mx = int(item.get("max", lvl))
        bonus += float(item["value"]) * min(lvl, mx)
        bonus += self.talent_mods(state)["offline"]
        bonus += self.artifact_mods(state)["offline"]
        bonus += stage3.extra_offline_bonus(self, state)
        return bonus

    def cost_reduction(self, state: GameState) -> float:
        total = self.talent_mods(state)["cost"]
        for uid in self.upgrade_order:
            u = self.upgrades[uid]
            if u["effect_type"] != "cost_reduction":
                continue
            lvl = state.upgrade_levels.get(uid, 0)
            total += u["effect_value"] * lvl
        return min(0.8, total)

    def upgrade_cost(self, state: GameState, uid: str) -> float:
        u = self.upgrades[uid]
        lvl = state.upgrade_levels.get(uid, 0)
        reduction = self.cost_reduction(state)
        raw = u["base_cost"] * (u["growth"] ** lvl)
        cost = raw * (1.0 - reduction)
        return stage3.adjust_cost(self, state, cost, u["base_cost"], u["growth"], lvl, reduction)

    def production(self, state: GameState) -> float:
        self.refresh_derived(state)
        base = float(self.balance["base_qi_per_sec"])
        tmods = self.talent_mods(state)
        amods = self.artifact_mods(state)
        flat_sum = tmods["flat"] + amods["flat"]
        mult_add = 0.0
        speed_mult = 1.0 + tmods["speed"] + amods["speed"]
        for uid in self.upgrade_order:
            u = self.upgrades[uid]
            lvl = state.upgrade_levels.get(uid, 0)
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
        prod = (
            base
            * (1.0 + flat_sum)
            * (1.0 + mult_add)
            * rank_mult
            * karma_mult
            * state.shop_mult
            * tmods["mult"]
            * amods["mult"]
            * speed_mult
        )
        return stage3.adjust_prod(
            self,
            state,
            prod,
            {"flat_sum": flat_sum, "mult_add": mult_add, "speed_mult": speed_mult},
        )

    def breakthrough_cost(self, state: GameState) -> Optional[float]:
        nxt = self.next_rank(state)
        if nxt is None:
            return None
        disc = self.artifact_mods(state)["discount"]
        cost = float(nxt["cost_qi"]) * (1.0 - disc)
        return stage3.adjust_breakthrough(self, state, cost)

    # ----- upgrades / breakthrough -----

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
        u = self.upgrades[uid]
        state.qi -= cost
        state.upgrade_levels[uid] = state.upgrade_levels.get(uid, 0) + 1
        extra = stage3.bonus_levels(self, state, int(state.upgrade_levels[uid]))
        if extra:
            mx = int(u.get("max_level") or 0)
            nxt = int(state.upgrade_levels[uid]) + extra
            if mx <= 0 or nxt <= mx:
                state.upgrade_levels[uid] = nxt
        state.last_purchase_or_unlock_time = state.time_sec
        key = f"upgrade:{uid}:L{state.upgrade_levels[uid]}"
        if key not in state.milestones:
            state.milestones[key] = state.time_sec
        if "first_upgrade" not in state.milestones:
            state.milestones["first_upgrade"] = state.time_sec
        return True

    def can_breakthrough(self, state: GameState) -> bool:
        cost = self.breakthrough_cost(state)
        if cost is None:
            return False
        return state.qi >= cost

    def _mark(self, state: GameState, key: str) -> None:
        if key not in state.milestones:
            state.milestones[key] = state.time_sec

    def on_rank_entered(self, state: GameState, rank: dict) -> None:
        for feature in rank.get("unlocks") or []:
            state.unlocked.add(feature)
        if "spiritual_roots" in (rank.get("unlocks") or []):
            self.grant_talent_once(state, "unlock", int(self.talents["roll_seed_unlock"]))
        rid = rank["id"]
        if rid in self.talents.get("milestone_ranks", []) and rid != self.talents.get("unlock_rank"):
            seed = 84000 + int(rank["index"])
            self.grant_talent_once(state, "rank:" + rid, seed)
        if "artifacts_basic" in (rank.get("unlocks") or []):
            if not state.artifacts_owned:
                self.grant_next_artifact(state)

    def breakthrough(self, state: GameState) -> bool:
        if not self.can_breakthrough(state):
            return False
        nxt = self.next_rank(state)
        cost = self.breakthrough_cost(state)
        spent = stage3.bank_spent_on_breakthrough(self, state)
        if spent > 0.0:
            state.banked_sec = max(0.0, state.banked_sec - spent)
        state.qi -= float(cost)
        state.rank_index += 1
        state.highest_rank_index = max(state.highest_rank_index, state.rank_index)
        state.last_purchase_or_unlock_time = state.time_sec
        self.on_rank_entered(state, nxt)
        self._mark(state, f"rank:{nxt['id']}")
        if state.rank_index == 1:
            self._mark(state, "first_breakthrough")
        if "rebirth_unlock" in (nxt.get("unlocks") or []):
            self._mark(state, "rebirth_unlocked")
        return True

    def _apply_start_rank(self, state: GameState) -> None:
        bonus = 0
        for tier in self.rebirth["tiers"]:
            if state.rebirth_count >= int(tier["min_rebirths"]):
                bonus = max(bonus, int(tier.get("start_rank_bonus", 0)))
        bonus = min(bonus, self.max_playable_index())
        if bonus <= 0:
            return
        # Walk each skipped rank so its feature flags latch. Rolls are once-ever.
        while state.rank_index < bonus:
            nxt = self.ranks[state.rank_index + 1]
            state.rank_index += 1
            state.highest_rank_index = max(state.highest_rank_index, state.rank_index)
            self.on_rank_entered(state, nxt)

    # ----- talents -----

    def roll_talent_fields(self, seed: int) -> dict:
        rarities = self.talents["rarities"]
        total = sum(float(r["weight"]) for r in rarities)
        u = cbh_unit(seed) * total
        acc = 0.0
        rarity = rarities[-1]
        for r in rarities:
            acc += float(r["weight"])
            if u < acc:
                rarity = r
                break
        roots = self.talents["roots"]
        ri = int(cbh_unit(seed + 17) * len(roots))
        if ri >= len(roots):
            ri = len(roots) - 1
        root = roots[ri]
        lo, hi = float(rarity["mult_range"][0]), float(rarity["mult_range"][1])
        t = cbh_unit(seed + 41)
        roll = lo + (hi - lo) * t
        return {"root_id": root["id"], "rarity": rarity["id"], "roll": roll}

    def grant_talent(self, state: GameState, seed: int) -> dict:
        rolled = self.roll_talent_fields(seed)
        talent = {
            "uid": "t%d" % state.talent_seq,
            "root_id": rolled["root_id"],
            "rarity": rolled["rarity"],
            "roll": rolled["roll"],
            "level": 0,
        }
        state.talent_seq += 1
        state.talents_owned.append(talent)
        cap = int(self.talents["max_equipped"])
        if len(state.talents_equipped) < cap:
            state.talents_equipped.append(talent["uid"])
        self._mark(state, "talent:%s" % talent["uid"])
        return talent

    def grant_talent_once(self, state: GameState, key: str, seed: int) -> Optional[dict]:
        if key in state.talent_roll_keys:
            return None
        if "spiritual_roots" not in state.unlocked and key != "unlock":
            return None
        state.talent_roll_keys.add(key)
        talent = self.grant_talent(state, seed)
        self._mark(state, "talent_roll:%s" % key)
        return talent

    def talent_power(self, state: GameState, talent: dict) -> float:
        value = self._talent_value(talent)
        root = self.roots_by_id[talent["root_id"]]
        weights = {
            "mult_prod": 3.0,
            "speed_mult": 2.5,
            "cost_reduction": 2.2,
            "offline_bonus": 1.6,
            "flat_prod": 0.4,
        }
        return value * weights.get(root["effect_type"], 1.0)

    def equip_best_talents(self, state: GameState) -> None:
        owned = state.talents_owned
        cap = int(self.talents["max_equipped"])
        n = min(cap, len(owned))
        sig = "|".join(
            "%s:%s:%s:%s" % (t["uid"], t.get("level", 0), t.get("root_id"), t.get("roll"))
            for t in owned
        ) + "#%d#%s" % (n, state.path_id or "")
        if n > 0 and sig == state._talent_sig and state.talents_equipped:
            return
        state._talent_sig = sig
        if n <= 0:
            state.talents_equipped = []
            return
        best_ids: Optional[Tuple[str, ...]] = None
        best_score = None
        for combo in itertools.combinations(owned, n):
            ids = tuple(sorted(t["uid"] for t in combo))
            score = self.talent_score(state, ids)
            if best_score is None or score > best_score + 1e-12 or (
                abs(score - best_score) <= 1e-12 and (best_ids is None or ids < best_ids)
            ):
                best_score = score
                best_ids = ids
        state.talents_equipped = list(best_ids or ())

    def talent_upgrade_cost(self, level: int) -> int:
        up = self.talents["upgrade"]
        raw = float(up["cost_base"]) * (float(up["cost_growth"]) ** level)
        return max(1, int(math.floor(raw + 1e-9)))

    def can_upgrade_talent(self, state: GameState, uid: str) -> bool:
        talent = next((t for t in state.talents_owned if t["uid"] == uid), None)
        if talent is None:
            return False
        mx = int(self.talents["upgrade"]["max_level"])
        if int(talent["level"]) >= mx:
            return False
        return state.karma_shards >= self.talent_upgrade_cost(int(talent["level"]))

    def upgrade_talent(self, state: GameState, uid: str) -> bool:
        if not self.can_upgrade_talent(state, uid):
            return False
        talent = next(t for t in state.talents_owned if t["uid"] == uid)
        cost = self.talent_upgrade_cost(int(talent["level"]))
        state.karma_shards -= cost
        talent["level"] = int(talent["level"]) + 1
        self._mark(state, "talent_up:%s:L%d" % (uid, talent["level"]))
        return True

    def reroll_talent(self, state: GameState, uid: str) -> bool:
        if state.rebirth_count < 3 and "talent_reroll" not in state.unlocked:
            return False
        if "talent_reroll" not in state.unlocked and state.rebirth_count < 3:
            return False
        cost = int(self.rebirth.get("talent_reroll_cost", 4))
        if state.karma_shards < cost:
            return False
        talent = next((t for t in state.talents_owned if t["uid"] == uid), None)
        if talent is None:
            return False
        state.karma_shards -= cost
        state.reroll_count += 1
        seed = int(self.talents["roll_seed_reroll_base"]) + state.reroll_count
        rolled = self.roll_talent_fields(seed)
        talent["root_id"] = rolled["root_id"]
        talent["rarity"] = rolled["rarity"]
        talent["roll"] = rolled["roll"]
        self._mark(state, "reroll:%d" % state.reroll_count)
        return True

    # ----- artifacts -----

    def grant_next_artifact(self, state: GameState) -> Optional[str]:
        for aid in self.drop_order:
            if aid not in state.artifacts_owned:
                state.artifacts_owned[aid] = 0
                self._consider_equip_artifact(state, aid)
                self._mark(state, "artifact:%s" % aid)
                return aid
        mx = int(self.artifacts_doc["upgrade"]["max_level"])
        candidates = [
            aid
            for aid in self.drop_order
            if aid in state.artifacts_owned and int(state.artifacts_owned[aid]) < mx
        ]
        if not candidates:
            return None
        candidates.sort(key=lambda a: (int(state.artifacts_owned[a]), self.drop_order.index(a)))
        aid = candidates[0]
        state.artifacts_owned[aid] = int(state.artifacts_owned[aid]) + 1
        self._mark(state, "artifact_dup:%s:L%d" % (aid, state.artifacts_owned[aid]))
        return aid

    def _consider_equip_artifact(self, state: GameState, aid: str) -> None:
        """Fill an empty slot only. Replacing a relic is a deliberate loadout change."""
        if aid in state.artifacts_equipped:
            return
        cap = int(self.artifacts_doc["max_equipped"])
        if len(state.artifacts_equipped) < cap:
            state.artifacts_equipped.append(aid)

    def equip_artifacts_for(self, state: GameState, style: str) -> None:
        owned = [a for a in self.drop_order if a in state.artifacts_owned]
        cap = min(int(self.artifacts_doc["max_equipped"]), len(owned))
        if cap <= 0:
            state.artifacts_equipped = []
            return
        hook_frac = float(self.artifacts_doc.get("stage2_hook_as_mult", 0.5))

        def score(aid: str) -> float:
            art, ev = self._artifact_scaled(state, aid)
            et = art["effect_type"]
            if style == "offline" and et == "offline_bonus":
                return 10.0 + ev * 5.0
            if et == "mult_prod":
                return ev * 4.0
            if et in HOOK_EFFECTS:
                return ev * hook_frac * 3.0
            if et == "breakthrough_discount":
                return ev * 2.5
            if et == "speed_mult":
                return ev * 3.0
            if et == "flat_prod":
                return ev * 0.04
            if et == "offline_bonus":
                return ev * 0.3
            return ev

        ranked = sorted(owned, key=lambda a: (-score(a), self.drop_order.index(a)))
        state.artifacts_equipped = ranked[:cap]

    def artifact_upgrade_cost(self, level: int) -> float:
        up = self.artifacts_doc["upgrade"]
        return float(up["cost_base"]) * (float(up["cost_growth"]) ** level)

    def upgrade_artifact(self, state: GameState, aid: str) -> bool:
        if aid not in state.artifacts_owned:
            return False
        level = int(state.artifacts_owned[aid])
        mx = int(self.artifacts_doc["upgrade"]["max_level"])
        if level >= mx:
            return False
        cost = self.artifact_upgrade_cost(level)
        if state.qi < cost:
            return False
        state.qi -= cost
        state.artifacts_owned[aid] = level + 1
        self._mark(state, "art_up:%s:L%d" % (aid, level + 1))
        return True

    # ----- shop / rebirth -----

    def shop_cost(self, item_id: str, level: int) -> int:
        item = self.shop_by_id[item_id]
        raw = float(item["cost"]) * (float(item["growth"]) ** level)
        return max(1, int(math.floor(raw + 1e-9)))

    def can_buy_shop(self, state: GameState, item_id: str) -> bool:
        if "karma_shop_basic" not in state.unlocked and state.rebirth_count < 1:
            return False
        item = self.shop_by_id[item_id]
        if item_id == "karma_keep_upgrade" and "karma_shop_advanced" not in state.unlocked:
            if state.rebirth_count < 10:
                return False
        level = int(state.shop_levels.get(item_id, 0))
        mx = int(item.get("max", 0) or 0)
        if mx > 0 and level >= mx:
            return False
        if not item.get("repeatable", True) and level >= 1:
            return False
        return state.karma_shards >= self.shop_cost(item_id, level)

    def buy_shop(self, state: GameState, item_id: str) -> bool:
        if not self.can_buy_shop(state, item_id):
            return False
        level = int(state.shop_levels.get(item_id, 0))
        state.karma_shards -= self.shop_cost(item_id, level)
        state.shop_levels[item_id] = level + 1
        self.refresh_derived(state)
        self._mark(state, "shop:%s:L%d" % (item_id, level + 1))
        return True

    def karma_gain(self, state: GameState) -> int:
        f = self.rebirth["formula"]
        lq = max(1.0, state.lifetime_qi)
        # log(x)/log(10) matches GDScript. math.log10 can disagree at the floor boundary.
        return int(
            math.floor(
                f["base"]
                + (math.log(lq) / math.log(10.0)) / f["from_lifetime_qi_log10_div"]
                + state.highest_rank_index * f["from_highest_rank_index"]
            )
        )

    def can_rebirth(self, state: GameState) -> bool:
        return state.rank_index >= int(self.rebirth["min_rank_index_to_rebirth"])

    def _kept_upgrade_ids(self, state: GameState) -> List[str]:
        item = self.shop_by_id["karma_keep_upgrade"]
        n = int(state.shop_levels.get("karma_keep_upgrade", 0))
        mx = int(item.get("max", n) or n)
        n = min(n, mx)
        if n <= 0:
            return []
        pairs = [(lvl, uid) for uid, lvl in state.upgrade_levels.items() if lvl > 0]
        pairs.sort(key=lambda p: (-p[0], p[1]))
        return [uid for _, uid in pairs[:n]]

    def do_rebirth(self, state: GameState) -> bool:
        if not self.can_rebirth(state):
            return False
        gain = self.karma_gain(state)
        kept = self._kept_upgrade_ids(state)
        kept_levels = {uid: int(state.upgrade_levels[uid]) for uid in kept}
        state.karma_shards += gain
        state.rebirth_count += 1
        for tier in self.rebirth["tiers"]:
            if state.rebirth_count >= int(tier["min_rebirths"]):
                for feature in tier.get("unlocks") or []:
                    state.unlocked.add(feature)
        if "spiritual_roots" in state.unlocked:
            seed = int(self.talents["roll_seed_rebirth_base"]) + state.rebirth_count
            self.grant_talent(state, seed)
        if "artifacts_basic" in state.unlocked:
            grants = int(self.artifacts_doc.get("grant_per_rebirth", 1))
            if state.rebirth_count >= int(self.artifacts_doc.get("gacha_min_rebirths", 5)):
                grants = int(self.artifacts_doc.get("grant_per_rebirth_after_gacha", grants))
            for _ in range(grants):
                self.grant_next_artifact(state)
        self.refresh_derived(state)
        state.qi = state.starting_qi_bonus
        state.upgrade_levels = kept_levels
        state.rank_index = 0
        self._apply_start_rank(state)
        state.last_purchase_or_unlock_time = state.time_sec
        stage3.on_rebirth(self, state)
        self._mark(state, "rebirth:%d" % state.rebirth_count)
        self._mark(state, "first_rebirth")
        return True

    # ----- automation -----

    def _auto_entry(self, aid: str) -> Optional[dict]:
        for entry in self.automation["unlock_order"]:
            if entry["id"] == aid:
                return entry
        return None

    def auto_available(self, state: GameState, aid: str) -> bool:
        if aid in state.unlocked and aid != "auto_buy_upgrades":
            # auto_buy's feature flag is automation_buy_upgrades, not the toggle id.
            pass
        entry = self._auto_entry(aid)
        if entry is None or int(entry.get("order", 99)) > AUTO_ORDER_MAX:
            return False
        if aid in state.unlocked:
            return True
        spec = entry["unlock"]
        if spec["type"] == "rank":
            need = int(self.ranks_by_id[spec["id"]]["index"])
            return state.rank_index >= need or state.highest_rank_index >= need
        if spec["type"] == "rebirths":
            return state.rebirth_count >= int(spec["min"])
        if spec["type"] == "path_level":
            return stage3.path_level(state) >= int(spec["min"])
        if spec["type"] == "ascension":
            return state.ascension_count >= int(spec["min"])
        return False

    def sync_automation_unlocks(self, state: GameState) -> None:
        if state.auto_rebirth_min_rank <= 0:
            state.auto_rebirth_min_rank = self.default_rebirth_rank
        for entry in self.automation["unlock_order"]:
            if int(entry.get("order", 99)) > AUTO_ORDER_MAX:
                continue
            aid = entry["id"]
            if self.auto_available(state, aid):
                state.unlocked.add(aid)
                if aid == "auto_buy_upgrades":
                    state.unlocked.add("automation_buy_upgrades")
                if aid not in state.automation_toggles:
                    state.automation_toggles[aid] = True

    def auto_on(self, state: GameState, aid: str) -> bool:
        return bool(state.automation_toggles.get(aid, False)) and self.auto_available(state, aid)

    def automation_act(self, state: GameState) -> None:
        self.sync_automation_unlocks(state)
        if self.auto_on(state, "auto_equip_talents"):
            self.equip_best_talents(state)
        if self.auto_on(state, "auto_rebirth") and self.can_rebirth(state):
            if (
                state.rank_index >= int(state.auto_rebirth_min_rank)
                and self.karma_gain(state) >= int(state.auto_rebirth_min_karma)
            ):
                self.do_rebirth(state)
        guard = 0
        if self.auto_on(state, "auto_breakthrough"):
            while self.can_breakthrough(state) and guard < 48:
                self.breakthrough(state)
                guard += 1
        if self.auto_on(state, "auto_buy_upgrades"):
            if state.auto_buy_mode == "cheapest":
                self.act_cheapest(state, breakthroughs=False)
            else:
                self.act_best_roi(state, breakthroughs=False)
        stage3.auto_systems(self, state)

    # ----- bot actions -----

    def _roi(self, state: GameState, uid: str) -> float:
        cost = self.upgrade_cost(state, uid)
        if cost <= 0:
            return 1e18
        before = self.production(state)
        state.upgrade_levels[uid] = state.upgrade_levels.get(uid, 0) + 1
        after = self.production(state)
        state.upgrade_levels[uid] -= 1
        if state.upgrade_levels[uid] <= 0:
            del state.upgrade_levels[uid]
        d = after - before
        if d <= 0:
            return -1.0
        return d / cost

    def act_best_roi(self, state: GameState, breakthroughs: bool = True) -> None:
        if breakthroughs:
            guard = 0
            while self.can_breakthrough(state) and guard < 48:
                self.breakthrough(state)
                guard += 1
        nxt_cost = self.breakthrough_cost(state)
        for _ in range(80):
            ups = self.unlocked_upgrades(state)
            candidates = []
            for u in ups:
                if not self.can_buy_upgrade(state, u["id"]):
                    continue
                cost = self.upgrade_cost(state, u["id"])
                roi = self._roi(state, u["id"])
                if roi <= 0:
                    continue
                payback = 1.0 / roi
                cheap_vs_rank = nxt_cost is not None and cost <= 0.08 * nxt_cost
                near_instant = payback <= 45.0
                leftover_ok = nxt_cost is None or (state.qi - cost) >= 0.85 * nxt_cost or state.qi >= nxt_cost
                if (near_instant or cheap_vs_rank) and leftover_ok:
                    candidates.append((roi, u["id"]))
                elif (
                    near_instant
                    and nxt_cost
                    and state.qi < nxt_cost
                    and cost < 0.2 * (nxt_cost - state.qi + cost)
                ):
                    candidates.append((roi * 0.5, u["id"]))
            if not candidates:
                break
            candidates.sort(reverse=True)
            if not self.buy_upgrade(state, candidates[0][1]):
                break
            if breakthroughs:
                while self.can_breakthrough(state):
                    self.breakthrough(state)
            nxt_cost = self.breakthrough_cost(state)

    def act_cheapest(self, state: GameState, breakthroughs: bool = True) -> None:
        if breakthroughs:
            prod = self.production(state)
            while self.can_breakthrough(state):
                nxt = self.next_rank(state)
                if nxt is None:
                    break
                if float(nxt["cost_qi"]) <= max(prod * 60.0, state.qi):
                    self.breakthrough(state)
                    prod = self.production(state)
                else:
                    break
        for _ in range(80):
            ups = self.unlocked_upgrades(state)
            affordable = [u for u in ups if self.can_buy_upgrade(state, u["id"])]
            if not affordable:
                break
            affordable.sort(key=lambda u: (self.upgrade_cost(state, u["id"]), u["id"]))
            if not self.buy_upgrade(state, affordable[0]["id"]):
                break

    def act_rush(self, state: GameState) -> None:
        nxt_cost = self.breakthrough_cost(state)
        if self.can_breakthrough(state):
            self.breakthrough(state)
            nxt_cost = self.breakthrough_cost(state)
        ups = sorted(self.unlocked_upgrades(state), key=lambda u: self.upgrade_cost(state, u["id"]))
        for u in ups:
            if not self.can_buy_upgrade(state, u["id"]):
                continue
            cost = self.upgrade_cost(state, u["id"])
            if nxt_cost is None or cost <= 0.15 * nxt_cost or state.qi - cost >= nxt_cost:
                self.buy_upgrade(state, u["id"])
            elif nxt_cost is not None and state.qi >= nxt_cost:
                break

    def spend_karma(self, state: GameState, style: str) -> None:
        if style == "talent":
            self._spend_talent_upgrades(state, limit=2)
            self._maybe_reroll(state)
        if style == "offline":
            self.buy_shop_if_worth(state, "karma_offline", style)
        for _ in range(8):
            if not self.buy_shop_if_worth(state, "karma_prod_1", style):
                break
        if style != "talent":
            self.buy_shop_if_worth(state, "karma_offline", style)
        for _ in range(2):
            if not self.buy_shop_if_worth(state, "karma_start_qi", style):
                break
        if state.rebirth_count >= 8:
            self.buy_shop_if_worth(state, "karma_keep_upgrade", style)
        if style == "artifact":
            self._spend_artifact_upgrade(state)

    def buy_shop_if_worth(self, state: GameState, item_id: str, style: str) -> bool:
        """Buy one level only when the purchase does not cut production."""
        if not self.can_buy_shop(state, item_id):
            return False
        before = self.production(state)
        before_off = self.offline_bonus(state)
        karma = state.karma_shards
        level = int(state.shop_levels.get(item_id, 0))
        if not self.buy_shop(state, item_id):
            return False
        after = self.production(state)
        after_off = self.offline_bonus(state)
        keep = after + 1e-9 >= before
        if item_id == "karma_offline" and after_off > before_off + 1e-12:
            # A little less Qi/s is fine if sleep gets closer to 100%.
            keep = style == "offline" or after >= before * 0.97
        if item_id in ("karma_start_qi", "karma_keep_upgrade"):
            keep = after >= before * 0.995
        if keep:
            return True
        state.karma_shards = karma
        state.shop_levels[item_id] = level
        self.refresh_derived(state)
        return False

    def _spend_talent_upgrades(self, state: GameState, limit: int) -> None:
        for _ in range(limit):
            if not state.talents_equipped:
                return
            best = max(
                state.talents_equipped,
                key=lambda uid: self.talent_power(
                    state, next(t for t in state.talents_owned if t["uid"] == uid)
                ),
            )
            talent = next(t for t in state.talents_owned if t["uid"] == best)
            before = self.production(state)
            karma = state.karma_shards
            level = int(talent["level"])
            if not self.upgrade_talent(state, best):
                return
            self.equip_best_talents(state)
            if self.production(state) + 1e-9 < before:
                talent["level"] = level
                state.karma_shards = karma
                self.equip_best_talents(state)
                return

    def _maybe_reroll(self, state: GameState) -> None:
        if "talent_reroll" not in state.unlocked:
            return
        key = "reroll_used_on:%d" % state.rebirth_count
        if key in state.milestones:
            return
        cost = int(self.rebirth.get("talent_reroll_cost", 4))
        if state.karma_shards < cost + 2:
            return
        pool = state.talents_owned
        if not pool:
            return
        worst = min(pool, key=lambda t: (self.talent_power(state, t), t["uid"]))
        if worst["rarity"] not in ("common", "uncommon"):
            return
        before = self.production(state)
        karma = state.karma_shards
        snapshot = (worst["root_id"], worst["rarity"], worst["roll"], state.reroll_count)
        if not self.reroll_talent(state, worst["uid"]):
            return
        self.equip_best_talents(state)
        if self.production(state) + 1e-9 < before:
            worst["root_id"], worst["rarity"], worst["roll"], state.reroll_count = snapshot
            state.karma_shards = karma
            self.equip_best_talents(state)
        state.milestones[key] = state.time_sec

    def _spend_artifact_upgrade(self, state: GameState) -> None:
        if not state.artifacts_equipped:
            return
        aid = max(state.artifacts_equipped, key=lambda a: self.artifact_score(state, a))
        level = int(state.artifacts_owned.get(aid, 0))
        mx = int(self.artifacts_doc["upgrade"]["max_level"])
        if level >= min(mx, 4):
            return
        cost = self.artifact_upgrade_cost(level)
        nxt = self.breakthrough_cost(state)
        if state.qi < cost:
            return
        if nxt is not None and state.qi - cost < nxt and cost > 0.02 * max(state.qi, 1.0):
            return
        self.upgrade_artifact(state, aid)

    def policy_rebirth(self, state: GameState, min_rank: int, min_gain: int, first_free: bool) -> bool:
        if self.auto_on(state, "auto_rebirth"):
            return False
        if not self.can_rebirth(state):
            return False
        if state.rank_index < min_rank:
            return False
        gain = self.karma_gain(state)
        if state.rebirth_count == 0 and first_free:
            return self.do_rebirth(state)
        if gain >= min_gain:
            return self.do_rebirth(state)
        return False

    def play_rebirth_policy(
        self,
        state: GameState,
        style: str,
        min_rank: int,
        min_gain: int,
    ) -> None:
        """Shared body for rebirth_early / late / talent / artifact / offline bots."""
        self.sync_automation_unlocks(state)
        self.equip_best_talents(state)
        self.equip_artifacts_for(state, "offline" if style == "offline" else "active")
        if style == "late":
            state.auto_rebirth_min_rank = max(state.auto_rebirth_min_rank, min_rank)
            state.auto_rebirth_min_karma = max(int(state.auto_rebirth_min_karma), min_gain)
        elif style == "offline":
            state.auto_rebirth_min_rank = self.default_rebirth_rank
            state.auto_rebirth_min_karma = 1
        else:
            state.auto_rebirth_min_rank = self.default_rebirth_rank
            state.auto_rebirth_min_karma = min_gain
        self.spend_karma(state, "talent" if style == "talent" else ("offline" if style == "offline" else ("artifact" if style == "artifact" else "balanced")))
        if self.policy_rebirth(state, min_rank, min_gain, first_free=True):
            self.spend_karma(state, "talent" if style == "talent" else "balanced")
        self.automation_act(state)
        if not self.auto_on(state, "auto_buy_upgrades"):
            self.act_best_roi(state, breakthroughs=not self.auto_on(state, "auto_breakthrough"))
        elif not self.auto_on(state, "auto_breakthrough"):
            guard = 0
            while self.can_breakthrough(state) and guard < 48:
                self.breakthrough(state)
                guard += 1
        if self.policy_rebirth(state, min_rank, min_gain, first_free=True):
            if not self.auto_on(state, "auto_buy_upgrades"):
                self.act_best_roi(state, breakthroughs=not self.auto_on(state, "auto_breakthrough"))

    # ----- time -----

    def tick(self, state: GameState, dt: float) -> None:
        prod = self.production(state)
        gained = prod * dt
        state.qi += gained
        state.lifetime_qi += gained
        state.time_sec += dt
        stage3.advance(self, state, dt, gained, offline=False)
        stage3.clamp_state(self, state)
        if not state.history or state.time_sec - state.history[-1][0] >= 5.0:
            state.history.append((state.time_sec, prod, state.rank_index))

    def _offline_eff(self, state: GameState) -> float:
        base = float(self.balance["offline"]["efficiency"])
        return min(stage3.offline_cap(self, state), base + self.offline_bonus(state))

    def offline_needs_chunks(self, state: GameState) -> bool:
        self.sync_automation_unlocks(state)
        return self.auto_on(state, "auto_buy_upgrades") or self.auto_on(
            state, "auto_breakthrough"
        ) or self.auto_on(state, "auto_rebirth") or stage3.needs_chunks(self, state)

    def apply_offline(self, state: GameState, absent_sec: float) -> dict:
        off = self.balance["offline"]
        soft = (float(off["soft_cap_hours"]) + stage3.soft_cap_bonus_hours(self, state)) * 3600.0
        hard = float(off["hard_cap_hours"]) * 3600.0
        raw = float(absent_sec)
        absent = min(max(0.0, raw), hard)
        if not self.offline_needs_chunks(state):
            eff = self._offline_eff(state)
            if absent <= soft:
                gained = self.production(state) * absent * eff
            else:
                gained = self.production(state) * soft * eff + self.production(state) * (absent - soft) * eff * 0.5
            state.qi += gained
            state.lifetime_qi += gained
            state.time_sec += absent
            return {
                "gained": gained,
                "absent_sec": absent,
                "raw_absent_sec": raw,
                "efficiency": eff,
                "chunked": False,
                "hard_capped": raw > hard + 1e-6,
                "soft_capped": absent > soft + 1e-6,
            }
        chunk = float(off["chunk_seconds"])
        remaining = absent
        elapsed = 0.0
        gained_total = 0.0
        guard = 0
        while remaining > 1e-6 and guard < 2000:
            guard += 1
            dt = min(chunk, remaining)
            if elapsed < soft < elapsed + dt:
                dt1 = soft - elapsed
                gained_total += self._offline_slice(state, dt1, half=False)
                gained_total += self._offline_slice(state, dt - dt1, half=True)
            else:
                gained_total += self._offline_slice(state, dt, half=elapsed >= soft)
            self.automation_act(state)
            elapsed += dt
            remaining -= dt
        state.time_sec += absent
        eff = self._offline_eff(state)
        return {
            "gained": gained_total,
            "absent_sec": absent,
            "raw_absent_sec": raw,
            "efficiency": eff,
            "chunked": True,
            "hard_capped": raw > hard + 1e-6,
            "soft_capped": absent > soft + 1e-6,
        }

    def _offline_slice(self, state: GameState, dt: float, half: bool) -> float:
        if dt <= 0:
            return 0.0
        eff = self._offline_eff(state) * (0.5 if half else 1.0)
        gained = self.production(state) * dt * eff
        state.qi += gained
        state.lifetime_qi += gained
        banked = stage3.maybe_bank_offline(self, state, gained, dt)
        if banked > 0.0:
            state.qi -= banked
            state.lifetime_qi -= banked
            gained -= banked
        stage3.advance(self, state, dt, gained, offline=True)
        stage3.clamp_state(self, state)
        return gained


def fresh_state() -> GameState:
    state = GameState()
    state.unlocked.add("upgrades_basic")
    return state
