class_name SimState
extends RefCounted
## Float-economy state used by the parity simulator (mirrors sim/economy.py GameState).

var qi: float = 0.0
var lifetime_qi: float = 0.0
var rank_index: int = 0
var highest_rank_index: int = 0
var upgrade_levels: Dictionary = {}
var karma_shards: float = 0.0
var rebirth_count: int = 0
var unlocked: Dictionary = {}
var time_sec: float = 0.0
var last_purchase_or_unlock_time: float = 0.0
var milestones: Dictionary = {}
var shop_mult: float = 1.0
var starting_qi_bonus: float = 0.0
var offline_eff_bonus: float = 0.0


func _init() -> void:
	unlocked["upgrades_basic"] = true
