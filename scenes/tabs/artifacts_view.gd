extends Control
## Relic collection. Drops are automatic. Equip and upgrade spend nothing but Qi on the upgrade.

const RARITY_COLOR := {
	"common": "9E9E9E",
	"uncommon": "4CAF50",
	"rare": "2196F3",
	"epic": "9C27B0",
	"legendary": "FF9800",
	"mythic": "F44336",
}

var _list: VBoxContainer
var _sig: String = ""
var _selected: String = ""


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	margin.add_child(_list)
	EventBus.state_changed.connect(func(): _sig = "")


func _process(_delta: float) -> void:
	if not visible or GameState.run == null:
		return
	var scroll := get_child(0) as ScrollContainer
	if scroll and scroll.get_child_count() > 0:
		(scroll.get_child(0) as Control).custom_minimum_size.x = maxf(0.0, scroll.size.x)
	var sig := _signature()
	if sig != _sig:
		_sig = sig
		_rebuild()


func _signature() -> String:
	var run := GameState.run
	if not run.unlocked.has("artifacts_basic"):
		return "locked"
	return "%s|%s|%s" % [str(run.artifacts_owned), ",".join(run.artifacts_equipped), _selected]


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	var theme := CBHTheme.shared()
	var title := Label.new()
	title.text = "Реликвии"
	CBHTheme.style_label(title, theme.font_serif, 26, CBHTheme.COL_TEXT)
	_list.add_child(title)
	if not GameState.run.unlocked.has("artifacts_basic"):
		_list.add_child(_locked("Основание · Позднее"))
		return
	if _selected == "" and not GameState.run.artifacts_equipped.is_empty():
		_selected = str(GameState.run.artifacts_equipped[0])
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	_list.add_child(slots)
	for i in int(Content.data.artifacts["max_equipped"]):
		var aid := str(GameState.run.artifacts_equipped[i]) if i < GameState.run.artifacts_equipped.size() else ""
		slots.add_child(_slot(aid, theme))
	if _selected != "" and GameState.run.artifacts_owned.has(_selected):
		_list.add_child(_upgrade(theme))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_list.add_child(grid)
	for aid in Content.data.artifacts.get("drop_order", []):
		grid.add_child(_cell(str(aid), theme))


func _slot(aid: String, theme: CBHTheme) -> Button:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 120)
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var art := _art(aid)
	var color := _color(str(art.get("rarity", ""))) if not art.is_empty() else CBHTheme.COL_LINE
	var style := CBHTheme.flat(CBHTheme.COL_BG, color, 16, 2 if aid == _selected else 1)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_font_override("font", theme.font_bold)
	button.add_theme_font_size_override("font_size", 14)
	if art.is_empty():
		button.text = "—"
		button.disabled = true
		button.add_theme_color_override("font_color", CBHTheme.COL_MUTED)
	else:
		button.text = str(art.get("name_ru", aid)).split(" ")[0]
		button.add_theme_color_override("font_color", color)
		button.pressed.connect(func():
			_selected = aid
			_sig = ""
		)
	return button


func _cell(aid: String, theme: CBHTheme) -> Button:
	var art := _art(aid)
	var owned := GameState.run.artifacts_owned.has(aid)
	var button := Button.new()
	button.custom_minimum_size = Vector2(140, 88)
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not owned:
		button.text = "·"
		button.disabled = true
	else:
		var lvl := int(GameState.run.artifacts_owned[aid])
		var on := GameState.run.artifacts_equipped.has(aid)
		button.text = "%s\n%s%d" % [str(art.get("name_ru", "")).split(" ")[0], "● " if on else "", lvl]
		button.pressed.connect(func():
			_selected = aid
			GameState.toggle_artifact(aid)
			_sig = ""
		)
	var color := _color(str(art.get("rarity", ""))) if owned else CBHTheme.COL_LINE
	button.add_theme_color_override("font_color", color if owned else CBHTheme.COL_MUTED)
	button.add_theme_font_override("font", theme.font_sans)
	button.add_theme_font_size_override("font_size", 14)
	return button


func _upgrade(theme: CBHTheme) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 64)
	button.focus_mode = Control.FOCUS_NONE
	var level := int(GameState.run.artifacts_owned.get(_selected, 0))
	var mx := int(Content.data.artifacts["upgrade"]["max_level"])
	if level >= mx:
		button.text = "Максимум"
		button.disabled = true
	else:
		var cost := EconomyCore.artifact_upgrade_cost(Content.data, level)
		button.text = "Усилить   %s Ци" % Economy.format_qi(BigNum.from_float(cost))
		button.disabled = GameState.run.qi.to_float() < cost
		var aid := _selected
		button.pressed.connect(func(): GameState.try_upgrade_artifact(aid))
	button.add_theme_font_override("font", theme.font_bold)
	return button


func _locked(need: String) -> PanelContainer:
	var theme := CBHTheme.shared()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 280)
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_GOLD, 24, 1))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var mark := Label.new()
	mark.text = "◇"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(mark, theme.font_serif, 64, CBHTheme.COL_GOLD)
	box.add_child(mark)
	var label := Label.new()
	label.text = need
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(label, theme.font_sans, 18, CBHTheme.COL_MUTED)
	box.add_child(label)
	return panel


func _art(aid: String) -> Dictionary:
	if aid == "":
		return {}
	for a in Content.data.artifacts["artifacts"]:
		if str(a["id"]) == aid:
			return a
	return {}


func _color(rarity: String) -> Color:
	return Color.html(str(RARITY_COLOR.get(rarity, "8B97B0")))
