extends Control
## Ascension confirmation. What leaves, what stays, which world opens.


var _gain: Label
var _world: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 24)
	frame.add_theme_constant_override("margin_right", 24)
	frame.add_theme_constant_override("margin_top", 160)
	frame.add_theme_constant_override("margin_bottom", 160)
	add_child(frame)
	var theme := CBHTheme.shared()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_JADE, 24, 2))
	frame.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Вознесение"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(title, theme.font_serif, 32, CBHTheme.COL_JADE)
	box.add_child(title)
	_gain = Label.new()
	_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_gain, theme.font_bold, 48, CBHTheme.COL_QI)
	box.add_child(_gain)
	_world = Label.new()
	_world.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_world, theme.font_serif, 22, CBHTheme.COL_GOLD)
	box.add_child(_world)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(columns)
	columns.add_child(_column("Уйдёт", ["Ци", "Ранг", "Карма", "Лавка"], CBHTheme.COL_DANGER, theme))
	columns.add_child(_column("Останется", ["Путь", "Корни", "Реликвии", "Дао"], CBHTheme.COL_JADE, theme))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(_button("Назад", false, func(): visible = false))
	row.add_child(_button("Войти", true, _confirm))


func show_offer() -> void:
	if GameState.run == null or not Content.valid:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sim := GameState.run.to_sim()
	var gain := 0
	var world_name := ""
	if Stage3Rules.can_ascend(Content.data, sim):
		gain = Stage3Rules.ascension_gain(Content.data, sim)
		var nxt := Stage3Rules.next_world_id(sim)
		world_name = str(Content.data.worlds.get(nxt, {}).get("name_ru", nxt))
	_gain.text = "+%d" % gain
	_world.text = world_name
	visible = true


func _confirm() -> void:
	visible = false
	GameState.try_ascend()


func _column(title: String, lines: Array, color: Color, theme: CBHTheme) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 0)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(head, theme.font_bold, 16, color)
	box.add_child(head)
	for line in lines:
		var label := Label.new()
		label.text = str(line)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		CBHTheme.style_label(label, theme.font_sans, 18, CBHTheme.COL_TEXT)
		box.add_child(label)
	return box


func _button(text: String, gold: bool, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(200, 64)
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	if gold:
		var style := CBHTheme.flat(CBHTheme.COL_JADE, CBHTheme.COL_JADE, 16, 0)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_color_override("font_color", CBHTheme.COL_BG)
	button.pressed.connect(action)
	return button
