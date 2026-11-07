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
var path_joined: bool = false
var path_currency: float = 0.0
var path_nodes: Dictionary = {}
var sword_charge: float = 0.0
var burst_left: float = 0.0
var demon_permanent: float = 0.0
var demon_fed: float = 0.0
var cultivated_hours: float = 0.0
var devour_types: Dictionary = {}
var devour_bonus: float = 0.0
var chrono_charge: float = 0.0
var speed_left: float = 0.0
var banked_sec: float = 0.0
var skip_used_sec: float = 0.0
var world_res: Dictionary = {}
var essence_ratio: float = 0.0
var retain_seconds: float = 180.0
var stance: String = "guard"
var tribulation_t: float = 0.0
var tribulation_cycle: int = 0
var boon_left: float = 0.0
var penalty_left: float = 0.0
var chaos_pulse_t: float = 0.0
var slotted_laws: Array = []
var active_rewrite: String = ""
var research_done: Dictionary = {}
var research_order: Array = []
var research_progress: float = 0.0
var dao_marks: float = 0.0
var ascension_count: int = 0
var reality_mode: String = "still"
var path_switch_count: int = 0
var sacrifice_count: int = 0
var mechanic_counts: Dictionary = {}
var achievements: Dictionary = {}
var stats: Dictionary = {}
var heavenly_rites: Dictionary = {}
var void_seals: Dictionary = {}
var chaos_attunements: Dictionary = {}
var notation: String = "letters"
var sound_on: bool = true
var reduced_effects: bool = false


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
	run.dao_marks = float(data.get("dao_marks", 0.0))
	run.ascension_count = int(data.get("ascension_count", 0))
	run.achievements = _flag_dict(data.get("achievements", []))
	var stats_v = data.get("stats", {})
	run.stats = stats_v.duplicate(true) if typeof(stats_v) == TYPE_DICTIONARY else {}
	var prefs = data.get("prefs", {})
	if typeof(prefs) == TYPE_DICTIONARY:
		run.notation = str(prefs.get("notation", "letters"))
		run.sound_on = bool(prefs.get("sound", true))
		run.reduced_effects = bool(prefs.get("reduced_effects", false))
	Prefs.apply_run(run)
	var layer = data.get("stage3", {})
	if typeof(layer) == TYPE_DICTIONARY:
		run._read_layer(layer)
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
		"dao_marks": dao_marks,
		"ascension_count": ascension_count,
		"stage3": _write_layer(),
		"achievements": _flag_list(achievements),
		"stats": stats.duplicate(true),
		"prefs": {
			"notation": notation,
			"sound": sound_on,
			"reduced_effects": reduced_effects,
		},
		"meta": {},
	}


func to_sim() -> SimState:
	var sim := SimState.new()
	Ledger.from_bn(sim, qi, false)
	Ledger.from_bn(sim, lifetime_qi, true)
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
	_copy_layer_to_sim(sim)
	return sim


func apply_sim(sim: SimState, copy_lifetime: bool = false) -> void:
	qi = Ledger.to_bn(sim, false)
	if copy_lifetime:
		lifetime_qi = Ledger.to_bn(sim, true)
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
	world_id = sim.world_id
	_copy_layer_from_sim(sim)


func _read_layer(layer: Dictionary) -> void:
	path_joined = bool(layer.get("path_joined", false))
	path_currency = float(layer.get("path_currency", 0.0))
	path_nodes = {}
	var nodes = layer.get("path_nodes", {})
	if typeof(nodes) == TYPE_DICTIONARY:
		for k in nodes.keys():
			path_nodes[str(k)] = int(nodes[k])
	sword_charge = float(layer.get("sword_charge", 0.0))
	burst_left = float(layer.get("burst_left", 0.0))
	demon_permanent = float(layer.get("demon_permanent", 0.0))
	demon_fed = float(layer.get("demon_fed", 0.0))
	cultivated_hours = float(layer.get("cultivated_hours", 0.0))
	devour_types = _flag_dict(layer.get("devour_types", []))
	devour_bonus = float(layer.get("devour_bonus", 0.0))
	chrono_charge = float(layer.get("chrono_charge", 0.0))
	speed_left = float(layer.get("speed_left", 0.0))
	banked_sec = float(layer.get("banked_sec", 0.0))
	skip_used_sec = float(layer.get("skip_used_sec", 0.0))
	world_res = {}
	var res = layer.get("world_res", {})
	if typeof(res) == TYPE_DICTIONARY:
		for k in res.keys():
			world_res[str(k)] = float(res[k])
	essence_ratio = float(layer.get("essence_ratio", 0.0))
	retain_seconds = float(layer.get("retain_seconds", 180.0))
	stance = str(layer.get("stance", "guard"))
	tribulation_t = float(layer.get("tribulation_t", 0.0))
	tribulation_cycle = int(layer.get("tribulation_cycle", 0))
	boon_left = float(layer.get("boon_left", 0.0))
	penalty_left = float(layer.get("penalty_left", 0.0))
	chaos_pulse_t = float(layer.get("chaos_pulse_t", 0.0))
	slotted_laws = _string_array(layer.get("slotted_laws", []))
	active_rewrite = str(layer.get("active_rewrite", ""))
	research_done = _flag_dict(layer.get("research_done", []))
	research_order = _string_array(layer.get("research_order", []))
	research_progress = float(layer.get("research_progress", 0.0))
	reality_mode = str(layer.get("reality_mode", "still"))
	path_switch_count = int(layer.get("path_switch_count", 0))
	sacrifice_count = int(layer.get("sacrifice_count", 0))
	heavenly_rites = _flag_dict(layer.get("heavenly_rites", []))
	void_seals = _flag_dict(layer.get("void_seals", []))
	chaos_attunements = _flag_dict(layer.get("chaos_attunements", []))
	mechanic_counts = {}
	var counts = layer.get("mechanic_counts", {})
	if typeof(counts) == TYPE_DICTIONARY:
		for k in counts.keys():
			mechanic_counts[str(k)] = int(counts[k])


func _write_layer() -> Dictionary:
	return {
		"path_joined": path_joined,
		"path_currency": path_currency,
		"path_nodes": path_nodes.duplicate(),
		"sword_charge": sword_charge,
		"burst_left": burst_left,
		"demon_permanent": demon_permanent,
		"demon_fed": demon_fed,
		"cultivated_hours": cultivated_hours,
		"devour_types": _flag_list(devour_types),
		"devour_bonus": devour_bonus,
		"chrono_charge": chrono_charge,
		"speed_left": speed_left,
		"banked_sec": banked_sec,
		"skip_used_sec": skip_used_sec,
		"world_res": world_res.duplicate(),
		"essence_ratio": essence_ratio,
		"retain_seconds": retain_seconds,
		"stance": stance,
		"tribulation_t": tribulation_t,
		"tribulation_cycle": tribulation_cycle,
		"boon_left": boon_left,
		"penalty_left": penalty_left,
		"chaos_pulse_t": chaos_pulse_t,
		"slotted_laws": slotted_laws.duplicate(),
		"active_rewrite": active_rewrite,
		"research_done": _flag_list(research_done),
		"research_order": research_order.duplicate(),
		"research_progress": research_progress,
		"reality_mode": reality_mode,
		"path_switch_count": path_switch_count,
		"sacrifice_count": sacrifice_count,
		"mechanic_counts": mechanic_counts.duplicate(),
		"heavenly_rites": _flag_list(heavenly_rites),
		"void_seals": _flag_list(void_seals),
		"chaos_attunements": _flag_list(chaos_attunements),
	}


func _copy_layer_to_sim(sim: SimState) -> void:
	sim.path_joined = path_joined
	sim.path_currency = path_currency
	sim.path_nodes = path_nodes.duplicate()
	sim.sword_charge = sword_charge
	sim.burst_left = burst_left
	sim.demon_permanent = demon_permanent
	sim.demon_fed = demon_fed
	sim.cultivated_hours = cultivated_hours
	sim.devour_types = devour_types.duplicate()
	sim.devour_bonus = devour_bonus
	sim.chrono_charge = chrono_charge
	sim.speed_left = speed_left
	sim.banked_sec = banked_sec
	sim.skip_used_sec = skip_used_sec
	sim.world_id = world_id
	sim.world_res = world_res.duplicate()
	sim.essence_ratio = essence_ratio
	sim.retain_seconds = retain_seconds
	sim.stance = stance
	sim.tribulation_t = tribulation_t
	sim.tribulation_cycle = tribulation_cycle
	sim.boon_left = boon_left
	sim.penalty_left = penalty_left
	sim.chaos_pulse_t = chaos_pulse_t
	sim.slotted_laws = slotted_laws.duplicate()
	sim.active_rewrite = active_rewrite
	sim.research_done = research_done.duplicate()
	sim.research_order = research_order.duplicate()
	sim.research_progress = research_progress
	sim.dao_marks = dao_marks
	sim.ascension_count = ascension_count
	sim.reality_mode = reality_mode
	sim.path_switch_count = path_switch_count
	sim.sacrifice_count = sacrifice_count
	sim.mechanic_counts = mechanic_counts.duplicate()
	sim.achievements = achievements.duplicate()
	sim.stats = stats.duplicate(true)
	sim.heavenly_rites = heavenly_rites.duplicate()
	sim.void_seals = void_seals.duplicate()
	sim.chaos_attunements = chaos_attunements.duplicate()


func _copy_layer_from_sim(sim: SimState) -> void:
	path_joined = sim.path_joined
	path_currency = sim.path_currency
	path_nodes = sim.path_nodes.duplicate()
	sword_charge = sim.sword_charge
	burst_left = sim.burst_left
	demon_permanent = sim.demon_permanent
	demon_fed = sim.demon_fed
	cultivated_hours = sim.cultivated_hours
	devour_types = sim.devour_types.duplicate()
	devour_bonus = sim.devour_bonus
	chrono_charge = sim.chrono_charge
	speed_left = sim.speed_left
	banked_sec = sim.banked_sec
	skip_used_sec = sim.skip_used_sec
	world_res = sim.world_res.duplicate()
	essence_ratio = sim.essence_ratio
	retain_seconds = sim.retain_seconds
	stance = sim.stance
	tribulation_t = sim.tribulation_t
	tribulation_cycle = sim.tribulation_cycle
	boon_left = sim.boon_left
	penalty_left = sim.penalty_left
	chaos_pulse_t = sim.chaos_pulse_t
	slotted_laws = sim.slotted_laws.duplicate()
	active_rewrite = sim.active_rewrite
	research_done = sim.research_done.duplicate()
	research_order = sim.research_order.duplicate()
	research_progress = sim.research_progress
	dao_marks = sim.dao_marks
	ascension_count = sim.ascension_count
	reality_mode = sim.reality_mode
	path_switch_count = sim.path_switch_count
	sacrifice_count = sim.sacrifice_count
	mechanic_counts = sim.mechanic_counts.duplicate()
	achievements = sim.achievements.duplicate()
	stats = sim.stats.duplicate(true)
	heavenly_rites = sim.heavenly_rites.duplicate()
	void_seals = sim.void_seals.duplicate()
	chaos_attunements = sim.chaos_attunements.duplicate()


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
