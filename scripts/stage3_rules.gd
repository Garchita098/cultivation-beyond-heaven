class_name Stage3Rules
extends RefCounted
## Stage 3 rules. Port of tools/sim/stage3.py. Idle runs stay on the stage-2 formula.

const RESOURCE_KEYS: Array = ["spirit_essence", "dao_fragments", "void_dust", "chaos_seed"]
const WORLD_ORDER: Array = ["mortal_world", "spirit_world", "heavenly_world", "void_dimension", "chaos_origin"]


static func cap_of(data: EconData) -> float:
	return float(data.balance.get("magnitude_cap", 1e300))


static func clamp_num(data: EconData, value: float) -> float:
	if not is_finite(value) or value < 0.0:
		return 0.0
	var limit := cap_of(data)
	if value > limit:
		return limit
	return value


static func clamp_state(data: EconData, state: SimState) -> void:
	state.qi = clamp_num(data, state.qi)
	state.lifetime_qi = clamp_num(data, state.lifetime_qi)
	for key in RESOURCE_KEYS:
		state.world_res[key] = clamp_num(data, float(state.world_res.get(key, 0.0)))


static func path_def(data: EconData, path_id: String) -> Dictionary:
	if path_id == "":
		return {}
	return data.paths_by_id.get(path_id, {})


static func world_def(data: EconData, world_id: String) -> Dictionary:
	return data.worlds.get(world_id, {})


static func node_level(state: SimState, node_id: String) -> int:
	return int(state.path_nodes.get(node_id, 0))


static func path_level(state: SimState) -> int:
	var total := 0
	for v in state.path_nodes.values():
		total += int(v)
	return total


static func node_sum(data: EconData, state: SimState, effect: String) -> float:
	var path := path_def(data, state.path_id if state.path_joined else "")
	if path.is_empty():
		return 0.0
	var total := 0.0
	for node in path.get("nodes", []):
		if str(node.get("effect", "")) != effect:
			continue
		total += float(node["value"]) * float(node_level(state, str(node["id"])))
	return total


static func study_done(state: SimState, study_id: String) -> bool:
	return bool(state.research_done.get(study_id, false))


static func law_by_id(data: EconData, law_id: String) -> Dictionary:
	for law in data.research.get("laws", []):
		if str(law["id"]) == law_id:
			return law
	return {}


static func has_rule(data: EconData, state: SimState, rule: String) -> Dictionary:
	for law_id in state.slotted_laws:
		var law := law_by_id(data, str(law_id))
		if not law.is_empty() and str(law.get("rule", "")) == rule:
			return law
	if state.active_rewrite != "" and state.world_id == "void_dimension":
		var rewrite := law_by_id(data, state.active_rewrite)
		if not rewrite.is_empty() and str(rewrite.get("rule", "")) == rule:
			return rewrite
	return {}


static func _has_unlock(state: SimState, key: String) -> bool:
	return bool(state.unlocked.get(key, false))


static func research_unlocked(data: EconData, state: SimState) -> bool:
	var need := int(data.research.get("unlock_rebirths", 5))
	return state.rebirth_count >= need or _has_unlock(state, "path_selection")


static func law_slots(data: EconData, state: SimState) -> int:
	var n := 0
	if _has_unlock(state, "dao_laws"):
		n += 1
	if study_done(state, "law_primer"):
		n += 1
	if state.world_id == "chaos_origin":
		n = maxi(n, int(world_def(data, "chaos_origin").get("forge_slots", 2)))
	if _has_unlock(state, "law_rewrite"):
		n += 1
	if state.path_joined:
		for aid in state.artifacts_equipped:
			var art := EconomyCore._art(data, str(aid))
			if art.is_empty() or str(art.get("effect_type", "")) != "rule_slot":
				continue
			if not state.artifacts_owned.has(str(aid)):
				continue
			n += 1
	return mini(3, n)


static func _prod_dirty(state: SimState) -> bool:
	if state.path_joined:
		return true
	if state.world_id != "mortal_world":
		return true
	if state.dao_marks > 0.0 or state.ascension_count > 0:
		return true
	if state.reality_mode != "still":
		return true
	if not state.slotted_laws.is_empty() or state.active_rewrite != "":
		return true
	if state.boon_left > 0.0 or state.penalty_left > 0.0:
		return true
	if _has_unlock(state, "dao_authority"):
		return true
	return false


static func qi_keep(data: EconData, state: SimState) -> float:
	if state.world_id != "spirit_world":
		return 1.0
	var ratio := float(state.essence_ratio)
	if ratio < 0.0:
		ratio = 0.0
	if ratio > 0.9:
		ratio = 0.9
	return 1.0 - ratio


static func path_mult(data: EconData, state: SimState) -> float:
	if not state.path_joined:
		return 1.0
	var path := path_def(data, state.path_id)
	if path.is_empty():
		return 1.0
	var params: Dictionary = path["params"]
	var level := path_level(state)
	if state.path_id == "heavenly_sword":
		var burst := float(params["burst_mult_base"]) + float(level) * float(params["burst_mult_per_path_level"])
		burst += node_sum(data, state, "burst_add")
		if state.burst_left > 0.0:
			return burst
		return float(params["outside_burst_mult"])
	if state.path_id == "demon_emperor":
		var perm := 1.0 + float(state.demon_permanent)
		if state.burst_left > 0.0:
			return float(params["sacrifice_burst_mult"]) * perm
		var idle := float(params["idle_penalty_mult"]) + node_sum(data, state, "idle_add")
		if idle > 1.0:
			idle = 1.0
		if state.demon_fed > 0.0:
			return perm
		return idle * perm
	if state.path_id == "immortal":
		var rate := float(params["compound_rate_per_hour"]) + node_sum(data, state, "compound_add")
		var active := float(params["active_play_mult"]) + node_sum(data, state, "active_add")
		if active > 1.0:
			active = 1.0
		var hours := float(params["starting_hours"]) + node_sum(data, state, "start_hours") + float(state.cultivated_hours)
		return active * pow(1.0 + rate, hours)
	if state.path_id == "world_devourer":
		var per := float(params["devour_mult_per_resource_type"]) + node_sum(data, state, "per_type_add")
		var types := state.devour_types.size()
		var bonus := minf(float(params["devour_mult_cap"]) - 1.0, float(types) * per) + float(state.devour_bonus)
		if bonus < 0.0:
			bonus = 0.0
		return 1.0 + bonus
	return 1.0


static func speed_extra(data: EconData, state: SimState) -> float:
	if not state.path_joined or state.path_id != "time_lord" or state.speed_left <= 0.0:
		return 1.0
	var params: Dictionary = path_def(data, "time_lord")["params"]
	return float(params["speed_mult_value"]) + node_sum(data, state, "speed_add")


static func extra_offline_bonus(data: EconData, state: SimState) -> float:
	if not state.path_joined or state.path_id != "immortal":
		return 0.0
	return float(path_def(data, "immortal")["params"]["offline_efficiency_bonus"])


static func offline_cap(data: EconData, state: SimState) -> float:
	if state.path_joined and state.path_id == "immortal":
		return float(path_def(data, "immortal")["params"]["offline_efficiency_cap"])
	return 1.0


static func soft_cap_bonus_hours(data: EconData, state: SimState) -> float:
	if not study_done(state, "longer_dream"):
		return 0.0
	for study in data.research["studies"]:
		if str(study["id"]) == "longer_dream":
			return float(study["value"])
	return 0.0


static func bank_ratio(data: EconData, state: SimState) -> float:
	if not state.path_joined or state.path_id != "time_lord":
		return 0.0
	var base := float(path_def(data, "time_lord")["params"]["bank_ratio"])
	base += node_sum(data, state, "bank_add")
	if study_done(state, "time_ledger"):
		for study in data.research["studies"]:
			if str(study["id"]) == "time_ledger":
				base += float(study["value"])
	if base < 0.0:
		return 0.0
	if base > 0.6:
		return 0.6
	return base


static func _research_pending(data: EconData, state: SimState) -> bool:
	for study in data.research["studies"]:
		if not study_done(state, str(study["id"])):
			return true
	return false


static func needs_chunks(data: EconData, state: SimState) -> bool:
	if state.path_joined:
		return true
	if state.world_id != "mortal_world":
		return true
	if not state.slotted_laws.is_empty() or state.active_rewrite != "":
		return true
	if state.boon_left > 0.0 or state.penalty_left > 0.0 or state.speed_left > 0.0:
		return true
	if research_unlocked(data, state) and _research_pending(data, state):
		return true
	if state.reality_mode != "still":
		return true
	return false


static func adjust_prod(data: EconData, state: SimState, prod: float, parts: Dictionary) -> float:
	if not _prod_dirty(state):
		return prod
	var mult := path_mult(data, state) * speed_extra(data, state)
	var flat_sum := float(parts.get("flat_sum", 0.0))
	var mult_add := float(parts.get("mult_add", 0.0))
	var inverted := state.reality_mode == "inverted" and _has_unlock(state, "reality_stitch")
	if inverted:
		var coeff := float(data.research.get("inverted_exp_coeff", 0.08))
		var cap := float(data.research.get("inverted_exp_cap", 6.0))
		var old := (1.0 + flat_sum) * (1.0 + mult_add)
		var newv := (1.0 + flat_sum) * exp(minf(cap, mult_add * coeff))
		if old > 0.0:
			prod = prod / old * newv
	var law := has_rule(data, state, "flat_power")
	if not law.is_empty() and not inverted:
		var old_m := 1.0 + mult_add
		var new_m := pow(old_m, 1.0 + float(law["value"]))
		if old_m > 0.0:
			prod = prod / old_m * new_m
	if state.path_joined and state.path_id == "heavenly_sword" and state.burst_left > 0.0:
		var edge := node_sum(data, state, "burst_flat")
		if edge > 0.0 and flat_sum > 0.0:
			mult *= 1.0 + flat_sum * edge
	if state.boon_left > 0.0 and state.world_id == "heavenly_world":
		var boon := float(world_def(data, "heavenly_world").get("boon_flat_coeff", 0.012))
		mult *= 1.0 + flat_sum * boon
	if _has_unlock(state, "dao_authority") and flat_sum > 0.0:
		mult *= 1.0 + flat_sum * float(data.research.get("authority_flat_coeff", 0.004))
	if state.penalty_left > 0.0 and state.world_id == "heavenly_world":
		mult *= float(world_def(data, "heavenly_world").get("fail_penalty_mult", 0.72))
	if state.reality_mode == "dilated" and _has_unlock(state, "reality_stitch"):
		mult *= float(data.research.get("dilated_prod", 1.32))
	var tithe := has_rule(data, state, "time_log")
	if not tithe.is_empty():
		var hours := float(state.cultivated_hours)
		mult *= 1.0 + float(tithe["value"]) * (log(1.0 + hours) / log(10.0))
		mult *= 0.92
	var marks := float(data.worlds_doc["ascension"]["perm_mult_per_mark"])
	mult *= 1.0 + float(state.dao_marks) * marks
	mult *= qi_keep(data, state)
	return clamp_num(data, prod * mult)


static func adjust_cost(data: EconData, state: SimState, cost: float, base_cost: float, growth: float, level: int, reduction: float) -> float:
	var law := has_rule(data, state, "growth_exp")
	var dilated := state.reality_mode == "dilated" and _has_unlock(state, "reality_stitch")
	if law.is_empty() and not dilated:
		return cost
	if not law.is_empty():
		var raw := float(base_cost) * pow(float(growth), float(level) * float(law["value"]))
		cost = raw * (1.0 - reduction)
	if dilated:
		cost *= float(data.research.get("dilated_cost", 1.1))
	return cost


static func adjust_breakthrough(data: EconData, state: SimState, cost: float) -> float:
	if cost < 0.0:
		return cost
	var essence := float(state.world_res.get("spirit_essence", 0.0))
	var dirty := false
	if essence > 0.0:
		var spirit := world_def(data, "spirit_world")
		var per := float(spirit["essence_breakthrough_discount_per"])
		var cap := float(spirit["essence_discount_cap"])
		var disc := minf(cap, essence * per)
		if disc > 0.0:
			cost = cost * (1.0 - disc)
			dirty = true
	if state.reality_mode == "dilated" and _has_unlock(state, "reality_stitch"):
		cost *= float(data.research.get("dilated_cost", 1.1))
		dirty = true
	if _half_breakthrough(data, state):
		cost *= 0.5
		dirty = true
	var tithe := has_rule(data, state, "time_log")
	if not tithe.is_empty():
		cost *= 1.2
		dirty = true
	if not dirty:
		return cost
	return cost


static func _half_breakthrough(data: EconData, state: SimState) -> bool:
	if has_rule(data, state, "breakthrough_half_if_bank").is_empty():
		return false
	var need := float(data.research.get("bank_breakthrough_sec", 30))
	return float(state.banked_sec) >= need


static func bank_spent_on_breakthrough(data: EconData, state: SimState) -> float:
	if not _half_breakthrough(data, state):
		return 0.0
	return float(data.research.get("bank_breakthrough_sec", 30))


static func bonus_levels(data: EconData, state: SimState, new_level: int) -> int:
	var every := 0
	var law := has_rule(data, state, "bonus_level_every")
	if not law.is_empty():
		every = int(law["value"])
	elif study_done(state, "batch_training"):
		for study in data.research["studies"]:
			if str(study["id"]) == "batch_training":
				every = int(study["value"])
	if every <= 0:
		return 0
	if new_level > 0 and new_level % every == 0:
		return 1
	return 0


static func hook_consumed(state: SimState, effect_type: String) -> bool:
	if not state.path_joined:
		return false
	return (
		(effect_type == "sacrifice_efficiency" and state.path_id == "demon_emperor")
		or (effect_type == "absorb_rate" and state.path_id == "world_devourer")
		or (effect_type == "time_skip_charge" and state.path_id == "time_lord")
		or (effect_type == "rule_slot")
	)


static func _artifact_effect(data: EconData, state: SimState, effect_type: String) -> float:
	var total := 0.0
	for aid in state.artifacts_equipped:
		var key := str(aid)
		if not state.artifacts_owned.has(key):
			continue
		var art := EconomyCore._art(data, key)
		if art.is_empty() or str(art.get("effect_type", "")) != effect_type:
			continue
		var scaled: Dictionary = EconomyCore._artifact_scaled(data, state, key)
		total += float(scaled["ev"])
	return total


static func on_rebirth(data: EconData, state: SimState) -> void:
	state.burst_left = 0.0
	state.sword_charge = 0.0
	state.speed_left = 0.0
	state.demon_fed = 0.0
	state.boon_left = 0.0
	state.penalty_left = 0.0
	state.tribulation_t = 0.0
	if not (state.path_joined and state.path_id == "world_devourer" and node_sum(data, state, "types_persist") > 0.0):
		state.devour_types = {}
	for key in RESOURCE_KEYS:
		state.world_res[key] = 0.0


static func choose_path(data: EconData, state: SimState, path_id: String) -> bool:
	if not data.paths_by_id.has(path_id):
		return false
	var need := int(data.paths.get("unlock_rebirths", 5))
	if state.rebirth_count < need and not _has_unlock(state, "path_selection"):
		return false
	if state.path_joined and state.path_id == path_id:
		return false
	if not state.path_joined:
		state.path_id = path_id
		state.path_joined = true
		state.unlocked["path_selection"] = true
		EconomyCore._mark(state, "path:" + path_id)
		return true
	var level := path_level(state)
	var base := float(data.paths.get("switch_karma_base", 6))
	var scale := float(data.paths.get("switch_level_scale", 1))
	var cost := base * (1.0 + float(level) * scale)
	if state.karma_shards < cost:
		return false
	state.karma_shards -= cost
	state.path_nodes = {}
	state.path_currency = 0.0
	state.demon_permanent = 0.0
	state.cultivated_hours = 0.0
	state.devour_types = {}
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
	state.path_joined = true
	EconomyCore._mark(state, "path_switch:" + path_id)
	return true


static func node_cost(node: Dictionary, level: int) -> float:
	return float(node["cost"]) * pow(float(node["growth"]), float(level))


static func buy_node(data: EconData, state: SimState, node_id: String) -> bool:
	var path := path_def(data, state.path_id if state.path_joined else "")
	if path.is_empty():
		return false
	var node := {}
	for item in path.get("nodes", []):
		if str(item["id"]) == node_id:
			node = item
			break
	if node.is_empty():
		return false
	var level := node_level(state, node_id)
	if level >= int(node["max_level"]):
		return false
	var cost := node_cost(node, level)
	if state.path_currency + 1e-9 < cost:
		return false
	state.path_currency -= cost
	state.path_nodes[node_id] = level + 1
	EconomyCore._mark(state, "node:%s:L%d" % [node_id, level + 1])
	return true


static func sacrifice(data: EconData, state: SimState, mode: String = "qi") -> bool:
	if not state.path_joined or state.path_id != "demon_emperor":
		return false
	var params: Dictionary = path_def(data, "demon_emperor")["params"]
	var gain := 0.0
	if mode == "rank":
		if node_sum(data, state, "rank_sacrifice") <= 0.0:
			return false
		if state.rank_index <= 0:
			return false
		state.rank_index -= 1
		gain = float(params["rank_permanent"])
	else:
		if state.qi <= 1.0:
			return false
		var frac := float(params["sacrifice_qi_fraction"])
		var eff := _artifact_effect(data, state, "sacrifice_efficiency")
		frac *= maxf(0.4, 1.0 - eff)
		if frac > 0.85:
			frac = 0.85
		state.qi *= 1.0 - frac
		gain = float(params["permanent_gain_per_sacrifice"]) + node_sum(data, state, "perm_add")
	var cap := float(params["permanent_gain_cap"])
	state.demon_permanent = minf(cap, float(state.demon_permanent) + gain)
	state.burst_left = float(params["sacrifice_burst_sec"])
	state.demon_fed = float(params["fed_window_sec"]) + node_sum(data, state, "fed_sec")
	state.path_currency += 1.0
	state.sacrifice_count += 1
	EconomyCore._mark(state, "sacrifice:%d" % state.sacrifice_count)
	return true


static func _count(state: SimState, key: String) -> void:
	state.mechanic_counts[key] = int(state.mechanic_counts.get(key, 0)) + 1


static func absorb(data: EconData, state: SimState, kind: String) -> bool:
	if not state.path_joined or state.path_id != "world_devourer":
		return false
	var params: Dictionary = path_def(data, "world_devourer")["params"]
	if kind == "upgrade":
		var best := ""
		var best_lvl := 0
		for uid in state.upgrade_levels.keys():
			var lvl := int(state.upgrade_levels[uid])
			if lvl > best_lvl or (lvl == best_lvl and best != "" and str(uid) < best):
				best = str(uid)
				best_lvl = lvl
		if best_lvl <= 0:
			return false
		state.upgrade_levels[best] = best_lvl - 1
		if int(state.upgrade_levels[best]) <= 0:
			state.upgrade_levels.erase(best)
		state.devour_types["upgrade"] = true
		state.path_currency += 0.4
		_count(state, "absorb")
		return true
	if kind == "artifact":
		var pick := ""
		for aid in state.artifacts_owned.keys():
			var key := str(aid)
			if pick == "" or key < pick:
				pick = key
		if pick == "":
			return false
		var level := int(state.artifacts_owned[pick])
		if level <= 0:
			state.artifacts_owned.erase(pick)
			state.artifacts_equipped.erase(pick)
		else:
			state.artifacts_owned[pick] = level - 1
		state.devour_types["artifact"] = true
		state.devour_bonus += 0.04 + node_sum(data, state, "artifact_bonus")
		state.path_currency += 0.4
		_count(state, "absorb")
		return true
	if not RESOURCE_KEYS.has(kind):
		return false
	var have := float(state.world_res.get(kind, 0.0))
	if have <= 0.0:
		return false
	var ratio := float(params["absorb_ratio"])
	ratio += _artifact_effect(data, state, "absorb_rate")
	if ratio > 0.9:
		ratio = 0.9
	var take := have * ratio
	state.world_res[kind] = have - take
	var convert := float(params["qi_convert_bonus"]) + node_sum(data, state, "convert_add")
	state.qi = clamp_num(data, state.qi + take * convert)
	state.devour_types[kind] = true
	state.path_currency += 0.25
	_count(state, "absorb")
	return true


static func start_speed(data: EconData, state: SimState) -> bool:
	if not state.path_joined or state.path_id != "time_lord":
		return false
	if state.speed_left > 0.0:
		return false
	var params: Dictionary = path_def(data, "time_lord")["params"]
	var cost := float(params["speed_mult_cost"])
	if state.chrono_charge + 1e-9 < cost:
		return false
	state.chrono_charge -= cost
	state.speed_left = float(params["speed_mult_duration_sec"])
	_count(state, "speed_window")
	return true


static func time_skip(data: EconData, state: SimState) -> bool:
	if not state.path_joined or state.path_id != "time_lord":
		return false
	var params: Dictionary = path_def(data, "time_lord")["params"]
	if state.chrono_charge + 1e-9 < 1.0:
		return false
	var cap := float(params["max_skip_per_day_minutes"]) * 60.0
	if state.skip_used_sec >= cap - 1.0:
		return false
	if state.banked_sec < 30.0:
		return false
	var minutes := float(params["skip_minutes_per_charge"]) * (1.0 + node_sum(data, state, "skip_add"))
	var want := minutes * 60.0
	var spend := minf(state.banked_sec, minf(want, cap - state.skip_used_sec))
	if spend < 30.0:
		return false
	var prod := EconomyCore.production_state(data, state)
	var eff := EconomyCore.offline_eff(data, state)
	var gain := prod * spend * eff
	state.qi = clamp_num(data, state.qi + gain)
	state.lifetime_qi = clamp_num(data, state.lifetime_qi + gain)
	state.banked_sec -= spend
	state.chrono_charge -= 1.0
	state.skip_used_sec += spend
	EconomyCore._mark(state, "time_skip")
	return true


static func set_essence_ratio(state: SimState, ratio: float) -> void:
	if ratio < 0.0:
		ratio = 0.0
	if ratio > 0.75:
		ratio = 0.75
	state.essence_ratio = ratio


static func set_retain(data: EconData, state: SimState, seconds: float) -> void:
	var choices: Array = world_def(data, "void_dimension").get("retain_choices", [60, 180, 600])
	var best := float(choices[0])
	for choice in choices:
		if absf(float(choice) - seconds) < absf(best - seconds):
			best = float(choice)
	state.retain_seconds = best


static func set_stance(state: SimState, stance: String) -> void:
	if stance != "guard" and stance != "defy":
		return
	state.stance = stance


static func set_reality(state: SimState, mode: String) -> bool:
	if mode != "still" and mode != "dilated" and mode != "inverted":
		return false
	if mode != "still" and not _has_unlock(state, "reality_stitch"):
		return false
	state.reality_mode = mode
	return true


static func slot_law(data: EconData, state: SimState, law_id: String) -> bool:
	var law := law_by_id(data, law_id)
	if law.is_empty():
		return false
	if state.slotted_laws.has(law_id):
		return false
	var slots := law_slots(data, state)
	if state.slotted_laws.size() >= slots:
		if state.slotted_laws.is_empty():
			return false
		state.slotted_laws[state.slotted_laws.size() - 1] = law_id
		return true
	if state.world_id == "chaos_origin":
		var seeds := float(state.world_res.get("chaos_seed", 0.0))
		if seeds < 1.0 and state.ascension_count < 1 and not _has_unlock(state, "dao_laws"):
			return false
		if seeds >= 1.0:
			state.world_res["chaos_seed"] = seeds - 1.0
	state.slotted_laws.append(law_id)
	EconomyCore._mark(state, "law:" + law_id)
	return true


static func buy_void_rewrite(data: EconData, state: SimState) -> bool:
	if state.world_id != "void_dimension" and not _has_unlock(state, "dao_laws"):
		return false
	var cost := float(world_def(data, "void_dimension").get("rewrite_cost", 20))
	var dust := float(state.world_res.get("void_dust", 0.0))
	if dust + 1e-9 < cost:
		return false
	state.world_res["void_dust"] = dust - cost
	state.active_rewrite = "qi_or_time"
	if not state.slotted_laws.has("qi_or_time") and state.slotted_laws.size() < law_slots(data, state):
		state.slotted_laws.append("qi_or_time")
	EconomyCore._mark(state, "rewrite:qi_or_time")
	return true


static func promote_research(data: EconData, state: SimState, study_id: String) -> bool:
	var ids: Array = []
	for study in data.research["studies"]:
		ids.append(str(study["id"]))
	if not ids.has(study_id):
		return false
	if state.research_order.is_empty():
		state.research_order = ids.duplicate()
	state.research_order.erase(study_id)
	state.research_order.insert(0, study_id)
	state.research_progress = 0.0
	return true


static func _ensure_research_order(data: EconData, state: SimState) -> void:
	var ids: Array = []
	for study in data.research["studies"]:
		ids.append(str(study["id"]))
	if state.research_order.is_empty():
		state.research_order = ids.duplicate()
		return
	for study_id in ids:
		if not state.research_order.has(str(study_id)):
			state.research_order.append(str(study_id))


static func _active_study(data: EconData, state: SimState) -> Dictionary:
	if not research_unlocked(data, state):
		return {}
	_ensure_research_order(data, state)
	var by_id := {}
	for study in data.research["studies"]:
		by_id[str(study["id"])] = study
	for study_id in state.research_order:
		var key := str(study_id)
		if not study_done(state, key) and by_id.has(key):
			return by_id[key]
	return {}


static func next_world_id(state: SimState) -> String:
	var index := WORLD_ORDER.find(state.world_id)
	if index < 0 or index + 1 >= WORLD_ORDER.size():
		return ""
	return str(WORLD_ORDER[index + 1])


static func can_ascend(data: EconData, state: SimState) -> bool:
	var gate := int(data.worlds_doc["ascension"]["min_rebirths"])
	if state.rebirth_count < gate:
		return false
	var nxt := next_world_id(state)
	if nxt == "":
		return false
	var req = world_def(data, nxt).get("unlock_requirement")
	if typeof(req) != TYPE_DICTIONARY:
		return false
	if str(req.get("type", "")) == "rank":
		var need := int(data.ranks_by_id[str(req["id"])]["index"])
		return state.rank_index >= need
	if str(req.get("type", "")) == "ascension_count":
		if state.ascension_count + 1 < int(req["min"]):
			return false
		var floor_rank := int(data.ranks_by_id["void_early"]["index"])
		return state.rank_index >= floor_rank
	return false


static func ascension_gain(data: EconData, state: SimState) -> int:
	var cfg: Dictionary = data.worlds_doc["ascension"]
	var lq := maxf(1.0, state.lifetime_qi)
	var raw := (
		1.0
		+ (log(lq) / log(10.0)) / float(cfg["gain_log_div"])
		+ float(state.highest_rank_index) * float(cfg["gain_per_rank"])
		+ float(state.ascension_count) * float(cfg["gain_per_ascension"])
	)
	return maxi(1, int(floor(raw)))


static func do_ascension(data: EconData, state: SimState) -> bool:
	if not can_ascend(data, state):
		return false
	var nxt := next_world_id(state)
	var gain := ascension_gain(data, state)
	state.dao_marks += float(gain)
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
	state.unlocked["ascension_gate"] = true
	state.unlocked["world:" + nxt] = true
	EconomyCore.refresh_derived(data, state)
	EconomyCore._apply_start_rank(data, state)
	state.last_purchase_or_unlock_time = state.time_sec
	EconomyCore._mark(state, "ascension:%d" % state.ascension_count)
	EconomyCore._mark(state, "world:" + nxt)
	return true


static func _charge_period(data: EconData, state: SimState) -> float:
	var params: Dictionary = path_def(data, "heavenly_sword")["params"]
	return maxf(20.0, float(params["charge_period_sec"]) + node_sum(data, state, "charge_sec"))


static func _burst_duration(data: EconData, state: SimState) -> float:
	var params: Dictionary = path_def(data, "heavenly_sword")["params"]
	return float(params["burst_duration_sec"]) + node_sum(data, state, "burst_sec")


static func _advance_sword(data: EconData, state: SimState, dt: float) -> void:
	var left := dt
	var guard := 0
	while left > 1e-9 and guard < 8:
		guard += 1
		if state.burst_left > 0.0:
			var step := minf(left, state.burst_left)
			state.burst_left -= step
			left -= step
			continue
		var period := _charge_period(data, state)
		var need := period - state.sword_charge
		var step2 := minf(left, need)
		state.sword_charge += step2
		left -= step2
		if state.sword_charge >= period - 1e-9:
			state.sword_charge = 0.0
			state.burst_left = _burst_duration(data, state)
			_count(state, "sword_burst")


static func _resolve_tribulation(data: EconData, state: SimState) -> void:
	var heavenly := world_def(data, "heavenly_world")
	var prod := maxf(EconomyCore.production_state(data, state), 1e-9)
	var power := (log(prod) / log(10.0)) + float(state.rank_index) * float(heavenly["power_rank_weight"])
	power += state.karma_shards * 0.02 + state.dao_marks * 0.15
	var pressure := float(heavenly["pressure_base"]) + float(state.tribulation_cycle) * float(heavenly["pressure_per_cycle"])
	if study_done(state, "tribulation_eye"):
		for study in data.research["studies"]:
			if str(study["id"]) == "tribulation_eye":
				pressure *= float(study["value"])
	var reward_mult := 1.0
	if state.stance == "guard":
		pressure *= float(heavenly["guard_pressure"])
		reward_mult = float(heavenly["guard_reward"])
	else:
		pressure *= float(heavenly["defy_pressure"])
		reward_mult = float(heavenly["defy_reward"])
	var success := power + 1e-9 >= pressure
	var fragments := 0.0
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
	EconomyCore._mark(state, "tribulation:%d" % state.tribulation_cycle)


static func advance(data: EconData, state: SimState, dt: float, gained_qi: float, offline: bool) -> void:
	if dt <= 0.0:
		return
	if not (
		state.path_joined
		or state.world_id != "mortal_world"
		or research_unlocked(data, state)
		or _has_unlock(state, "dual_flow")
		or state.boon_left > 0.0
		or state.penalty_left > 0.0
	):
		return
	if state.path_joined and state.path_id == "heavenly_sword":
		_advance_sword(data, state, dt)
	elif state.burst_left > 0.0:
		state.burst_left = maxf(0.0, state.burst_left - dt)
	if state.demon_fed > 0.0:
		state.demon_fed = maxf(0.0, state.demon_fed - dt)
	if state.speed_left > 0.0:
		state.speed_left = maxf(0.0, state.speed_left - dt)
	if state.boon_left > 0.0:
		state.boon_left = maxf(0.0, state.boon_left - dt)
	if state.penalty_left > 0.0:
		state.penalty_left = maxf(0.0, state.penalty_left - dt)
	var hour := dt / 3600.0
	if state.path_joined:
		var per := float(data.paths.get("currency_per_hour", 10))
		state.path_currency += per * hour
		var scale := 1.0
		if state.path_id == "immortal" and offline:
			scale = 1.0 + node_sum(data, state, "dream_mult")
		if state.reality_mode == "dilated" and _has_unlock(state, "reality_stitch"):
			scale *= float(data.research.get("dilated_time", 1.25))
		state.cultivated_hours += hour * scale
		if state.path_id == "time_lord":
			var params: Dictionary = path_def(data, "time_lord")["params"]
			var rate := float(params["charge_per_offline_hour"] if offline else params["charge_per_active_hour"])
			rate += node_sum(data, state, "charge_add")
			var art := _artifact_effect(data, state, "time_skip_charge")
			state.chrono_charge += hour * rate * (1.0 + art)
	var keep := qi_keep(data, state)
	var raw := gained_qi / keep if keep > 1e-6 else 0.0
	if state.world_id == "spirit_world" and keep < 0.999:
		var convert := float(world_def(data, "spirit_world")["qi_to_essence_convert_ratio"])
		var diverted := raw - gained_qi
		state.world_res["spirit_essence"] = float(state.world_res.get("spirit_essence", 0.0)) + diverted * convert
	if _has_unlock(state, "dual_flow"):
		var frac := float(data.research.get("dual_flow_fraction", 0.08))
		var convert2 := float(world_def(data, "spirit_world")["qi_to_essence_convert_ratio"])
		state.world_res["spirit_essence"] = float(state.world_res.get("spirit_essence", 0.0)) + raw * frac * convert2
	if state.world_id == "void_dimension":
		var rate2 := float(world_def(data, "void_dimension")["entropy_rate"])
		if study_done(state, "entropy_valve"):
			for study in data.research["studies"]:
				if str(study["id"]) == "entropy_valve":
					rate2 *= float(study["value"])
		var retain := maxf(1.0, EconomyCore.production_state(data, state) * float(state.retain_seconds))
		if state.qi > retain:
			var excess := state.qi - retain
			var drain := minf(excess, excess * rate2 * dt)
			state.qi -= drain
			var dust := drain * float(world_def(data, "void_dimension")["dust_per_qi"])
			state.world_res["void_dust"] = float(state.world_res.get("void_dust", 0.0)) + dust
	if state.world_id == "heavenly_world":
		state.tribulation_t += dt
		var interval := float(world_def(data, "heavenly_world")["tribulation_interval_sec"])
		if state.tribulation_t >= interval:
			_resolve_tribulation(data, state)
	if state.world_id == "chaos_origin":
		state.chaos_pulse_t += dt
		var pulse := float(world_def(data, "chaos_origin").get("pulse_sec", 90))
		if state.chaos_pulse_t >= pulse:
			state.chaos_pulse_t -= pulse
			state.world_res["chaos_seed"] = float(state.world_res.get("chaos_seed", 0.0)) + float(world_def(data, "chaos_origin").get("seed_per_pulse", 1))
			EconomyCore._mark(state, "chaos_pulse")
	var study := _active_study(data, state)
	if not study.is_empty():
		state.research_progress += dt
		if state.research_progress + 1e-9 >= float(study["seconds"]):
			state.research_done[str(study["id"])] = true
			state.research_progress = 0.0
			EconomyCore._mark(state, "research:" + str(study["id"]))
	clamp_state(data, state)


static func maybe_bank_offline(data: EconData, state: SimState, gained: float, dt: float) -> float:
	var ratio := bank_ratio(data, state)
	if ratio <= 0.0 or dt <= 0.0 or gained <= 0.0:
		return 0.0
	state.banked_sec += dt * ratio
	return gained * ratio


static func auto_systems(data: EconData, state: SimState) -> void:
	if EconomyCore.auto_on(data, state, "auto_path_burst"):
		_auto_path(data, state)
	if EconomyCore.auto_on(data, state, "auto_world_balance"):
		_auto_world(data, state)
	if EconomyCore.auto_on(data, state, "auto_rule_forge"):
		_auto_laws(data, state)


static func _auto_path(data: EconData, state: SimState) -> void:
	if not state.path_joined or path_level(state) < 5:
		return
	if state.path_id == "demon_emperor":
		if state.burst_left <= 0.0 and state.demon_fed <= 0.0 and state.qi > 50.0:
			sacrifice(data, state, "qi")
	elif state.path_id == "world_devourer":
		if not state.devour_types.has("upgrade"):
			absorb(data, state, "upgrade")
		if not state.devour_types.has("artifact") and not state.artifacts_owned.is_empty():
			absorb(data, state, "artifact")
		for key in RESOURCE_KEYS:
			if not state.devour_types.has(str(key)) and float(state.world_res.get(key, 0.0)) > 0.0:
				absorb(data, state, str(key))
				break
	elif state.path_id == "time_lord":
		if state.speed_left <= 0.0:
			start_speed(data, state)
		var nxt := EconomyCore.breakthrough_cost(data, state)
		if nxt >= 0.0 and state.qi < nxt and state.banked_sec >= 60.0:
			time_skip(data, state)


static func _auto_world(data: EconData, state: SimState) -> void:
	if state.world_id == "spirit_world":
		var essence := float(state.world_res.get("spirit_essence", 0.0))
		var per := float(world_def(data, "spirit_world")["essence_breakthrough_discount_per"])
		var cap := float(world_def(data, "spirit_world")["essence_discount_cap"])
		var disc := minf(cap, essence * per)
		if disc < 0.2:
			state.essence_ratio = 0.5
		elif disc < 0.4:
			state.essence_ratio = 0.25
		else:
			state.essence_ratio = 0.0
	elif state.world_id == "void_dimension":
		state.retain_seconds = 180.0
	elif state.world_id == "heavenly_world":
		if state.stance != "guard" and state.stance != "defy":
			state.stance = "guard"


static func _auto_laws(data: EconData, state: SimState) -> void:
	var order: Array = ["soft_growth", "time_tithe", "flat_as_mult", "batch_insight", "qi_or_time"]
	var slots := law_slots(data, state)
	while state.slotted_laws.size() < slots:
		var placed := false
		for law_id in order:
			if state.slotted_laws.has(str(law_id)):
				continue
			if slot_law(data, state, str(law_id)):
				placed = true
				break
		if not placed:
			break
