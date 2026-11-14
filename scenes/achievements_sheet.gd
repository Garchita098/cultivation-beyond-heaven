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
	CBHTheme.style_label(count, theme.font_sans, 16, CBHTheme.COL_GOLD if owned > 0 else CBHTheme.COL_MUTED)
	box.add_child(count)
	box.move_child(count, 1)
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
	var bg := Color("1C2A24") if unlocked else Color("10151F")
	var border := CBHTheme.COL_GOLD if unlocked else CBHTheme.COL_LINE
	var style := CBHTheme.flat(bg, border, 12, 2 if unlocked else 1)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ArtBank.achievement_icon(ach)
	if not unlocked:
		icon.modulate = Color(0.45, 0.48, 0.55, 0.85)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var name := Label.new()
	name.text = str(ach.get("name_ru", ach["id"]))
	CBHTheme.style_label(name, theme.font_bold, 18, CBHTheme.COL_TEXT if unlocked else Color("6E788C"))
	col.add_child(name)
	var desc := Label.new()
	desc.text = str(ach.get("desc_ru", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CBHTheme.style_label(desc, theme.font_sans, 14, CBHTheme.COL_MUTED if unlocked else Color("5C6578"))
	col.add_child(desc)
	var bonus := float(ach.get("bonus_value", 0.0))
	if bonus > 0.0:
		var line := Label.new()
		var kind := "Ци" if str(ach.get("bonus_type", "")) == "qi_mult" else "оффлайн"
		line.text = "+%d%% %s" % [int(round(bonus * 100.0)), kind]
		CBHTheme.style_label(line, theme.font_sans, 14, CBHTheme.COL_QI if unlocked else Color("4E6A78"))
		col.add_child(line)
	var progress := 1.0 if unlocked else Achievements.progress(Content.data, sim, ach)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = progress
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	if unlocked:
		fill.bg_color = CBHTheme.COL_JADE
	elif progress > 0.0:
		fill.bg_color = CBHTheme.COL_QI
	else:
		fill.bg_color = Color("2A3348")
	fill.set_corner_radius_all(5)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("121826") if not unlocked else Color("163028")
	back.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	col.add_child(bar)
	var mark := Label.new()
	mark.text = "✓" if unlocked else ""
	mark.custom_minimum_size = Vector2(28, 0)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CBHTheme.style_label(mark, theme.font_bold, 22, CBHTheme.COL_JADE)
	row.add_child(mark)
	return panel
