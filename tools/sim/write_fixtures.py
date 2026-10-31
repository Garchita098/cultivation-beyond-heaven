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


def main() -> None:
    os.makedirs(REPORTS, exist_ok=True)
    eco = Economy()
    write_cases(eco)
    write_golden(eco)


if __name__ == "__main__":
    main()
