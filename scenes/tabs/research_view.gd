extends Control
## Dao studies run on a timer. Automation sits behind the second segment.

var _studies: VBoxContainer
var _auto: Control
var _study_box: Control
var _sig: String = ""
var _mode: String = "research"


func _ready() -> void:
	var theme := CBHTheme.shared()
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 8)
	root.add_child(seg)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	seg.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	row.add_child(_seg_button("Исследования", "research", theme))
	row.add_child(_seg_button("Авто", "auto", theme))
	var host := Control.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(host)
	_study_box = _build_studies()
	_study_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(_study_box)
	_auto = preload("res://scenes/tabs/automation_view.gd").new()
	_auto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_auto.visible = false
	host.add_child(_auto)


func show_mode(mode: String) -> void:
	_mode = mode
	if _study_box:
		_study_box.visible = mode == "research"
	if _auto:
		_auto.visible = mode == "auto"
	_sig = ""


func _seg_button(text: String, mode: String, theme: CBHTheme) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(160, 48)
	button.add_theme_font_override("font", theme.font_bold)
	button.pressed.connect(func(): show_mode(mode))
	return button


func _build_studies() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)
	_studies = VBoxContainer.new()
	_studies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_studies.add_theme_constant_override("separation", 10)
	margin.add_child(_studies)
	return scroll


func _process(_delta: float) -> void:
	if not visible or _mode != "research" or GameState.run == null:
		return
	var run := GameState.run
	var sig := "%s|%s|%.0f" % [str(run.research_done.keys()), str(run.research_order), run.research_progress]
	if sig == _sig:
		return
	_sig = sig
	_rebuild()


func _rebuild() -> void:
	for child in _studies.get_children():
		child.queue_free()
	var theme := CBHTheme.shared()
	var run := GameState.run
	var order: Array = run.research_order.duplicate()
	for study in Content.data.research["studies"]:
		var sid := str(study["id"])
		if not order.has(sid):
			order.append(sid)
	var by_id := {}
	for study in Content.data.research["studies"]:
		by_id[str(study["id"])] = study
	var first_open := true
	for study_id in order:
		var study: Dictionary = by_id.get(str(study_id), {})
		if study.is_empty():
			continue
		var done := bool(run.research_done.get(str(study_id), false))
		var active := not done and first_open
		if not done:
			first_open = false
		_studies.add_child(_row(study, done, active, run.research_progress, theme))


func _row(study: Dictionary, done: bool, active: bool, progress: float, theme: CBHTheme) -> PanelContainer:
	var panel := PanelContainer.new()
	var border := CBHTheme.COL_JADE if done else (CBHTheme.COL_QI if active else CBHTheme.COL_LINE)
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, border, 16, 1))
	var box := VBoxContainer.new()
	panel.add_child(box)
	var name := Label.new()
	name.text = str(study["name_ru"])
	CBHTheme.style_label(name, theme.font_bold, 18, CBHTheme.COL_TEXT if not done else CBHTheme.COL_JADE)
	box.add_child(name)
	if active:
		var bar := ProgressBar.new()
		bar.max_value = float(study["seconds"])
		bar.value = progress
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		box.add_child(bar)
	elif not done:
		var button := Button.new()
		button.text = "Дальше"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 48)
		var id := str(study["id"])
		button.pressed.connect(func(): GameState.promote_research(id))
		box.add_child(button)
	return panel
