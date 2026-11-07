extends Control
## Lifetime totals. The numbers live in the save under stats.


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_sheet() -> void:
	for child in get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var theme := CBHTheme.shared()
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 20)
	frame.add_theme_constant_override("margin_right", 20)
	frame.add_theme_constant_override("margin_top", 80)
	frame.add_theme_constant_override("margin_bottom", 36)
	add_child(frame)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_QI, 18, 1))
	frame.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Статистика"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(title, theme.font_serif, 30, CBHTheme.COL_QI)
	box.add_child(title)
	var run := GameState.run
	if run == null:
		visible = true
		return
	var rank: Dictionary = Content.data.rank_at(run.highest_rank_index)
	var stats: Dictionary = run.stats
	var lines: Array = [
		["Ци за всё время", Economy.format_qi(run.lifetime_qi)],
		["В игре", _clock(run.time_sec)],
		["Оффлайн", _clock(float(stats.get("offline_sec", 0.0)))],
		["Перерождения", str(run.rebirth_count)],
		["Вознесения", str(run.ascension_count)],
		["Лучший забег", _clock(float(stats.get("best_rebirth_sec", 0.0)))],
		["Быстрейшее вознесение", _clock(float(stats.get("fastest_ascension_sec", 0.0)))],
		["Высший ранг", str(rank.get("name_ru", ""))],
		["Исследования", "%d" % run.research_done.size()],
		["Артефакты", "%d" % run.artifacts_owned.size()],
	]
	for pair in lines:
		box.add_child(_line(theme, str(pair[0]), str(pair[1])))
	var path_sec: Dictionary = stats.get("path_sec", {})
	if not path_sec.is_empty():
		var head := Label.new()
		head.text = "Пути"
		CBHTheme.style_label(head, theme.font_bold, 18, CBHTheme.COL_DAO)
		box.add_child(head)
		for key in path_sec.keys():
			box.add_child(_line(theme, str(key), _clock(float(path_sec[key]))))
	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(0, 64)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): visible = false)
	box.add_child(back)
	visible = true


func _line(theme: CBHTheme, label_text: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var left := Label.new()
	left.text = label_text
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CBHTheme.style_label(left, theme.font_sans, 16, CBHTheme.COL_MUTED)
	row.add_child(left)
	var right := Label.new()
	right.text = value
	CBHTheme.style_label(right, theme.font_bold, 16, CBHTheme.COL_TEXT)
	row.add_child(right)
	return row


func _clock(seconds: float) -> String:
	if seconds <= 0.0:
		return "—"
	var total := int(seconds)
	var h := int(total / 3600)
	var m := int((total % 3600) / 60)
	var s := total % 60
	if h > 0:
		return "%dч %02dм" % [h, m]
	return "%dм %02dс" % [m, s]
