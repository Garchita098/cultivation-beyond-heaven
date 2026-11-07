extends Control
## Notation, motion, and a text save you can copy.


var _box: TextEdit
var _status: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_sheet() -> void:
	for child in get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.84)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var theme := CBHTheme.shared()
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 18)
	frame.add_theme_constant_override("margin_right", 18)
	frame.add_theme_constant_override("margin_top", 72)
	frame.add_theme_constant_override("margin_bottom", 28)
	add_child(frame)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_GOLD, 18, 1))
	frame.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Настройки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(title, theme.font_serif, 30, CBHTheme.COL_GOLD)
	box.add_child(title)
	box.add_child(_choice(theme, "Буквы", "letters"))
	box.add_child(_choice(theme, "Научная", "scientific"))
	box.add_child(_toggle(theme, "Меньше эффектов", Prefs.reduced_effects, func(on: bool):
		Prefs.reduced_effects = on
		_store()
	))
	box.add_child(_toggle(theme, "Звук (эффектов пока нет)", Prefs.sound_on, func(on: bool):
		Prefs.sound_on = on
		_store()
	))
	var hint := Label.new()
	hint.text = "Сохранение текстом. Вставьте строку и нажмите «Взять»."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CBHTheme.style_label(hint, theme.font_sans, 14, CBHTheme.COL_MUTED)
	box.add_child(hint)
	_box = TextEdit.new()
	_box.custom_minimum_size = Vector2(0, 220)
	_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(_action(theme, "Выдать", _export_save))
	row.add_child(_action(theme, "Взять", _import_save))
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_status, theme.font_sans, 14, CBHTheme.COL_JADE)
	box.add_child(_status)
	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(0, 64)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): visible = false)
	box.add_child(back)
	visible = true


func _choice(theme: CBHTheme, label_text: String, mode: String) -> Button:
	var button := Button.new()
	button.text = label_text + ("  ·" if Prefs.notation == mode else "")
	button.custom_minimum_size = Vector2(0, 56)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func():
		Prefs.notation = mode
		_store()
		show_sheet()
	)
	return button


func _toggle(theme: CBHTheme, label_text: String, on: bool, apply: Callable) -> Button:
	var button := Button.new()
	button.text = "%s  %s" % [label_text, "вкл" if on else "выкл"]
	button.custom_minimum_size = Vector2(0, 56)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func(): apply.call(not on))
	button.pressed.connect(show_sheet)
	return button


func _action(theme: CBHTheme, label_text: String, call: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 56)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(call)
	return button


func _store() -> void:
	if GameState.run == null:
		return
	Prefs.write_run(GameState.run)
	SaveSystem.save_run(GameState.run)


func _export_save() -> void:
	_box.text = GameState.export_text()
	_status.text = "Строка готова"


func _import_save() -> void:
	if GameState.import_text(_box.text):
		_status.text = "Сохранение принято"
	else:
		_status.text = "Строка не читается"
