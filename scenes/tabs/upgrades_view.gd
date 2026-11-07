extends Control
## Purchasable trainings. Buying spends Qi; it never grants Qi.

var _list: VBoxContainer
var _rows: Dictionary = {}
var _built_rank: int = -1


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	margin.add_child(_list)
	EventBus.rank_up.connect(func(_i, _id): _rebuild())
	EventBus.state_changed.connect(_refresh_rows)


func _process(_delta: float) -> void:
	if not visible:
		return
	var scroll := get_child(0) as ScrollContainer
	if scroll and scroll.get_child_count() > 0:
		(scroll.get_child(0) as Control).custom_minimum_size.x = maxf(0.0, scroll.size.x)
	if _built_rank < 0:
		_rebuild()
	else:
		_refresh_rows()


func _rebuild() -> void:
	if not Content.valid or GameState.run == null:
		return
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()
	var theme := CBHTheme.shared()
	var title := Label.new()
	title.text = "Тренировки"
	CBHTheme.style_label(title, theme.font_serif, 26, CBHTheme.COL_TEXT)
	_list.add_child(title)
	for uid in Content.data.upgrade_order:
		var u: Dictionary = Content.data.upgrades[uid]
		if int(u.get("stage", 1)) > EconomyCore.STAGE_CAP:
			continue
		_list.add_child(_make_row(uid, u))
	var later := PanelContainer.new()
	later.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_LINE, 16, 1))
	var later_label := Label.new()
	later_label.text = "Пустота и законы — следующий этап"
	CBHTheme.style_label(later_label, theme.font_sans, 16, CBHTheme.COL_MUTED)
	later.add_child(later_label)
	_list.add_child(later)
	_built_rank = GameState.run.rank_index
	_refresh_rows()


func _make_row(uid: String, u: Dictionary) -> PanelContainer:
	var theme := CBHTheme.shared()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_LINE, 16, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ArtBank.upgrade_icon(uid)
	row.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)
	var name_l := Label.new()
	name_l.text = str(u.get("name_ru", uid))
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	CBHTheme.style_label(name_l, theme.font_bold, 18, CBHTheme.COL_TEXT)
	text_col.add_child(name_l)
	var effect_l := Label.new()
	effect_l.text = _effect_line(u)
	CBHTheme.style_label(effect_l, theme.font_sans, 14, CBHTheme.COL_MUTED)
	text_col.add_child(effect_l)
	var meta_l := Label.new()
	CBHTheme.style_label(meta_l, theme.font_sans, 14, CBHTheme.COL_QI)
	text_col.add_child(meta_l)

	var buy := Button.new()
	buy.text = "Купить"
	buy.custom_minimum_size = Vector2(112, 64)
	buy.focus_mode = Control.FOCUS_NONE
	buy.pressed.connect(func(): GameState.try_buy(uid))
	row.add_child(buy)

	_rows[uid] = {"panel": panel, "meta": meta_l, "buy": buy, "name": name_l}
	return panel


func _refresh_rows() -> void:
	if GameState.run == null or not Content.valid:
		return
	if _built_rank != GameState.run.rank_index:
		_rebuild()
		return
	var run := GameState.run
	for uid in _rows.keys():
		var pack: Dictionary = _rows[uid]
		var u: Dictionary = Content.data.upgrades[uid]
		var req := int(Content.data.ranks_by_id[str(u["unlock_rank"])]["index"])
		var lvl := int(run.upgrade_levels.get(uid, 0))
		var mx := int(u.get("max_level", 0))
		var meta: Label = pack["meta"]
		var buy: Button = pack["buy"]
		if run.rank_index < req:
			var need: Dictionary = Content.data.ranks_by_id[str(u["unlock_rank"])]
			meta.text = str(need.get("name_ru", ""))
			meta.add_theme_color_override("font_color", CBHTheme.COL_MUTED)
			buy.disabled = true
			buy.text = "Закрыто"
		else:
			var cost := Economy.cost_of(run, uid)
			meta.text = "Ур. %d   %s" % [lvl, Economy.format_qi(cost)]
			meta.add_theme_color_override("font_color", CBHTheme.COL_QI)
			var capped := mx > 0 and lvl >= mx
			buy.disabled = capped or run.qi.cmp(cost) < 0
			buy.text = "Макс." if capped else "Купить"


func _effect_line(u: Dictionary) -> String:
	var ev := float(u["effect_value"])
	match str(u["effect_type"]):
		"flat_prod":
			return "+%s Ци/с за уровень" % _trim_num(ev)
		"mult_prod":
			return "+%s%% силы за уровень" % _pct(ev)
		"speed_mult":
			return "+%s%% скорости за уровень" % _pct(ev)
		"cost_reduction":
			return "−%s%% цены за уровень" % _pct(ev)
		_:
			return str(u["effect_type"])


func _pct(ev: float) -> String:
	var pct := ev * 100.0
	if absf(pct - round(pct)) < 0.05:
		return str(int(round(pct)))
	return "%.1f" % pct


func _trim_num(v: float) -> String:
	var s := "%.2f" % v
	while s.ends_with("0") and s.contains("."):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s
