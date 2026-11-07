class_name ArtBank
extends RefCounted
## Resolves stage-4 art under res://assets/art/ and falls back to the stage-1 placeholders.
## The generated pack (cbh_art.tar.gz) was not in this workspace, so the fallbacks are what ship
## until those files are added at the paths below.


static func texture(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


static func icon(preferred: String, fallback: String) -> Texture2D:
	var tex := texture(preferred)
	if tex != null:
		return tex
	return texture(fallback)


static func tab_icon(tab_id: String) -> Texture2D:
	return icon(
		"res://assets/art/icons/tab_%s_64.png" % tab_id,
		"res://assets/icons/tabs/%s.png" % tab_id
	)


static func upgrade_icon(uid: String) -> Texture2D:
	var mapped := uid
	if uid == "foundation_mantra":
		mapped = "foundation_pill"
	elif uid == "heaven_breath":
		mapped = "breath_meditation"
	elif uid == "chaos_weaving":
		mapped = "void_attunement"
	var art := icon(
		"res://assets/art/icons/upg_%s_64.png" % mapped,
		"res://assets/icons/upgrades/%s.png" % uid
	)
	if art != null:
		return art
	return texture("res://assets/icons/upgrades/%s.png" % mapped)


static func qi_icon() -> Texture2D:
	return icon("res://assets/art/icons/res_qi_64.png", "res://assets/icons/ui/icon_qi.png")


static func world_background(world_id: String) -> Texture2D:
	var names: Dictionary = {
		"mortal_world": "bg_mortal",
		"spirit_world": "bg_spirit",
		"heavenly_world": "bg_heavenly",
		"void_dimension": "bg_void",
		"chaos_origin": "bg_chaos",
	}
	var key := str(names.get(world_id, "bg_mortal"))
	var art := texture("res://assets/art/bg/%s.webp" % key)
	if art != null:
		return art
	return texture("res://assets/backgrounds/bg_mortal_night.png")


static func world_tint(world_id: String) -> Color:
	match world_id:
		"spirit_world":
			return Color("8FB8A4")
		"heavenly_world":
			return Color("E4C98A")
		"void_dimension":
			return Color("B7A6E8")
		"chaos_origin":
			return Color("E0A0A0")
		_:
			return Color.WHITE


static func hero_path(run: RunState) -> String:
	if run != null and run.path_joined and run.path_id != "":
		return "res://assets/art/hero/hero_path_%s.webp" % run.path_id
	var major := ""
	if run != null and Content.valid:
		major = str(Content.data.rank_at(run.rank_index).get("major", ""))
	var majors: Dictionary = {
		"mortal": "hero_rank_mortal",
		"qi_practitioner": "hero_rank_qi",
		"foundation": "hero_rank_foundation",
		"core_formation": "hero_rank_golden_core",
		"nascent_soul": "hero_rank_nascent_soul",
		"soul_transformation": "hero_rank_nascent_soul",
		"void_refinement": "hero_rank_immortal",
		"body_integration": "hero_rank_immortal",
		"mahayana": "hero_rank_immortal",
		"immortal": "hero_rank_immortal",
		"heavenly": "hero_rank_dimension_lord",
		"beyond": "hero_rank_dimension_lord",
	}
	var file := str(majors.get(major, "hero_base"))
	return "res://assets/art/hero/%s.webp" % file


static func hero(run: RunState) -> Texture2D:
	return texture(hero_path(run))
