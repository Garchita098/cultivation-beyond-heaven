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
var world_id: String = "mortal_world"
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
var qi_e: int = 0
var life_e: int = 0
var achievements: Dictionary = {}
var stats: Dictionary = {}
var fresh_achievements: Array = []
var _talent_sig: String = ""


func _init() -> void:
	unlocked["upgrades_basic"] = true
