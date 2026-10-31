extends Control
## Spiritual roots. Three slots, a collection, one upgrade. No tap-to-earn.

const ELEMENTS := {
	"fire": "Огонь",
	"water": "Вода",
	"wood": "Дерево",
	"metal": "Металл",
	"earth": "Земля",
	"thunder": "Гром",
	"void": "Пустота",
}

var _list: VBoxContainer
var _slots: HBoxContainer
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
	if not run.unlocked.has("spiritual_roots"):
		return "locked"
	var parts: Array = [str(run.talents_owned.size()), str(run.rebirth_count), _selected]
	for t in run.talents_owned:
		parts.append("%s:%s:%s" % [str(t["uid"]), str(t["level"]), str(t["rarity"])])
	parts.append(",".join(run.talents_equipped))
	return "|".join(parts)


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	var theme := CBHTheme.shared()
	var title := Label.new()
	title.text = "Духовные корни"
	CBHTheme.style_label(title, theme.font_serif, 26, CBHTheme.COL_TEXT)
	_list.add_child(title)
	if GameState.run == null or not GameState.run.unlocked.has("spiritual_roots"):
		_list.add_child(_locked_card("Практик Ци", CBHTheme.COL_DAO))
		return
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 8)
	_list.add_child(_slots)
	var run := GameState.run
	for i in int(Content.data.talents["max_equipped"]):
		var uid := str(run.talents_equipped[i]) if i < run.talents_equipped.size() else ""
		_slots.add_child(_slot(uid, theme))
	if _synergy_live():
		var chip := Label.new()
		chip.text = "Синергия"
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		CBHTheme.style_label(chip, theme.font_bold, 16, CBHTheme.COL_JADE)
		_list.add_child(chip)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_list.add_child(actions)
	actions.add_child(_upgrade_button(theme))
	if run.unlocked.has("talent_reroll") or run.rebirth_count >= 3:
		actions.add_child(_reroll_button(theme))
	for t in run.talents_owned:
		_list.add_child(_owned_row(t, theme))
	if run.talents_owned.is_empty():
		var empty := Label.new()
		empty.text = "Корень придёт с рангом"
		CBHTheme.style_label(empty, theme.font_sans, 16, CBHTheme.COL_MUTED)
		_list.add_child(empty)


func _slot(uid: String, theme: CBHTheme) -> Button:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 148)
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var talent := _talent(uid)
	var color := _rarity_color(str(talent.get("rarity", ""))) if not talent.is_empty() else CBHTheme.COL_LINE
	var style := CBHTheme.flat(CBHTheme.COL_BG, color, 16, 2 if uid == _selected else 1)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_font_override("font", theme.font_bold)
	if talent.is_empty():
		button.text = "Пусто"
		button.add_theme_color_override("font_color", CBHTheme.COL_MUTED)
		button.disabled = true
	else:
		var root := _root(str(talent["root_id"]))
		button.text = "%s\n+%d%%" % [str(ELEMENTS.get(str(root.get("element", "")), "")), int(round(_value(talent) * 100.0))]
		button.add_theme_color_override("font_color", color)
		button.pressed.connect(func():
			_selected = uid
			_sig = ""
		)
	return button


func _owned_row(talent: Dictionary, theme: CBHTheme) -> Button:
	var uid := str(talent["uid"])
	var root := _root(str(talent["root_id"]))
	var color := _rarity_color(str(talent["rarity"]))
	var on := GameState.run.talents_equipped.has(uid)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 64)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "%s   %s   +%d%%" % [
		"●" if on else "○",
		str(ELEMENTS.get(str(root.get("element", "")), root.get("name_ru", ""))),
		int(round(_value(talent) * 100.0)),
	]
	button.add_theme_color_override("font_color", color if on else CBHTheme.COL_TEXT)
	button.add_theme_font_override("font", theme.font_sans)
	var auto := bool(GameState.run.automation_toggles.get("auto_equip_talents", false)) and GameState.run.rebirth_count >= 5
	button.disabled = auto
	button.pressed.connect(func():
		_selected = uid
		if not auto:
			GameState.toggle_talent(uid)
		_sig = ""
	)
	return button


func _upgrade_button(theme: CBHTheme) -> Button:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 64)
	button.focus_mode = Control.FOCUS_NONE
	var uid := _selected if _selected != "" else (str(GameState.run.talents_equipped[0]) if not GameState.run.talents_equipped.is_empty() else "")
	var talent := _talent(uid)
	if talent.is_empty():
		button.text = "Выберите корень"
		button.disabled = true
	else:
		var cost := EconomyCore.talent_upgrade_cost(Content.data, int(talent["level"]))
		button.text = "Ур. %d   ·   %d кармы" % [int(talent["level"]), cost]
		button.disabled = GameState.run.karma_shards.to_float() < float(cost)
		button.pressed.connect(func(): GameState.try_upgrade_talent(uid))
	button.add_theme_font_override("font", theme.font_bold)
	return button


func _reroll_button(theme: CBHTheme) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 64)
	button.focus_mode = Control.FOCUS_NONE
	var cost := int(Content.data.rebirth.get("talent_reroll_cost", 4))
	button.text = "Сменить\n%d" % cost
	button.add_theme_font_override("font", theme.font_bold)
	var uid := _weakest_uid()
	button.disabled = uid == "" or GameState.run.karma_shards.to_float() < float(cost)
	button.pressed.connect(func():
		if uid != "":
			GameState.try_reroll_talent(uid)
	)
	return button


func _locked_card(need: String, color: Color) -> PanelContainer:
	var theme := CBHTheme.shared()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 280)
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, color, 24, 1))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var mark := Label.new()
	mark.text = "○"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(mark, theme.font_serif, 64, color)
	box.add_child(mark)
	var label := Label.new()
	label.text = need
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(label, theme.font_sans, 18, CBHTheme.COL_MUTED)
	box.add_child(label)
	return panel


func _synergy_live() -> bool:
	var elements: Array = []
	for uid in GameState.run.talents_equipped:
		var talent := _talent(str(uid))
		if talent.is_empty():
			continue
		elements.append(str(_root(str(talent["root_id"])).get("element", "")))
	for pair in Content.data.talents.get("element_synergies", []):
		if elements.has(str(pair["a"])) and elements.has(str(pair["b"])):
			return true
	return false


func _value(talent: Dictionary) -> float:
	return EconomyCore._talent_value(Content.data, talent)


func _talent(uid: String) -> Dictionary:
	if uid == "":
		return {}
	for t in GameState.run.talents_owned:
		if str(t["uid"]) == uid:
			return t
	return {}


func _root(root_id: String) -> Dictionary:
	for r in Content.data.talents["roots"]:
		if str(r["id"]) == root_id:
			return r
	return {}


func _rarity_color(id: String) -> Color:
	for r in Content.data.talents["rarities"]:
		if str(r["id"]) == id:
			return Color.html(str(r["color"]))
	return CBHTheme.COL_MUTED


func _weakest_uid() -> String:
	var worst := ""
	var score := 1e9
	for t in GameState.run.talents_owned:
		var p := EconomyCore.talent_power(Content.data, GameState.run.to_sim(), t)
		if worst == "" or p < score:
			worst = str(t["uid"])
			score = p
	return worst
