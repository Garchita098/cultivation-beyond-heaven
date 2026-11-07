extends Control
## Scroll of achievements and their progress. Bonuses are already in the sim.


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
	frame.add_theme_constant_override("margin_left", 16)
	frame.add_theme_constant_override("margin_right", 16)
	frame.add_theme_constant_override("margin_top", 72)
	frame.add_theme_constant_override("margin_bottom", 24)
	add_child(frame)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_DAO, 18, 1))
	frame.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Достижения"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(title, theme.font_serif, 28, CBHTheme.COL_GOLD)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 820)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var run := GameState.run
	var owned := 0
	if run != null:
		owned = run.achievements.size()
	var count := Label.new()
	count.text = "%d / %d" % [owned, Content.data.achievements.size()]
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(count, theme.font_sans, 16, CBHTheme.COL_MUTED)
	box.add_child(count)
	if run != null:
		var sim := run.to_sim()
		for ach in Content.data.achievements:
			list.add_child(_row(theme, sim, ach))
	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(0, 64)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): visible = false)
	box.add_child(back)
	visible = true


func _row(theme: CBHTheme, sim: SimState, ach: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var unlocked: bool = sim.achievements.has(str(ach["id"]))
	var border := CBHTheme.COL_JADE if unlocked else CBHTheme.COL_LINE
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_BG_RAISED, border, 12, 1))
	var col := VBoxContainer.new()
	panel.add_child(col)
	var name := Label.new()
	name.text = str(ach.get("name_ru", ach["id"]))
	CBHTheme.style_label(name, theme.font_bold, 18, CBHTheme.COL_TEXT if unlocked else CBHTheme.COL_MUTED)
	col.add_child(name)
	var desc := Label.new()
	desc.text = str(ach.get("desc_ru", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CBHTheme.style_label(desc, theme.font_sans, 14, CBHTheme.COL_MUTED)
	col.add_child(desc)
	var bonus := float(ach.get("bonus_value", 0.0))
	if bonus > 0.0:
		var line := Label.new()
		var kind := "Ци" if str(ach.get("bonus_type", "")) == "qi_mult" else "оффлайн"
		line.text = "+%d%% %s" % [int(round(bonus * 100.0)), kind]
		CBHTheme.style_label(line, theme.font_sans, 14, CBHTheme.COL_QI)
		col.add_child(line)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = 1.0 if unlocked else Achievements.progress(Content.data, sim, ach)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	col.add_child(bar)
	return panel
