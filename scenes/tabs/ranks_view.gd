extends Control
## Rank ladder with sub-stages. Later-stage ranks stay visible as a single lock.

var _list: VBoxContainer
var _shown_rank: int = -999


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
	_list.add_theme_constant_override("separation", 12)
	margin.add_child(_list)


func _process(_delta: float) -> void:
	if not visible or GameState.run == null:
		return
	var scroll := get_child(0) as ScrollContainer
	if scroll and scroll.get_child_count() > 0:
		(scroll.get_child(0) as Control).custom_minimum_size.x = maxf(0.0, scroll.size.x)
	if _shown_rank != GameState.run.rank_index:
		_rebuild()
		_shown_rank = GameState.run.rank_index


func _rebuild() -> void:
	if not Content.valid or GameState.run == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var theme := CBHTheme.shared()
	var title := Label.new()
	title.text = "Лестница рангов"
	CBHTheme.style_label(title, theme.font_serif, 26, CBHTheme.COL_TEXT)
	_list.add_child(title)

	var groups: Dictionary = {}
	var order: Array[String] = []
	for r in Content.data.ranks:
		var major := str(r["major"])
		if int(r.get("stage", 1)) > EconomyCore.STAGE_CAP:
			if not groups.has("_later"):
				groups["_later"] = []
				order.append("_later")
			groups["_later"].append(r)
			continue
		if not groups.has(major):
			groups[major] = []
			order.append(major)
		groups[major].append(r)

	var current := GameState.run.rank_index
	for major in order:
		if major == "_later":
			var peek: Dictionary = groups["_later"][0]
			var lock := PanelContainer.new()
			lock.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_LINE, 16, 1))
			var lock_l := Label.new()
			lock_l.text = "Дальше  ·  %s" % str(peek.get("name_ru", "")).split(" · ")[0]
			CBHTheme.style_label(lock_l, theme.font_sans, 16, CBHTheme.COL_MUTED)
			lock.add_child(lock_l)
			_list.add_child(lock)
			continue
		var panel := PanelContainer.new()
		var border := CBHTheme.COL_LINE
		var any_current := false
		for r in groups[major]:
			if int(r["index"]) == current:
				any_current = true
		if any_current:
			border = CBHTheme.COL_GOLD
		panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, border, 16, 1 if not any_current else 2))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		panel.add_child(box)
		for r in groups[major]:
			var idx := int(r["index"])
			var line := Label.new()
			var mark := "·"
			var color := CBHTheme.COL_MUTED
			if idx < current:
				mark = "✓"
				color = CBHTheme.COL_JADE
			elif idx == current:
				mark = "●"
				color = CBHTheme.COL_GOLD
			var sub := str(r.get("name_ru", ""))
			var cost := float(r["cost_qi"])
			var cost_txt := "" if idx == 0 else Economy.format_qi(BigNum.from_float(cost))
			line.text = "%s  %s    ×%s" % [mark, sub, _mult(float(r["prod_mult"]))]
			if idx > current and cost_txt != "":
				line.text += "    %s" % cost_txt
			CBHTheme.style_label(line, theme.font_sans, 16, color)
			box.add_child(line)
		_list.add_child(panel)


func _mult(v: float) -> String:
	if absf(v - round(v)) < 0.05:
		return str(int(round(v)))
	return "%.1f" % v
