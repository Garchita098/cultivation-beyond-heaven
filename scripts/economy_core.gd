class_name EconomyCore
extends RefCounted
## Direct port of tools/sim/economy.py (docs/FORMULAS.md). Stage cap is 3.

const STAGE_CAP := 3
const HOOK_EFFECTS := {
	"sacrifice_efficiency": true,
	"absorb_rate": true,
	"time_skip_charge": true,
	"rule_slot": true,
}
const AUTO_ORDER_MAX := 7


static func cbh_unit(n: int) -> float:
	n = n & 0x7FFFFFFF
	n = (n * 1103515245 + 12345) & 0x7FFFFFFF
	return float(n) / 2147483648.0


static func production(data: EconData, rank_index: int, levels: Dictionary, karma: float, shop_mult: float) -> float:
	var state := SimState.new()
	state.rank_index = rank_index
	state.highest_rank_index = rank_index
	state.upgrade_levels = levels.duplicate()
	state.karma_shards = karma
	state.shop_mult = shop_mult
	return production_state(data, state)


static func production_bn(data: EconData, rank_index: int, levels: Dictionary, karma: float, shop_mult: float) -> BigNum:
	return BigNum.from_float(production(data, rank_index, levels, karma, shop_mult))


static func production_state(data: EconData, state: SimState) -> float:
	Achievements.sync(data, state)
	refresh_derived(data, state)
	var base := float(data.balance["base_qi_per_sec"])
	var tmods := talent_mods(data, state)
	var amods := artifact_mods(data, state)
	var flat_sum: float = float(tmods["flat"]) + float(amods["flat"])
	var mult_add := 0.0
	var speed_mult: float = 1.0 + float(tmods["speed"]) + float(amods["speed"])
	for uid in data.upgrade_order:
		var lvl := int(state.upgrade_levels.get(uid, 0))
		if lvl <= 0:
			continue
		var u: Dictionary = data.upgrades[uid]
		var ev := float(u["effect_value"])
		match str(u["effect_type"]):
			"flat_prod":
				flat_sum += ev * float(lvl)
			"mult_prod":
				mult_add += ev * float(lvl)
			"speed_mult":
				speed_mult += ev * float(lvl)
	var rank_mult := float(data.rank_at(state.rank_index)["prod_mult"])
	var perm := float(data.rebirth["tiers"][0]["perm_mult_per_karma"])
	var karma_mult := 1.0 + state.karma_shards * perm
	var prod := (
		base
		* (1.0 + flat_sum)
		* (1.0 + mult_add)
		* rank_mult
		* karma_mult
		* state.shop_mult
		* float(tmods["mult"])
		* float(amods["mult"])
		* speed_mult
	)
	var out := Stage3Rules.adjust_prod(data, state, prod, {"flat_sum": flat_sum, "mult_add": mult_add, "speed_mult": speed_mult})
	var bonus := Achievements.qi_mult(data, state)
	if bonus != 1.0:
		out *= bonus
	return out


static func upgrade_cost(data: EconData, levels: Dictionary, uid: String) -> float:
	var state := SimState.new()
	state.upgrade_levels = levels.duplicate()
	return upgrade_cost_state(data, state, uid)


static func upgrade_cost_bn(data: EconData, levels: Dictionary, uid: String) -> BigNum:
	return BigNum.from_float(upgrade_cost(data, levels, uid))


static func upgrade_cost_state(data: EconData, state: SimState, uid: String) -> float:
	var u: Dictionary = data.upgrades[uid]
	var lvl := int(state.upgrade_levels.get(uid, 0))
	var reduction := cost_reduction(data, state)
	var raw := float(u["base_cost"]) * pow(float(u["growth"]), float(lvl))
	var cost := raw * (1.0 - reduction)
	return Stage3Rules.adjust_cost(data, state, cost, float(u["base_cost"]), float(u["growth"]), lvl, reduction)


static func cost_reduction(data: EconData, state: SimState) -> float:
	var total: float = float(talent_mods(data, state)["cost"])
	for uid in data.upgrade_order:
		var u: Dictionary = data.upgrades[uid]
		if str(u["effect_type"]) != "cost_reduction":
			continue
		total += float(u["effect_value"]) * float(int(state.upgrade_levels.get(uid, 0)))
	return minf(0.8, total)


static func refresh_derived(data: EconData, state: SimState) -> void:
	var shops := _shop_by_id(data)
	var prod: Dictionary = shops["karma_prod_1"]
	state.shop_mult = 1.0 + float(prod["value"]) * float(int(state.shop_levels.get("karma_prod_1", 0)))
	var start: Dictionary = shops["karma_start_qi"]
	state.starting_qi_bonus = float(start["value"]) * float(int(state.shop_levels.get("karma_start_qi", 0)))


static func offline_bonus(data: EconData, state: SimState) -> float:
	var bonus := float(state.offline_eff_bonus)
	for t in data.rebirth["tiers"]:
		var tier: Dictionary = t
		if state.rebirth_count >= int(tier["min_rebirths"]):
			bonus += float(tier.get("offline_efficiency_bonus", 0.0))
	var item: Dictionary = _shop_by_id(data)["karma_offline"]
	var lvl := int(state.shop_levels.get("karma_offline", 0))
	var mx := int(item.get("max", lvl))
	bonus += float(item["value"]) * float(mini(lvl, mx))
	bonus += float(talent_mods(data, state)["offline"])
	bonus += float(artifact_mods(data, state)["offline"])
	bonus += Stage3Rules.extra_offline_bonus(data, state)
	var ach_off := Achievements.offline_bonus(data, state)
	if ach_off:
		bonus += ach_off
	return bonus


static func max_playable_index(data: EconData) -> int:
	var last := 0
	for r in data.ranks:
		if int(r.get("stage", 1)) <= STAGE_CAP:
			last = int(r["index"])
	return last


static func next_rank_dict(data: EconData, rank_index: int, stage_cap: int = STAGE_CAP) -> Dictionary:
	if rank_index + 1 >= data.ranks.size():
		return {}
	var nxt: Dictionary = data.ranks[rank_index + 1]
	var cap := stage_cap if stage_cap > 0 else STAGE_CAP
	if int(nxt.get("stage", 1)) > cap:
		return {}
	return nxt


static func next_rank_state(data: EconData, state: SimState) -> Dictionary:
	return next_rank_dict(data, state.rank_index, STAGE_CAP)


static func breakthrough_cost(data: EconData, state: SimState) -> float:
	var nxt := next_rank_state(data, state)
	if nxt.is_empty():
		return -1.0
	var disc: float = float(artifact_mods(data, state)["discount"])
	var cost := float(nxt["cost_qi"]) * (1.0 - disc)
	return Stage3Rules.adjust_breakthrough(data, state, cost)


static func unlocked_upgrades(data: EconData, state: SimState) -> Array:
	var out: Array = []
	for uid in data.upgrade_order:
		var u: Dictionary = data.upgrades[uid]
		var req := int(data.ranks_by_id[str(u["unlock_rank"])]["index"])
		if state.rank_index >= req:
			out.append(u)
	return out


static func can_buy(data: EconData, state: SimState, uid: String) -> bool:
	var u: Dictionary = data.upgrades[uid]
	if state.rank_index < int(data.ranks_by_id[str(u["unlock_rank"])]["index"]):
		return false
	var lvl := int(state.upgrade_levels.get(uid, 0))
	var mx := int(u.get("max_level", 0))
	if mx > 0 and lvl >= mx:
		return false
	return state.qi >= upgrade_cost_state(data, state, uid)


static func buy(data: EconData, state: SimState, uid: String) -> bool:
	if not can_buy(data, state, uid):
		return false
	var cost := upgrade_cost_state(data, state, uid)
	var u: Dictionary = data.upgrades[uid]
	state.qi -= cost
	state.upgrade_levels[uid] = int(state.upgrade_levels.get(uid, 0)) + 1
	var extra := Stage3Rules.bonus_levels(data, state, int(state.upgrade_levels[uid]))
	if extra > 0:
		var mx := int(u.get("max_level", 0))
		var nxt_lvl := int(state.upgrade_levels[uid]) + extra
		if mx <= 0 or nxt_lvl <= mx:
			state.upgrade_levels[uid] = nxt_lvl
	state.last_purchase_or_unlock_time = state.time_sec
	var key := "upgrade:%s:L%d" % [uid, int(state.upgrade_levels[uid])]
	_mark(state, key)
	_mark(state, "first_upgrade")
	return true


static func can_breakthrough(data: EconData, state: SimState) -> bool:
	var cost := breakthrough_cost(data, state)
	if cost < 0.0:
		return false
	return state.qi >= cost


static func breakthrough(data: EconData, state: SimState) -> bool:
	if not can_breakthrough(data, state):
		return false
	var nxt := next_rank_state(data, state)
	var cost := breakthrough_cost(data, state)
	var spent := Stage3Rules.bank_spent_on_breakthrough(data, state)
	if spent > 0.0:
		state.banked_sec = maxf(0.0, state.banked_sec - spent)
	state.qi -= cost
	state.rank_index += 1
	state.highest_rank_index = maxi(state.highest_rank_index, state.rank_index)
	state.last_purchase_or_unlock_time = state.time_sec
	on_rank_entered(data, state, nxt)
	_mark(state, "rank:%s" % str(nxt["id"]))
	if state.rank_index == 1:
		_mark(state, "first_breakthrough")
	var unlocks: Array = nxt.get("unlocks", [])
	if unlocks.has("rebirth_unlock"):
		_mark(state, "rebirth_unlocked")
	return true


static func on_rank_entered(data: EconData, state: SimState, rank: Dictionary) -> void:
	for feature in rank.get("unlocks", []):
		state.unlocked[str(feature)] = true
	var unlocks: Array = rank.get("unlocks", [])
	if unlocks.has("spiritual_roots"):
		grant_talent_once(data, state, "unlock", int(data.talents["roll_seed_unlock"]))
	var rid := str(rank["id"])
	var milestones: Array = data.talents.get("milestone_ranks", [])
	if milestones.has(rid) and rid != str(data.talents.get("unlock_rank", "")):
		grant_talent_once(data, state, "rank:" + rid, 84000 + int(rank["index"]))
	if unlocks.has("artifacts_basic") and state.artifacts_owned.is_empty():
		grant_next_artifact(data, state)


static func _apply_start_rank(data: EconData, state: SimState) -> void:
	var bonus := 0
	for t in data.rebirth["tiers"]:
		var tier: Dictionary = t
		if state.rebirth_count >= int(tier["min_rebirths"]):
			bonus = maxi(bonus, int(tier.get("start_rank_bonus", 0)))
	bonus = mini(bonus, max_playable_index(data))
	while state.rank_index < bonus:
		var nxt: Dictionary = data.ranks[state.rank_index + 1]
		state.rank_index += 1
		state.highest_rank_index = maxi(state.highest_rank_index, state.rank_index)
		on_rank_entered(data, state, nxt)


# ----- talents -----

static func roll_talent_fields(data: EconData, seed: int) -> Dictionary:
	var rarities: Array = data.talents["rarities"]
	var total := 0.0
	for r in rarities:
		total += float(r["weight"])
	var u := cbh_unit(seed) * total
	var acc := 0.0
	var rarity: Dictionary = rarities[rarities.size() - 1]
	for r in rarities:
		acc += float(r["weight"])
		if u < acc:
			rarity = r
			break
	var roots: Array = data.talents["roots"]
	var ri := int(cbh_unit(seed + 17) * float(roots.size()))
	if ri >= roots.size():
		ri = roots.size() - 1
	var root: Dictionary = roots[ri]
	var span: Array = rarity["mult_range"]
	var lo := float(span[0])
	var hi := float(span[1])
	var roll := lo + (hi - lo) * cbh_unit(seed + 41)
	return {"root_id": str(root["id"]), "rarity": str(rarity["id"]), "roll": roll}


static func grant_talent(data: EconData, state: SimState, seed: int) -> Dictionary:
	var rolled := roll_talent_fields(data, seed)
	var talent := {
		"uid": "t%d" % state.talent_seq,
		"root_id": rolled["root_id"],
		"rarity": rolled["rarity"],
		"roll": rolled["roll"],
		"level": 0,
	}
	state.talent_seq += 1
	state.talents_owned.append(talent)
	var cap := int(data.talents["max_equipped"])
	if state.talents_equipped.size() < cap:
		state.talents_equipped.append(str(talent["uid"]))
	_mark(state, "talent:%s" % str(talent["uid"]))
	return talent


static func grant_talent_once(data: EconData, state: SimState, key: String, seed: int) -> Dictionary:
	if state.talent_roll_keys.has(key):
		return {}
	if key != "unlock" and not state.unlocked.has("spiritual_roots"):
		return {}
	state.talent_roll_keys[key] = true
	var talent := grant_talent(data, state, seed)
	_mark(state, "talent_roll:%s" % key)
	return talent


static func _find_talent(state: SimState, uid: String) -> Dictionary:
	for t in state.talents_owned:
		if str(t["uid"]) == uid:
			return t
	return {}


static func _talent_value(data: EconData, talent: Dictionary) -> float:
	var gain := float(data.talents["upgrade"]["effect_gain_per_level"])
	return float(talent["roll"]) + float(int(talent.get("level", 0))) * gain


static func _root(data: EconData, root_id: String) -> Dictionary:
	for r in data.talents["roots"]:
		if str(r["id"]) == root_id:
			return r
	return {}


static func _path_tag_list(data: EconData, state: SimState) -> Array:
	if state.path_id == "":
		return []
	var tags: Dictionary = data.talents.get("path_tags", {})
	return tags.get(state.path_id, [])


static func talent_power(data: EconData, state: SimState, talent: Dictionary) -> float:
	var value := _talent_value(data, talent)
	var root := _root(data, str(talent["root_id"]))
	var w := 1.0
	match str(root.get("effect_type", "")):
		"mult_prod":
			w = 3.0
		"speed_mult":
			w = 2.5
		"cost_reduction":
			w = 2.2
		"offline_bonus":
			w = 1.6
		"flat_prod":
			w = 0.4
	return value * w


static func talent_mods(data: EconData, state: SimState, equipped_ids: Array = []) -> Dictionary:
	var ids := equipped_ids if not equipped_ids.is_empty() else state.talents_equipped
	var idset := {}
	for id in ids:
		idset[str(id)] = true
	var mult := 1.0
	var flat := 0.0
	var speed := 0.0
	var cost := 0.0
	var offline := 0.0
	var elements: Array = []
	var tags := _path_tag_list(data, state)
	for t in state.talents_owned:
		if not idset.has(str(t["uid"])):
			continue
		var root := _root(data, str(t["root_id"]))
		var value := _talent_value(data, t)
		var syn := 0.0
		if not tags.is_empty():
			for tag in root.get("synergy_with", []):
				if tags.has(tag):
					syn = float(root.get("synergy_bonus", 0.0))
					break
		match str(root.get("effect_type", "")):
			"mult_prod":
				mult *= 1.0 + value
				if syn:
					mult *= 1.0 + syn
			"flat_prod":
				flat += value + syn
			"speed_mult":
				speed += value + syn
			"cost_reduction":
				cost += value + syn
			"offline_bonus":
				offline += value + syn
		elements.append(str(root.get("element", "")))
	for pair in data.talents.get("element_synergies", []):
		if elements.has(str(pair["a"])) and elements.has(str(pair["b"])):
			mult *= 1.0 + float(pair["bonus"])
	return {"mult": mult, "flat": flat, "speed": speed, "cost": cost, "offline": offline}


static func talent_score(data: EconData, state: SimState, ids: Array) -> float:
	var m := talent_mods(data, state, ids)
	return (
		float(m["mult"]) * 1000.0
		+ float(m["flat"])
		+ float(m["speed"]) * 50.0
		+ float(m["offline"]) * 20.0
		+ float(m["cost"]) * 30.0
	)


static func equip_best_talents(data: EconData, state: SimState) -> void:
	var owned: Array = state.talents_owned
	var n := mini(int(data.talents["max_equipped"]), owned.size())
	if n <= 0:
		state.talents_equipped = []
		return
	var best_ids: Array = []
	var best_score := -1.0
	var have := false
	for combo in _combinations(owned, n):
		var ids: Array = []
		for t in combo:
			ids.append(str(t["uid"]))
		ids.sort()
		var score := talent_score(data, state, ids)
		var better := false
		if not have or score > best_score + 1e-12:
			better = true
		elif absf(score - best_score) <= 1e-12 and _array_lt(ids, best_ids):
			better = true
		if better:
			have = true
			best_score = score
			best_ids = ids
	state.talents_equipped = best_ids


static func talent_upgrade_cost(data: EconData, level: int) -> int:
	var up: Dictionary = data.talents["upgrade"]
	var raw := float(up["cost_base"]) * pow(float(up["cost_growth"]), float(level))
	return maxi(1, int(floor(raw + 1e-9)))


static func can_upgrade_talent(data: EconData, state: SimState, uid: String) -> bool:
	var talent := _find_talent(state, uid)
	if talent.is_empty():
		return false
	if int(talent["level"]) >= int(data.talents["upgrade"]["max_level"]):
		return false
	return state.karma_shards >= float(talent_upgrade_cost(data, int(talent["level"])))


static func upgrade_talent(data: EconData, state: SimState, uid: String) -> bool:
	if not can_upgrade_talent(data, state, uid):
		return false
	var talent := _find_talent(state, uid)
	var cost := talent_upgrade_cost(data, int(talent["level"]))
	state.karma_shards -= float(cost)
	talent["level"] = int(talent["level"]) + 1
	_mark(state, "talent_up:%s:L%d" % [uid, int(talent["level"])])
	return true


static func reroll_talent(data: EconData, state: SimState, uid: String) -> bool:
	if state.rebirth_count < 3 and not state.unlocked.has("talent_reroll"):
		return false
	var cost := int(data.rebirth.get("talent_reroll_cost", 4))
	if state.karma_shards < float(cost):
		return false
	var talent := _find_talent(state, uid)
	if talent.is_empty():
		return false
	state.karma_shards -= float(cost)
	state.reroll_count += 1
	var seed := int(data.talents["roll_seed_reroll_base"]) + state.reroll_count
	var rolled := roll_talent_fields(data, seed)
	talent["root_id"] = rolled["root_id"]
	talent["rarity"] = rolled["rarity"]
	talent["roll"] = rolled["roll"]
	_mark(state, "reroll:%d" % state.reroll_count)
	return true


# ----- artifacts -----

static func _art(data: EconData, aid: String) -> Dictionary:
	for a in data.artifacts["artifacts"]:
		if str(a["id"]) == aid:
			return a
	return {}


static func _drop_order(data: EconData) -> Array:
	return data.artifacts.get("drop_order", [])


static func _artifact_scaled(data: EconData, state: SimState, aid: String) -> Dictionary:
	var art := _art(data, aid)
	var level := int(state.artifacts_owned.get(aid, 0))
	var frac := float(data.artifacts["upgrade"]["effect_gain_fraction"])
	var ev := float(art["effect_value"]) * (1.0 + frac * float(level))
	if state.path_id != "" and state.path_id == str(art.get("path_bonus", "")):
		ev *= float(data.artifacts.get("path_match_effect_scale", 1.5))
	return {"art": art, "ev": ev}


static func artifact_score(data: EconData, state: SimState, aid: String) -> float:
	if not state.artifacts_owned.has(aid):
		return -1.0
	var scaled := _artifact_scaled(data, state, aid)
	var art: Dictionary = scaled["art"]
	var ev := float(scaled["ev"])
	var w := 1.0
	match str(art.get("effect_type", "")):
		"mult_prod":
			w = 3.0
		"offline_bonus":
			w = 2.0
		"breakthrough_discount":
			w = 2.5
		"flat_prod":
			w = 0.15
		"speed_mult":
			w = 2.0
	return ev * w


static func artifact_mods(data: EconData, state: SimState, equipped: Array = []) -> Dictionary:
	var ids: Array = equipped if not equipped.is_empty() else state.artifacts_equipped
	var mult := 1.0
	var flat := 0.0
	var speed := 0.0
	var offline := 0.0
	var discount := 0.0
	var hook_frac := float(data.artifacts.get("stage2_hook_as_mult", 0.5))
	for aid in ids:
		var key := str(aid)
		if not state.artifacts_owned.has(key):
			continue
		var scaled := _artifact_scaled(data, state, key)
		var art: Dictionary = scaled["art"]
		var ev := float(scaled["ev"])
		var et := str(art.get("effect_type", ""))
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
		elif HOOK_EFFECTS.has(et) and not Stage3Rules.hook_consumed(state, et):
			mult *= 1.0 + ev * hook_frac
	return {
		"mult": mult,
		"flat": flat,
		"speed": speed,
		"offline": offline,
		"discount": minf(0.5, discount),
	}


static func grant_next_artifact(data: EconData, state: SimState) -> String:
	for aid in _drop_order(data):
		var key := str(aid)
		if not state.artifacts_owned.has(key):
			state.artifacts_owned[key] = 0
			_consider_equip_artifact(data, state, key)
			_mark(state, "artifact:%s" % key)
			return key
	var mx := int(data.artifacts["upgrade"]["max_level"])
	var candidates: Array = []
	for aid in _drop_order(data):
		var key := str(aid)
		if state.artifacts_owned.has(key) and int(state.artifacts_owned[key]) < mx:
			candidates.append(key)
	if candidates.is_empty():
		return ""
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var la := int(state.artifacts_owned[a])
		var lb := int(state.artifacts_owned[b])
		if la != lb:
			return la < lb
		return _drop_order(data).find(a) < _drop_order(data).find(b)
	)
	var pick := str(candidates[0])
	state.artifacts_owned[pick] = int(state.artifacts_owned[pick]) + 1
	_mark(state, "artifact_dup:%s:L%d" % [pick, int(state.artifacts_owned[pick])])
	return pick


static func _consider_equip_artifact(data: EconData, state: SimState, aid: String) -> void:
	if state.artifacts_equipped.has(aid):
		return
	if state.artifacts_equipped.size() < int(data.artifacts["max_equipped"]):
		state.artifacts_equipped.append(aid)


static func equip_artifacts_for(data: EconData, state: SimState, style: String) -> void:
	var owned: Array = []
	for aid in _drop_order(data):
		if state.artifacts_owned.has(str(aid)):
			owned.append(str(aid))
	var cap := mini(int(data.artifacts["max_equipped"]), owned.size())
	if cap <= 0:
		state.artifacts_equipped = []
		return
	var hook_frac := float(data.artifacts.get("stage2_hook_as_mult", 0.5))
	var ranked := owned.duplicate()
	ranked.sort_custom(func(a: String, b: String) -> bool:
		var sa := _equip_score(data, state, a, style, hook_frac)
		var sb := _equip_score(data, state, b, style, hook_frac)
		if absf(sa - sb) > 1e-12:
			return sa > sb
		return _drop_order(data).find(a) < _drop_order(data).find(b)
	)
	var equipped: Array = []
	for i in cap:
		equipped.append(ranked[i])
	state.artifacts_equipped = equipped


static func _equip_score(data: EconData, state: SimState, aid: String, style: String, hook_frac: float) -> float:
	var scaled := _artifact_scaled(data, state, aid)
	var art: Dictionary = scaled["art"]
	var ev := float(scaled["ev"])
	var et := str(art.get("effect_type", ""))
	if style == "offline" and et == "offline_bonus":
		return 10.0 + ev * 5.0
	if et == "mult_prod":
		return ev * 4.0
	if HOOK_EFFECTS.has(et):
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


static func artifact_upgrade_cost(data: EconData, level: int) -> float:
	var up: Dictionary = data.artifacts["upgrade"]
	return float(up["cost_base"]) * pow(float(up["cost_growth"]), float(level))


static func upgrade_artifact(data: EconData, state: SimState, aid: String) -> bool:
	if not state.artifacts_owned.has(aid):
		return false
	var level := int(state.artifacts_owned[aid])
	if level >= int(data.artifacts["upgrade"]["max_level"]):
		return false
	var cost := artifact_upgrade_cost(data, level)
	if state.qi < cost:
		return false
	state.qi -= cost
	state.artifacts_owned[aid] = level + 1
	_mark(state, "art_up:%s:L%d" % [aid, level + 1])
	return true


# ----- shop / rebirth -----

static func _shop_by_id(data: EconData) -> Dictionary:
	var out := {}
	for s in data.rebirth["shop"]:
		out[str(s["id"])] = s
	return out


static func shop_cost(data: EconData, item_id: String, level: int) -> int:
	var item: Dictionary = _shop_by_id(data)[item_id]
	var raw := float(item["cost"]) * pow(float(item["growth"]), float(level))
	return maxi(1, int(floor(raw + 1e-9)))


static func can_buy_shop(data: EconData, state: SimState, item_id: String) -> bool:
	if not state.unlocked.has("karma_shop_basic") and state.rebirth_count < 1:
		return false
	var item: Dictionary = _shop_by_id(data)[item_id]
	if item_id == "karma_keep_upgrade" and not state.unlocked.has("karma_shop_advanced"):
		if state.rebirth_count < 10:
			return false
	var level := int(state.shop_levels.get(item_id, 0))
	var mx := int(item.get("max", 0))
	if mx > 0 and level >= mx:
		return false
	if not bool(item.get("repeatable", true)) and level >= 1:
		return false
	return state.karma_shards >= float(shop_cost(data, item_id, level))


static func buy_shop(data: EconData, state: SimState, item_id: String) -> bool:
	if not can_buy_shop(data, state, item_id):
		return false
	var level := int(state.shop_levels.get(item_id, 0))
	state.karma_shards -= float(shop_cost(data, item_id, level))
	state.shop_levels[item_id] = level + 1
	refresh_derived(data, state)
	_mark(state, "shop:%s:L%d" % [item_id, level + 1])
	return true


static func buy_shop_if_worth(data: EconData, state: SimState, item_id: String, style: String) -> bool:
	if not can_buy_shop(data, state, item_id):
		return false
	var before := production_state(data, state)
	var before_off := offline_bonus(data, state)
	var karma := state.karma_shards
	var level := int(state.shop_levels.get(item_id, 0))
	if not buy_shop(data, state, item_id):
		return false
	var after := production_state(data, state)
	var after_off := offline_bonus(data, state)
	var keep := after + 1e-9 >= before
	if item_id == "karma_offline" and after_off > before_off + 1e-12:
		keep = style == "offline" or after >= before * 0.97
	if item_id == "karma_start_qi" or item_id == "karma_keep_upgrade":
		keep = after >= before * 0.995
	if keep:
		return true
	state.karma_shards = karma
	state.shop_levels[item_id] = level
	refresh_derived(data, state)
	return false


static func karma_gain(data: EconData, state: SimState) -> int:
	var f: Dictionary = data.rebirth["formula"]
	var lq := maxf(1.0, state.lifetime_qi)
	var raw := (
		float(f["base"])
		+ (log(lq) / log(10.0)) / float(f["from_lifetime_qi_log10_div"])
		+ float(state.highest_rank_index) * float(f["from_highest_rank_index"])
	)
	return int(floor(raw))


static func can_rebirth(data: EconData, state: SimState) -> bool:
	return state.rank_index >= int(data.rebirth["min_rank_index_to_rebirth"])


static func _kept_upgrade_ids(data: EconData, state: SimState) -> Array:
	var item: Dictionary = _shop_by_id(data)["karma_keep_upgrade"]
	var n := int(state.shop_levels.get("karma_keep_upgrade", 0))
	var mx := int(item.get("max", n))
	n = mini(n, mx)
	if n <= 0:
		return []
	var pairs: Array = []
	for uid in state.upgrade_levels.keys():
		var lvl := int(state.upgrade_levels[uid])
		if lvl > 0:
			pairs.append({"uid": str(uid), "lvl": lvl})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["lvl"]) != int(b["lvl"]):
			return int(a["lvl"]) > int(b["lvl"])
		return str(a["uid"]) < str(b["uid"])
	)
	var out: Array = []
	for i in mini(n, pairs.size()):
		out.append(str(pairs[i]["uid"]))
	return out


static func do_rebirth(data: EconData, state: SimState) -> bool:
	if not can_rebirth(data, state):
		return false
	var kept := _kept_upgrade_ids(data, state)
	var kept_levels := {}
	for uid in kept:
		kept_levels[str(uid)] = int(state.upgrade_levels[uid])
	state.karma_shards += float(karma_gain(data, state))
	state.rebirth_count += 1
	for t in data.rebirth["tiers"]:
		var tier: Dictionary = t
		if state.rebirth_count >= int(tier["min_rebirths"]):
			for feature in tier.get("unlocks", []):
				state.unlocked[str(feature)] = true
	if state.unlocked.has("spiritual_roots"):
		var seed := int(data.talents["roll_seed_rebirth_base"]) + state.rebirth_count
		grant_talent(data, state, seed)
	if state.unlocked.has("artifacts_basic"):
		var grants := int(data.artifacts.get("grant_per_rebirth", 1))
		if state.rebirth_count >= int(data.artifacts.get("gacha_min_rebirths", 5)):
			grants = int(data.artifacts.get("grant_per_rebirth_after_gacha", grants))
		for _i in grants:
			grant_next_artifact(data, state)
	refresh_derived(data, state)
	state.qi = state.starting_qi_bonus
	state.upgrade_levels = kept_levels
	state.rank_index = 0
	_apply_start_rank(data, state)
	state.last_purchase_or_unlock_time = state.time_sec
	Stage3Rules.on_rebirth(data, state)
	_mark(state, "rebirth:%d" % state.rebirth_count)
	_mark(state, "first_rebirth")
	return true


# ----- automation -----

static func _auto_entry(data: EconData, aid: String) -> Dictionary:
	for entry in data.automation["unlock_order"]:
		if str(entry["id"]) == aid:
			return entry
	return {}


static func _defaults(data: EconData) -> Dictionary:
	return data.automation.get("auto_rebirth_defaults", {"min_rank_index": 15, "min_karma_gain": 1})


static func auto_available(data: EconData, state: SimState, aid: String) -> bool:
	var entry := _auto_entry(data, aid)
	if entry.is_empty() or int(entry.get("order", 99)) > AUTO_ORDER_MAX:
		return false
	if state.unlocked.has(aid):
		return true
	var spec: Dictionary = entry["unlock"]
	if str(spec["type"]) == "rank":
		var need := int(data.ranks_by_id[str(spec["id"])]["index"])
		return state.rank_index >= need or state.highest_rank_index >= need
	if str(spec["type"]) == "rebirths":
		return state.rebirth_count >= int(spec["min"])
	if str(spec["type"]) == "path_level":
		return Stage3Rules.path_level(state) >= int(spec["min"])
	if str(spec["type"]) == "ascension":
		return state.ascension_count >= int(spec["min"])
	return false


static func sync_automation_unlocks(data: EconData, state: SimState) -> void:
	if state.auto_rebirth_min_rank <= 0:
		state.auto_rebirth_min_rank = int(_defaults(data).get("min_rank_index", 15))
	for entry in data.automation["unlock_order"]:
		if int(entry.get("order", 99)) > AUTO_ORDER_MAX:
			continue
		var aid := str(entry["id"])
		if auto_available(data, state, aid):
			state.unlocked[aid] = true
			if aid == "auto_buy_upgrades":
				state.unlocked["automation_buy_upgrades"] = true
			if not state.automation_toggles.has(aid):
				state.automation_toggles[aid] = true


static func auto_on(data: EconData, state: SimState, aid: String) -> bool:
	return bool(state.automation_toggles.get(aid, false)) and auto_available(data, state, aid)


static func automation_act(data: EconData, state: SimState) -> void:
	sync_automation_unlocks(data, state)
	if auto_on(data, state, "auto_equip_talents"):
		equip_best_talents(data, state)
	if auto_on(data, state, "auto_rebirth") and can_rebirth(data, state):
		if state.rank_index >= state.auto_rebirth_min_rank and karma_gain(data, state) >= state.auto_rebirth_min_karma:
			do_rebirth(data, state)
	if auto_on(data, state, "auto_breakthrough"):
		var guard := 0
		while can_breakthrough(data, state) and guard < 48:
			breakthrough(data, state)
			guard += 1
	if auto_on(data, state, "auto_buy_upgrades"):
		if state.auto_buy_mode == "cheapest":
			act_cheapest(data, state, false)
		else:
			act_best_roi(data, state, false)
	Stage3Rules.auto_systems(data, state)


static func _roi(data: EconData, state: SimState, uid: String) -> float:
	var cost := upgrade_cost_state(data, state, uid)
	if cost <= 0.0:
		return 1e18
	var before := production_state(data, state)
	var lvl := int(state.upgrade_levels.get(uid, 0))
	state.upgrade_levels[uid] = lvl + 1
	var after := production_state(data, state)
	if lvl <= 0:
		state.upgrade_levels.erase(uid)
	else:
		state.upgrade_levels[uid] = lvl
	var d := after - before
	if d <= 0.0:
		return -1.0
	return d / cost


static func act_best_roi(data: EconData, state: SimState, breakthroughs: bool = true) -> void:
	if breakthroughs:
		var guard := 0
		while can_breakthrough(data, state) and guard < 48:
			breakthrough(data, state)
			guard += 1
	var nxt_cost := breakthrough_cost(data, state)
	for _i in 80:
		var candidates: Array = []
		for u in unlocked_upgrades(data, state):
			var uid := str(u["id"])
			if not can_buy(data, state, uid):
				continue
			var cost := upgrade_cost_state(data, state, uid)
			var roi := _roi(data, state, uid)
			if roi <= 0.0:
				continue
			var payback := 1.0 / roi
			var cheap := nxt_cost >= 0.0 and cost <= 0.08 * nxt_cost
			var near := payback <= 45.0
			var leftover := nxt_cost < 0.0 or (state.qi - cost) >= 0.85 * nxt_cost or state.qi >= nxt_cost
			if (near or cheap) and leftover:
				candidates.append([roi, uid])
			elif near and nxt_cost >= 0.0 and state.qi < nxt_cost and cost < 0.2 * (nxt_cost - state.qi + cost):
				candidates.append([roi * 0.5, uid])
		if candidates.is_empty():
			break
		candidates.sort_custom(func(a: Array, b: Array) -> bool:
			if float(a[0]) != float(b[0]):
				return float(a[0]) > float(b[0])
			return str(a[1]) > str(b[1])
		)
		if not buy(data, state, str(candidates[0][1])):
			break
		if breakthroughs:
			while can_breakthrough(data, state):
				breakthrough(data, state)
		nxt_cost = breakthrough_cost(data, state)


static func act_cheapest(data: EconData, state: SimState, breakthroughs: bool = true) -> void:
	if breakthroughs:
		var prod := production_state(data, state)
		while can_breakthrough(data, state):
			var nxt := next_rank_state(data, state)
			if nxt.is_empty():
				break
			if float(nxt["cost_qi"]) <= maxf(prod * 60.0, state.qi):
				breakthrough(data, state)
				prod = production_state(data, state)
			else:
				break
	for _i in 80:
		var affordable: Array = []
		for u in unlocked_upgrades(data, state):
			var uid := str(u["id"])
			if can_buy(data, state, uid):
				affordable.append(uid)
		if affordable.is_empty():
			break
		affordable.sort_custom(func(a: String, b: String) -> bool:
			var ca := upgrade_cost_state(data, state, a)
			var cb := upgrade_cost_state(data, state, b)
			if ca != cb:
				return ca < cb
			return a < b
		)
		if not buy(data, state, str(affordable[0])):
			break


static func spend_karma(data: EconData, state: SimState, style: String) -> void:
	if style == "talent":
		_spend_talent_upgrades(data, state, 2)
		_maybe_reroll(data, state)
	if style == "offline":
		buy_shop_if_worth(data, state, "karma_offline", style)
	for _i in 8:
		if not buy_shop_if_worth(data, state, "karma_prod_1", style):
			break
	if style != "talent":
		buy_shop_if_worth(data, state, "karma_offline", style)
	for _j in 2:
		if not buy_shop_if_worth(data, state, "karma_start_qi", style):
			break
	if state.rebirth_count >= 8:
		buy_shop_if_worth(data, state, "karma_keep_upgrade", style)
	if style == "artifact":
		_spend_artifact_upgrade(data, state)


static func _spend_talent_upgrades(data: EconData, state: SimState, limit: int) -> void:
	for _i in limit:
		if state.talents_equipped.is_empty():
			return
		var best := ""
		var best_p := -1.0
		for uid in state.talents_equipped:
			var talent := _find_talent(state, str(uid))
			var p := talent_power(data, state, talent)
			# First maximum wins, matching Python max().
			if best == "" or p > best_p:
				best = str(uid)
				best_p = p
		var target := _find_talent(state, best)
		var before := production_state(data, state)
		var karma := state.karma_shards
		var level := int(target["level"])
		if not upgrade_talent(data, state, best):
			return
		equip_best_talents(data, state)
		if production_state(data, state) + 1e-9 < before:
			target["level"] = level
			state.karma_shards = karma
			equip_best_talents(data, state)
			return


static func _maybe_reroll(data: EconData, state: SimState) -> void:
	if not state.unlocked.has("talent_reroll"):
		return
	var key := "reroll_used_on:%d" % state.rebirth_count
	if state.milestones.has(key):
		return
	var cost := int(data.rebirth.get("talent_reroll_cost", 4))
	if state.karma_shards < float(cost + 2):
		return
	if state.talents_owned.is_empty():
		return
	var worst: Dictionary = {}
	var worst_p := 0.0
	var have := false
	for t in state.talents_owned:
		var p := talent_power(data, state, t)
		if not have or p < worst_p - 1e-12 or (absf(p - worst_p) <= 1e-12 and str(t["uid"]) < str(worst.get("uid", ""))):
			have = true
			worst = t
			worst_p = p
	if str(worst.get("rarity", "")) != "common" and str(worst.get("rarity", "")) != "uncommon":
		return
	var before := production_state(data, state)
	var karma := state.karma_shards
	var snap_root := str(worst["root_id"])
	var snap_rar := str(worst["rarity"])
	var snap_roll := float(worst["roll"])
	var snap_count := state.reroll_count
	if not reroll_talent(data, state, str(worst["uid"])):
		return
	equip_best_talents(data, state)
	if production_state(data, state) + 1e-9 < before:
		worst["root_id"] = snap_root
		worst["rarity"] = snap_rar
		worst["roll"] = snap_roll
		state.reroll_count = snap_count
		state.karma_shards = karma
		equip_best_talents(data, state)
	state.milestones[key] = state.time_sec


static func _spend_artifact_upgrade(data: EconData, state: SimState) -> void:
	if state.artifacts_equipped.is_empty():
		return
	var aid := ""
	var best := -1.0
	for a in state.artifacts_equipped:
		var sc := artifact_score(data, state, str(a))
		if aid == "" or sc > best:
			aid = str(a)
			best = sc
	var level := int(state.artifacts_owned.get(aid, 0))
	var mx := int(data.artifacts["upgrade"]["max_level"])
	if level >= mini(mx, 4):
		return
	var cost := artifact_upgrade_cost(data, level)
	var nxt := breakthrough_cost(data, state)
	if state.qi < cost:
		return
	if nxt >= 0.0 and state.qi - cost < nxt and cost > 0.02 * maxf(state.qi, 1.0):
		return
	upgrade_artifact(data, state, aid)


static func policy_rebirth(data: EconData, state: SimState, min_rank: int, min_gain: int) -> bool:
	if auto_on(data, state, "auto_rebirth"):
		return false
	if not can_rebirth(data, state):
		return false
	if state.rank_index < min_rank:
		return false
	if state.rebirth_count == 0:
		return do_rebirth(data, state)
	if karma_gain(data, state) >= min_gain:
		return do_rebirth(data, state)
	return false


static func play_rebirth_policy(data: EconData, state: SimState, style: String, min_rank: int, min_gain: int) -> void:
	sync_automation_unlocks(data, state)
	equip_best_talents(data, state)
	equip_artifacts_for(data, state, "offline" if style == "offline" else "active")
	var defaults := _defaults(data)
	if style == "late":
		state.auto_rebirth_min_rank = maxi(state.auto_rebirth_min_rank, min_rank)
		state.auto_rebirth_min_karma = maxi(state.auto_rebirth_min_karma, min_gain)
	elif style == "offline":
		state.auto_rebirth_min_rank = int(defaults.get("min_rank_index", 15))
		state.auto_rebirth_min_karma = 1
	else:
		state.auto_rebirth_min_rank = int(defaults.get("min_rank_index", 15))
		state.auto_rebirth_min_karma = min_gain
	var spend_style := "balanced"
	if style == "talent":
		spend_style = "talent"
	elif style == "offline":
		spend_style = "offline"
	elif style == "artifact":
		spend_style = "artifact"
	spend_karma(data, state, spend_style)
	if policy_rebirth(data, state, min_rank, min_gain):
		spend_karma(data, state, "talent" if style == "talent" else "balanced")
	automation_act(data, state)
	if not auto_on(data, state, "auto_buy_upgrades"):
		act_best_roi(data, state, not auto_on(data, state, "auto_breakthrough"))
	elif not auto_on(data, state, "auto_breakthrough"):
		var guard := 0
		while can_breakthrough(data, state) and guard < 48:
			breakthrough(data, state)
			guard += 1
	if policy_rebirth(data, state, min_rank, min_gain):
		if not auto_on(data, state, "auto_buy_upgrades"):
			act_best_roi(data, state, not auto_on(data, state, "auto_breakthrough"))


static func offline_needs_chunks(data: EconData, state: SimState) -> bool:
	sync_automation_unlocks(data, state)
	return auto_on(data, state, "auto_buy_upgrades") or auto_on(data, state, "auto_breakthrough") or auto_on(data, state, "auto_rebirth") or Stage3Rules.needs_chunks(data, state)


static func offline_eff(data: EconData, state: SimState) -> float:
	return minf(Stage3Rules.offline_cap(data, state), float(data.balance["offline"]["efficiency"]) + offline_bonus(data, state))


static func apply_offline(data: EconData, state: SimState, absent_sec: float) -> Dictionary:
	var off: Dictionary = data.balance["offline"]
	var soft := (float(off["soft_cap_hours"]) + Stage3Rules.soft_cap_bonus_hours(data, state)) * 3600.0
	var hard := float(off["hard_cap_hours"]) * 3600.0
	var raw := float(absent_sec)
	var absent := minf(maxf(0.0, raw), hard)
	if not offline_needs_chunks(data, state):
		var eff := offline_eff(data, state)
		var prod := production_state(data, state)
		var gained := 0.0
		if absent <= soft:
			gained = prod * absent * eff
		else:
			gained = prod * soft * eff + prod * (absent - soft) * eff * 0.5
		state.qi += gained
		state.lifetime_qi += gained
		state.time_sec += absent
		Achievements.on_offline(state, absent)
		Achievements.track_tick(state, absent)
		return {
			"gained": gained,
			"absent_sec": absent,
			"raw_absent_sec": raw,
			"efficiency": eff,
			"chunked": false,
			"hard_capped": raw > hard + 1e-6,
			"soft_capped": absent > soft + 1e-6,
		}
	var chunk := float(off["chunk_seconds"])
	var remaining := absent
	var elapsed := 0.0
	var gained_total := 0.0
	var guard := 0
	while remaining > 1e-6 and guard < 2000:
		guard += 1
		var dt := minf(chunk, remaining)
		if elapsed < soft and soft < elapsed + dt:
			var dt1 := soft - elapsed
			gained_total += _offline_slice(data, state, dt1, false)
			gained_total += _offline_slice(data, state, dt - dt1, true)
		else:
			gained_total += _offline_slice(data, state, dt, elapsed >= soft)
		automation_act(data, state)
		elapsed += dt
		remaining -= dt
	state.time_sec += absent
	Achievements.on_offline(state, absent)
	Achievements.track_tick(state, absent)
	return {
		"gained": gained_total,
		"absent_sec": absent,
		"raw_absent_sec": raw,
		"efficiency": offline_eff(data, state),
		"chunked": true,
		"hard_capped": raw > hard + 1e-6,
		"soft_capped": absent > soft + 1e-6,
	}


static func _offline_slice(data: EconData, state: SimState, dt: float, half: bool) -> float:
	if dt <= 0.0:
		return 0.0
	var eff := offline_eff(data, state) * (0.5 if half else 1.0)
	var gained := production_state(data, state) * dt * eff
	state.qi += gained
	state.lifetime_qi += gained
	var banked := Stage3Rules.maybe_bank_offline(data, state, gained, dt)
	if banked > 0.0:
		state.qi -= banked
		state.lifetime_qi -= banked
		gained -= banked
	Stage3Rules.advance(data, state, dt, gained, true)
	Stage3Rules.clamp_state(data, state)
	return gained


static func tick(data: EconData, state: SimState, dt: float) -> void:
	var prod := production_state(data, state)
	var gained := prod * dt
	state.qi += gained
	state.lifetime_qi += gained
	state.time_sec += dt
	Stage3Rules.advance(data, state, dt, gained, false)
	Stage3Rules.clamp_state(data, state)
	Achievements.track_tick(state, dt)


static func _mark(state: SimState, key: String) -> void:
	if not state.milestones.has(key):
		state.milestones[key] = state.time_sec


static func _combinations(items: Array, k: int) -> Array:
	var out: Array = []
	if k <= 0 or k > items.size():
		return out
	var idx: Array = []
	idx.resize(k)
	for i in k:
		idx[i] = i
	while true:
		var combo: Array = []
		for i in k:
			combo.append(items[idx[i]])
		out.append(combo)
		var t := k - 1
		while t >= 0 and int(idx[t]) == items.size() - k + t:
			t -= 1
		if t < 0:
			break
		idx[t] = int(idx[t]) + 1
		for j in range(t + 1, k):
			idx[j] = int(idx[j - 1]) + 1
	return out


static func _array_lt(a: Array, b: Array) -> bool:
	var n := mini(a.size(), b.size())
	for i in n:
		if str(a[i]) != str(b[i]):
			return str(a[i]) < str(b[i])
	return a.size() < b.size()
