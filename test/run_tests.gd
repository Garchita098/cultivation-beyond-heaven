extends SceneTree
## Headless checks: BigNum, save migration, offline ticks, golden-tick parity.

var _fails: Array[String] = []
var _passes: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var code := 0
	if not _all():
		code = 1
	print("RESULT passes=%d fails=%d" % [_passes, _fails.size()])
	quit(code)


func _all() -> bool:
	var content := preload("res://autoload/content.gd")
	if not content.load_all():
		_fail("content load: %s" % content.error)
		return false
	_ok("content schema 1, ranks=%d upgrades=%d" % [content.data.ranks.size(), content.data.upgrade_order.size()])
	_test_bignum()
	_test_production_fixture()
	_test_live_buy()
	_test_save_migration()
	_test_offline_matches_ticks()
	_test_golden_parity()
	_test_rebirth_rules()
	_test_stage2_cases()
	_test_offline_automation()
	return _fails.is_empty()


func _ok(msg: String) -> void:
	_passes += 1
	print("ok ", msg)


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("FAIL ", msg)


func _test_bignum() -> void:
	var z := BigNum.from_float(0.0)
	if not z.is_zero() or BigNum.format(z) != "0":
		_fail("zero format")
	else:
		_ok("bignum zero")

	var nan_b := BigNum.from_float(NAN)
	var inf_b := BigNum.from_float(INF)
	if not nan_b.is_zero() or not inf_b.is_zero():
		_fail("non-finite not clamped")
	else:
		_ok("bignum nan/inf clamp")

	var sum := BigNum.from_float(1.5).add(BigNum.from_float(1.5))
	if sum.exponent != 0 or absf(sum.mantissa - 3.0) > 1e-9:
		_fail("1.5+1.5 -> %s e%d" % [str(sum.mantissa), sum.exponent])
	else:
		_ok("bignum add 1.5+1.5")

	var big := BigNum.from_float(1.5e20).add(BigNum.from_float(3.0))
	if big.exponent != 20 or absf(big.mantissa - 1.5) > 1e-9:
		_fail("large add dropped small term got %s e%d" % [str(big.mantissa), big.exponent])
	else:
		_ok("bignum add discards tiny term")

	var prod := BigNum.from_float(1.5).mul(BigNum.from_float(2000.0))
	if prod.exponent != 3 or absf(prod.mantissa - 3.0) > 1e-6:
		_fail("mul 1.5*2000 got %s e%d" % [str(prod.mantissa), prod.exponent])
	else:
		_ok("bignum mul")

	if BigNum.from_float(1.5).cmp(BigNum.from_float(1.6)) != -1:
		_fail("cmp 1.5<1.6")
	elif BigNum.normalize(1.0, 5).cmp(BigNum.normalize(9.0, 4)) != 1:
		_fail("cmp exponent align")
	else:
		_ok("bignum compare")

	var cases := {
		8.0: "8",
		1.25: "1.25",
		1500.0: "1.5K",
		1230000.0: "1.23M",
		2.5e9: "2.5B",
	}
	for value in cases.keys():
		var got := BigNum.format(BigNum.from_float(float(value)))
		if got != str(cases[value]):
			_fail("format %s -> %s expected %s" % [str(value), got, str(cases[value])])
		else:
			_ok("format %s" % got)
	var sci := BigNum.format(BigNum.normalize(1.23, 33))
	if sci != "1.23e33":
		_fail("sci format %s" % sci)
	else:
		_ok("format scientific")

	var samples: Array[BigNum] = [BigNum.from_float(1500.0), BigNum.from_float(0.1), BigNum.normalize(1.23, 45), BigNum.normalize(1.23, 400), BigNum.from_float(12.0)]
	for sample in samples:
		var text: String = sample.to_save_string()
		var back: BigNum = BigNum.from_save_string(text)
		if not back.nearly(sample, 1e-9):
			_fail("roundtrip %s -> %s e%d vs %s e%d" % [text, str(back.mantissa), back.exponent, str(sample.mantissa), sample.exponent])
		else:
			_ok("roundtrip %s" % text)
	var bad := BigNum.from_save_string("nan")
	if not bad.is_zero():
		_fail("nan string")
	else:
		_ok("nan string clamps")


func _test_production_fixture() -> void:
	var data: EconData = preload("res://autoload/content.gd").data
	var levels := {"breath_meditation": 4, "body_tempering": 2, "swift_circulation": 3}
	var prod := EconomyCore.production(data, 4, levels, 2.0, 1.0)
	var cost := EconomyCore.upgrade_cost(data, levels, "breath_meditation")
	if absf(prod - 22.176) > 1e-6:
		_fail("production fixture %s" % str(prod))
	else:
		_ok("production fixture")
	if absf(cost - 10.4940375) > 1e-6:
		_fail("cost fixture %s" % str(cost))
	else:
		_ok("cost fixture")
	var as_bn := EconomyCore.production_bn(data, 4, levels, 2.0, 1.0)
	if not as_bn.nearly(BigNum.from_float(prod), 1e-9):
		_fail("production bignum mirror")
	else:
		_ok("production bignum mirror")


func _test_live_buy() -> void:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		_fail("GameState autoload missing")
		return
	gs.run = RunState.new()
	gs.run.qi = BigNum.from_float(20.0)
	if not gs.try_buy("breath_meditation"):
		_fail("live buy refused a payable training")
		return
	var spent := BigNum.from_float(20.0).sub(gs.run.qi)
	if int(gs.run.upgrade_levels.get("breath_meditation", 0)) != 1:
		_fail("live buy did not increment level")
	elif not spent.nearly(BigNum.from_float(6.0), 1e-6):
		_fail("live buy spent %s" % spent.to_save_string())
	elif gs.try_breakthrough():
		_fail("breakthrough succeeded without the cost")
	else:
		_ok("live buy spends qi and does not grant it")


func _test_save_migration() -> void:
	var save := preload("res://autoload/save_system.gd")
	var original := {
		"save_version": 1,
		"timestamp_unix": 100,
		"qi": "1.5e10",
		"lifetime_qi": "2e10",
		"rank_index": 12,
		"upgrade_levels": {"breath_meditation": 40},
		"karma_shards": "12",
		"rebirth_count": 1,
		"unlocked": ["rebirth_unlock"],
		"path_id": null,
		"world_id": "mortal_world",
		"meta": {},
	}
	var migrated: Dictionary = save.migrate(original)
	if int(original["save_version"]) != 1:
		_fail("migrate mutated caller")
	elif int(migrated["save_version"]) != 3 or int(migrated["highest_rank_index"]) != 12:
		_fail("v1->current missing highest_rank_index")
	elif str(migrated["qi"]) != "1.5e10":
		_fail("v1 qi changed %s" % str(migrated["qi"]))
	elif typeof(migrated.get("talents_owned")) != TYPE_ARRAY or typeof(migrated.get("shop_levels")) != TYPE_DICTIONARY:
		_fail("v1->v3 missing stage 2 fields")
	else:
		_ok("migrate v1 stage-1 save through v3")
	var again: Dictionary = save.migrate(migrated)
	if int(again["save_version"]) != 3 or int(again["highest_rank_index"]) != 12:
		_fail("migrate v3 not idempotent")
	else:
		_ok("migrate v3 idempotent")

	var stage1 := {
		"save_version": 2,
		"timestamp_unix": 50,
		"qi": "8.5e6",
		"lifetime_qi": "9e6",
		"rank_index": 9,
		"highest_rank_index": 9,
		"upgrade_levels": {"breath_meditation": 20, "body_tempering": 5},
		"karma_shards": "0",
		"rebirth_count": 0,
		"unlocked": ["upgrades_basic", "spiritual_roots"],
		"path_id": null,
		"world_id": "mortal_world",
		"shop_mult": 1.0,
		"offline_eff_bonus": 0.0,
		"starting_qi": "0",
		"time_sec": 1200.0,
		"meta": {},
	}
	var from_stage1: Dictionary = save.migrate(stage1)
	var stage1_run := RunState.from_save_dict(from_stage1)
	if int(from_stage1["save_version"]) != 3:
		_fail("stage-1 v2 did not become v3")
	elif not stage1_run.qi.nearly(BigNum.from_save_string("8.5e6")) or stage1_run.rank_index != 9:
		_fail("stage-1 qi/rank lost")
	elif int(stage1_run.upgrade_levels.get("breath_meditation", 0)) != 20:
		_fail("stage-1 upgrades lost")
	elif not stage1_run.unlocked.has("spiritual_roots") or not stage1_run.talents_owned.is_empty():
		_fail("stage-1 unlocks or empty talents")
	elif int(stage1_run.shop_levels.get("karma_prod_1", 0)) != 0:
		_fail("stage-1 invented shop levels")
	else:
		_ok("migrate stage-1 v2 save to v3")

	var legacy: Dictionary = save.migrate({"save_version": 0, "qi": 100, "rank": 1})
	var legacy_run := RunState.from_save_dict(legacy)
	if int(legacy["save_version"]) != 3 or not legacy_run.qi.nearly(BigNum.from_float(100.0)):
		_fail("v0 numeric qi migration %s" % str(legacy.get("qi")))
	elif legacy_run.rank_index != 1:
		_fail("v0 rank")
	else:
		_ok("migrate v0 numeric qi")

	var future := {"save_version": 99, "qi": "5", "rank_index": 3, "meta": {}}
	var kept: Dictionary = save.migrate(future)
	if int(kept["save_version"]) != 99 or str(kept["qi"]) != "5":
		_fail("future save was rewritten")
	elif not bool(kept["meta"].get("future_version", false)):
		_fail("future save not flagged")
	else:
		_ok("future save kept")

	var dir := "user://cbh_unit/"
	var run := RunState.new()
	run.qi = BigNum.normalize(1.25, 8)
	run.lifetime_qi = run.qi.dup()
	run.rank_index = 4
	run.upgrade_levels = {"breath_meditation": 7}
	run.world_id = "mortal_world"
	if not save.save_run(run, dir):
		_fail("save_run failed")
		return
	var loaded := save.load_run(dir)
	if loaded == null or not loaded.qi.nearly(run.qi, 1e-8) or loaded.rank_index != 4:
		_fail("save/load roundtrip")
	elif int(loaded.upgrade_levels.get("breath_meditation", -1)) != 7:
		_fail("upgrade level roundtrip")
	else:
		_ok("save/load roundtrip")
	var doc: Dictionary = save.load_document(dir)
	if int(doc["data"]["save_version"]) != 3:
		_fail("saved version")
	else:
		_ok("saved document is v3")

	var latest := dir + "save_latest.json"
	var file := FileAccess.open(latest, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	var corrupt: Dictionary = save.load_document(dir)
	if bool(corrupt.get("ok", true)):
		_fail("corrupt save treated as ok")
	elif not FileAccess.file_exists(dir + "save_latest.json.bak"):
		_fail("corrupt save was not backed up")
	else:
		_ok("corrupt save backed up")


func _test_offline_matches_ticks() -> void:
	var offline := preload("res://autoload/offline_calc.gd")
	var data: EconData = preload("res://autoload/content.gd").data
	var levels := {"breath_meditation": 3}
	var prod := EconomyCore.production(data, 0, levels, 0.0, 1.0)
	var dt := float(data.balance["tick_seconds"])
	var n := 400
	var absent := float(n) * dt
	var eff := offline.efficiency(0.0)
	var sim := 0.0
	for _i in n:
		sim += prod * dt * eff
	var closed: Dictionary = offline.gained_float(prod, absent, 0.0)
	if absf(float(closed["gained"]) - sim) > 1e-4:
		_fail("offline %s != %s ticks" % [str(closed["gained"]), str(sim)])
	else:
		_ok("offline equals %d ticks inside soft cap" % n)

	var soft := float(data.balance["offline"]["soft_cap_hours"]) * 3600.0
	var long_absent := 10.0 * 3600.0
	var step := 1.0
	var t := 0.0
	var sim_long := 0.0
	while t < long_absent - 1e-6:
		var e := eff if t < soft else eff * 0.5
		sim_long += prod * step * e
		t += step
	var closed_long: Dictionary = offline.gained_float(prod, long_absent, 0.0)
	var tol := maxf(1e-2, absf(sim_long) * 1e-6)
	if absf(float(closed_long["gained"]) - sim_long) > tol:
		_fail("soft-cap offline %s != simulated %s" % [str(closed_long["gained"]), str(sim_long)])
	else:
		_ok("offline equals per-second ticks across soft cap")

	var hard := float(data.balance["offline"]["hard_cap_hours"]) * 3600.0
	var capped: Dictionary = offline.gained_float(prod, 48.0 * 3600.0, 0.0)
	var cap_closed: Dictionary = offline.gained_float(prod, hard, 0.0)
	if not bool(capped["hard_capped"]) or absf(float(capped["gained"]) - float(cap_closed["gained"])) > 1e-4:
		_fail("hard cap")
	else:
		_ok("offline hard cap")


func _test_golden_parity() -> void:
	var path := "res://tools/sim/reports/golden_ticks.json"
	if not FileAccess.file_exists(path):
		_fail("missing golden_ticks.json")
		return
	var golden = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(golden) != TYPE_DICTIONARY:
		_fail("golden json")
		return
	var data: EconData = preload("res://autoload/content.gd").data
	var last_t := float(golden["ticks_every_30s"][-1]["t"])
	var dt := float(data.balance["tick_seconds"])
	var ran := SimParity.run_rebirth_early(data, last_t + dt, true)
	var by_t := {}
	for sample in ran["samples"]:
		by_t[snappedf(float(sample["t"]), 0.0001)] = sample
	var fails := 0
	var shown := 0
	for exp in golden["ticks_every_30s"]:
		var key := snappedf(float(exp["t"]), 0.0001)
		if not by_t.has(key):
			fails += 1
			if shown < 8:
				print("FAIL missing t=", exp["t"])
				shown += 1
			continue
		var got: Dictionary = by_t[key]
		if int(got["rank_index"]) != int(exp["rank_index"]) or int(got["rebirths"]) != int(exp["rebirths"]) or str(got["rank_id"]) != str(exp["rank_id"]) or int(got["talents"]) != int(exp["talents"]) or int(got["artifacts"]) != int(exp["artifacts"]):
			fails += 1
			if shown < 8:
				print("FAIL t=%s rank %s#%s r%s != %s#%s r%s" % [str(exp["t"]), got["rank_id"], str(got["rank_index"]), str(got["rebirths"]), exp["rank_id"], str(exp["rank_index"]), str(exp["rebirths"])])
				shown += 1
			continue
		if not _close(float(got["qi"]), float(exp["qi"])) or not _close(float(got["prod"]), float(exp["prod"])) or not _close(float(got["karma"]), float(exp["karma"])) or not _close(float(got["shop_mult"]), float(exp["shop_mult"])):
			fails += 1
			if shown < 8:
				print("FAIL t=%s qi %s != %s prod %s != %s" % [str(exp["t"]), str(got["qi"]), str(exp["qi"]), str(got["prod"]), str(exp["prod"])])
				shown += 1
	var miles: Dictionary = golden["milestones"]
	var got_m: Dictionary = ran["milestones"]
	for mkey in miles.keys():
		if not got_m.has(mkey) or absf(float(got_m[mkey]) - float(miles[mkey])) > 1e-6:
			fails += 1
			if shown < 12:
				print("FAIL milestone %s got %s expected %s" % [str(mkey), str(got_m.get(mkey, "missing")), str(miles[mkey])])
				shown += 1
	if fails > 0:
		_fail("golden parity mismatches=%d samples=%d" % [fails, ran["samples"].size()])
	else:
		_ok("golden parity %d samples" % ran["samples"].size())


func _test_rebirth_rules() -> void:
	var data: EconData = preload("res://autoload/content.gd").data
	var state := SimState.new()
	state.rank_index = 15
	state.highest_rank_index = 15
	state.qi = 80.0
	state.lifetime_qi = 2.5e9
	state.upgrade_levels = {"breath_meditation": 15, "swift_circulation": 3}
	state.karma_shards = 4.0
	state.unlocked["spiritual_roots"] = true
	state.unlocked["artifacts_basic"] = true
	state.unlocked["rebirth_unlock"] = true
	state.shop_levels["karma_prod_1"] = 2
	state.talents_owned = [{"uid": "t1", "root_id": "water_root", "rarity": "common", "roll": 0.04, "level": 0}]
	state.talents_equipped = ["t1"]
	state.talent_seq = 2
	state.artifacts_owned = {"jade_slip": 0}
	state.artifacts_equipped = ["jade_slip"]
	state.path_id = "immortal"
	state.automation_toggles["auto_buy_upgrades"] = false
	var life := state.lifetime_qi
	var karma_before := state.karma_shards
	if not EconomyCore.do_rebirth(data, state):
		_fail("rebirth refused at core peak")
		return
	var kept_qi := state.qi
	if state.rebirth_count != 1 or state.rank_index != 0:
		_fail("rebirth count/rank %d / %d" % [state.rebirth_count, state.rank_index])
	elif not state.upgrade_levels.is_empty():
		_fail("upgrades were not reset")
	elif absf(state.lifetime_qi - life) > 1.0:
		_fail("lifetime qi was reset")
	elif state.karma_shards <= karma_before:
		_fail("karma did not increase")
	elif state.talents_owned.size() != 2 or not state.artifacts_owned.has("jade_slip"):
		_fail("talents/artifacts did not persist")
	elif state.path_id != "immortal" or int(state.shop_levels.get("karma_prod_1", 0)) != 2:
		_fail("path or shop did not persist")
	elif not state.unlocked.has("karma_shop_basic"):
		_fail("first rebirth did not open the shop")
	elif kept_qi < 0.0:
		_fail("qi negative after rebirth")
	else:
		_ok("rebirth resets the run and keeps the meta")

	# A pinned training line survives when the shop says so.
	state.rank_index = 15
	state.highest_rank_index = 15
	state.upgrade_levels = {"breath_meditation": 9, "body_tempering": 2}
	state.shop_levels["karma_keep_upgrade"] = 1
	state.unlocked["karma_shop_advanced"] = true
	state.rebirth_count = 10
	if not EconomyCore.do_rebirth(data, state):
		_fail("second rebirth refused")
	elif int(state.upgrade_levels.get("breath_meditation", 0)) != 9 or state.upgrade_levels.has("body_tempering"):
		_fail("keep-one-line kept the wrong training %s" % str(state.upgrade_levels))
	else:
		_ok("rebirth keeps the strongest training line")


func _test_stage2_cases() -> void:
	var path := "res://tools/sim/reports/stage2_cases.json"
	if not FileAccess.file_exists(path):
		_fail("missing stage2_cases.json")
		return
	var cases = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(cases) != TYPE_DICTIONARY:
		_fail("stage2 cases json")
		return
	var data: EconData = preload("res://autoload/content.gd").data
	var roll: Dictionary = EconomyCore.roll_talent_fields(data, 81001)
	var expect: Dictionary = cases["roll_81001"]
	if str(roll["root_id"]) != str(expect["root_id"]) or str(roll["rarity"]) != str(expect["rarity"]) or not _close(float(roll["roll"]), float(expect["roll"])):
		_fail("talent roll 81001 %s" % str(roll))
	else:
		_ok("talent roll matches sim")
	var costs: Array = cases["shop_prod_costs"]
	var cost_ok := true
	for i in costs.size():
		if EconomyCore.shop_cost(data, "karma_prod_1", i) != int(costs[i]):
			cost_ok = false
	if not cost_ok:
		_fail("shop costs diverged")
	else:
		_ok("shop costs match sim")

	var plain := SimState.new()
	plain.artifacts_owned["flying_sword_shard"] = 0
	plain.artifacts_equipped = ["flying_sword_shard"]
	var with_path := SimState.new()
	with_path.artifacts_owned["flying_sword_shard"] = 0
	with_path.artifacts_equipped = ["flying_sword_shard"]
	with_path.path_id = "heavenly_sword"
	var hook: Dictionary = cases["path_hook_prod"]
	if not _close(EconomyCore.production_state(data, plain), float(hook["plain"])) or not _close(EconomyCore.production_state(data, with_path), float(hook["with_path"])):
		_fail("path hook prod %s / %s" % [str(EconomyCore.production_state(data, plain)), str(EconomyCore.production_state(data, with_path))])
	elif float(hook["with_path"]) <= float(hook["plain"]):
		_fail("path hook did not raise production")
	else:
		_ok("artifact path hook matches sim")

	var rb: Dictionary = cases["rebirth"]
	var st := SimState.new()
	st.rank_index = 15
	st.highest_rank_index = 15
	st.qi = 50.0
	st.lifetime_qi = 1.0e10
	st.upgrade_levels = {"breath_meditation": 12, "body_tempering": 4}
	st.unlocked["spiritual_roots"] = true
	st.unlocked["artifacts_basic"] = true
	st.unlocked["rebirth_unlock"] = true
	st.artifacts_owned["jade_slip"] = 1
	st.artifacts_equipped = ["jade_slip"]
	st.talents_owned = [{"uid": "t1", "root_id": "fire_root", "rarity": "rare", "roll": 0.12, "level": 1}]
	st.talents_equipped = ["t1"]
	st.talent_seq = 2
	st.shop_levels["karma_prod_1"] = 1
	st.karma_shards = 3.0
	st.path_id = "heavenly_sword"
	EconomyCore.do_rebirth(data, st)
	if st.rebirth_count != int(rb["rebirths"]) or st.rank_index != int(rb["rank_index"]) or st.talents_owned.size() != int(rb["talents"]):
		_fail("rebirth case shape r%d rank %d talents %d" % [st.rebirth_count, st.rank_index, st.talents_owned.size()])
	elif not _close(st.karma_shards, float(rb["karma"])) or not _close(st.qi, float(rb["qi"])) or not _close(st.shop_mult, float(rb["shop_mult"])):
		_fail("rebirth case numbers karma %s qi %s" % [str(st.karma_shards), str(st.qi)])
	elif st.path_id != str(rb["path_id"]) or not st.unlocked.has("karma_shop_basic"):
		_fail("rebirth case persist")
	else:
		_ok("rebirth case matches sim")


func _test_offline_automation() -> void:
	var path := "res://tools/sim/reports/stage2_cases.json"
	var cases = JSON.parse_string(FileAccess.get_file_as_string(path))
	var data: EconData = preload("res://autoload/content.gd").data
	var state := SimState.new()
	state.rank_index = 12
	state.highest_rank_index = 12
	state.qi = 0.0
	state.unlocked["automation_buy_upgrades"] = true
	state.unlocked["auto_buy_upgrades"] = true
	state.automation_toggles["auto_buy_upgrades"] = true
	var info := EconomyCore.apply_offline(data, state, 180.0)
	var expect: Dictionary = cases["offline_auto"]
	if not bool(info["chunked"]):
		_fail("automation offline stayed closed-form")
	elif int(state.upgrade_levels.get("breath_meditation", 0)) != int(expect["breath"]):
		_fail("offline auto breath %s != %s" % [str(state.upgrade_levels.get("breath_meditation", 0)), str(expect["breath"])])
	elif not _close(state.qi, float(expect["qi"])) or state.rank_index != int(expect["rank_index"]):
		_fail("offline auto qi/rank %s / %d" % [str(state.qi), state.rank_index])
	elif int(state.upgrade_levels.get("breath_meditation", 0)) <= 0:
		_fail("offline auto bought nothing")
	else:
		_ok("offline with auto-buy matches sim")

	# Same window with automation off stays closed-form and does not buy.
	var quiet := SimState.new()
	quiet.rank_index = 12
	quiet.highest_rank_index = 12
	quiet.automation_toggles["auto_buy_upgrades"] = false
	var closed := EconomyCore.apply_offline(data, quiet, 180.0)
	if bool(closed["chunked"]) or int(quiet.upgrade_levels.get("breath_meditation", 0)) != 0:
		_fail("automation off still acted")
	else:
		_ok("offline without automation is closed-form")


func _close(a: float, b: float) -> bool:
	return absf(a - b) <= maxf(1e-3, 1e-5 * maxf(absf(a), absf(b)))
