extends Control
## Rebirth confirmation. One screen: what you gain, what leaves, what stays.


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 24)
	frame.add_theme_constant_override("margin_right", 24)
	frame.add_theme_constant_override("margin_top", 180)
	frame.add_theme_constant_override("margin_bottom", 180)
	add_child(frame)
	var theme := CBHTheme.shared()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_GOLD, 24, 2))
	frame.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Перерождение"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(title, theme.font_serif, 32, CBHTheme.COL_GOLD)
	box.add_child(title)

	_gain = Label.new()
	_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_gain, theme.font_bold, 48, CBHTheme.COL_QI)
	box.add_child(_gain)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(columns)
	columns.add_child(_column("Уйдёт", ["Ци", "Тренировки", "Ранг"], CBHTheme.COL_DANGER, theme))
	columns.add_child(_column("Останется", ["Карма", "Корни", "Реликвии"], CBHTheme.COL_JADE, theme))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(_button("Назад", false, _hide_offer))
	row.add_child(_button("Переродиться", true, _confirm))


var _gain: Label


func show_offer() -> void:
	if GameState.run == null or not Content.valid:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	for child in get_children():
		if child is Control:
			(child as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sim := GameState.run.to_sim()
	var gain := 0
	if EconomyCore.can_rebirth(Content.data, sim):
		gain = EconomyCore.karma_gain(Content.data, sim)
	_gain.text = "+%d" % gain
	visible = true


func _hide_offer() -> void:
	visible = false


func _confirm() -> void:
	visible = false
	GameState.try_rebirth()


func _column(title: String, lines: Array, color: Color, theme: CBHTheme) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_BG, color, 16, 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(head, theme.font_bold, 16, color)
	box.add_child(head)
	for line in lines:
		var chip := Label.new()
		chip.text = str(line)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		CBHTheme.style_label(chip, theme.font_sans, 18, CBHTheme.COL_TEXT)
		box.add_child(chip)
	return panel


func _button(text: String, gold: bool, cb: Callable) -> Button:
	var theme := CBHTheme.shared()
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 72)
	button.focus_mode = Control.FOCUS_NONE
	var bg := CBHTheme.COL_GOLD if gold else CBHTheme.COL_BG_RAISED
	var fg := CBHTheme.COL_BG if gold else CBHTheme.COL_TEXT
	var style := CBHTheme.flat(bg, CBHTheme.COL_GOLD if gold else CBHTheme.COL_LINE, 16, 1)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_font_override("font", theme.font_bold)
	button.add_theme_color_override("font_color", fg)
	button.pressed.connect(cb)
	return button
