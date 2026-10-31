class_name EconomyCore
extends RefCounted
## Direct port of tools/sim/economy.py formulas (docs/FORMULAS.md).
## Float path matches the Python sim. Live Qi is stored as BigNum by GameState.

const STAGE1_CAP := 1


static func production(data: EconData, rank_index: int, levels: Dictionary, karma: float, shop_mult: float) -> float:
	var base := float(data.balance["base_qi_per_sec"])
	var flat_sum := 0.0
	var mult_add := 0.0
	var speed_mult := 1.0
	for uid in data.upgrade_order:
		var lvl := int(levels.get(uid, 0))
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
	var rank_mult := float(data.rank_at(rank_index)["prod_mult"])
	var perm := float(data.rebirth["tiers"][0]["perm_mult_per_karma"])
	var karma_mult := 1.0 + karma * perm
	return base * (1.0 + flat_sum) * (1.0 + mult_add) * rank_mult * karma_mult * shop_mult * speed_mult


static func production_bn(data: EconData, rank_index: int, levels: Dictionary, karma: float, shop_mult: float) -> BigNum:
	return BigNum.from_float(production(data, rank_index, levels, karma, shop_mult))


static func cost_reduction(data: EconData, levels: Dictionary) -> float:
	var total := 0.0
	for uid in data.upgrade_order:
		var u: Dictionary = data.upgrades[uid]
		if str(u["effect_type"]) != "cost_reduction":
			continue
		var lvl := int(levels.get(uid, 0))
		total += float(u["effect_value"]) * float(lvl)
	return minf(0.8, total)


static func upgrade_cost(data: EconData, levels: Dictionary, uid: String) -> float:
	var u: Dictionary = data.upgrades[uid]
	var lvl := int(levels.get(uid, 0))
	var raw := float(u["base_cost"]) * pow(float(u["growth"]), float(lvl))
	return raw * (1.0 - cost_reduction(data, levels))


static func upgrade_cost_bn(data: EconData, levels: Dictionary, uid: String) -> BigNum:
	return BigNum.from_float(upgrade_cost(data, levels, uid))


static func unlocked_upgrades(data: EconData, rank_index: int) -> Array:
	var out: Array = []
	for uid in data.upgrade_order:
		var u: Dictionary = data.upgrades[uid]
		var req := int(data.ranks_by_id[str(u["unlock_rank"])]["index"])
		if rank_index >= req:
			out.append(u)
	return out


static func can_buy(data: EconData, qi: float, rank_index: int, levels: Dictionary, uid: String) -> bool:
	var u: Dictionary = data.upgrades[uid]
	if rank_index < int(data.ranks_by_id[str(u["unlock_rank"])]["index"]):
		return false
	var lvl := int(levels.get(uid, 0))
	var mx := int(u.get("max_level", 0))
	if mx > 0 and lvl >= mx:
		return false
	return qi >= upgrade_cost(data, levels, uid)


static func buy(data: EconData, state: SimState, uid: String) -> bool:
	if not can_buy(data, state.qi, state.rank_index, state.upgrade_levels, uid):
		return false
	var cost := upgrade_cost(data, state.upgrade_levels, uid)
	state.qi -= cost
	state.upgrade_levels[uid] = int(state.upgrade_levels.get(uid, 0)) + 1
	state.last_purchase_or_unlock_time = state.time_sec
	var key := "upgrade:%s:L%d" % [uid, int(state.upgrade_levels[uid])]
	if not state.milestones.has(key):
		state.milestones[key] = state.time_sec
	if not state.milestones.has("first_upgrade"):
		state.milestones["first_upgrade"] = state.time_sec
	return true


static func next_rank_dict(data: EconData, rank_index: int, stage_cap: int = 0) -> Dictionary:
	if rank_index + 1 >= data.ranks.size():
		return {}
	var nxt: Dictionary = data.ranks[rank_index + 1]
	if stage_cap > 0 and int(nxt.get("stage", 1)) > stage_cap:
		return {}
	return nxt


static func can_breakthrough(data: EconData, state: SimState, stage_cap: int = 0) -> bool:
	var nxt := next_rank_dict(data, state.rank_index, stage_cap)
	if nxt.is_empty():
		return false
	return state.qi >= float(nxt["cost_qi"])


static func breakthrough(data: EconData, state: SimState, stage_cap: int = 0) -> bool:
	if not can_breakthrough(data, state, stage_cap):
		return false
	var nxt := next_rank_dict(data, state.rank_index, stage_cap)
	state.qi -= float(nxt["cost_qi"])
	state.rank_index += 1
	state.highest_rank_index = maxi(state.highest_rank_index, state.rank_index)
	state.last_purchase_or_unlock_time = state.time_sec
	for feature in nxt.get("unlocks", []):
		state.unlocked[str(feature)] = true
	var mid := "rank:%s" % str(nxt["id"])
	if not state.milestones.has(mid):
		state.milestones[mid] = state.time_sec
	if state.rank_index == 1 and not state.milestones.has("first_breakthrough"):
		state.milestones["first_breakthrough"] = state.time_sec
	var unlocks: Array = nxt.get("unlocks", [])
	if unlocks.has("rebirth_unlock") and not state.milestones.has("rebirth_unlocked"):
		state.milestones["rebirth_unlocked"] = state.time_sec
	return true


static func karma_gain(data: EconData, state: SimState) -> int:
	var f: Dictionary = data.rebirth["formula"]
	var lq := maxf(1.0, state.lifetime_qi)
	var raw := float(f["base"]) + (log(lq) / log(10.0)) / float(f["from_lifetime_qi_log10_div"]) + float(state.highest_rank_index) * float(f["from_highest_rank_index"])
	return int(floor(raw))


static func can_rebirth(data: EconData, state: SimState) -> bool:
	return state.rank_index >= int(data.rebirth["min_rank_index_to_rebirth"])


static func do_rebirth(data: EconData, state: SimState) -> bool:
	if not can_rebirth(data, state):
		return false
	var gain := karma_gain(data, state)
	state.karma_shards += float(gain)
	state.rebirth_count += 1
	state.qi = state.starting_qi_bonus
	state.upgrade_levels = {}
	state.rank_index = 0
	for t in data.rebirth["tiers"]:
		var tier: Dictionary = t
		if state.rebirth_count >= int(tier["min_rebirths"]) and int(tier.get("start_rank_bonus", 0)) > 0:
			state.rank_index = mini(int(tier["start_rank_bonus"]), data.ranks.size() - 1)
	state.last_purchase_or_unlock_time = state.time_sec
	state.milestones["rebirth:%d" % state.rebirth_count] = state.time_sec
	if not state.milestones.has("first_rebirth"):
		state.milestones["first_rebirth"] = state.time_sec
	return true


static func tick(data: EconData, state: SimState, dt: float) -> void:
	var prod := production(data, state.rank_index, state.upgrade_levels, state.karma_shards, state.shop_mult)
	var gained := prod * dt
	state.qi += gained
	state.lifetime_qi += gained
	state.time_sec += dt


static func _roi(data: EconData, state: SimState, uid: String) -> float:
	var cost := upgrade_cost(data, state.upgrade_levels, uid)
	if cost <= 0.0:
		return 1e18
	var before := production(data, state.rank_index, state.upgrade_levels, state.karma_shards, state.shop_mult)
	var lvl := int(state.upgrade_levels.get(uid, 0))
	state.upgrade_levels[uid] = lvl + 1
	var after := production(data, state.rank_index, state.upgrade_levels, state.karma_shards, state.shop_mult)
	if lvl <= 0:
		state.upgrade_levels.erase(uid)
	else:
		state.upgrade_levels[uid] = lvl
	var d := after - before
	if d <= 0.0:
		return -1.0
	return d / cost


static func decide_best_roi(data: EconData, state: SimState) -> void:
	while can_breakthrough(data, state, 0):
		breakthrough(data, state, 0)
	var nxt_cost := -1.0
	var nxt := next_rank_dict(data, state.rank_index, 0)
	if not nxt.is_empty():
		nxt_cost = float(nxt["cost_qi"])
	for _i in 80:
		var ups := unlocked_upgrades(data, state.rank_index)
		var best_roi := -1e30
		var best_uid := ""
		for u in ups:
			var uid := str(u["id"])
			if not can_buy(data, state.qi, state.rank_index, state.upgrade_levels, uid):
				continue
			var cost := upgrade_cost(data, state.upgrade_levels, uid)
			var roi := _roi(data, state, uid)
			if roi <= 0.0:
				continue
			var payback := 1.0 / roi
			var cheap_vs_rank := nxt_cost >= 0.0 and cost <= 0.08 * nxt_cost
			var near_instant := payback <= 45.0
			var leftover_ok := nxt_cost < 0.0 or (state.qi - cost) >= 0.85 * nxt_cost or state.qi >= nxt_cost
			var take := false
			var score := roi
			if (near_instant or cheap_vs_rank) and leftover_ok:
				take = true
			elif near_instant and nxt_cost >= 0.0 and state.qi < nxt_cost and cost < 0.2 * (nxt_cost - state.qi + cost):
				take = true
				score = roi * 0.5
			if not take:
				continue
			if best_uid == "" or score > best_roi or (score == best_roi and uid > best_uid):
				best_roi = score
				best_uid = uid
		if best_uid == "":
			break
		if not buy(data, state, best_uid):
			break
		while can_breakthrough(data, state, 0):
			breakthrough(data, state, 0)
		nxt = next_rank_dict(data, state.rank_index, 0)
		if nxt.is_empty():
			nxt_cost = -1.0
		else:
			nxt_cost = float(nxt["cost_qi"])


static func decide_rebirth_early(data: EconData, state: SimState) -> void:
	if can_rebirth(data, state):
		var gain := karma_gain(data, state)
		if state.rebirth_count == 0 or gain >= 3:
			do_rebirth(data, state)
			return
	decide_best_roi(data, state)
