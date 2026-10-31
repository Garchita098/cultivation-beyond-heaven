extends Control
## Meditating cultivator, aura that tracks the major rank, Qi, and breakthrough progress.

var _shader_rect: ColorRect
var _mat: ShaderMaterial
var _rank_label: Label
var _qi_label: Label
var _rate_label: Label
var _next_label: Label
var _bar: ProgressBar


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

	_rank_label = Label.new()
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_rank_label, theme.font_serif, 28, CBHTheme.COL_GOLD)
	col.add_child(_rank_label)

	_shader_rect = ColorRect.new()
	_shader_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shader_rect.custom_minimum_size = Vector2(0, 420)
	_shader_rect.color = Color.WHITE
	_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = load("res://assets/shaders/cultivator_aura.gdshader")
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_shader_rect.material = _mat
	col.add_child(_shader_rect)

	_qi_label = Label.new()
	_qi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_qi_label, theme.font_bold, 52, CBHTheme.COL_QI)
	col.add_child(_qi_label)

	_rate_label = Label.new()
	_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_rate_label, theme.font_sans, 20, CBHTheme.COL_MUTED)
	col.add_child(_rate_label)

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
	col.add_child(_bar)

	_next_label = Label.new()
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_next_label, theme.font_sans, 16, CBHTheme.COL_MUTED)
	col.add_child(_next_label)


func _process(_delta: float) -> void:
	if not visible:
		return
	refresh()


func refresh() -> void:
	if GameState.run == null or not Content.valid:
		return
	var run := GameState.run
	var rank: Dictionary = Content.data.rank_at(run.rank_index)
	_rank_label.text = str(rank.get("name_ru", ""))
	_qi_label.text = Economy.format_qi(run.qi)
	var rate := BigNum.from_float(GameState.last_prod)
	_rate_label.text = "%s Ци/с" % Economy.format_qi(rate)
	var nxt := Economy.next_rank(run, EconomyCore.STAGE1_CAP)
	var progress := 0.0
	if nxt.is_empty():
		progress = 1.0
		_next_label.text = "Пик этого этапа"
		_bar.value = 1.0
	else:
		var cost := BigNum.from_float(float(nxt["cost_qi"]))
		progress = clampf(run.qi.ratio_to(cost), 0.0, 1.0)
		_bar.value = progress
		_next_label.text = "%s  ·  %s" % [str(nxt.get("name_ru", "")), Economy.format_qi(cost)]
	if _mat:
		_mat.set_shader_parameter("tier", _tier(rank))
		_mat.set_shader_parameter("progress", progress)
		_mat.set_shader_parameter("canvas_size", _shader_rect.size)


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
