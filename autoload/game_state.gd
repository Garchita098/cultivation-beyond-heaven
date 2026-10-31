extends Node
## Runtime state, frame tick, purchases, and offline catch-up.
## The frame pump lives in scenes/main.gd so headless tests do not simulate a player.

var run: RunState
var last_prod: float = 1.0
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
	var prod := EconomyCore.production(
		Content.data, run.rank_index, run.upgrade_levels, run.karma_float(), run.shop_mult
	)
	if not is_finite(prod) or prod < 0.0:
		push_error("Qi production is not a finite non-negative number")
		last_prod = 0.0
		return
	last_prod = prod
	var gained := prod * delta
	if not is_finite(gained):
		push_error("Qi tick gain is not finite")
		return
	var gained_bn := BigNum.from_float(gained)
	run.qi = run.qi.add(gained_bn)
	run.lifetime_qi = run.lifetime_qi.add(gained_bn)
	run.time_sec += delta


func try_buy(uid: String) -> bool:
	if run == null or not Content.data.upgrades.has(uid):
		return false
	var u: Dictionary = Content.data.upgrades[uid]
	var req := int(Content.data.ranks_by_id[str(u["unlock_rank"])]["index"])
	if run.rank_index < req:
		return false
	var lvl := int(run.upgrade_levels.get(uid, 0))
	var mx := int(u.get("max_level", 0))
	if mx > 0 and lvl >= mx:
		return false
	var cost := EconomyCore.upgrade_cost_bn(Content.data, run.upgrade_levels, uid)
	if run.qi.cmp(cost) < 0:
		return false
	run.qi = run.qi.sub(cost)
	if run.qi.mantissa < 0.0:
		run.qi = BigNum.zero()
	run.upgrade_levels[uid] = lvl + 1
	last_prod = Economy.production_float(run)
	EventBus.state_changed.emit()
	return true


func try_breakthrough() -> bool:
	if run == null:
		return false
	var nxt := Economy.next_rank(run, EconomyCore.STAGE1_CAP)
	if nxt.is_empty():
		return false
	var cost := BigNum.from_float(float(nxt["cost_qi"]))
	if run.qi.cmp(cost) < 0:
		return false
	run.qi = run.qi.sub(cost)
	if run.qi.mantissa < 0.0:
		run.qi = BigNum.zero()
	run.rank_index += 1
	run.highest_rank_index = maxi(run.highest_rank_index, run.rank_index)
	for feature in nxt.get("unlocks", []):
		var fid := str(feature)
		run.unlocked[fid] = true
		EventBus.feature_unlocked.emit(fid)
	last_prod = Economy.production_float(run)
	EventBus.rank_up.emit(run.rank_index, str(nxt["id"]))
	EventBus.state_changed.emit()
	return true


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
	# Deterministic mid-early state so the aura and boards are not an empty frame.
	var sim := SimParity.run_rebirth_early_until(Content.data, 600.0)
	run.qi = BigNum.from_float(sim.qi)
	run.lifetime_qi = BigNum.from_float(sim.lifetime_qi)
	run.rank_index = sim.rank_index
	run.highest_rank_index = sim.highest_rank_index
	run.upgrade_levels = sim.upgrade_levels.duplicate()
	run.karma_shards = BigNum.from_float(sim.karma_shards)
	run.rebirth_count = sim.rebirth_count
	run.shop_mult = sim.shop_mult
	run.time_sec = sim.time_sec
	for k in sim.unlocked.keys():
		run.unlocked[str(k)] = true
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
