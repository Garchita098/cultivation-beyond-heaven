extends Node
## Loads res://data/*.json. schema_version must be 1 or loading fails loudly.

const FILES := {
	"balance": "res://data/balance.json",
	"ranks": "res://data/ranks.json",
	"upgrades": "res://data/upgrades.json",
	"rebirth": "res://data/rebirth.json",
	"worlds": "res://data/worlds.json",
	"talents": "res://data/talents.json",
	"artifacts": "res://data/artifacts.json",
	"paths": "res://data/paths.json",
	"automation": "res://data/automation.json",
	"research": "res://data/research.json",
	"achievements": "res://data/achievements.json",
}

static var data: EconData
static var valid: bool = false
static var error: String = ""


func _ready() -> void:
	load_all()


static func load_all() -> bool:
	if valid and data != null:
		return true
	var parsed := {}
	for key in FILES.keys():
		var doc := _read_json(FILES[key])
		if doc.is_empty():
			valid = false
			error = "Cannot read %s" % FILES[key]
			push_error(error)
			return false
		if int(doc.get("schema_version", -1)) != 1:
			valid = false
			error = "%s schema_version %s is not 1" % [FILES[key], str(doc.get("schema_version"))]
			push_error(error)
			return false
		parsed[key] = doc
	var econ := EconData.new()
	econ.balance = parsed["balance"]
	econ.rebirth = parsed["rebirth"]
	econ.talents = parsed["talents"]
	econ.artifacts = parsed["artifacts"]
	econ.paths = parsed["paths"]
	econ.automation = parsed["automation"]
	econ.research = parsed["research"]
	econ.achievements = parsed["achievements"]["achievements"]
	econ.worlds_doc = parsed["worlds"]
	for p in parsed["paths"]["paths"]:
		econ.paths_by_id[str(p["id"])] = p
	econ.ranks = parsed["ranks"]["ranks"]
	for r in econ.ranks:
		econ.ranks_by_id[str(r["id"])] = r
	for u in parsed["upgrades"]["upgrades"]:
		var id := str(u["id"])
		econ.upgrades[id] = u
		econ.upgrade_order.append(id)
		if not econ.ranks_by_id.has(str(u["unlock_rank"])):
			valid = false
			error = "Upgrade %s unlock_rank missing" % id
			push_error(error)
			return false
	for w in parsed["worlds"]["worlds"]:
		econ.worlds[str(w["id"])] = w
	if econ.ranks.is_empty() or econ.upgrade_order.is_empty():
		valid = false
		error = "Ranks or upgrades empty"
		push_error(error)
		return false
	data = econ
	valid = true
	error = ""
	return true


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing JSON %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON root is not an object: %s" % path)
		return {}
	return parsed


static func sci_from() -> int:
	if data == null:
		return 33
	return int(data.balance.get("bignum", {}).get("scientific_from_exponent", 33))
