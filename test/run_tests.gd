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
	_test_stage3()
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
	var huge := BigNum.normalize(1.23, 1000000)
	var huge_text := huge.to_save_string()
	var huge_back := BigNum.from_save_string(huge_text)
	if BigNum.format(huge) != "1.23e1000000" or not huge_back.nearly(huge, 1e-9):
		_fail("e1e6 notation %s" % huge_text)
	else:
		_ok("notation exponent 1000000")

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
	elif int(migrated["save_version"]) != 4 or int(migrated["highest_rank_index"]) != 12:
		_fail("v1->current missing highest_rank_index")
	elif str(migrated["qi"]) != "1.5e10":
		_fail("v1 qi changed %s" % str(migrated["qi"]))
	elif typeof(migrated.get("talents_owned")) != TYPE_ARRAY or typeof(migrated.get("shop_levels")) != TYPE_DICTIONARY:
		_fail("v1->v4 missing stage 2 fields")
	elif typeof(migrated.get("stage3")) != TYPE_DICTIONARY or int(migrated.get("ascension_count", -1)) != 0:
		_fail("v1->v4 missing stage 3 fields")
	else:
		_ok("migrate v1 stage-1 save through v4")
	var again: Dictionary = save.migrate(migrated)
	if int(again["save_version"]) != 4 or int(again["highest_rank_index"]) != 12:
		_fail("migrate v4 not idempotent")
	else:
		_ok("migrate v4 idempotent")

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
	if int(from_stage1["save_version"]) != 4:
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
		_ok("migrate stage-1 v2 save to v4")

	var legacy: Dictionary = save.migrate({"save_version": 0, "qi": 100, "rank": 1})
	var legacy_run := RunState.from_save_dict(legacy)
	if int(legacy["save_version"]) != 4 or not legacy_run.qi.nearly(BigNum.from_float(100.0)):
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
	if int(doc["data"]["save_version"]) != 4:
		_fail("saved version")
	else:
		_ok("saved document is v4")

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


func _test_stage3() -> void:
	var path := "res://tools/sim/reports/stage3_cases.json"
	if not FileAccess.file_exists(path):
		_fail("missing stage3_cases.json")
		return
	var cases = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(cases) != TYPE_DICTIONARY:
		_fail("stage3 cases json")
		return
	var data: EconData = preload("res://autoload/content.gd").data

	var sword := SimState.new()
	sword.path_joined = true
	sword.path_id = "heavenly_sword"
	sword.rank_index = 4
	sword.upgrade_levels = {"breath_meditation": 10}
	var outside := EconomyCore.production_state(data, sword)
	var period := int(Stage3Rules._charge_period(data, sword))
	for _i in period:
		EconomyCore.tick(data, sword, 1.0)
	var expect_sword: Dictionary = cases["sword"]
	if not _close(outside, float(expect_sword["outside"])) or not _close(EconomyCore.production_state(data, sword), float(expect_sword["burst"])):
		_fail("sword burst %s -> %s" % [str(outside), str(EconomyCore.production_state(data, sword))])
	elif float(expect_sword["burst"]) <= float(expect_sword["outside"]) or int(sword.mechanic_counts.get("sword_burst", 0)) < 1:
		_fail("sword did not burst")
	else:
		_ok("heavenly sword charge then burst")

	var demon := SimState.new()
	demon.path_joined = true
	demon.path_id = "demon_emperor"
	demon.qi = 1000.0
	demon.rank_index = 8
	var before := EconomyCore.production_state(data, demon)
	if not Stage3Rules.sacrifice(data, demon, "qi"):
		_fail("demon sacrifice refused")
	else:
		var expect_demon: Dictionary = cases["demon"]
		if demon.qi >= 1000.0 or demon.demon_permanent <= 0.0 or EconomyCore.production_state(data, demon) <= before:
			_fail("demon sacrifice did not trade qi for power")
		elif not _close(demon.qi, float(expect_demon["qi"])) or not _close(demon.demon_permanent, float(expect_demon["permanent"])):
			_fail("demon numbers qi %s perm %s" % [str(demon.qi), str(demon.demon_permanent)])
		else:
			_ok("demon emperor sacrifice")

	var immortal := SimState.new()
	immortal.path_joined = true
	immortal.path_id = "immortal"
	immortal.rank_index = 4
	var info := EconomyCore.apply_offline(data, immortal, 3600.0)
	var expect_imm: Dictionary = cases["immortal"]
	if not bool(info["chunked"]) or immortal.cultivated_hours < 0.9 or EconomyCore.offline_eff(data, immortal) < 0.99:
		_fail("immortal offline hours %s eff %s" % [str(immortal.cultivated_hours), str(EconomyCore.offline_eff(data, immortal))])
	elif not _close(immortal.qi, float(expect_imm["qi"])) or not _close(EconomyCore.production_state(data, immortal), float(expect_imm["after"])):
		_fail("immortal offline parity qi %s" % str(immortal.qi))
	else:
		_ok("immortal compound offline")

	var devour := SimState.new()
	devour.path_joined = true
	devour.path_id = "world_devourer"
	devour.upgrade_levels = {"breath_meditation": 6, "body_tempering": 3}
	devour.artifacts_owned = {"jade_slip": 1, "spirit_stone_pouch": 0}
	devour.artifacts_equipped = ["jade_slip"]
	var plain := EconomyCore.production_state(data, devour)
	Stage3Rules.absorb(data, devour, "upgrade")
	Stage3Rules.absorb(data, devour, "artifact")
	var expect_dev: Dictionary = cases["devour"]
	if devour.devour_types.size() < 2 or EconomyCore.production_state(data, devour) <= plain:
		_fail("devourer did not grow from diversity")
	elif not _close(EconomyCore.production_state(data, devour), float(expect_dev["after"])) or int(devour.upgrade_levels.get("breath_meditation", 0)) != int(expect_dev["breath"]):
		_fail("devourer parity %s" % str(EconomyCore.production_state(data, devour)))
	else:
		_ok("world devourer absorbs upgrade and relic")

	var clock := SimState.new()
	clock.path_joined = true
	clock.path_id = "time_lord"
	clock.rank_index = 6
	clock.upgrade_levels = {"breath_meditation": 12}
	clock.chrono_charge = 3.0
	clock.banked_sec = 600.0
	var qi_before := clock.qi
	if not Stage3Rules.start_speed(data, clock) or not Stage3Rules.time_skip(data, clock):
		_fail("time lord refused speed or skip")
	else:
		var expect_time: Dictionary = cases["time"]
		if clock.qi <= qi_before or clock.banked_sec >= 600.0:
			_fail("time skip did not spend banked offline")
		elif not _close(clock.qi, float(expect_time["qi"])) or not _close(clock.banked_sec, float(expect_time["bank"])):
			_fail("time lord parity qi %s bank %s" % [str(clock.qi), str(clock.banked_sec)])
		else:
			_ok("time lord speed window and offline skip")

	var asc := SimState.new()
	asc.rank_index = 19
	asc.highest_rank_index = 19
	asc.rebirth_count = 25
	asc.qi = 1.0e12
	asc.lifetime_qi = 1.0e14
	asc.karma_shards = 40.0
	asc.upgrade_levels = {"breath_meditation": 10}
	asc.path_joined = true
	asc.path_id = "immortal"
	asc.path_nodes = {"dew_rate": 1}
	asc.shop_levels = {"karma_prod_1": 2}
	asc.unlocked["spiritual_roots"] = true
	asc.unlocked["ascension_gate"] = true
	asc.unlocked["path_selection"] = true
	asc.talents_owned = [{"uid": "t1", "root_id": "water_root", "rarity": "common", "roll": 0.04, "level": 0}]
	asc.artifacts_owned = {"jade_slip": 0}
	var expect_asc: Dictionary = cases["ascension"]
	if not Stage3Rules.do_ascension(data, asc):
		_fail("ascension refused")
	elif asc.qi != 0.0 or asc.karma_shards != 0.0 or not asc.upgrade_levels.is_empty() or int(asc.shop_levels.get("karma_prod_1", 0)) != 0:
		_fail("ascension did not reset the layer")
	elif asc.path_id != "immortal" or int(asc.path_nodes.get("dew_rate", 0)) != 1 or asc.talents_owned.size() != 1:
		_fail("ascension dropped path or roots")
	elif asc.world_id != "spirit_world" or not _close(asc.dao_marks, float(expect_asc["marks"])) or asc.rank_index != int(expect_asc["rank"]):
		_fail("ascension grant world %s marks %s rank %s" % [asc.world_id, str(asc.dao_marks), str(asc.rank_index)])
	else:
		_ok("ascension resets more than rebirth and grants dao marks")

	var spirit := SimState.new()
	spirit.world_id = "spirit_world"
	spirit.essence_ratio = 0.5
	spirit.rank_index = 4
	spirit.upgrade_levels = {"breath_meditation": 8}
	for _j in 10:
		EconomyCore.tick(data, spirit, 1.0)
	var expect_sp: Dictionary = cases["spirit"]
	if float(spirit.world_res.get("spirit_essence", 0.0)) <= 0.0:
		_fail("spirit channel produced no essence")
	elif not _close(spirit.qi, float(expect_sp["qi"])) or not _close(float(spirit.world_res["spirit_essence"]), float(expect_sp["essence"])):
		_fail("spirit parity qi %s essence %s" % [str(spirit.qi), str(spirit.world_res["spirit_essence"])])
	else:
		_ok("spirit channels split qi and essence")

	var heaven := SimState.new()
	heaven.world_id = "heavenly_world"
	heaven.rank_index = 16
	heaven.karma_shards = 20.0
	heaven.upgrade_levels = {"breath_meditation": 30, "body_tempering": 10}
	heaven.stance = "defy"
	var heaven_plain := EconomyCore.production_state(data, heaven)
	for _k in 180:
		EconomyCore.tick(data, heaven, 1.0)
	var expect_h: Dictionary = cases["heaven"]
	if heaven.tribulation_cycle < 1 or float(heaven.world_res.get("dao_fragments", 0.0)) <= 0.0 or heaven.boon_left <= 0.0:
		_fail("heavenly tribulation did not resolve")
	elif not _close(EconomyCore.production_state(data, heaven), float(expect_h["boon"])) or EconomyCore.production_state(data, heaven) <= heaven_plain:
		_fail("heavenly boon did not rewrite production %s" % str(EconomyCore.production_state(data, heaven)))
	else:
		_ok("heavenly tribulation changes the formula")

	var void_st := SimState.new()
	void_st.world_id = "void_dimension"
	void_st.rank_index = 4
	void_st.qi = 1.0e6
	void_st.retain_seconds = 60.0
	void_st.upgrade_levels = {"breath_meditation": 5}
	for _n in 5:
		EconomyCore.tick(data, void_st, 1.0)
	var expect_v: Dictionary = cases["void"]
	if float(void_st.world_res.get("void_dust", 0.0)) <= 0.0 or void_st.qi >= 1.0e6:
		_fail("void entropy did not drain qi into dust")
	elif not _close(void_st.qi, float(expect_v["qi"])) or not _close(float(void_st.world_res["void_dust"]), float(expect_v["dust"])):
		_fail("void parity qi %s dust %s" % [str(void_st.qi), str(void_st.world_res["void_dust"])])
	else:
		_ok("void entropy")

	var law := SimState.new()
	law.rank_index = 8
	law.upgrade_levels = {"breath_meditation": 12, "body_tempering": 10}
	law.unlocked["dao_laws"] = true
	var base_cost := EconomyCore.upgrade_cost_state(data, law, "breath_meditation")
	var base_prod := EconomyCore.production_state(data, law)
	if not Stage3Rules.slot_law(data, law, "soft_growth"):
		_fail("could not slot soft growth")
	else:
		var soft := EconomyCore.upgrade_cost_state(data, law, "breath_meditation")
		law.slotted_laws = ["flat_as_mult"]
		var powered := EconomyCore.production_state(data, law)
		var expect_law: Dictionary = cases["law"]
		if soft >= base_cost or not _close(powered, float(expect_law["powered"])) or not _close(base_prod, float(expect_law["base_prod"])):
			_fail("dao law did not rewrite cost/prod %s %s" % [str(soft), str(powered)])
		else:
			_ok("dao laws rewrite cost and production")

	var reality := SimState.new()
	reality.rank_index = 12
	reality.upgrade_levels = {"breath_meditation": 20, "body_tempering": 30}
	reality.unlocked["reality_stitch"] = true
	var still := EconomyCore.production_state(data, reality)
	reality.reality_mode = "inverted"
	var inverted := EconomyCore.production_state(data, reality)
	reality.reality_mode = "dilated"
	var dilated := EconomyCore.production_state(data, reality)
	var expect_r: Dictionary = cases["reality"]
	if inverted == still or not _close(dilated, float(expect_r["dilated"])) or not _close(inverted, float(expect_r["inverted"])):
		_fail("reality modes %s %s %s" % [str(still), str(inverted), str(dilated)])
	else:
		_ok("reality stitch inverts and dilates")

	var dual := SimState.new()
	dual.unlocked["dual_flow"] = true
	dual.rank_index = 4
	dual.upgrade_levels = {"breath_meditation": 6}
	for _d in 4:
		EconomyCore.tick(data, dual, 1.0)
	var expect_d: Dictionary = cases["dual"]
	if float(dual.world_res.get("spirit_essence", 0.0)) <= 0.0 or not _close(float(dual.world_res["spirit_essence"]), float(expect_d["essence"])):
		_fail("dual flow essence %s" % str(dual.world_res.get("spirit_essence", 0.0)))
	else:
		_ok("soul transformation dual flow")

	var research := SimState.new()
	research.rebirth_count = 5
	research.unlocked["path_selection"] = true
	for _r in 90:
		EconomyCore.tick(data, research, 1.0)
	if not bool(research.research_done.get("quiet_meridians", false)):
		_fail("research did not finish on time")
	else:
		_ok("research queue finishes by time")

	var off := SimState.new()
	off.path_joined = true
	off.path_id = "heavenly_sword"
	off.rank_index = 3
	off.upgrade_levels = {"breath_meditation": 4}
	var off_info := EconomyCore.apply_offline(data, off, 120.0)
	var manual := SimState.new()
	manual.path_joined = true
	manual.path_id = "heavenly_sword"
	manual.rank_index = 3
	manual.upgrade_levels = {"breath_meditation": 4}
	for _s in 2:
		EconomyCore._offline_slice(data, manual, 60.0, false)
		EconomyCore.automation_act(data, manual)
	var expect_off: Dictionary = cases["offline_sword"]
	if not bool(off_info["chunked"]) or not _close(off.qi, manual.qi) or not _close(off.qi, float(expect_off["qi"])):
		_fail("path offline parity %s vs %s" % [str(off.qi), str(manual.qi)])
	else:
		_ok("offline path chunks match ticks")

	var capped := SimState.new()
	capped.qi = 1e308
	Stage3Rules.clamp_state(data, capped)
	if capped.qi > float(data.balance["magnitude_cap"]):
		_fail("magnitude cap")
	else:
		_ok("qi clamps at the float cap")


func _close(a: float, b: float) -> bool:
	return absf(a - b) <= maxf(1e-3, 1e-5 * maxf(absf(a), absf(b)))
