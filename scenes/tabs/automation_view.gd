extends Control
## Automation toggles. Conditions are chips, not forms.

const RANK_CHOICES := [15, 16, 19]
const KARMA_CHOICES := [1, 3, 5, 8]

var _list: VBoxContainer
var _sig: String = ""


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
	EventBus.state_changed.connect(func(): _sig = "")


func _process(_delta: float) -> void:
	if not visible or GameState.run == null:
		return
	var scroll := get_child(0) as ScrollContainer
	if scroll and scroll.get_child_count() > 0:
		(scroll.get_child(0) as Control).custom_minimum_size.x = maxf(0.0, scroll.size.x)
	var run := GameState.run
	var sig := "%s|%s|%d|%d|%d" % [str(run.automation_toggles), run.auto_buy_mode, run.auto_rebirth_min_rank, run.auto_rebirth_min_karma, run.rebirth_count]
	if sig != _sig:
		_sig = sig
		_rebuild()


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	var theme := CBHTheme.shared()
	var title := Label.new()
	title.text = "Автоматизация"
	CBHTheme.style_label(title, theme.font_serif, 26, CBHTheme.COL_TEXT)
	_list.add_child(title)
	if not _open():
		_list.add_child(_locked(theme))
		return
	for entry in Content.data.automation["unlock_order"]:
		_list.add_child(_row(entry, theme))
		var id := str(entry["id"])
		if id == "auto_buy_upgrades" and _available(entry):
			_list.add_child(_mode_chips(theme))
		if id == "auto_rebirth" and _available(entry):
			_list.add_child(_rebirth_chips(theme))


func _open() -> bool:
	var run := GameState.run
	return run.unlocked.has("automation_buy_upgrades") or run.unlocked.has("auto_buy_upgrades") or run.highest_rank_index >= 12


func _available(entry: Dictionary) -> bool:
	return EconomyCore.auto_available(Content.data, GameState.run.to_sim(), str(entry["id"]))


func _row(entry: Dictionary, theme: CBHTheme) -> PanelContainer:
	var id := str(entry["id"])
	var open := _available(entry)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_LINE, 16, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var name := Label.new()
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text = str(entry.get("name_ru", id))
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CBHTheme.style_label(name, theme.font_bold, 16, CBHTheme.COL_TEXT if open else CBHTheme.COL_MUTED)
	row.add_child(name)
	var toggle := Button.new()
	toggle.custom_minimum_size = Vector2(96, 56)
	toggle.focus_mode = Control.FOCUS_NONE
	if not open:
		toggle.text = "···"
		toggle.disabled = true
	else:
		var on := bool(GameState.run.automation_toggles.get(id, false))
		toggle.text = "Вкл" if on else "Выкл"
		var bg := CBHTheme.COL_JADE if on else CBHTheme.COL_BG_RAISED
		var style := CBHTheme.flat(bg, CBHTheme.COL_JADE if on else CBHTheme.COL_LINE, 14, 1)
		toggle.add_theme_stylebox_override("normal", style)
		toggle.add_theme_stylebox_override("hover", style)
		toggle.add_theme_stylebox_override("pressed", style)
		toggle.add_theme_color_override("font_color", CBHTheme.COL_BG if on else CBHTheme.COL_TEXT)
		toggle.pressed.connect(func(): GameState.set_auto(id, not on))
	row.add_child(toggle)
	return panel


func _mode_chips(theme: CBHTheme) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_chip("Выгода", GameState.run.auto_buy_mode == "roi", theme, func(): GameState.set_auto_buy_mode("roi")))
	row.add_child(_chip("Дешевле", GameState.run.auto_buy_mode == "cheapest", theme, func(): GameState.set_auto_buy_mode("cheapest")))
	return row


func _rebirth_chips(theme: CBHTheme) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var ranks := HBoxContainer.new()
	ranks.add_theme_constant_override("separation", 6)
	box.add_child(ranks)
	for idx in RANK_CHOICES:
		var rank: Dictionary = Content.data.rank_at(idx)
		var short := str(rank.get("name_ru", "")).split(" · ")[0]
		var chosen: bool = GameState.run.auto_rebirth_min_rank == idx
		ranks.add_child(_chip(short, chosen, theme, _pick_rank.bind(idx)))
	var karmas := HBoxContainer.new()
	karmas.add_theme_constant_override("separation", 6)
	box.add_child(karmas)
	for k in KARMA_CHOICES:
		var chosen: bool = GameState.run.auto_rebirth_min_karma == k
		karmas.add_child(_chip("+%d" % k, chosen, theme, _pick_karma.bind(k)))
	return box


func _chip(text: String, on: bool, theme: CBHTheme, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", theme.font_sans)
	button.add_theme_font_size_override("font_size", 14)
	var style := CBHTheme.flat(Color("243049") if on else CBHTheme.COL_BG, CBHTheme.COL_QI if on else CBHTheme.COL_LINE, 12, 1)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", CBHTheme.COL_QI if on else CBHTheme.COL_MUTED)
	button.pressed.connect(cb)
	return button


func _pick_rank(idx: int) -> void:
	GameState.set_auto_rebirth(idx, GameState.run.auto_rebirth_min_karma)


func _pick_karma(amount: int) -> void:
	GameState.set_auto_rebirth(GameState.run.auto_rebirth_min_rank, amount)


func _locked(theme: CBHTheme) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 240)
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_DAO, 24, 1))
	var label := Label.new()
	label.text = "Золотое Ядро"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(label, theme.font_sans, 18, CBHTheme.COL_MUTED)
	panel.add_child(label)
	return panel
