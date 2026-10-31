class_name SimState
extends RefCounted
## Float-economy state. Mirrors tools/sim/economy.py GameState for parity.

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
var path_id: String = ""
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


func _init() -> void:
	unlocked["upgrades_basic"] = true
