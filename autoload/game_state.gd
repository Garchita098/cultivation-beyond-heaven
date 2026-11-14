extends Node
## Runtime state, frame tick, purchases, and offline catch-up.
## The frame pump lives in scenes/main.gd so headless tests do not simulate a player.

var run: RunState
var last_prod: float = 1.0
var _tick_acc: float = 0.0
var pending_offline: Dictionary = {}
var screenshot_mode: bool = false


func _ready() -> void:
	screenshot_mode = _screenshot_mode()
	if _test_mode():
		run = RunState.new()
		return
	Content.load_all()
	if screenshot_mode:
		_bootstrap_screenshot()
		return
	_bootstrap_player()


func tick(delta: float) -> void:
	if run == null or delta <= 0.0 or not Content.valid:
		return
	# Fixed economy step. Drawing at 60fps only accumulates time. A hitch
	# runs at most 20 steps (5s) so one frame cannot stall the phone.
	_tick_acc += delta
	var step := float(Content.data.balance.get("tick_seconds", 0.25))
	if step <= 0.0:
		step = 0.25
	var steps := 0
	while _tick_acc >= step and steps < 20:
		_tick_acc -= step
		_step(step)
		steps += 1
	if _tick_acc > step * 40.0:
		_tick_acc = step


func _step(step: float) -> void:
	var before := run.achievements.duplicate()
	var sim := run.to_sim()
	EconomyCore.tick(Content.data, sim, step)
	run.apply_sim(sim, true)
	_emit_achievements(before)
	last_prod = EconomyCore.production_state(Content.data, sim)
	if not is_finite(last_prod) or last_prod < 0.0:
		push_error("Qi production is not a finite non-negative number")
		last_prod = 0.0


func try_buy(uid: String) -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return EconomyCore.buy(Content.data, sim, uid)
	)


func try_breakthrough() -> bool:
	var before := run.rank_index if run != null else -1
	var ok := _mutate(func(sim: SimState) -> bool:
		return EconomyCore.breakthrough(Content.data, sim)
	)
	if ok and run.rank_index != before:
		var rank: Dictionary = Content.data.rank_at(run.rank_index)
		EventBus.rank_up.emit(run.rank_index, str(rank.get("id", "")))
	return ok


func try_rebirth() -> bool:
	var before := run.rebirth_count if run != null else -1
	var ok := _mutate(func(sim: SimState) -> bool:
		return EconomyCore.do_rebirth(Content.data, sim)
	)
	if ok and run.rebirth_count != before:
		EventBus.rebirth_done.emit(run.rebirth_count)
		_emit_new_unlocks()
	return ok


func try_shop(item_id: String) -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return EconomyCore.buy_shop(Content.data, sim, item_id)
	)


func try_upgrade_talent(uid: String) -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return EconomyCore.upgrade_talent(Content.data, sim, uid)
	)


func try_reroll_talent(uid: String) -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return EconomyCore.reroll_talent(Content.data, sim, uid)
	)


func try_upgrade_artifact(aid: String) -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return EconomyCore.upgrade_artifact(Content.data, sim, aid)
	)


func toggle_talent(uid: String) -> void:
	_mutate(func(sim: SimState) -> bool:
		if not EconomyCore._find_talent(sim, uid).is_empty():
			if sim.talents_equipped.has(uid):
				sim.talents_equipped.erase(uid)
			elif sim.talents_equipped.size() < int(Content.data.talents["max_equipped"]):
				sim.talents_equipped.append(uid)
		return true
	)


func toggle_artifact(aid: String) -> void:
	_mutate(func(sim: SimState) -> bool:
		if not sim.artifacts_owned.has(aid):
			return false
		if sim.artifacts_equipped.has(aid):
			sim.artifacts_equipped.erase(aid)
		elif sim.artifacts_equipped.size() < int(Content.data.artifacts["max_equipped"]):
			sim.artifacts_equipped.append(aid)
		return true
	)


func set_auto(aid: String, enabled: bool) -> void:
	_mutate(func(sim: SimState) -> bool:
		sim.automation_toggles[aid] = enabled
		return true
	)


func set_auto_buy_mode(mode: String) -> void:
	_mutate(func(sim: SimState) -> bool:
		sim.auto_buy_mode = mode
		return true
	)


func try_choose_path(path_id: String) -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return Stage3Rules.choose_path(Content.data, sim, path_id)
	)


func try_buy_node(node_id: String) -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return Stage3Rules.buy_node(Content.data, sim, node_id)
	)


func try_sacrifice(mode: String = "qi") -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return Stage3Rules.sacrifice(Content.data, sim, mode)
	)


func try_absorb(kind: String) -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return Stage3Rules.absorb(Content.data, sim, kind)
	)


func try_speed() -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return Stage3Rules.start_speed(Content.data, sim)
	)


func try_skip() -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return Stage3Rules.time_skip(Content.data, sim)
	)


func export_text() -> String:
	if run == null:
		return ""
	Prefs.write_run(run)
	return JSON.stringify(run.to_save_dict(SaveSystem.CURRENT_VERSION))


func import_text(text: String) -> bool:
	var parsed = JSON.parse_string(text.strip_edges())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var migrated: Dictionary = SaveSystem.migrate(parsed)
	if bool(migrated.get("meta", {}).get("future_version", false)):
		return false
	run = RunState.from_save_dict(migrated)
	run.timestamp_unix = int(Time.get_unix_time_from_system())
	SaveSystem.save_run(run)
	last_prod = Economy.production_float(run)
	EventBus.state_changed.emit()
	return true


func try_buy_layer(kind: String) -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return Stage3Rules.buy_layer(Content.data, sim, kind)
	)


func try_ascend() -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return Stage3Rules.do_ascension(Content.data, sim)
	)


func set_essence_ratio(ratio: float) -> void:
	_mutate(func(sim: SimState) -> bool:
		Stage3Rules.set_essence_ratio(sim, ratio)
		return true
	)


func set_retain(seconds: float) -> void:
	_mutate(func(sim: SimState) -> bool:
		Stage3Rules.set_retain(Content.data, sim, seconds)
		return true
	)


func set_stance(stance: String) -> void:
	_mutate(func(sim: SimState) -> bool:
		Stage3Rules.set_stance(sim, stance)
		return true
	)


func set_reality(mode: String) -> void:
	_mutate(func(sim: SimState) -> bool:
		return Stage3Rules.set_reality(sim, mode)
	)


func try_slot_law(law_id: String) -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return Stage3Rules.slot_law(Content.data, sim, law_id)
	)


func try_rewrite() -> bool:
	return _mutate(func(sim: SimState) -> bool:
		return Stage3Rules.buy_void_rewrite(Content.data, sim)
	)


func promote_research(study_id: String) -> void:
	_mutate(func(sim: SimState) -> bool:
		return Stage3Rules.promote_research(Content.data, sim, study_id)
	)


func set_auto_rebirth(min_rank: int, min_karma: int) -> void:
	_mutate(func(sim: SimState) -> bool:
		sim.auto_rebirth_min_rank = min_rank
		sim.auto_rebirth_min_karma = min_karma
		return true
	)


func _mutate(action: Callable) -> bool:
	if run == null or not Content.valid:
		return false
	var before_ach := run.achievements.duplicate()
	var sim := run.to_sim()
	var before_unlock := run.unlocked.duplicate()
	if not bool(action.call(sim)):
		return false
	run.apply_sim(sim, false)
	_emit_achievements(before_ach)
	last_prod = Economy.production_float(run)
	for k in run.unlocked.keys():
		if run.unlocked[k] and not before_unlock.has(k):
			EventBus.feature_unlocked.emit(str(k))
	EventBus.state_changed.emit()
	return true


func _emit_new_unlocks() -> void:
	pass


func _emit_achievements(before: Dictionary) -> void:
	if run == null or screenshot_mode:
		return
	for key in run.achievements.keys():
		if not before.has(key):
			EventBus.achievement_unlocked.emit(str(key))


func catch_up_offline() -> void:
	if run == null or screenshot_mode or _test_mode() or not Content.valid:
		return
	var now := int(Time.get_unix_time_from_system())
	var absent := now - int(run.timestamp_unix)
	if absent <= 2:
		return
	pending_offline = OfflineCalc.apply_to_run(run, float(absent))
	SaveSystem.save_run(run)
	EventBus.offline_summary.emit(pending_offline)


func _bootstrap_player() -> void:
	if not Content.valid:
		run = RunState.new()
		return
	var loaded := SaveSystem.load_run()
	if loaded == null:
		run = RunState.new()
		run.timestamp_unix = int(Time.get_unix_time_from_system())
		SaveSystem.save_run(run)
		return
	run = loaded
	var now := int(Time.get_unix_time_from_system())
	var absent := now - int(run.timestamp_unix)
	if absent > 2:
		pending_offline = OfflineCalc.apply_to_run(run, float(absent))
	run.timestamp_unix = now
	SaveSystem.save_run(run)
	last_prod = Economy.production_float(run)


func _bootstrap_screenshot() -> void:
	run = RunState.new()
	if not Content.valid:
		return
	# A fifth-run Core Peak so every stage-2 tab has something to show.
	run.qi = BigNum.from_float(9.4e8)
	run.lifetime_qi = BigNum.from_float(6.2e9)
	run.rank_index = 15
	run.highest_rank_index = 15
	run.karma_shards = BigNum.from_float(18)
	run.rebirth_count = 5
	run.shop_levels = {"karma_prod_1": 2, "karma_offline": 1}
	run.shop_mult = 1.2
	run.upgrade_levels = {
		"breath_meditation": 25,
		"body_tempering": 12,
		"meridian_opening": 8,
		"swift_circulation": 6,
		"foundation_mantra": 4,
	}
	for feature in [
		"upgrades_basic", "spiritual_roots", "artifacts_basic", "rebirth_unlock",
		"automation_buy_upgrades", "auto_buy_upgrades", "auto_breakthrough",
		"karma_shop_basic", "offline_efficiency_boost", "talent_reroll",
		"path_selection", "artifact_gacha_basic",
	]:
		run.unlocked[feature] = true
	run.talents_owned = [
		{"uid": "t1", "root_id": "fire_root", "rarity": "rare", "roll": 0.14, "level": 1},
		{"uid": "t2", "root_id": "metal_root", "rarity": "uncommon", "roll": 0.08, "level": 0},
		{"uid": "t3", "root_id": "water_root", "rarity": "epic", "roll": 0.22, "level": 0},
		{"uid": "t4", "root_id": "thunder_root", "rarity": "common", "roll": 0.04, "level": 0},
	]
	run.talents_equipped = ["t1", "t2", "t3"]
	run.talent_seq = 5
	run.artifacts_owned = {
		"jade_slip": 2,
		"spirit_stone_pouch": 1,
		"flying_sword_shard": 0,
		"heavenly_mirror": 0,
	}
	run.artifacts_equipped = ["jade_slip", "spirit_stone_pouch", "flying_sword_shard", "heavenly_mirror"]
	run.automation_toggles = {"auto_buy_upgrades": true, "auto_breakthrough": true}
	run.auto_buy_mode = "roi"
	run.auto_rebirth_min_rank = 15
	run.auto_rebirth_min_karma = 3
	run.rebirth_count = 25
	run.rank_index = 19
	run.highest_rank_index = 19
	run.path_id = "heavenly_sword"
	run.path_joined = true
	run.path_currency = 4.0
	run.path_nodes = {"shorten_charge": 2, "extend_burst": 1, "echo_slash": 1}
	run.burst_left = 6.0
	run.dao_marks = 3.0
	run.ascension_count = 1
	run.time_sec = 780.0
	run.stats = {
		"offline_sec": 5400.0,
		"best_rebirth_sec": 2740.0,
		"fastest_ascension_sec": 5820.0,
		"path_sec": {"heavenly_sword": 780.0},
		"worlds": ["mortal_world", "spirit_world"],
	}
	run.achievements = {"asc_1": true}
	run.essence_ratio = 0.25
	run.world_res = {"spirit_essence": 12.0}
	run.research_progress = 40.0
	run.unlocked["ascension_gate"] = true
	run.unlocked["dao_laws"] = true
	run.unlocked["dual_flow"] = true
	run.unlocked["reality_stitch"] = true
	for feature in ["spiritual_roots", "artifacts_basic", "rebirth_unlock", "automation_buy_upgrades", "path_selection"]:
		run.reveal_seen[feature] = true
	last_prod = Economy.production_float(run)
	run.timestamp_unix = int(Time.get_unix_time_from_system())


static func _test_mode() -> bool:
	if OS.get_environment("CBH_TEST") == "1":
		return true
	for a in OS.get_cmdline_args():
		var s := str(a)
		if s == "-s" or s == "--script" or s.ends_with("run_tests.gd"):
			return true
	return OS.get_cmdline_user_args().has("--test")


static func _screenshot_mode() -> bool:
	return OS.get_cmdline_user_args().has("--screenshots")
