extends Control
## One screen per world rule: channels, tribulation stance, entropy, or the forge.


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_world() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var run := GameState.run
	if run == null:
		return
	var world: Dictionary = Content.data.worlds.get(run.world_id, {})
	var tint := Color(str(world.get("tint", "#8BA0B8")))
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var theme := CBHTheme.shared()
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 24)
	frame.add_theme_constant_override("margin_right", 24)
	frame.add_theme_constant_override("margin_top", 80)
	frame.add_theme_constant_override("margin_bottom", 48)
	add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	frame.add_child(box)
	var title := Label.new()
	title.text = str(world.get("name_ru", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(title, theme.font_serif, 36, tint)
	box.add_child(title)
	var resource := Label.new()
	resource.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resource.text = _resource_line(run, world)
	CBHTheme.style_label(resource, theme.font_bold, 42, CBHTheme.COL_QI)
	box.add_child(resource)
	match str(world.get("mechanic", "")):
		"essence_channels":
			_channels(box, run, tint)
		"tribulation_cycles":
			_stance(box, run, tint)
		"entropy_drain":
			_entropy(box, run, tint)
		"rule_forge":
			_forge(box, run, tint)
		_:
			var idle := Label.new()
			idle.text = "Ци"
			idle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			CBHTheme.style_label(idle, theme.font_sans, 20, CBHTheme.COL_MUTED)
			box.add_child(idle)
	if run.unlocked.has("dao_laws") or run.world_id == "chaos_origin":
		_laws(box, run, theme)
	if run.unlocked.has("reality_stitch"):
		_reality(box, run)
	_layers(box, run)
	var back := Button.new()
	back.custom_minimum_size = Vector2(0, 64)
	back.focus_mode = Control.FOCUS_NONE
	back.text = "Назад"
	back.pressed.connect(func(): visible = false)
	box.add_child(back)
	visible = true


func _resource_line(run: RunState, world: Dictionary) -> String:
	var rid := str(world.get("resource_id", "qi"))
	if rid == "qi":
		return Economy.format_qi(run.qi)
	var amount := float(run.world_res.get(rid, 0.0))
	return "%s  %s" % [str(world.get("resource_name_ru", "")), _trim(amount)]


func _channels(box: VBoxContainer, run: RunState, tint: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for ratio in [0.0, 0.25, 0.5, 0.75]:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 88)
		button.focus_mode = Control.FOCUS_NONE
		button.text = "%d%%" % int(ratio * 100.0)
		if absf(run.essence_ratio - ratio) < 0.01:
			var style := CBHTheme.flat(tint, tint, 16, 0)
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
			button.add_theme_color_override("font_color", CBHTheme.COL_BG)
		var picked: float = float(ratio)
		button.pressed.connect(func():
			GameState.set_essence_ratio(picked)
			show_world()
		)
		row.add_child(button)


func _stance(box: VBoxContainer, run: RunState, tint: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for stance in ["guard", "defy"]:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 96)
		button.focus_mode = Control.FOCUS_NONE
		button.text = "Щит" if stance == "guard" else "Вызов"
		if run.stance == stance:
			var style := CBHTheme.flat(tint, tint, 18, 0)
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
			button.add_theme_color_override("font_color", CBHTheme.COL_BG)
		var picked: String = str(stance)
		button.pressed.connect(func():
			GameState.set_stance(picked)
			show_world()
		)
		row.add_child(button)


func _entropy(box: VBoxContainer, run: RunState, tint: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for seconds in Content.data.worlds["void_dimension"]["retain_choices"]:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 88)
		button.focus_mode = Control.FOCUS_NONE
		button.text = "%ds" % int(seconds)
		if absf(run.retain_seconds - float(seconds)) < 1.0:
			var style := CBHTheme.flat(tint, tint, 16, 0)
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
			button.add_theme_color_override("font_color", CBHTheme.COL_BG)
		var picked := float(seconds)
		button.pressed.connect(func():
			GameState.set_retain(picked)
			show_world()
		)
		row.add_child(button)
	var rewrite := Button.new()
	rewrite.custom_minimum_size = Vector2(0, 72)
	rewrite.focus_mode = Control.FOCUS_NONE
	rewrite.text = "Закон" if run.active_rewrite == "" else "Ци или время"
	rewrite.pressed.connect(func():
		GameState.try_rewrite()
		show_world()
	)
	box.add_child(rewrite)


func _forge(box: VBoxContainer, run: RunState, _tint: Color) -> void:
	var seeds := Label.new()
	seeds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seeds.text = "Семена  %s" % _trim(float(run.world_res.get("chaos_seed", 0.0)))
	CBHTheme.style_label(seeds, CBHTheme.shared().font_sans, 18, CBHTheme.COL_MUTED)
	box.add_child(seeds)


func _laws(box: VBoxContainer, run: RunState, theme: CBHTheme) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for law in Content.data.research["laws"]:
		var id := str(law["id"])
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 72)
		button.focus_mode = Control.FOCUS_NONE
		button.text = str(law["name_ru"]).split(" ")[0]
		if run.slotted_laws.has(id):
			var style := CBHTheme.flat(CBHTheme.COL_DAO, CBHTheme.COL_DAO, 14, 0)
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
			button.add_theme_color_override("font_color", CBHTheme.COL_BG)
		button.add_theme_font_override("font", theme.font_sans)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(func():
			GameState.try_slot_law(id)
			show_world()
		)
		row.add_child(button)


func _reality(box: VBoxContainer, run: RunState) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for mode in ["still", "dilated", "inverted"]:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 64)
		button.focus_mode = Control.FOCUS_NONE
		button.text = {"still": "Тишь", "dilated": "Время", "inverted": "Инверсия"}[mode]
		if run.reality_mode == mode:
			var style := CBHTheme.flat(CBHTheme.COL_GOLD, CBHTheme.COL_GOLD, 14, 0)
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
			button.add_theme_color_override("font_color", CBHTheme.COL_BG)
		var picked: String = str(mode)
		button.pressed.connect(func():
			GameState.set_reality(picked)
			show_world()
		)
		row.add_child(button)


func _layers(box: VBoxContainer, run: RunState) -> void:
	var kind := ""
	var key := ""
	var owned: Dictionary = {}
	match run.world_id:
		"heavenly_world":
			kind = "rite"
			key = "rites"
			owned = run.heavenly_rites
		"void_dimension":
			kind = "seal"
			key = "seals"
			owned = run.void_seals
		"chaos_origin":
			kind = "attune"
			key = "attunements"
			owned = run.chaos_attunements
		_:
			return
	var world: Dictionary = Content.data.worlds.get(run.world_id, {})
	for spec in world.get(key, []):
		var id := str(spec["id"])
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		button.focus_mode = Control.FOCUS_NONE
		if owned.has(id):
			button.text = "%s  ·  есть" % str(spec.get("name_ru", id))
			button.disabled = true
		else:
			button.text = "%s  ·  %s" % [str(spec.get("name_ru", id)), str(spec.get("cost", ""))]
			button.pressed.connect(func():
				GameState.try_buy_layer(kind)
				show_world()
			)
		box.add_child(button)


func _trim(value: float) -> String:
	if value >= 1000.0:
		return Economy.format_qi(BigNum.from_float(value))
	if absf(value - round(value)) < 0.05:
		return str(int(round(value)))
	return "%.1f" % value
