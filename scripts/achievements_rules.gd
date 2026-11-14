class_name Achievements
extends RefCounted
## Mirrors tools/sim/achievements.py. Zero bonuses do not multiply production.


static func sync(data: EconData, state: SimState) -> Array:
	var fresh: Array = []
	for ach in data.achievements:
		var aid := str(ach["id"])
		if state.achievements.has(aid):
			continue
		if _met(state, ach):
			state.achievements[aid] = true
			fresh.append(aid)
	if not fresh.is_empty():
		state.fresh_achievements = fresh.duplicate()
	return fresh


static func qi_mult(data: EconData, state: SimState) -> float:
	if state.achievements.is_empty():
		return 1.0
	var total := 0.0
	for ach in data.achievements:
		if not state.achievements.has(str(ach["id"])):
			continue
		if str(ach.get("bonus_type", "")) == "qi_mult":
			total += float(ach.get("bonus_value", 0.0))
	if total <= 0.0:
		return 1.0
	return 1.0 + total


static func offline_bonus(data: EconData, state: SimState) -> float:
	if state.achievements.is_empty():
		return 0.0
	var total := 0.0
	for ach in data.achievements:
		if not state.achievements.has(str(ach["id"])):
			continue
		if str(ach.get("bonus_type", "")) == "offline":
			total += float(ach.get("bonus_value", 0.0))
	return total


static func track_tick(state: SimState, dt: float) -> void:
	if dt <= 0.0:
		return
	if state.path_joined and state.path_id != "":
		var path_sec: Dictionary = state.stats.get("path_sec", {})
		path_sec[state.path_id] = float(path_sec.get(state.path_id, 0.0)) + dt
		state.stats["path_sec"] = path_sec
	var worlds: Array = state.stats.get("worlds", [])
	if not worlds.has(state.world_id):
		worlds.append(state.world_id)
		state.stats["worlds"] = worlds


static func on_rebirth(state: SimState) -> void:
	var start := float(state.stats.get("segment_start", 0.0))
	var dur := state.time_sec - start
	var best := float(state.stats.get("best_rebirth_sec", 0.0))
	if dur > 1.0 and (best <= 0.0 or dur < best):
		state.stats["best_rebirth_sec"] = dur
	state.stats["segment_start"] = state.time_sec


static func on_ascension(state: SimState) -> void:
	var start := float(state.stats.get("asc_segment_start", 0.0))
	var dur := state.time_sec - start
	var best := float(state.stats.get("fastest_ascension_sec", 0.0))
	if dur > 1.0 and (best <= 0.0 or dur < best):
		state.stats["fastest_ascension_sec"] = dur
	state.stats["asc_segment_start"] = state.time_sec
	state.stats["segment_start"] = state.time_sec


static func on_offline(state: SimState, absent: float) -> void:
	if absent <= 0.0:
		return
	state.stats["offline_sec"] = float(state.stats.get("offline_sec", 0.0)) + absent


static func progress(data: EconData, state: SimState, ach: Dictionary) -> float:
	var metric := str(ach.get("metric", ""))
	var goal := float(ach.get("goal", 1))
	if goal == 0.0:
		return 1.0
	var cur := 0.0
	match metric:
		"rank_index":
			cur = float(state.highest_rank_index)
		"rebirths":
			cur = float(state.rebirth_count)
		"ascensions":
			cur = float(state.ascension_count)
		"research":
			cur = float(state.research_done.size())
		"artifacts":
			cur = float(state.artifacts_owned.size())
		"offline_sec":
			cur = float(state.stats.get("offline_sec", 0.0))
		"time_sec":
			cur = state.time_sec
		"lifetime_exp":
			cur = _exp(state.lifetime_qi)
		"qi_exp":
			cur = _exp(state.qi)
		"sacrifices":
			cur = float(state.sacrifice_count)
		"tribulations":
			cur = float(state.tribulation_cycle)
		"path", "world", "study":
			return 1.0 if _met(state, ach) else 0.0
		_:
			return 0.0
	return clampf(cur / goal, 0.0, 1.0)


static func _met(state: SimState, ach: Dictionary) -> bool:
	if int(ach.get("min_ascension", 0)) > state.ascension_count:
		return false
	var metric := str(ach.get("metric", ""))
	var goal = ach.get("goal", 0)
	match metric:
		"rank_index":
			return state.highest_rank_index >= int(goal)
		"rebirths":
			return state.rebirth_count >= int(goal)
		"ascensions":
			return state.ascension_count >= int(goal)
		"path":
			return state.path_joined and state.path_id == str(goal)
		"world":
			var worlds: Array = state.stats.get("worlds", [])
			return state.world_id == str(goal) or worlds.has(str(goal)) or state.unlocked.has("world:" + str(goal))
		"research":
			return state.research_done.size() >= int(goal)
		"study":
			return state.research_done.has(str(goal))
		"artifacts":
			return state.artifacts_owned.size() >= int(goal)
		"offline_sec":
			return float(state.stats.get("offline_sec", 0.0)) >= float(goal)
		"time_sec":
			return state.time_sec >= float(goal)
		"lifetime_exp":
			return _exp(state.lifetime_qi) >= float(goal)
		"qi_exp":
			return _exp(state.qi) >= float(goal)
		"sacrifices":
			return state.sacrifice_count >= int(goal)
		"tribulations":
			return state.tribulation_cycle >= int(goal)
		_:
			return false


static func _exp(value: float) -> float:
	if not is_finite(value) or value <= 1.0:
		return 0.0
	return log(value) / log(10.0)
