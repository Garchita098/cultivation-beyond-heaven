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
var talents_owned: Array = []
var talents_equipped: Array = []
var talent_seq: int = 1
var talent_roll_keys: Dictionary = {}
var reroll_count: int = 0
var artifacts_owned: Dictionary = {}
var artifacts_equipped: Array = []
var shop_levels: Dictionary = {}
var automation_toggles: Dictionary = {}
var auto_buy_mode: String = "roi"
var auto_rebirth_min_rank: int = 15
var auto_rebirth_min_karma: int = 1
var reveal_seen: Dictionary = {}


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
	run.talents_owned = _dup_array(data.get("talents_owned", []))
	run.talents_equipped = _string_array(data.get("talents_equipped", []))
	run.talent_seq = int(data.get("talent_seq", 1))
	run.talent_roll_keys = _flag_dict(data.get("talent_roll_keys", []))
	run.reroll_count = int(data.get("reroll_count", 0))
	run.artifacts_owned = {}
	var owned = data.get("artifacts_owned", {})
	if typeof(owned) == TYPE_DICTIONARY:
		for k in owned.keys():
			run.artifacts_owned[str(k)] = int(owned[k])
	run.artifacts_equipped = _string_array(data.get("artifacts_equipped", []))
	run.shop_levels = {}
	var shops = data.get("shop_levels", {})
	if typeof(shops) == TYPE_DICTIONARY:
		for k in shops.keys():
			run.shop_levels[str(k)] = int(shops[k])
	run.automation_toggles = {}
	var toggles = data.get("automation_toggles", {})
	if typeof(toggles) == TYPE_DICTIONARY:
		for k in toggles.keys():
			run.automation_toggles[str(k)] = bool(toggles[k])
	run.auto_buy_mode = str(data.get("auto_buy_mode", "roi"))
	run.auto_rebirth_min_rank = int(data.get("auto_rebirth_min_rank", 15))
	run.auto_rebirth_min_karma = int(data.get("auto_rebirth_min_karma", 1))
	run.reveal_seen = _flag_dict(data.get("reveal_seen", []))
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
		"talents_owned": talents_owned.duplicate(true),
		"talents_equipped": talents_equipped.duplicate(),
		"talent_seq": talent_seq,
		"talent_roll_keys": _flag_list(talent_roll_keys),
		"reroll_count": reroll_count,
		"artifacts_owned": artifacts_owned.duplicate(),
		"artifacts_equipped": artifacts_equipped.duplicate(),
		"shop_levels": shop_levels.duplicate(),
		"automation_toggles": automation_toggles.duplicate(),
		"auto_buy_mode": auto_buy_mode,
		"auto_rebirth_min_rank": auto_rebirth_min_rank,
		"auto_rebirth_min_karma": auto_rebirth_min_karma,
		"reveal_seen": _flag_list(reveal_seen),
		"meta": {},
	}


func to_sim() -> SimState:
	var sim := SimState.new()
	sim.qi = _finite(qi)
	sim.lifetime_qi = _finite(lifetime_qi)
	sim.rank_index = rank_index
	sim.highest_rank_index = highest_rank_index
	sim.upgrade_levels = upgrade_levels.duplicate()
	sim.karma_shards = _finite(karma_shards)
	sim.rebirth_count = rebirth_count
	sim.unlocked = unlocked.duplicate()
	sim.time_sec = time_sec
	sim.shop_mult = shop_mult
	sim.starting_qi_bonus = _finite(starting_qi)
	sim.offline_eff_bonus = offline_eff_bonus
	sim.path_id = path_id
	sim.talents_owned = talents_owned.duplicate(true)
	sim.talents_equipped = talents_equipped.duplicate()
	sim.talent_seq = talent_seq
	sim.talent_roll_keys = talent_roll_keys.duplicate()
	sim.reroll_count = reroll_count
	sim.artifacts_owned = artifacts_owned.duplicate()
	sim.artifacts_equipped = artifacts_equipped.duplicate()
	sim.shop_levels = shop_levels.duplicate()
	sim.automation_toggles = automation_toggles.duplicate()
	sim.auto_buy_mode = auto_buy_mode
	sim.auto_rebirth_min_rank = auto_rebirth_min_rank
	sim.auto_rebirth_min_karma = auto_rebirth_min_karma
	return sim


func apply_sim(sim: SimState, copy_lifetime: bool = false) -> void:
	qi = BigNum.from_float(sim.qi)
	if copy_lifetime:
		lifetime_qi = BigNum.from_float(sim.lifetime_qi)
		time_sec = sim.time_sec
	rank_index = sim.rank_index
	highest_rank_index = sim.highest_rank_index
	upgrade_levels = sim.upgrade_levels.duplicate()
	karma_shards = BigNum.from_float(sim.karma_shards)
	rebirth_count = sim.rebirth_count
	unlocked = sim.unlocked.duplicate()
	shop_mult = sim.shop_mult
	starting_qi = BigNum.from_float(sim.starting_qi_bonus)
	offline_eff_bonus = sim.offline_eff_bonus
	path_id = sim.path_id
	talents_owned = sim.talents_owned.duplicate(true)
	talents_equipped = sim.talents_equipped.duplicate()
	talent_seq = sim.talent_seq
	talent_roll_keys = sim.talent_roll_keys.duplicate()
	reroll_count = sim.reroll_count
	artifacts_owned = sim.artifacts_owned.duplicate()
	artifacts_equipped = sim.artifacts_equipped.duplicate()
	shop_levels = sim.shop_levels.duplicate()
	automation_toggles = sim.automation_toggles.duplicate()
	auto_buy_mode = sim.auto_buy_mode
	auto_rebirth_min_rank = sim.auto_rebirth_min_rank
	auto_rebirth_min_karma = sim.auto_rebirth_min_karma


func _finite(bn: BigNum) -> float:
	var f := bn.to_float()
	if not is_finite(f):
		push_error("RunState number is not finite")
		return 0.0
	return f


static func _dup_array(v) -> Array:
	if typeof(v) != TYPE_ARRAY:
		return []
	return (v as Array).duplicate(true)


static func _string_array(v) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for item in v:
		out.append(str(item))
	return out


static func _flag_dict(v) -> Dictionary:
	var out := {}
	if typeof(v) == TYPE_ARRAY:
		for item in v:
			out[str(item)] = true
	elif typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			out[str(k)] = true
	return out


static func _flag_list(flags: Dictionary) -> Array:
	var out: Array = []
	for k in flags.keys():
		if flags[k]:
			out.append(str(k))
	out.sort()
	return out
