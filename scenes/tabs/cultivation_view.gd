extends Control
## Meditating cultivator, aura that tracks the major rank, Qi, and breakthrough progress.

var _shader_rect: ColorRect
var _mat: ShaderMaterial
var _aura: ColorRect
var _aura_mat: ShaderMaterial
var _hero: TextureRect
var _qi_label: Label
var _float_t: float = 0.0
var _last_qi: String = ""
var _rank_label: Label
var _rate_label: Label
var _next_label: Label
var _bar: ProgressBar
var _path_btn: Button
var _act_btn: Button


func _ready() -> void:
	var theme := CBHTheme.shared()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(col)

	var rank_panel := PanelContainer.new()
	rank_panel.add_theme_stylebox_override("panel", CBHTheme.flat(Color(0.04, 0.05, 0.09, 0.72), CBHTheme.COL_GOLD, 14, 1))
	col.add_child(rank_panel)
	_rank_label = Label.new()
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_rank_label, theme.font_serif, 28, CBHTheme.COL_GOLD)
	rank_panel.add_child(_rank_label)

	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 420)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stage)
	_shader_rect = ColorRect.new()
	_shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shader_rect.color = Color.WHITE
	_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = load("res://assets/shaders/cultivator_aura.gdshader")
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_shader_rect.material = _mat
	stage.add_child(_shader_rect)
	_aura = ColorRect.new()
	_aura.set_anchors_preset(Control.PRESET_FULL_RECT)
	_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura.visible = false
	var aura_shader: Shader = load("res://assets/shaders/hero_aura.gdshader")
	_aura_mat = ShaderMaterial.new()
	_aura_mat.shader = aura_shader
	_aura.material = _aura_mat
	stage.add_child(_aura)
	_hero = TextureRect.new()
	_hero.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hero.offset_top = 8.0
	_hero.offset_bottom = -8.0
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_hero)

	var qi_panel := PanelContainer.new()
	var qi_style := CBHTheme.flat(Color(0.04, 0.05, 0.09, 0.82), CBHTheme.COL_QI, 16, 1)
	qi_panel.add_theme_stylebox_override("panel", qi_style)
	col.add_child(qi_panel)
	var qi_box := VBoxContainer.new()
	qi_panel.add_child(qi_box)
	_qi_label = Label.new()
	_qi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_qi_label, theme.font_bold, 52, CBHTheme.COL_QI)
	qi_box.add_child(_qi_label)

	_rate_label = Label.new()
	_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_rate_label, theme.font_sans, 20, CBHTheme.COL_MUTED)
	qi_box.add_child(_rate_label)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = CBHTheme.COL_QI
	fill.set_corner_radius_all(7)
	var back := StyleBoxFlat.new()
	back.bg_color = CBHTheme.COL_LINE
	back.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	qi_box.add_child(_bar)

	_next_label = Label.new()
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_next_label, theme.font_sans, 16, CBHTheme.COL_MUTED)
	qi_box.add_child(_next_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	col.add_child(actions)
	_path_btn = Button.new()
	_path_btn.focus_mode = Control.FOCUS_NONE
	_path_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_btn.custom_minimum_size = Vector2(0, 64)
	_path_btn.pressed.connect(func(): EventBus.open_path_sheet.emit())
	actions.add_child(_path_btn)
	_act_btn = Button.new()
	_act_btn.focus_mode = Control.FOCUS_NONE
	_act_btn.custom_minimum_size = Vector2(180, 64)
	_act_btn.pressed.connect(_path_action)
	actions.add_child(_act_btn)
	var world_btn := Button.new()
	world_btn.focus_mode = Control.FOCUS_NONE
	world_btn.custom_minimum_size = Vector2(120, 64)
	world_btn.text = "Мир"
	world_btn.pressed.connect(func(): EventBus.open_world_sheet.emit())
	actions.add_child(world_btn)


func _process(delta: float) -> void:
	if not visible:
		return
	_float_t += delta
	if _hero != null and _hero.texture != null and not Prefs.reduced_effects:
		var bob := sin(_float_t * 1.25) * 8.0
		_hero.pivot_offset = _hero.size * 0.5
		_hero.offset_top = 4.0 + bob
		_hero.offset_bottom = -12.0 + bob
		_hero.scale = Vector2.ONE * (1.0 + sin(_float_t * 1.05) * 0.012)
	refresh()


func refresh() -> void:
	if GameState.run == null or not Content.valid:
		return
	var run := GameState.run
	var rank: Dictionary = Content.data.rank_at(run.rank_index)
	_rank_label.text = str(rank.get("name_ru", ""))
	var qi_text := Economy.format_qi(run.qi)
	if qi_text != _last_qi and _last_qi != "":
		_pop_number(_qi_label)
	_last_qi = qi_text
	_qi_label.text = qi_text
	var rate := BigNum.from_float(GameState.last_prod)
	_rate_label.text = "%s Ци/с" % Economy.format_qi(rate)
	var nxt := Economy.next_rank(run, EconomyCore.STAGE_CAP)
	var progress := 0.0
	if nxt.is_empty():
		progress = 1.0
		_next_label.text = "Пик этого этапа"
		_bar.value = 1.0
	else:
		var cost := BigNum.from_float(Economy.breakthrough_cost_of(run))
		progress = clampf(run.qi.ratio_to(cost), 0.0, 1.0)
		_bar.value = progress
		_next_label.text = "%s  ·  %s" % [str(nxt.get("name_ru", "")), Economy.format_qi(cost)]
	var hero_tex: Texture2D = null
	if _hero != null:
		hero_tex = ArtBank.hero(run)
		if _hero.texture != hero_tex:
			_hero.texture = hero_tex
		_hero.visible = hero_tex != null
	var use_sprite := hero_tex != null
	_shader_rect.visible = not use_sprite
	if _aura != null:
		_aura.visible = use_sprite
	var active_mat := _aura_mat if use_sprite else _mat
	if active_mat:
		active_mat.set_shader_parameter("tier", _tier(rank))
		active_mat.set_shader_parameter("progress", progress)
		active_mat.set_shader_parameter("canvas_size", _shader_rect.size)
		if use_sprite:
			active_mat.set_shader_parameter("reduced", 1.0 if Prefs.reduced_effects else 0.0)
		var tint := Color(-1, -1, -1)
		if run.path_joined:
			tint = CBHTheme.path_color(run.path_id)
		active_mat.set_shader_parameter("path_tint", Vector3(tint.r, tint.g, tint.b))
	_refresh_path_chip(run)


func _refresh_path_chip(run: RunState) -> void:
	if _path_btn == null:
		return
	if not run.path_joined:
		_path_btn.text = "Путь"
		_act_btn.visible = false
		return
	var tint := CBHTheme.path_color(run.path_id)
	var style := CBHTheme.flat(tint, tint, 16, 0)
	_path_btn.add_theme_stylebox_override("normal", style)
	_path_btn.add_theme_stylebox_override("hover", style)
	_path_btn.add_theme_stylebox_override("pressed", style)
	_path_btn.add_theme_color_override("font_color", CBHTheme.COL_BG)
	var name := str(Content.data.paths_by_id[run.path_id].get("name_ru", ""))
	if run.path_id == "heavenly_sword":
		_path_btn.text = name if run.burst_left <= 0.0 else "%s  %ds" % [name, int(ceil(run.burst_left))]
		_act_btn.visible = false
	elif run.path_id == "demon_emperor":
		_path_btn.text = name
		_act_btn.visible = true
		_act_btn.text = "Жертва"
	elif run.path_id == "world_devourer":
		_path_btn.text = name
		_act_btn.visible = true
		_act_btn.text = "Поглотить"
	elif run.path_id == "time_lord":
		_path_btn.text = name
		_act_btn.visible = true
		_act_btn.text = "Ускорить" if run.speed_left <= 0.0 else "Пропуск"
	else:
		_path_btn.text = name
		_act_btn.visible = false


func _path_action() -> void:
	if GameState.run == null:
		return
	match GameState.run.path_id:
		"demon_emperor":
			GameState.try_sacrifice("qi")
		"world_devourer":
			if not GameState.run.devour_types.has("upgrade"):
				GameState.try_absorb("upgrade")
			elif not GameState.run.devour_types.has("artifact"):
				GameState.try_absorb("artifact")
			else:
				GameState.try_absorb("spirit_essence")
		"time_lord":
			if GameState.run.speed_left <= 0.0:
				GameState.try_speed()
			else:
				GameState.try_skip()


func _pop_number(label: Label) -> void:
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(1.12, 1.12)
	var tw := create_tween()
	tw.tween_property(label, "scale", Vector2.ONE, 0.22)


func _tier(rank: Dictionary) -> float:
	match str(rank.get("major", "")):
		"mortal":
			return 0.0
		"qi_practitioner":
			return 1.0
		"foundation":
			return 2.0
		"core_formation":
			return 3.0
		_:
			return 4.0
