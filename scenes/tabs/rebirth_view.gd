extends Control
## Karma, the shop, rebirth tiers, and the locked path / ascension hooks.

var _list: VBoxContainer
var _sig: String = ""


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
	EventBus.rebirth_done.connect(func(_c): _sig = "")


func _process(_delta: float) -> void:
	if not visible or GameState.run == null:
		return
	var scroll := get_child(0) as ScrollContainer
	if scroll and scroll.get_child_count() > 0:
		(scroll.get_child(0) as Control).custom_minimum_size.x = maxf(0.0, scroll.size.x)
	var run := GameState.run
	var sig := "%d|%s|%s|%d" % [run.rebirth_count, run.karma_shards.to_save_string(), str(run.shop_levels), run.rank_index]
	if sig != _sig:
		_sig = sig
		_rebuild()


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	var theme := CBHTheme.shared()
	var run := GameState.run
	if not run.unlocked.has("rebirth_unlock") and run.rebirth_count < 1:
		_list.add_child(_seal("Пик Золотого Ядра", CBHTheme.COL_GOLD, theme))
		return
	var karma := Label.new()
	karma.text = Economy.format_qi(run.karma_shards)
	karma.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(karma, theme.font_bold, 48, CBHTheme.COL_QI)
	_list.add_child(karma)
	var caption := Label.new()
	caption.text = "Осколки кармы"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(caption, theme.font_sans, 14, CBHTheme.COL_MUTED)
	_list.add_child(caption)
	_list.add_child(_tiers(theme))
	_list.add_child(_rebirth_button(theme))
	for item in Content.data.rebirth["shop"]:
		_list.add_child(_shop_row(item, theme))
	if run.rebirth_count >= 5 or run.unlocked.has("path_selection"):
		_list.add_child(_paths(theme))
	_list.add_child(_ascension(theme))


func _tiers(theme: CBHTheme) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for t in Content.data.rebirth["tiers"]:
		var tier: Dictionary = t
		var need := int(tier["min_rebirths"])
		var on := GameState.run.rebirth_count >= need
		var label := Label.new()
		label.text = str(need)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(64, 36)
		CBHTheme.style_label(label, theme.font_bold, 18, CBHTheme.COL_GOLD if on else CBHTheme.COL_MUTED)
		row.add_child(label)
	return row


func _rebirth_button(theme: CBHTheme) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 76)
	button.focus_mode = Control.FOCUS_NONE
	var sim := GameState.run.to_sim()
	if EconomyCore.can_rebirth(Content.data, sim):
		var gain := EconomyCore.karma_gain(Content.data, sim)
		button.text = "Переродиться   +%d" % gain
		button.disabled = false
		button.pressed.connect(func(): EventBus.open_rebirth_confirm.emit())
		var gold := CBHTheme.flat(CBHTheme.COL_GOLD, CBHTheme.COL_GOLD, 16, 0)
		button.add_theme_stylebox_override("normal", gold)
		button.add_theme_stylebox_override("hover", gold)
		button.add_theme_stylebox_override("pressed", gold)
		button.add_theme_color_override("font_color", CBHTheme.COL_BG)
	else:
		button.text = "Нужен пик Ядра"
		button.disabled = true
	button.add_theme_font_override("font", theme.font_bold)
	button.add_theme_font_size_override("font_size", 20)
	return button


func _shop_row(item: Dictionary, theme: CBHTheme) -> PanelContainer:
	var id := str(item["id"])
	var level := int(GameState.run.shop_levels.get(id, 0))
	var panel := PanelContainer.new()
	var advanced := id == "karma_keep_upgrade" and GameState.run.rebirth_count < 10 and not GameState.run.unlocked.has("karma_shop_advanced")
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_LINE, 16, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name := Label.new()
	name.text = str(item.get("name_ru", id))
	CBHTheme.style_label(name, theme.font_bold, 16, CBHTheme.COL_TEXT if not advanced else CBHTheme.COL_MUTED)
	text.add_child(name)
	var meta := Label.new()
	meta.text = "Ур. %d" % level
	CBHTheme.style_label(meta, theme.font_sans, 14, CBHTheme.COL_QI)
	text.add_child(meta)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(120, 56)
	buy.focus_mode = Control.FOCUS_NONE
	if advanced:
		buy.text = "10"
		buy.disabled = true
	else:
		var mx := int(item.get("max", 0))
		if mx > 0 and level >= mx:
			buy.text = "Макс."
			buy.disabled = true
		else:
			var cost := EconomyCore.shop_cost(Content.data, id, level)
			buy.text = str(cost)
			buy.disabled = GameState.run.karma_shards.to_float() < float(cost)
			buy.pressed.connect(func(): GameState.try_shop(id))
	row.add_child(buy)
	return panel


func _paths(theme: CBHTheme) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_DAO, 16, 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := Label.new()
	head.text = "Пять путей"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(head, theme.font_serif, 18, CBHTheme.COL_DAO)
	box.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for p in Content.data.paths["paths"]:
		var chip := Label.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chip.text = str(p["name_ru"]).replace("Путь ", "")
		CBHTheme.style_label(chip, theme.font_sans, 12, CBHTheme.COL_MUTED)
		row.add_child(chip)
	var soon := Label.new()
	soon.text = "Скоро"
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(soon, theme.font_sans, 14, CBHTheme.COL_MUTED)
	box.add_child(soon)
	return panel


func _ascension(theme: CBHTheme) -> PanelContainer:
	var open := GameState.run.rebirth_count >= 25 or GameState.run.unlocked.has("ascension_gate")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 88)
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_JADE if open else CBHTheme.COL_LINE, 16, 1))
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "Врата Вознесения" if open else "Врата   ·   25"
	CBHTheme.style_label(label, theme.font_serif, 20, CBHTheme.COL_JADE if open else CBHTheme.COL_MUTED)
	panel.add_child(label)
	return panel


func _seal(need: String, color: Color, theme: CBHTheme) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 280)
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, color, 24, 1))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var mark := Label.new()
	mark.text = "♻"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(mark, theme.font_serif, 64, color)
	box.add_child(mark)
	var label := Label.new()
	label.text = need
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(label, theme.font_sans, 18, CBHTheme.COL_MUTED)
	box.add_child(label)
	return panel
