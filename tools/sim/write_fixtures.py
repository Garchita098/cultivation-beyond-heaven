#!/usr/bin/env python3
"""Write golden ticks and small stage-2 cases shared with the Godot tests."""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from bots import RebirthEarly  # noqa: E402
from economy import Economy, fresh_state  # noqa: E402

HERE = os.path.dirname(__file__)
REPORTS = os.path.join(HERE, "reports")


def sample(eco: Economy, state) -> dict:
    return {
        "t": state.time_sec,
        "qi": state.qi,
        "prod": eco.production(state),
        "rank_index": state.rank_index,
        "rank_id": eco.rank(state)["id"],
        "rebirths": state.rebirth_count,
        "karma": state.karma_shards,
        "talents": len(state.talents_owned),
        "artifacts": len(state.artifacts_owned),
        "shop_mult": state.shop_mult,
    }


def write_golden(eco: Economy) -> None:
    bot = RebirthEarly()
    state = fresh_state()
    dt = float(eco.balance["tick_seconds"])
    acc = 0.0
    samples = []
    while True:
        eco.tick(state, dt)
        acc += dt
        decided = False
        if acc >= 0.5 - 1e-12:
            acc = 0.0
            bot.decide(eco, state)
            decided = True
        t = state.time_sec
        if abs(t - dt) < 1e-9 or abs(t % 30.0) < 1e-6 or abs((t % 30.0) - 30.0) < 1e-6:
            if decided or abs(t - dt) < 1e-9:
                samples.append(sample(eco, state))
        rebirth_2 = state.milestones.get("rebirth:2")
        if rebirth_2 is not None and state.time_sec >= rebirth_2 + 60.0:
            break
        if state.time_sec > 7200:
            break
    doc = {
        "bot": "rebirth_early",
        "stage": 2,
        "milestones": dict(state.milestones),
        "ticks_every_30s": samples,
    }
    path = os.path.join(REPORTS, "golden_ticks.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
    print(f"golden samples={len(samples)} t={samples[-1]['t']:.1f} -> {path}")


def write_cases(eco: Economy) -> None:
    roll_a = eco.roll_talent_fields(81001)
    roll_b = eco.roll_talent_fields(82001)
    costs = [eco.shop_cost("karma_prod_1", i) for i in range(7)]

    st = fresh_state()
    st.rank_index = 15
    st.highest_rank_index = 15
    st.qi = 50.0
    st.lifetime_qi = 1.0e10
    st.upgrade_levels = {"breath_meditation": 12, "body_tempering": 4}
    st.unlocked.update({"spiritual_roots", "artifacts_basic", "rebirth_unlock"})
    st.artifacts_owned["jade_slip"] = 1
    st.artifacts_equipped = ["jade_slip"]
    st.talents_owned = [
        {"uid": "t1", "root_id": "fire_root", "rarity": "rare", "roll": 0.12, "level": 1}
    ]
    st.talents_equipped = ["t1"]
    st.talent_seq = 2
    st.shop_levels["karma_prod_1"] = 1
    st.karma_shards = 3.0
    st.path_id = "heavenly_sword"
    assert eco.do_rebirth(st)
    rebirth = {
        "qi": st.qi,
        "rank_index": st.rank_index,
        "karma": st.karma_shards,
        "rebirths": st.rebirth_count,
        "upgrades": dict(st.upgrade_levels),
        "talents": len(st.talents_owned),
        "talent_uids": [t["uid"] for t in st.talents_owned],
        "artifacts": sorted(st.artifacts_owned.keys()),
        "artifact_levels": {k: int(v) for k, v in st.artifacts_owned.items()},
        "path_id": st.path_id,
        "shop_mult": st.shop_mult,
        "unlocked_shop": "karma_shop_basic" in st.unlocked,
    }

    off = fresh_state()
    off.rank_index = 12
    off.highest_rank_index = 12
    off.qi = 0.0
    off.unlocked.add("automation_buy_upgrades")
    off.unlocked.add("auto_buy_upgrades")
    off.automation_toggles["auto_buy_upgrades"] = True
    info = eco.apply_offline(off, 180.0)
    offline = {
        "chunked": bool(info["chunked"]),
        "gained": info["gained"],
        "qi": off.qi,
        "breath": int(off.upgrade_levels.get("breath_meditation", 0)),
        "rank_index": off.rank_index,
    }

    bare = fresh_state()
    bare.artifacts_owned["flying_sword_shard"] = 0
    bare.artifacts_equipped = ["flying_sword_shard"]
    prod_plain = eco.production(bare)
    bare.path_id = "heavenly_sword"
    prod_path = eco.production(bare)

    cases = {
        "roll_81001": roll_a,
        "roll_82001": roll_b,
        "shop_prod_costs": costs,
        "rebirth": rebirth,
        "offline_auto": offline,
        "path_hook_prod": {"plain": prod_plain, "with_path": prod_path},
    }
    path = os.path.join(REPORTS, "stage2_cases.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(cases, f, indent=2)
    print(f"cases -> {path}")
    print("rebirth", rebirth)
    print("offline", offline)
    print("rolls", roll_a, roll_b)


def write_stage3(eco: Economy) -> None:
    import stage3

    def snap_sword():
        st = fresh_state()
        st.path_joined = True
        st.path_id = "heavenly_sword"
        st.rank_index = 4
        st.upgrade_levels = {"breath_meditation": 10}
        outside = eco.production(st)
        period = stage3._charge_period(eco, st)
        # dt=1 ticks. Burst starts at the end of the tick that fills the charge,
        # so production on the next read is the burst.
        steps = int(period)
        for _ in range(steps):
            eco.tick(st, 1.0)
        return {
            "outside": outside,
            "burst": eco.production(st),
            "burst_left": st.burst_left,
            "bursts": int(st.mechanic_counts.get("sword_burst", 0)),
        }

    def snap_demon():
        st = fresh_state()
        st.path_joined = True
        st.path_id = "demon_emperor"
        st.qi = 1000.0
        st.rank_index = 8
        before = eco.production(st)
        assert stage3.sacrifice(eco, st, "qi")
        return {
            "before": before,
            "after": eco.production(st),
            "qi": st.qi,
            "permanent": st.demon_permanent,
            "burst_left": st.burst_left,
        }

    def snap_immortal():
        st = fresh_state()
        st.path_joined = True
        st.path_id = "immortal"
        st.rank_index = 4
        start = eco.production(st)
        info = eco.apply_offline(st, 3600.0)
        return {
            "start": start,
            "after": eco.production(st),
            "hours": st.cultivated_hours,
            "qi": st.qi,
            "chunked": bool(info["chunked"]),
            "eff": info["efficiency"],
        }

    def snap_devour():
        st = fresh_state()
        st.path_joined = True
        st.path_id = "world_devourer"
        st.upgrade_levels = {"breath_meditation": 6, "body_tempering": 3}
        st.artifacts_owned = {"jade_slip": 1, "spirit_stone_pouch": 0}
        st.artifacts_equipped = ["jade_slip"]
        plain = eco.production(st)
        assert stage3.absorb(eco, st, "upgrade")
        assert stage3.absorb(eco, st, "artifact")
        return {
            "plain": plain,
            "after": eco.production(st),
            "types": sorted(st.devour_types),
            "bonus": st.devour_bonus,
            "breath": int(st.upgrade_levels.get("breath_meditation", 0)),
        }

    def snap_time():
        st = fresh_state()
        st.path_joined = True
        st.path_id = "time_lord"
        st.rank_index = 6
        st.upgrade_levels = {"breath_meditation": 12}
        st.chrono_charge = 3.0
        st.banked_sec = 600.0
        before = st.qi
        assert stage3.start_speed(eco, st)
        sped = eco.production(st)
        assert stage3.time_skip(eco, st)
        return {
            "sped": sped,
            "qi": st.qi,
            "qi_before": before,
            "bank": st.banked_sec,
            "charge": st.chrono_charge,
            "speed_left": st.speed_left,
        }

    def snap_ascend():
        st = fresh_state()
        st.rank_index = 19
        st.highest_rank_index = 19
        st.rebirth_count = 25
        st.qi = 1.0e12
        st.lifetime_qi = 1.0e14
        st.karma_shards = 40.0
        st.upgrade_levels = {"breath_meditation": 10}
        st.path_joined = True
        st.path_id = "immortal"
        st.path_nodes = {"dew_rate": 1}
        st.shop_levels = {"karma_prod_1": 2}
        st.unlocked.update({"spiritual_roots", "ascension_gate", "path_selection"})
        st.talents_owned = [{"uid": "t1", "root_id": "water_root", "rarity": "common", "roll": 0.04, "level": 0}]
        st.artifacts_owned = {"jade_slip": 0}
        gain = stage3.ascension_gain(eco, st)
        assert stage3.do_ascension(eco, st)
        return {
            "gain": gain,
            "marks": st.dao_marks,
            "world": st.world_id,
            "qi": st.qi,
            "karma": st.karma_shards,
            "rank": st.rank_index,
            "upgrades": dict(st.upgrade_levels),
            "path_id": st.path_id,
            "node": int(st.path_nodes.get("dew_rate", 0)),
            "talents": len(st.talents_owned),
            "artifacts": len(st.artifacts_owned),
            "ascensions": st.ascension_count,
            "shop": int(st.shop_levels.get("karma_prod_1", 0)),
        }

    def snap_spirit():
        st = fresh_state()
        st.world_id = "spirit_world"
        st.essence_ratio = 0.5
        st.rank_index = 4
        st.upgrade_levels = {"breath_meditation": 8}
        prod = eco.production(st)
        for _ in range(10):
            eco.tick(st, 1.0)
        return {"prod": prod, "qi": st.qi, "essence": float(st.world_res.get("spirit_essence", 0.0))}

    def snap_heaven():
        st = fresh_state()
        st.world_id = "heavenly_world"
        st.rank_index = 16
        st.karma_shards = 20.0
        st.upgrade_levels = {"breath_meditation": 30, "body_tempering": 10}
        st.stance = "defy"
        plain = eco.production(st)
        for _ in range(180):
            eco.tick(st, 1.0)
        return {
            "plain": plain,
            "boon": eco.production(st),
            "boon_left": st.boon_left,
            "fragments": float(st.world_res.get("dao_fragments", 0.0)),
            "cycle": st.tribulation_cycle,
        }

    def snap_void():
        st = fresh_state()
        st.world_id = "void_dimension"
        st.rank_index = 4
        st.qi = 1.0e6
        st.retain_seconds = 60.0
        st.upgrade_levels = {"breath_meditation": 5}
        for _ in range(5):
            eco.tick(st, 1.0)
        return {"qi": st.qi, "dust": float(st.world_res.get("void_dust", 0.0))}

    def snap_law():
        st = fresh_state()
        st.rank_index = 8
        st.upgrade_levels = {"breath_meditation": 12, "body_tempering": 10}
        st.unlocked.add("dao_laws")
        base_cost = eco.upgrade_cost(st, "breath_meditation")
        base_prod = eco.production(st)
        assert stage3.slot_law(eco, st, "soft_growth")
        soft = eco.upgrade_cost(st, "breath_meditation")
        st.slotted_laws = ["flat_as_mult"]
        powered = eco.production(st)
        return {"base_cost": base_cost, "soft_cost": soft, "base_prod": base_prod, "powered": powered}

    def snap_reality():
        st = fresh_state()
        st.rank_index = 12
        st.upgrade_levels = {"breath_meditation": 20, "body_tempering": 30}
        st.unlocked.add("reality_stitch")
        plain = eco.production(st)
        st.reality_mode = "inverted"
        inverted = eco.production(st)
        st.reality_mode = "dilated"
        dilated = eco.production(st)
        return {"plain": plain, "inverted": inverted, "dilated": dilated}

    def snap_dual():
        st = fresh_state()
        st.unlocked.add("dual_flow")
        st.rank_index = 4
        st.upgrade_levels = {"breath_meditation": 6}
        for _ in range(4):
            eco.tick(st, 1.0)
        return {"essence": float(st.world_res.get("spirit_essence", 0.0)), "qi": st.qi}

    def snap_research():
        st = fresh_state()
        st.rebirth_count = 5
        st.unlocked.add("path_selection")
        for _ in range(90):
            eco.tick(st, 1.0)
        return {
            "done": "quiet_meridians" in st.research_done,
            "progress": st.research_progress,
            "order0": st.research_order[0] if st.research_order else "",
        }

    def snap_offline_parity():
        st = fresh_state()
        st.path_joined = True
        st.path_id = "heavenly_sword"
        st.rank_index = 3
        st.upgrade_levels = {"breath_meditation": 4}
        info = eco.apply_offline(st, 120.0)
        manual = fresh_state()
        manual.path_joined = True
        manual.path_id = "heavenly_sword"
        manual.rank_index = 3
        manual.upgrade_levels = {"breath_meditation": 4}
        # Mirror chunked offline: 60s slices at full eff (120 < soft cap).
        for _ in range(2):
            eco._offline_slice(manual, 60.0, half=False)
            eco.automation_act(manual)
        manual.time_sec += 120.0
        return {
            "chunked": bool(info["chunked"]),
            "qi": st.qi,
            "manual_qi": manual.qi,
            "bursts": int(st.mechanic_counts.get("sword_burst", 0)),
        }

    cases = {
        "sword": snap_sword(),
        "demon": snap_demon(),
        "immortal": snap_immortal(),
        "devour": snap_devour(),
        "time": snap_time(),
        "ascension": snap_ascend(),
        "spirit": snap_spirit(),
        "heaven": snap_heaven(),
        "void": snap_void(),
        "law": snap_law(),
        "reality": snap_reality(),
        "dual": snap_dual(),
        "research": snap_research(),
        "offline_sword": snap_offline_parity(),
    }
    path = os.path.join(REPORTS, "stage3_cases.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(cases, f, indent=2)
    print("stage3 cases", cases["ascension"]["world"], "sword", cases["sword"])


def main() -> None:
    os.makedirs(REPORTS, exist_ok=True)
    eco = Economy()
    write_cases(eco)
    write_stage3(eco)
    write_golden(eco)


if __name__ == "__main__":
    main()
