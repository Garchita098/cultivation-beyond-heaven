extends Node
## Versioned JSON saves. Write temp file, then rename. Corrupt files are kept as .bak.

const CURRENT_VERSION := 3
const LATEST_NAME := "save_latest.json"
const AUTOSAVE_SEC := 20.0

static var _autosave_acc: float = 0.0


static func migrate(data: Dictionary) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	var version := int(d.get("save_version", 0))
	if version > CURRENT_VERSION:
		push_error("Save version %d is newer than supported %d; not wiping" % [version, CURRENT_VERSION])
		if typeof(d.get("meta")) != TYPE_DICTIONARY:
			d["meta"] = {}
		d["meta"]["future_version"] = true
		return d
	if version < 1:
		d = _migrate_0_to_1(d)
		version = 1
	if version < 2:
		d = _migrate_1_to_2(d)
		version = 2
	if version < 3:
		d = _migrate_2_to_3(d)
		version = 3
	d["save_version"] = CURRENT_VERSION
	return d


static func _migrate_0_to_1(d: Dictionary) -> Dictionary:
	d["qi"] = _as_save_num(d.get("qi", 0))
	d["lifetime_qi"] = _as_save_num(d.get("lifetime_qi", d.get("qi", 0)))
	d["karma_shards"] = _as_save_num(d.get("karma_shards", 0))
	d["rank_index"] = int(d.get("rank_index", d.get("rank", 0)))
	if not d.has("upgrade_levels") or typeof(d["upgrade_levels"]) != TYPE_DICTIONARY:
		d["upgrade_levels"] = {}
	if not d.has("unlocked"):
		d["unlocked"] = ["upgrades_basic"]
	d["rebirth_count"] = int(d.get("rebirth_count", 0))
	if not d.has("path_id"):
		d["path_id"] = null
	if not d.has("world_id"):
		d["world_id"] = "mortal_world"
	if not d.has("timestamp_unix"):
		d["timestamp_unix"] = 0
	if typeof(d.get("meta")) != TYPE_DICTIONARY:
		d["meta"] = {}
	d["save_version"] = 1
	return d


static func _migrate_1_to_2(d: Dictionary) -> Dictionary:
	if not d.has("highest_rank_index"):
		d["highest_rank_index"] = int(d.get("rank_index", 0))
	if not d.has("shop_mult"):
		d["shop_mult"] = 1.0
	if not d.has("offline_eff_bonus"):
		d["offline_eff_bonus"] = 0.0
	if not d.has("starting_qi"):
		d["starting_qi"] = "0"
	if not d.has("time_sec"):
		d["time_sec"] = 0.0
	if typeof(d.get("meta")) != TYPE_DICTIONARY:
		d["meta"] = {}
	d["save_version"] = 2
	return d


static func _migrate_2_to_3(d: Dictionary) -> Dictionary:
	# Stage 1 saves are version 2. Stage 2 adds loadout, shop, and automation.
	if typeof(d.get("talents_owned")) != TYPE_ARRAY:
		d["talents_owned"] = []
	if typeof(d.get("talents_equipped")) != TYPE_ARRAY:
		d["talents_equipped"] = []
	if not d.has("talent_seq"):
		d["talent_seq"] = 1
	if typeof(d.get("talent_roll_keys")) != TYPE_ARRAY and typeof(d.get("talent_roll_keys")) != TYPE_DICTIONARY:
		d["talent_roll_keys"] = []
	if not d.has("reroll_count"):
		d["reroll_count"] = 0
	if typeof(d.get("artifacts_owned")) != TYPE_DICTIONARY:
		d["artifacts_owned"] = {}
	if typeof(d.get("artifacts_equipped")) != TYPE_ARRAY:
		d["artifacts_equipped"] = []
	if typeof(d.get("shop_levels")) != TYPE_DICTIONARY:
		d["shop_levels"] = {}
	if typeof(d.get("automation_toggles")) != TYPE_DICTIONARY:
		d["automation_toggles"] = {}
	if not d.has("auto_buy_mode"):
		d["auto_buy_mode"] = "roi"
	if not d.has("auto_rebirth_min_rank"):
		d["auto_rebirth_min_rank"] = 15
	if not d.has("auto_rebirth_min_karma"):
		d["auto_rebirth_min_karma"] = 1
	if typeof(d.get("reveal_seen")) != TYPE_ARRAY and typeof(d.get("reveal_seen")) != TYPE_DICTIONARY:
		d["reveal_seen"] = []
	if typeof(d.get("meta")) != TYPE_DICTIONARY:
		d["meta"] = {}
	d["save_version"] = 3
	return d


static func _as_save_num(v) -> String:
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return BigNum.from_float(float(v)).to_save_string()
	if v == null:
		return "0"
	return str(v)


static func save_run(run: RunState, dir_path: String = "user://") -> bool:
	run.timestamp_unix = int(Time.get_unix_time_from_system())
	var payload := run.to_save_dict(CURRENT_VERSION)
	var text := JSON.stringify(payload, "\t")
	if text == "":
		push_error("Save stringify failed")
		return false
	var ok := _atomic_write(dir_path, LATEST_NAME, text)
	if ok:
		_atomic_write(dir_path, "save_v%d.json" % CURRENT_VERSION, text)
	return ok


static func load_run(dir_path: String = "user://") -> RunState:
	var result := load_document(dir_path)
	if not bool(result.get("ok", false)):
		return null
	return RunState.from_save_dict(result["data"])


static func load_document(dir_path: String = "user://") -> Dictionary:
	var path := _join(dir_path, LATEST_NAME)
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "missing"}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Corrupt save; moving to .bak")
		_rename_to_bak(dir_path, LATEST_NAME)
		return {"ok": false, "reason": "corrupt"}
	var migrated := migrate(parsed)
	return {"ok": true, "data": migrated, "from_version": int(parsed.get("save_version", 0))}


static func maybe_autosave(run: RunState, delta: float, dir_path: String = "user://") -> void:
	_autosave_acc += delta
	if _autosave_acc < AUTOSAVE_SEC:
		return
	_autosave_acc = 0.0
	save_run(run, dir_path)


static func reset_autosave_clock() -> void:
	_autosave_acc = 0.0


static func _atomic_write(dir_path: String, filename: String, text: String) -> bool:
	_ensure_dir(dir_path)
	var tmp_name := filename + ".tmp"
	var tmp_path := _join(dir_path, tmp_name)
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	file.flush()
	file.close()
	var base := _join(dir_path, "")
	var dir := DirAccess.open(base)
	if dir == null:
		push_error("Cannot open save dir %s" % base)
		return false
	var old_name := filename + ".old"
	if dir.file_exists(filename):
		dir.remove(old_name)
		var bak_err := dir.rename(filename, old_name)
		if bak_err != OK:
			push_error("Cannot rotate save (%s)" % error_string(bak_err))
			return false
	var err := dir.rename(tmp_name, filename)
	if err != OK:
		push_error("Atomic rename failed (%s)" % error_string(err))
		if dir.file_exists(old_name) and not dir.file_exists(filename):
			dir.rename(old_name, filename)
		return false
	if dir.file_exists(old_name):
		dir.remove(old_name)
	return true


static func _rename_to_bak(dir_path: String, filename: String) -> void:
	var dir := DirAccess.open(_join(dir_path, ""))
	if dir == null:
		return
	var bak := filename + ".bak"
	dir.remove(bak)
	dir.rename(filename, bak)


static func _ensure_dir(dir_path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(_join(dir_path, ""))
	DirAccess.make_dir_recursive_absolute(abs_path)


static func _join(dir_path: String, filename: String) -> String:
	var base := dir_path
	if not base.ends_with("/"):
		base += "/"
	return base + filename
