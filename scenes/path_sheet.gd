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
	dim.color = Color(0.02, 0.03, 0.06, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var theme := CBHTheme.shared()
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 20)
	frame.add_theme_constant_override("margin_right", 20)
	frame.add_theme_constant_override("margin_top", 48)
	frame.add_theme_constant_override("margin_bottom", 36)
	add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	frame.add_child(box)
	var title := Label.new()
	title.text = "Путь"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(title, theme.font_serif, 32, CBHTheme.COL_GOLD)
	box.add_child(title)
	var run := GameState.run
	for path in Content.data.paths["paths"]:
		box.add_child(_path_button(path, run, theme))
	if run != null and run.path_joined and not _picking:
		var currency := Label.new()
		currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cname := str(Content.data.paths_by_id[run.path_id].get("currency_name_ru", ""))
		currency.text = "%s  %s" % [cname, _trim(run.path_currency)]
		CBHTheme.style_label(currency, theme.font_bold, 18, CBHTheme.path_color(run.path_id))
		box.add_child(currency)
		for node in Content.data.paths_by_id[run.path_id].get("nodes", []):
			box.add_child(_node_button(node, run, theme))
		var switch_btn := Button.new()
		switch_btn.custom_minimum_size = Vector2(0, 56)
		switch_btn.focus_mode = Control.FOCUS_NONE
		switch_btn.text = "Сменить путь"
		switch_btn.pressed.connect(func():
			_picking = true
			show_sheet()
		)
		box.add_child(switch_btn)
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
	button.custom_minimum_size = Vector2(0, 64)
	button.focus_mode = Control.FOCUS_NONE
	var id := str(path["id"])
	var tint := CBHTheme.path_color(id)
	var chosen := run != null and run.path_joined and run.path_id == id
	button.text = str(path["name_ru"])
	var emblem := ArtBank.path_icon(id)
	if emblem != null:
		button.icon = emblem
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 36)
	var style := CBHTheme.flat(tint if chosen else CBHTheme.COL_PANEL, tint, 16, 2)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_font_override("font", theme.font_bold)
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
	button.text = "%s   %s" % [str(node["name_ru"]), pips]
	button.disabled = level >= mx
	if level < mx:
		var cost := Stage3Rules.node_cost(node, level)
		button.text += "   %s" % _trim(cost)
		button.disabled = run.path_currency + 1e-9 < cost
		button.pressed.connect(func():
			if GameState.try_buy_node(id):
				show_sheet()
		)
	button.add_theme_font_override("font", theme.font_sans)
	return button


func _trim(value: float) -> String:
	if absf(value - round(value)) < 0.05:
		return str(int(round(value)))
	return "%.1f" % value
