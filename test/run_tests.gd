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
	elif int(migrated["save_version"]) != 2 or int(migrated["highest_rank_index"]) != 12:
		_fail("v1->v2 missing highest_rank_index")
	elif str(migrated["qi"]) != "1.5e10":
		_fail("v1 qi changed %s" % str(migrated["qi"]))
	else:
		_ok("migrate v1 to v2")
	var again: Dictionary = save.migrate(migrated)
	if int(again["save_version"]) != 2 or int(again["highest_rank_index"]) != 12:
		_fail("migrate v2 not idempotent")
	else:
		_ok("migrate v2 idempotent")

	var legacy: Dictionary = save.migrate({"save_version": 0, "qi": 100, "rank": 1})
	var legacy_run := RunState.from_save_dict(legacy)
	if int(legacy["save_version"]) != 2 or not legacy_run.qi.nearly(BigNum.from_float(100.0)):
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
	if int(doc["data"]["save_version"]) != 2:
		_fail("saved version")
	else:
		_ok("saved document is v2")

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
		if int(got["rank_index"]) != int(exp["rank_index"]) or int(got["rebirths"]) != int(exp["rebirths"]) or str(got["rank_id"]) != str(exp["rank_id"]):
			fails += 1
			if shown < 8:
				print("FAIL t=%s rank %s#%s r%s != %s#%s r%s" % [str(exp["t"]), got["rank_id"], str(got["rank_index"]), str(got["rebirths"]), exp["rank_id"], str(exp["rank_index"]), str(exp["rebirths"])])
				shown += 1
			continue
		if not _close(float(got["qi"]), float(exp["qi"])) or not _close(float(got["prod"]), float(exp["prod"])):
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


func _close(a: float, b: float) -> bool:
	return absf(a - b) <= maxf(1e-3, 1e-5 * maxf(absf(a), absf(b)))
