class_name RunState
extends RefCounted
## Live game state. Qi and karma are BigNum so saves never store raw floats.

var qi: BigNum
var lifetime_qi: BigNum
var rank_index: int = 0
var highest_rank_index: int = 0
var upgrade_levels: Dictionary = {}
var karma_shards: BigNum
var rebirth_count: int = 0
var unlocked: Dictionary = {}
var time_sec: float = 0.0
var shop_mult: float = 1.0
var offline_eff_bonus: float = 0.0
var starting_qi: BigNum
var path_id: String = ""
var world_id: String = "mortal_world"
var timestamp_unix: int = 0


func _init() -> void:
	qi = BigNum.zero()
	lifetime_qi = BigNum.zero()
	karma_shards = BigNum.zero()
	starting_qi = BigNum.zero()
	unlocked = {"upgrades_basic": true}


func karma_float() -> float:
	var f := karma_shards.to_float()
	if not is_finite(f):
		push_error("RunState: karma not finite, treating as 0")
		return 0.0
	return f


static func from_save_dict(data: Dictionary) -> RunState:
	var run := RunState.new()
	run.qi = BigNum.from_save_string(str(data.get("qi", "0")))
	run.lifetime_qi = BigNum.from_save_string(str(data.get("lifetime_qi", "0")))
	run.rank_index = int(data.get("rank_index", 0))
	run.highest_rank_index = int(data.get("highest_rank_index", run.rank_index))
	run.upgrade_levels = {}
	var levels: Dictionary = data.get("upgrade_levels", {})
	for k in levels.keys():
		run.upgrade_levels[str(k)] = int(levels[k])
	run.karma_shards = BigNum.from_save_string(str(data.get("karma_shards", "0")))
	run.rebirth_count = int(data.get("rebirth_count", 0))
	run.unlocked = {}
	var unlocked_v = data.get("unlocked", ["upgrades_basic"])
	if typeof(unlocked_v) == TYPE_ARRAY:
		for item in unlocked_v:
			run.unlocked[str(item)] = true
	elif typeof(unlocked_v) == TYPE_DICTIONARY:
		for k in unlocked_v.keys():
			run.unlocked[str(k)] = true
	if run.unlocked.is_empty():
		run.unlocked["upgrades_basic"] = true
	run.shop_mult = float(data.get("shop_mult", 1.0))
	run.offline_eff_bonus = float(data.get("offline_eff_bonus", 0.0))
	run.starting_qi = BigNum.from_save_string(str(data.get("starting_qi", "0")))
	var path_v = data.get("path_id", null)
	run.path_id = "" if path_v == null else str(path_v)
	run.world_id = str(data.get("world_id", "mortal_world"))
	run.time_sec = float(data.get("time_sec", 0.0))
	run.timestamp_unix = int(data.get("timestamp_unix", 0))
	return run


func to_save_dict(save_version: int) -> Dictionary:
	var levels := {}
	for k in upgrade_levels.keys():
		levels[str(k)] = int(upgrade_levels[k])
	var unlocked_arr: Array = []
	for k in unlocked.keys():
		if unlocked[k]:
			unlocked_arr.append(str(k))
	unlocked_arr.sort()
	return {
		"save_version": save_version,
		"timestamp_unix": timestamp_unix,
		"qi": qi.to_save_string(),
		"lifetime_qi": lifetime_qi.to_save_string(),
		"rank_index": rank_index,
		"highest_rank_index": highest_rank_index,
		"upgrade_levels": levels,
		"karma_shards": karma_shards.to_save_string(),
		"rebirth_count": rebirth_count,
		"unlocked": unlocked_arr,
		"path_id": null if path_id == "" else path_id,
		"world_id": world_id,
		"shop_mult": shop_mult,
		"offline_eff_bonus": offline_eff_bonus,
		"starting_qi": starting_qi.to_save_string(),
		"time_sec": time_sec,
		"meta": {},
	}
