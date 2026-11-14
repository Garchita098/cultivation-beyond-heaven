class_name Prefs
extends RefCounted
## Notation, sound, and reduced motion. Stored on the save.


static var notation: String = "letters"
static var sound_on: bool = true
static var reduced_effects: bool = false


static func apply_run(run: RunState) -> void:
	if run == null:
		return
	notation = run.notation if run.notation == "scientific" else "letters"
	sound_on = run.sound_on
	reduced_effects = run.reduced_effects


static func write_run(run: RunState) -> void:
	if run == null:
		return
	run.notation = notation
	run.sound_on = sound_on
	run.reduced_effects = reduced_effects


static func sci_from() -> int:
	if notation == "scientific":
		return 3
	var content = load("res://autoload/content.gd")
	if content != null and content.data != null:
		return int(content.data.balance.get("bignum", {}).get("scientific_from_exponent", 33))
	return 33
