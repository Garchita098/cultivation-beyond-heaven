extends Control
## Path picker and the four nodes of the chosen path. One button per choice.

var _picking: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_sheet() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child in get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var theme := CBHTheme.shared()
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 16)
	frame.add_theme_constant_override("margin_right", 16)
	frame.add_theme_constant_override("margin_top", 36)
	frame.add_theme_constant_override("margin_bottom", 24)
	add_child(frame)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_BG, CBHTheme.COL_GOLD, 18, 1))
	frame.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Путь"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(title, theme.font_serif, 32, CBHTheme.COL_GOLD)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var run := GameState.run
	for path in Content.data.paths["paths"]:
		list.add_child(_path_button(path, run, theme))
	if run != null and run.path_joined and not _picking:
		var currency := Label.new()
		currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cname := str(Content.data.paths_by_id[run.path_id].get("currency_name_ru", ""))
		currency.text = "%s · %s" % [cname, _trim(run.path_currency)]
		currency.tooltip_text = "Валюта пути. Ею покупаются узлы ниже."
		CBHTheme.style_label(currency, theme.font_bold, 18, CBHTheme.path_color(run.path_id))
		list.add_child(currency)
		for node in Content.data.paths_by_id[run.path_id].get("nodes", []):
			list.add_child(_node_button(node, run, theme))
		var switch_btn := Button.new()
		switch_btn.custom_minimum_size = Vector2(0, 56)
		switch_btn.focus_mode = Control.FOCUS_NONE
		switch_btn.text = "Сменить путь"
		switch_btn.pressed.connect(func():
			_picking = true
			show_sheet()
		)
		list.add_child(switch_btn)
	var back := Button.new()
	back.custom_minimum_size = Vector2(0, 56)
	back.focus_mode = Control.FOCUS_NONE
	back.text = "Назад"
	back.pressed.connect(func():
		_picking = false
		visible = false
	)
	box.add_child(back)
	visible = true


func _path_button(path: Dictionary, run: RunState, theme: CBHTheme) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 108)
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var id := str(path["id"])
	var tint := CBHTheme.path_color(id)
	var chosen := run != null and run.path_joined and run.path_id == id and not _picking
	var style := CBHTheme.flat(tint if chosen else CBHTheme.COL_PANEL, tint, 16, 2)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	button.add_child(row)
	var emblem := TextureRect.new()
	emblem.custom_minimum_size = Vector2(40, 40)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.texture = ArtBank.path_icon(id)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(emblem)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var name := Label.new()
	name.text = str(path["name_ru"])
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CBHTheme.style_label(name, theme.font_bold, 18, CBHTheme.COL_BG if chosen else CBHTheme.COL_TEXT)
	col.add_child(name)
	var desc := Label.new()
	desc.text = str(path.get("desc_ru", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CBHTheme.style_label(desc, theme.font_sans, 14, Color("3A3220") if chosen else CBHTheme.COL_MUTED)
	col.add_child(desc)
	if not chosen:
		button.pressed.connect(func():
			if GameState.try_choose_path(id):
				_picking = false
				show_sheet()
		)
	return button


func _node_button(node: Dictionary, run: RunState, theme: CBHTheme) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 56)
	button.focus_mode = Control.FOCUS_NONE
	var id := str(node["id"])
	var level := int(run.path_nodes.get(id, 0))
	var mx := int(node["max_level"])
	var pips := ""
	for i in mx:
		pips += "●" if i < level else "○"
	var hint := _effect_hint(str(node.get("effect", "")))
	button.text = "%s   %s" % [str(node["name_ru"]), pips]
	button.tooltip_text = hint
	button.disabled = level >= mx
	if level < mx:
		var cost := Stage3Rules.node_cost(node, level)
		button.text = "%s   %s\n%s · цена %s" % [str(node["name_ru"]), pips, hint, _trim(cost)]
		button.disabled = run.path_currency + 1e-9 < cost
		button.pressed.connect(func():
			if GameState.try_buy_node(id):
				show_sheet()
		)
	if level >= mx:
		button.text = "%s   %s\n%s" % [str(node["name_ru"]), pips, hint]
	button.custom_minimum_size = Vector2(0, 72)
	button.add_theme_font_override("font", theme.font_sans)
	return button


func _effect_hint(effect: String) -> String:
	match effect:
		"charge_sec":
			return "Короче подготовка"
		"burst_sec":
			return "Дольше всплеск"
		"burst_add":
			return "Сильнее всплеск"
		"burst_flat":
			return "Постоянная кромка"
		"idle_add":
			return "Сила без жертвы"
		"perm_add":
			return "Постоянный рост"
		"fed_sec":
			return "Дольше сытость"
		"rank_sacrifice":
			return "Можно отдать ранг"
		"compound_add":
			return "Быстрее рост в час"
		"dream_mult":
			return "Сильнее сон"
		"active_add":
			return "Сильнее в игре"
		"start_hours":
			return "Больше стартовых часов"
		"per_type_add":
			return "Сила за каждый тип"
		"artifact_bonus":
			return "Сила реликвий"
		"convert_add":
			return "Больше выход переплава"
		"types_persist":
			return "Типы не сбрасываются"
		"charge_add":
			return "Быстрее копится песок"
		"speed_add":
			return "Сильнее ускорение"
		"bank_add":
			return "Больше банк времени"
		"skip_add":
			return "Дальше перемотка"
		_:
			return "Узел пути"


func _trim(value: float) -> String:
	if absf(value - round(value)) < 0.05:
		return str(int(round(value)))
	return "%.1f" % value
