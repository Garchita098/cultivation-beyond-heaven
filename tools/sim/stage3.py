"""Stage 3 rules: paths, worlds, research, ascension.

Inactive runs (no joined path, mortal world, no laws, no marks) must not change
production, costs, or breakthroughs. Economy calls these hooks after the stage-2 formula.
"""
from __future__ import annotations

import math
from typing import Any, Dict, List, Optional

CAP_DEFAULT = 1e300

PATH_IDS = (
    "heavenly_sword",
    "demon_emperor",
    "immortal",
    "world_devourer",
    "time_lord",
)

WORLD_ORDER = (
    "mortal_world",
    "spirit_world",
    "heavenly_world",
    "void_dimension",
    "chaos_origin",
)

RESOURCE_KEYS = ("spirit_essence", "dao_fragments", "void_dust", "chaos_seed")


def cap_of(eco) -> float:
    return float(eco.balance.get("magnitude_cap", CAP_DEFAULT))


def clamp(eco, value: float) -> float:
    if not math.isfinite(value) or value < 0.0:
        return 0.0
    limit = cap_of(eco)
    if value > limit:
        return limit
    return value


def clamp_state(eco, state) -> None:
    state.qi = clamp(eco, state.qi)
    state.lifetime_qi = clamp(eco, state.lifetime_qi)
    for key in RESOURCE_KEYS:
        state.world_res[key] = clamp(eco, float(state.world_res.get(key, 0.0)))


def research_doc(eco) -> dict:
    return eco.research


def worlds_doc(eco) -> dict:
    return eco.worlds_doc


def world_def(eco, world_id: str) -> dict:
    return eco.worlds_by_id[world_id]


def path_def(eco, path_id: Optional[str]) -> Optional[dict]:
    if not path_id:
        return None
    return eco.paths_by_id.get(path_id)


def node_level(state, node_id: str) -> int:
    return int(state.path_nodes.get(node_id, 0))


def node_sum(eco, state, effect: str) -> float:
    path = path_def(eco, state.path_id if state.path_joined else None)
    if not path:
        return 0.0
    total = 0.0
    for node in path.get("nodes", []):
        if node.get("effect") != effect:
            continue
        total += float(node["value"]) * node_level(state, node["id"])
    return total


def path_level(state) -> int:
    return sum(int(v) for v in state.path_nodes.values())


def study_done(state, study_id: str) -> bool:
    return study_id in state.research_done


def law_by_id(eco, law_id: str) -> Optional[dict]:
    for law in research_doc(eco).get("laws", []):
        if law["id"] == law_id:
            return law
    return None


def slotted(state) -> List[dict]:
    return list(state.slotted_laws)


def has_rule(eco, state, rule: str) -> Optional[dict]:
    for law_id in state.slotted_laws:
        law = law_by_id(eco, str(law_id))
        if law and law.get("rule") == rule:
            return law
    if state.active_rewrite and state.world_id == "void_dimension":
        law = law_by_id(eco, state.active_rewrite)
        if law and law.get("rule") == rule:
            return law
    return None


def research_unlocked(eco, state) -> bool:
    need = int(research_doc(eco).get("unlock_rebirths", 5))
    return state.rebirth_count >= need or "path_selection" in state.unlocked


def law_slots(eco, state) -> int:
    n = 0
    if "dao_laws" in state.unlocked:
        n += 1
    if study_done(state, "law_primer"):
        n += 1
    if state.world_id == "chaos_origin":
        n = max(n, int(world_def(eco, "chaos_origin").get("forge_slots", 2)))
    if "law_rewrite" in state.unlocked:
        n += 1
    if state.path_joined:
        for aid in state.artifacts_equipped:
            art = eco.artifacts_by_id.get(aid)
            if not art or art.get("effect_type") != "rule_slot":
                continue
            if aid not in state.artifacts_owned:
                continue
            n += 1
    return min(3, n)


def _prod_dirty(state) -> bool:
    if state.path_joined:
        return True
    if state.world_id != "mortal_world":
        return True
    if state.dao_marks > 0 or state.ascension_count > 0:
        return True
    if state.reality_mode != "still":
        return True
    if state.slotted_laws or state.active_rewrite:
        return True
    if state.boon_left > 0 or state.penalty_left > 0:
        return True
    if "dao_authority" in state.unlocked:
        return True
    return False


def qi_keep(eco, state) -> float:
    if state.world_id != "spirit_world":
        return 1.0
    ratio = float(state.essence_ratio)
    if ratio < 0.0:
        ratio = 0.0
    if ratio > 0.9:
        ratio = 0.9
    return 1.0 - ratio


def path_mult(eco, state) -> float:
    if not state.path_joined:
        return 1.0
    path = path_def(eco, state.path_id)
    if not path:
        return 1.0
    params = path["params"]
    level = path_level(state)
    if state.path_id == "heavenly_sword":
        burst = float(params["burst_mult_base"]) + level * float(params["burst_mult_per_path_level"])
        burst += node_sum(eco, state, "burst_add")
        if state.burst_left > 0.0:
            return burst
        return float(params["outside_burst_mult"])
    if state.path_id == "demon_emperor":
        perm = 1.0 + float(state.demon_permanent)
        if state.burst_left > 0.0:
            return float(params["sacrifice_burst_mult"]) * perm
        idle = float(params["idle_penalty_mult"]) + node_sum(eco, state, "idle_add")
        if idle > 1.0:
            idle = 1.0
        if state.demon_fed > 0.0:
            return perm
        return idle * perm
    if state.path_id == "immortal":
        rate = float(params["compound_rate_per_hour"]) + node_sum(eco, state, "compound_add")
        active = float(params["active_play_mult"]) + node_sum(eco, state, "active_add")
        if active > 1.0:
            active = 1.0
        hours = float(params["starting_hours"]) + node_sum(eco, state, "start_hours") + float(state.cultivated_hours)
        return active * ((1.0 + rate) ** hours)
    if state.path_id == "world_devourer":
        per = float(params["devour_mult_per_resource_type"]) + node_sum(eco, state, "per_type_add")
        types = len(state.devour_types)
        bonus = min(float(params["devour_mult_cap"]) - 1.0, types * per) + float(state.devour_bonus)
        if bonus < 0.0:
            bonus = 0.0
        return 1.0 + bonus
    return 1.0


def speed_extra(eco, state) -> float:
    if not state.path_joined or state.path_id != "time_lord" or state.speed_left <= 0.0:
        return 1.0
    path = path_def(eco, "time_lord")
    return float(path["params"]["speed_mult_value"]) + node_sum(eco, state, "speed_add")


def extra_offline_bonus(eco, state) -> float:
    if not state.path_joined or state.path_id != "immortal":
        return 0.0
    path = path_def(eco, "immortal")
    return float(path["params"]["offline_efficiency_bonus"])


def offline_cap(eco, state) -> float:
    if state.path_joined and state.path_id == "immortal":
        return float(path_def(eco, "immortal")["params"]["offline_efficiency_cap"])
    return 1.0


def soft_cap_bonus_hours(eco, state) -> float:
    if not study_done(state, "longer_dream"):
        return 0.0
    for study in research_doc(eco)["studies"]:
        if study["id"] == "longer_dream":
            return float(study["value"])
    return 0.0


def bank_ratio(eco, state) -> float:
    if not state.path_joined or state.path_id != "time_lord":
        return 0.0
    base = float(path_def(eco, "time_lord")["params"]["bank_ratio"])
    base += node_sum(eco, state, "bank_add")
    if study_done(state, "time_ledger"):
        for study in research_doc(eco)["studies"]:
            if study["id"] == "time_ledger":
                base += float(study["value"])
    if base < 0.0:
        return 0.0
    if base > 0.6:
        return 0.6
    return base


def needs_chunks(eco, state) -> bool:
    if state.path_joined:
        return True
    if state.world_id != "mortal_world":
        return True
    if state.slotted_laws or state.active_rewrite:
        return True
    if state.boon_left > 0 or state.penalty_left > 0 or state.speed_left > 0:
        return True
    if research_unlocked(eco, state) and _research_pending(eco, state):
        return True
    if state.reality_mode != "still":
        return True
    return False


def _research_pending(eco, state) -> bool:
    done = set(state.research_done)
    for study in research_doc(eco)["studies"]:
        if study["id"] not in done:
            return True
    return False


def adjust_prod(eco, state, prod: float, parts: dict) -> float:
    if not _prod_dirty(state):
        return prod
    mult = path_mult(eco, state) * speed_extra(eco, state)
    flat_sum = float(parts.get("flat_sum", 0.0))
    mult_add = float(parts.get("mult_add", 0.0))
    if state.reality_mode == "inverted" and "reality_stitch" in state.unlocked:
        coeff = float(research_doc(eco).get("inverted_exp_coeff", 0.08))
        cap = float(research_doc(eco).get("inverted_exp_cap", 6.0))
        old = (1.0 + flat_sum) * (1.0 + mult_add)
        new = (1.0 + flat_sum) * math.exp(min(cap, mult_add * coeff))
        if old > 0.0:
            prod = prod / old * new
    law = has_rule(eco, state, "flat_power")
    inverted = state.reality_mode == "inverted" and "reality_stitch" in state.unlocked
    if law and not inverted:
        # (1+mult_add) becomes (1+mult_add)^(1+value). A power, not another factor.
        old = 1.0 + mult_add
        new = old ** (1.0 + float(law["value"]))
        if old > 0.0:
            prod = prod / old * new
    if state.path_joined and state.path_id == "heavenly_sword" and state.burst_left > 0.0:
        edge = node_sum(eco, state, "burst_flat")
        if edge > 0.0 and flat_sum > 0.0:
            mult *= 1.0 + flat_sum * edge
    if state.boon_left > 0.0 and state.world_id == "heavenly_world":
        coeff = float(world_def(eco, "heavenly_world").get("boon_flat_coeff", 0.012))
        mult *= 1.0 + flat_sum * coeff
    if "dao_authority" in state.unlocked and flat_sum > 0.0:
        mult *= 1.0 + flat_sum * float(research_doc(eco).get("authority_flat_coeff", 0.004))
    if state.penalty_left > 0.0 and state.world_id == "heavenly_world":
        mult *= float(world_def(eco, "heavenly_world").get("fail_penalty_mult", 0.72))
    if state.reality_mode == "dilated" and "reality_stitch" in state.unlocked:
        mult *= float(research_doc(eco).get("dilated_prod", 1.32))
    tithe = has_rule(eco, state, "time_log")
    if tithe:
        hours = float(state.cultivated_hours)
        mult *= 1.0 + float(tithe["value"]) * (math.log(1.0 + hours) / math.log(10.0))
        mult *= 0.92  # the tithe: time helps, breakthroughs cost more via adjust_breakthrough
    marks = float(worlds_doc(eco)["ascension"]["perm_mult_per_mark"])
    mult *= 1.0 + float(state.dao_marks) * marks
    mult *= qi_keep(eco, state)
    out = prod * mult
    return clamp(eco, out)


def adjust_cost(eco, state, cost: float, base_cost: float, growth: float, level: int, reduction: float) -> float:
    law = has_rule(eco, state, "growth_exp")
    dilated = state.reality_mode == "dilated" and "reality_stitch" in state.unlocked
    if not law and not dilated:
        return cost
    if law:
        raw = float(base_cost) * (float(growth) ** (float(level) * float(law["value"])))
        cost = raw * (1.0 - reduction)
    if dilated:
        cost *= float(research_doc(eco).get("dilated_cost", 1.1))
    return cost


def adjust_breakthrough(eco, state, cost: Optional[float]) -> Optional[float]:
    if cost is None:
        return None
    essence = float(state.world_res.get("spirit_essence", 0.0))
    dirty = False
    if essence > 0.0:
        spirit = world_def(eco, "spirit_world")
        per = float(spirit["essence_breakthrough_discount_per"])
        cap = float(spirit["essence_discount_cap"])
        disc = min(cap, essence * per)
        if disc > 0.0:
            cost = cost * (1.0 - disc)
            dirty = True
    if state.reality_mode == "dilated" and "reality_stitch" in state.unlocked:
        cost *= float(research_doc(eco).get("dilated_cost", 1.1))
        dirty = True
    if _half_breakthrough(eco, state):
        cost *= 0.5
        dirty = True
    tithe = has_rule(eco, state, "time_log")
    if tithe:
        cost *= 1.2
        dirty = True
    if not dirty:
        return cost
    return cost


def _half_breakthrough(eco, state) -> bool:
    if not has_rule(eco, state, "breakthrough_half_if_bank"):
        return False
    need = float(research_doc(eco).get("bank_breakthrough_sec", 30))
    return float(state.banked_sec) >= need


def bank_spent_on_breakthrough(eco, state) -> float:
    if not _half_breakthrough(eco, state):
        return 0.0
    return float(research_doc(eco).get("bank_breakthrough_sec", 30))


def bonus_levels(eco, state, new_level: int) -> int:
    every = None
    law = has_rule(eco, state, "bonus_level_every")
    if law:
        every = int(law["value"])
    elif study_done(state, "batch_training"):
        for study in research_doc(eco)["studies"]:
            if study["id"] == "batch_training":
                every = int(study["value"])
    if not every or every <= 0:
        return 0
    if new_level > 0 and new_level % every == 0:
        return 1
    return 0


def hook_consumed(eco, state, effect_type: str) -> bool:
    if not state.path_joined:
        return False
    return (
        (effect_type == "sacrifice_efficiency" and state.path_id == "demon_emperor")
        or (effect_type == "absorb_rate" and state.path_id == "world_devourer")
        or (effect_type == "time_skip_charge" and state.path_id == "time_lord")
        or (effect_type == "rule_slot")
    )


def _artifact_effect(eco, state, effect_type: str) -> float:
    total = 0.0
    for aid in state.artifacts_equipped:
        if aid not in state.artifacts_owned:
            continue
        art = eco.artifacts_by_id.get(aid)
        if not art or art.get("effect_type") != effect_type:
            continue
        _art, ev = eco._artifact_scaled(state, aid)
        total += float(ev)
    return total


def on_rebirth(eco, state) -> None:
    state.burst_left = 0.0
    state.sword_charge = 0.0
    state.speed_left = 0.0
    state.demon_fed = 0.0
    state.boon_left = 0.0
    state.penalty_left = 0.0
    state.tribulation_t = 0.0
    if not (state.path_joined and state.path_id == "world_devourer" and node_sum(eco, state, "types_persist") > 0):
        state.devour_types = set()
    # World resources of the run leave with the rebirth. Marks and laws stay.
    for key in RESOURCE_KEYS:
        state.world_res[key] = 0.0


def choose_path(eco, state, path_id: str) -> bool:
    if path_id not in eco.paths_by_id:
        return False
    need = int(eco.paths_doc.get("unlock_rebirths", 5))
    if state.rebirth_count < need and "path_selection" not in state.unlocked:
        return False
    if state.path_joined and state.path_id == path_id:
        return False
    if not state.path_joined:
        state.path_id = path_id
        state.path_joined = True
        state.unlocked.add("path_selection")
        eco._mark(state, "path:" + path_id)
        return True
    level = path_level(state)
    base = float(eco.paths_doc.get("switch_karma_base", 6))
    scale = float(eco.paths_doc.get("switch_level_scale", 1))
    cost = base * (1.0 + level * scale)
    if state.karma_shards < cost:
        return False
    state.karma_shards -= cost
    state.path_nodes = {}
    state.path_currency = 0.0
    state.demon_permanent = 0.0
    state.cultivated_hours = 0.0
    state.devour_types = set()
    state.devour_bonus = 0.0
    state.chrono_charge = 0.0
    state.banked_sec = 0.0
    state.skip_used_sec = 0.0
    state.burst_left = 0.0
    state.sword_charge = 0.0
    state.speed_left = 0.0
    state.demon_fed = 0.0
    state.path_switch_count += 1
    state.path_id = path_id
    state.path_joined = True
    eco._mark(state, "path_switch:" + path_id)
    return True


def node_cost(node: dict, level: int) -> float:
    return float(node["cost"]) * (float(node["growth"]) ** level)


def buy_node(eco, state, node_id: str) -> bool:
    path = path_def(eco, state.path_id if state.path_joined else None)
    if not path:
        return False
    node = None
    for item in path.get("nodes", []):
        if item["id"] == node_id:
            node = item
            break
    if node is None:
        return False
    level = node_level(state, node_id)
    if level >= int(node["max_level"]):
        return False
    cost = node_cost(node, level)
    if state.path_currency + 1e-9 < cost:
        return False
    state.path_currency -= cost
    state.path_nodes[node_id] = level + 1
    eco._mark(state, "node:%s:L%d" % (node_id, level + 1))
    return True


def sacrifice(eco, state, mode: str = "qi") -> bool:
    if not state.path_joined or state.path_id != "demon_emperor":
        return False
    path = path_def(eco, "demon_emperor")
    params = path["params"]
    if mode == "rank":
        if node_sum(eco, state, "rank_sacrifice") <= 0.0:
            return False
        if state.rank_index <= 0:
            return False
        state.rank_index -= 1
        gain = float(params["rank_permanent"])
    else:
        if state.qi <= 1.0:
            return False
        frac = float(params["sacrifice_qi_fraction"])
        eff = _artifact_effect(eco, state, "sacrifice_efficiency")
        frac *= max(0.4, 1.0 - eff)
        if frac > 0.85:
            frac = 0.85
        state.qi *= 1.0 - frac
        gain = float(params["permanent_gain_per_sacrifice"]) + node_sum(eco, state, "perm_add")
    cap = float(params["permanent_gain_cap"])
    state.demon_permanent = min(cap, float(state.demon_permanent) + gain)
    state.burst_left = float(params["sacrifice_burst_sec"])
    state.demon_fed = float(params["fed_window_sec"]) + node_sum(eco, state, "fed_sec")
    state.path_currency += 1.0
    state.sacrifice_count += 1
    eco._mark(state, "sacrifice:%d" % state.sacrifice_count)
    return True


def absorb(eco, state, kind: str) -> bool:
    if not state.path_joined or state.path_id != "world_devourer":
        return False
    path = path_def(eco, "world_devourer")
    params = path["params"]
    if kind == "upgrade":
        best = ""
        best_lvl = 0
        for uid, lvl in state.upgrade_levels.items():
            if int(lvl) > best_lvl or (int(lvl) == best_lvl and best and uid < best):
                best = uid
                best_lvl = int(lvl)
        if best_lvl <= 0:
            return False
        state.upgrade_levels[best] = best_lvl - 1
        if state.upgrade_levels[best] <= 0:
            del state.upgrade_levels[best]
        state.devour_types.add("upgrade")
        state.path_currency += 0.4
        state.mechanic_counts["absorb"] = int(state.mechanic_counts.get("absorb", 0)) + 1
        return True
    if kind == "artifact":
        pick = ""
        for aid in list(state.artifacts_owned.keys()):
            if not pick or aid < pick:
                pick = aid
        if not pick:
            return False
        level = int(state.artifacts_owned[pick])
        if level <= 0:
            # Consuming the relic itself is the bite. It leaves the loadout.
            del state.artifacts_owned[pick]
            if pick in state.artifacts_equipped:
                state.artifacts_equipped.remove(pick)
        else:
            state.artifacts_owned[pick] = level - 1
        state.devour_types.add("artifact")
        bonus = 0.04 + node_sum(eco, state, "artifact_bonus")
        state.devour_bonus += bonus
        state.path_currency += 0.4
        state.mechanic_counts["absorb"] = int(state.mechanic_counts.get("absorb", 0)) + 1
        return True
    if kind not in RESOURCE_KEYS:
        return False
    have = float(state.world_res.get(kind, 0.0))
    if have <= 0.0:
        return False
    ratio = float(params["absorb_ratio"])
    ratio += _artifact_effect(eco, state, "absorb_rate")
    if ratio > 0.9:
        ratio = 0.9
    take = have * ratio
    state.world_res[kind] = have - take
    convert = float(params["qi_convert_bonus"]) + node_sum(eco, state, "convert_add")
    state.qi = clamp(eco, state.qi + take * convert)
    state.devour_types.add(kind)
    state.path_currency += 0.25
    state.mechanic_counts["absorb"] = int(state.mechanic_counts.get("absorb", 0)) + 1
    return True


def start_speed(eco, state) -> bool:
    if not state.path_joined or state.path_id != "time_lord":
        return False
    if state.speed_left > 0.0:
        return False
    params = path_def(eco, "time_lord")["params"]
    cost = float(params["speed_mult_cost"])
    if state.chrono_charge + 1e-9 < cost:
        return False
    state.chrono_charge -= cost
    state.speed_left = float(params["speed_mult_duration_sec"])
    state.mechanic_counts["speed_window"] = int(state.mechanic_counts.get("speed_window", 0)) + 1
    return True


def time_skip(eco, state) -> bool:
    """Spend banked offline seconds. This does not create Qi from a tap."""
    if not state.path_joined or state.path_id != "time_lord":
        return False
    params = path_def(eco, "time_lord")["params"]
    if state.chrono_charge + 1e-9 < 1.0:
        return False
    cap = float(params["max_skip_per_day_minutes"]) * 60.0
    if state.skip_used_sec >= cap - 1.0:
        return False
    if state.banked_sec < 30.0:
        return False
    minutes = float(params["skip_minutes_per_charge"]) * (1.0 + node_sum(eco, state, "skip_add"))
    want = minutes * 60.0
    spend = min(state.banked_sec, want, cap - state.skip_used_sec)
    if spend < 30.0:
        return False
    prod = eco.production(state)
    eff = eco._offline_eff(state)
    gain = prod * spend * eff
    state.qi = clamp(eco, state.qi + gain)
    state.lifetime_qi = clamp(eco, state.lifetime_qi + gain)
    state.banked_sec -= spend
    state.chrono_charge -= 1.0
    state.skip_used_sec += spend
    eco._mark(state, "time_skip")
    return True


def set_essence_ratio(state, ratio: float) -> None:
    if ratio < 0.0:
        ratio = 0.0
    if ratio > 0.75:
        ratio = 0.75
    state.essence_ratio = ratio


def set_retain(eco, state, seconds: float) -> None:
    choices = world_def(eco, "void_dimension").get("retain_choices", [60, 180, 600])
    best = float(choices[0])
    for choice in choices:
        if abs(float(choice) - seconds) < abs(best - seconds):
            best = float(choice)
    state.retain_seconds = best


def set_stance(state, stance: str) -> None:
    if stance not in ("guard", "defy"):
        return
    state.stance = stance


def set_reality(state, mode: str) -> bool:
    if mode not in ("still", "dilated", "inverted"):
        return False
    if mode != "still" and "reality_stitch" not in state.unlocked:
        return False
    state.reality_mode = mode
    return True


def slot_law(eco, state, law_id: str) -> bool:
    law = law_by_id(eco, law_id)
    if not law:
        return False
    if law_id in state.slotted_laws:
        return False
    slots = law_slots(eco, state)
    if len(state.slotted_laws) >= slots:
        if not state.slotted_laws:
            return False
        state.slotted_laws[-1] = law_id
        return True
    if state.world_id == "chaos_origin":
        seeds = float(state.world_res.get("chaos_seed", 0.0))
        if seeds < 1.0 and state.ascension_count < 1 and "dao_laws" not in state.unlocked:
            return False
        if seeds >= 1.0:
            state.world_res["chaos_seed"] = seeds - 1.0
    state.slotted_laws.append(law_id)
    eco._mark(state, "law:" + law_id)
    return True


def buy_void_rewrite(eco, state) -> bool:
    if state.world_id != "void_dimension" and "dao_laws" not in state.unlocked:
        return False
    cost = float(world_def(eco, "void_dimension").get("rewrite_cost", 20))
    dust = float(state.world_res.get("void_dust", 0.0))
    if dust + 1e-9 < cost:
        return False
    state.world_res["void_dust"] = dust - cost
    state.active_rewrite = "qi_or_time"
    if "qi_or_time" not in state.slotted_laws and len(state.slotted_laws) < law_slots(eco, state):
        state.slotted_laws.append("qi_or_time")
    eco._mark(state, "rewrite:qi_or_time")
    return True


def promote_research(eco, state, study_id: str) -> bool:
    ids = [s["id"] for s in research_doc(eco)["studies"]]
    if study_id not in ids:
        return False
    if not state.research_order:
        state.research_order = list(ids)
    if study_id in state.research_order:
        state.research_order.remove(study_id)
    state.research_order.insert(0, study_id)
    state.research_progress = 0.0
    return True


def _ensure_research_order(eco, state) -> None:
    ids = [s["id"] for s in research_doc(eco)["studies"]]
    if not state.research_order:
        state.research_order = list(ids)
        return
    for study_id in ids:
        if study_id not in state.research_order:
            state.research_order.append(study_id)


def _active_study(eco, state) -> Optional[dict]:
    if not research_unlocked(eco, state):
        return None
    _ensure_research_order(eco, state)
    by_id = {s["id"]: s for s in research_doc(eco)["studies"]}
    for study_id in state.research_order:
        if study_id not in state.research_done and study_id in by_id:
            return by_id[study_id]
    return None


def next_world_id(state) -> Optional[str]:
    try:
        index = WORLD_ORDER.index(state.world_id)
    except ValueError:
        return None
    if index + 1 >= len(WORLD_ORDER):
        return None
    return WORLD_ORDER[index + 1]


def can_ascend(eco, state) -> bool:
    gate = int(worlds_doc(eco)["ascension"]["min_rebirths"])
    if state.rebirth_count < gate and "ascension_gate" not in state.unlocked:
        return False
    if state.rebirth_count < gate:
        return False
    nxt = next_world_id(state)
    if not nxt:
        return False
    req = world_def(eco, nxt).get("unlock_requirement")
    if req == "start" or not isinstance(req, dict):
        return False
    if req.get("type") == "rank":
        need = int(eco.ranks_by_id[req["id"]]["index"])
        return state.rank_index >= need
    if req.get("type") == "ascension_count":
        # `min` is the ascension count after this transition.
        if state.ascension_count + 1 < int(req["min"]):
            return False
        floor = int(eco.ranks_by_id["void_early"]["index"])
        return state.rank_index >= floor
    return False


def ascension_gain(eco, state) -> int:
    cfg = worlds_doc(eco)["ascension"]
    lq = max(1.0, state.lifetime_qi)
    raw = (
        1.0
        + (math.log(lq) / math.log(10.0)) / float(cfg["gain_log_div"])
        + state.highest_rank_index * float(cfg["gain_per_rank"])
        + state.ascension_count * float(cfg["gain_per_ascension"])
    )
    return max(1, int(math.floor(raw)))


def do_ascension(eco, state) -> bool:
    if not can_ascend(eco, state):
        return False
    nxt = next_world_id(state)
    gain = ascension_gain(eco, state)
    state.dao_marks += gain
    state.ascension_count += 1
    state.world_id = nxt
    state.qi = 0.0
    state.lifetime_qi = 0.0
    state.upgrade_levels = {}
    state.karma_shards = 0.0
    state.shop_levels = {}
    state.shop_mult = 1.0
    state.starting_qi_bonus = 0.0
    state.rank_index = 0
    for key in RESOURCE_KEYS:
        state.world_res[key] = 0.0
    state.burst_left = 0.0
    state.sword_charge = 0.0
    state.speed_left = 0.0
    state.demon_fed = 0.0
    state.boon_left = 0.0
    state.penalty_left = 0.0
    state.tribulation_t = 0.0
    state.tribulation_cycle = 0
    state.essence_ratio = 0.25 if nxt == "spirit_world" else 0.0
    state.unlocked.add("ascension_gate")
    state.unlocked.add("world:" + nxt)
    eco.refresh_derived(state)
    eco._apply_start_rank(state)
    state.last_purchase_or_unlock_time = state.time_sec
    eco._mark(state, "ascension:%d" % state.ascension_count)
    import achievements as _achievements
    _achievements.on_ascension(state)
    eco._mark(state, "world:" + nxt)
    return True


def _charge_period(eco, state) -> float:
    params = path_def(eco, "heavenly_sword")["params"]
    period = float(params["charge_period_sec"]) + node_sum(eco, state, "charge_sec")
    return max(20.0, period)


def _burst_duration(eco, state) -> float:
    params = path_def(eco, "heavenly_sword")["params"]
    return float(params["burst_duration_sec"]) + node_sum(eco, state, "burst_sec")


def _advance_sword(eco, state, dt: float) -> None:
    left = dt
    guard = 0
    while left > 1e-9 and guard < 8:
        guard += 1
        if state.burst_left > 0.0:
            step = min(left, state.burst_left)
            state.burst_left -= step
            left -= step
            continue
        period = _charge_period(eco, state)
        need = period - state.sword_charge
        step = min(left, need)
        state.sword_charge += step
        left -= step
        if state.sword_charge >= period - 1e-9:
            state.sword_charge = 0.0
            state.burst_left = _burst_duration(eco, state)
            state.mechanic_counts["sword_burst"] = int(state.mechanic_counts.get("sword_burst", 0)) + 1


def _resolve_tribulation(eco, state) -> None:
    heavenly = world_def(eco, "heavenly_world")
    prod = max(eco.production(state), 1e-9)
    power = (math.log(prod) / math.log(10.0)) + state.rank_index * float(heavenly["power_rank_weight"])
    power += state.karma_shards * 0.02 + state.dao_marks * 0.15
    pressure = float(heavenly["pressure_base"]) + state.tribulation_cycle * float(heavenly["pressure_per_cycle"])
    if study_done(state, "tribulation_eye"):
        for study in research_doc(eco)["studies"]:
            if study["id"] == "tribulation_eye":
                pressure *= float(study["value"])
    if state.stance == "guard":
        pressure *= float(heavenly["guard_pressure"])
        reward_mult = float(heavenly["guard_reward"])
    else:
        pressure *= float(heavenly["defy_pressure"])
        reward_mult = float(heavenly["defy_reward"])
    success = power + 1e-9 >= pressure
    if success:
        fragments = float(heavenly["success_fragments"]) * reward_mult
        state.boon_left = float(heavenly["boon_sec"]) * (1.2 if state.stance == "defy" else 1.0)
        state.penalty_left = 0.0
    else:
        fragments = float(heavenly["fail_fragments"]) * reward_mult
        state.penalty_left = float(heavenly["fail_penalty_sec"])
        state.boon_left = 0.0
    state.world_res["dao_fragments"] = float(state.world_res.get("dao_fragments", 0.0)) + fragments
    state.tribulation_cycle += 1
    state.tribulation_t = 0.0
    eco._mark(state, "tribulation:%d" % state.tribulation_cycle)


def advance(eco, state, dt: float, gained_qi: float, offline: bool) -> None:
    """Timers, side resources, research. Qi from the main formula is already applied."""
    if dt <= 0.0:
        return
    if not (
        state.path_joined
        or state.world_id != "mortal_world"
        or research_unlocked(eco, state)
        or "dual_flow" in state.unlocked
        or state.boon_left > 0
        or state.penalty_left > 0
    ):
        return
    if state.path_joined and state.path_id == "heavenly_sword":
        _advance_sword(eco, state, dt)
    elif state.burst_left > 0.0:
        state.burst_left = max(0.0, state.burst_left - dt)
    if state.demon_fed > 0.0:
        state.demon_fed = max(0.0, state.demon_fed - dt)
    if state.speed_left > 0.0:
        state.speed_left = max(0.0, state.speed_left - dt)
    if state.boon_left > 0.0:
        state.boon_left = max(0.0, state.boon_left - dt)
    if state.penalty_left > 0.0:
        state.penalty_left = max(0.0, state.penalty_left - dt)

    hour = dt / 3600.0
    if state.path_joined:
        per = float(eco.paths_doc.get("currency_per_hour", 10))
        state.path_currency += per * hour
        scale = 1.0
        if state.path_id == "immortal" and offline:
            scale = 1.0 + node_sum(eco, state, "dream_mult")
        if state.reality_mode == "dilated" and "reality_stitch" in state.unlocked:
            scale *= float(research_doc(eco).get("dilated_time", 1.25))
        state.cultivated_hours += hour * scale
        if state.path_id == "time_lord":
            params = path_def(eco, "time_lord")["params"]
            rate = float(params["charge_per_offline_hour"] if offline else params["charge_per_active_hour"])
            rate += node_sum(eco, state, "charge_add")
            art = _artifact_effect(eco, state, "time_skip_charge")
            state.chrono_charge += hour * rate * (1.0 + art)

    keep = qi_keep(eco, state)
    raw = gained_qi / keep if keep > 1e-6 else 0.0
    if state.world_id == "spirit_world" and keep < 0.999:
        convert = float(world_def(eco, "spirit_world")["qi_to_essence_convert_ratio"])
        diverted = raw - gained_qi
        state.world_res["spirit_essence"] = float(state.world_res.get("spirit_essence", 0.0)) + diverted * convert
    if "dual_flow" in state.unlocked:
        frac = float(research_doc(eco).get("dual_flow_fraction", 0.08))
        convert = float(world_def(eco, "spirit_world")["qi_to_essence_convert_ratio"])
        state.world_res["spirit_essence"] = float(state.world_res.get("spirit_essence", 0.0)) + raw * frac * convert

    if state.world_id == "void_dimension":
        rate = float(world_def(eco, "void_dimension")["entropy_rate"])
        if study_done(state, "entropy_valve"):
            for study in research_doc(eco)["studies"]:
                if study["id"] == "entropy_valve":
                    rate *= float(study["value"])
        retain = max(1.0, eco.production(state) * float(state.retain_seconds))
        if state.qi > retain:
            excess = state.qi - retain
            drain = min(excess, excess * rate * dt)
            state.qi -= drain
            dust = drain * float(world_def(eco, "void_dimension")["dust_per_qi"])
            state.world_res["void_dust"] = float(state.world_res.get("void_dust", 0.0)) + dust

    if state.world_id == "heavenly_world":
        state.tribulation_t += dt
        interval = float(world_def(eco, "heavenly_world")["tribulation_interval_sec"])
        if state.tribulation_t >= interval:
            _resolve_tribulation(eco, state)

    if state.world_id == "chaos_origin":
        state.chaos_pulse_t += dt
        pulse = float(world_def(eco, "chaos_origin").get("pulse_sec", 90))
        if state.chaos_pulse_t >= pulse:
            state.chaos_pulse_t -= pulse
            state.world_res["chaos_seed"] = float(state.world_res.get("chaos_seed", 0.0)) + float(
                world_def(eco, "chaos_origin").get("seed_per_pulse", 1)
            )
            eco._mark(state, "chaos_pulse")

    study = _active_study(eco, state)
    if study is not None:
        state.research_progress += dt
        if state.research_progress + 1e-9 >= float(study["seconds"]):
            state.research_done.add(study["id"])
            state.research_progress = 0.0
            eco._mark(state, "research:" + study["id"])
    clamp_state(eco, state)


def maybe_bank_offline(eco, state, gained: float, dt: float) -> float:
    """Return Qi that should stay banked as offline time instead of being paid now."""
    ratio = bank_ratio(eco, state)
    if ratio <= 0.0 or dt <= 0.0 or gained <= 0.0:
        return 0.0
    state.banked_sec += dt * ratio
    return gained * ratio


def auto_systems(eco, state) -> None:
    if eco.auto_on(state, "auto_path_burst"):
        _auto_path(eco, state)
    if eco.auto_on(state, "auto_world_balance"):
        _auto_world(eco, state)
    if eco.auto_on(state, "auto_rule_forge"):
        _auto_laws(eco, state)


def _auto_path(eco, state) -> None:
    if not state.path_joined or path_level(state) < 5:
        return
    if state.path_id == "demon_emperor":
        if state.burst_left <= 0.0 and state.demon_fed <= 0.0 and state.qi > 50.0:
            sacrifice(eco, state, "qi")
    elif state.path_id == "world_devourer":
        if "upgrade" not in state.devour_types:
            absorb(eco, state, "upgrade")
        if "artifact" not in state.devour_types and state.artifacts_owned:
            absorb(eco, state, "artifact")
        for key in RESOURCE_KEYS:
            if key not in state.devour_types and float(state.world_res.get(key, 0.0)) > 0.0:
                absorb(eco, state, key)
                break
    elif state.path_id == "time_lord":
        if state.speed_left <= 0.0:
            start_speed(eco, state)
        nxt = eco.breakthrough_cost(state)
        if nxt and state.qi < nxt and state.banked_sec >= 60.0:
            time_skip(eco, state)


def _auto_world(eco, state) -> None:
    if state.world_id == "spirit_world":
        essence = float(state.world_res.get("spirit_essence", 0.0))
        per = float(world_def(eco, "spirit_world")["essence_breakthrough_discount_per"])
        cap = float(world_def(eco, "spirit_world")["essence_discount_cap"])
        disc = min(cap, essence * per)
        if disc < 0.2:
            state.essence_ratio = 0.5
        elif disc < 0.4:
            state.essence_ratio = 0.25
        else:
            state.essence_ratio = 0.0
    elif state.world_id == "void_dimension":
        state.retain_seconds = 180.0
    elif state.world_id == "heavenly_world":
        if state.stance not in ("guard", "defy"):
            state.stance = "guard"


def _auto_laws(eco, state) -> None:
    order = ["soft_growth", "time_tithe", "flat_as_mult", "batch_insight", "qi_or_time"]
    slots = law_slots(eco, state)
    while len(state.slotted_laws) < slots:
        placed = False
        for law_id in order:
            if law_id in state.slotted_laws:
                continue
            if slot_law(eco, state, law_id):
                placed = True
                break
        if not placed:
            break


def maintain(eco, state) -> None:
    """Path bot policy. One decision per call, not a tap loop."""
    if research_unlocked(eco, state) and not state.research_order:
        state.research_order = [s["id"] for s in research_doc(eco)["studies"]]
    if not state.path_joined:
        return
    _buy_nodes(eco, state)
    if state.path_id == "demon_emperor":
        if state.burst_left <= 0.0 and state.demon_fed <= 0.0 and state.qi > 80.0:
            sacrifice(eco, state, "qi")
        elif (
            node_sum(eco, state, "rank_sacrifice") > 0
            and state.demon_permanent < 0.2
            and state.rank_index > 15
            and state.rebirth_count >= 20
        ):
            sacrifice(eco, state, "rank")
    elif state.path_id == "world_devourer":
        if "upgrade" not in state.devour_types and any(int(v) > 2 for v in state.upgrade_levels.values()):
            absorb(eco, state, "upgrade")
        if "artifact" not in state.devour_types and len(state.artifacts_owned) >= 2:
            absorb(eco, state, "artifact")
        for key in RESOURCE_KEYS:
            if key not in state.devour_types and float(state.world_res.get(key, 0.0)) > 1.0:
                absorb(eco, state, key)
                break
    elif state.path_id == "time_lord":
        if state.speed_left <= 0.0:
            start_speed(eco, state)
        nxt = eco.breakthrough_cost(state)
        if nxt and 0 < state.qi < nxt * 0.85 and state.banked_sec >= 45.0:
            time_skip(eco, state)
    if state.world_id == "spirit_world" and not eco.auto_on(state, "auto_world_balance"):
        essence = float(state.world_res.get("spirit_essence", 0.0))
        if essence < 40:
            state.essence_ratio = 0.5
        elif essence < 200:
            state.essence_ratio = 0.25
        else:
            state.essence_ratio = 0.1
    if state.world_id == "heavenly_world" and state.stance == "guard" and state.tribulation_cycle >= 4:
        state.stance = "defy"
    if law_slots(eco, state) > len(state.slotted_laws):
        prefer = {
            "heavenly_sword": "flat_as_mult",
            "demon_emperor": "soft_growth",
            "immortal": "time_tithe",
            "world_devourer": "batch_insight",
            "time_lord": "qi_or_time",
        }.get(state.path_id, "soft_growth")
        slot_law(eco, state, prefer)
    if state.world_id == "void_dimension" and not state.active_rewrite:
        if float(state.world_res.get("void_dust", 0.0)) >= float(world_def(eco, "void_dimension")["rewrite_cost"]):
            buy_void_rewrite(eco, state)


def _buy_nodes(eco, state) -> None:
    path = path_def(eco, state.path_id)
    if not path:
        return
    # Prefer the node's listed order. Buy one level per decision so the tree is a choice, not a dump.
    for node in path.get("nodes", []):
        level = node_level(state, node["id"])
        if level >= int(node["max_level"]):
            continue
        if state.path_currency + 1e-9 >= node_cost(node, level):
            buy_node(eco, state, node["id"])
            return
