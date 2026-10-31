extends Control
## Portrait shell: status, tab body, breakthrough action, seven-tab bar.

const STATUS_H := 64.0
const CTA_H := 124.0
const NAV_H := 152.0

const TABS := [
	{"id": "cultivation", "label": "Культ.", "cta": true},
	{"id": "upgrades", "label": "Улучш.", "cta": false},
	{"id": "ranks", "label": "Ранги", "cta": true},
	{"id": "talents", "label": "Корни", "cta": false, "need": "spiritual_roots"},
	{"id": "artifacts", "label": "Артеф.", "cta": false, "need": "artifacts_basic"},
	{"id": "rebirth", "label": "Карма", "cta": false, "need": "rebirth_unlock"},
	{"id": "research", "label": "Дао", "cta": false, "need": "automation_buy_upgrades"},
]

const REVEALS := {
	"spiritual_roots": {"tab": 3, "title": "Духовные корни", "line": "Первый корень уже с вами", "color": Color("A78BFA")},
	"artifacts_basic": {"tab": 4, "title": "Реликвия", "line": "Она уже в коллекции", "color": Color("F0C75E")},
	"rebirth_unlock": {"tab": 5, "title": "Колесо кармы", "line": "Можно переродиться", "color": Color("F0C75E")},
	"automation_buy_upgrades": {"tab": 6, "title": "Автоматизация", "line": "Тренировки покупаются сами", "color": Color("5CE1FF")},
	"path_selection": {"tab": 5, "title": "Пять путей", "line": "Можно выбрать путь", "color": Color("A78BFA")},
	"ascension_gate": {"tab": 5, "title": "Врата Вознесения", "line": "Новый мир ждёт", "color": Color("3DDBA0")},
}

var _status_qi: Label
var _status_rate: Label
var _status_rank: Label
var _content: Control
var _cta: Control
var _cta_btn: Button
var _pages: Dictionary = {}
var _tab_buttons: Array = []
var _current: int = 0
var _flash: ColorRect
var _reveal: Control
var _rebirth_modal: Control
var _path_sheet: Control
var _ascension_modal: Control
var _world_sheet: Control

var _shooting: bool = false
var _shot_dir: String = ""
var _shot_i: int = 0
var _shot_timer: float = 0.0
var _shot_pending: bool = false


func _ready() -> void:
	var theme := CBHTheme.shared()
	self.theme = theme.theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = CBHTheme.COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_status(theme)
	_build_content()
	_build_cta(theme)
	_build_nav(theme)
	_build_pages()
	_show_tab(0)

	_flash = ColorRect.new()
	_flash.color = Color(CBHTheme.COL_GOLD.r, CBHTheme.COL_GOLD.g, CBHTheme.COL_GOLD.b, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	var modal := preload("res://scenes/offline_modal.gd").new()
	add_child(modal)
	if not GameState.pending_offline.is_empty() and not GameState.screenshot_mode:
		modal.show_summary(GameState.pending_offline)
	EventBus.offline_summary.connect(modal.show_summary)
	EventBus.rank_up.connect(func(_i, _id): _pulse())
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	_reveal = preload("res://scenes/reveal_overlay.gd").new()
	_reveal.set_meta("on_open", _show_tab)
	_reveal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(_reveal)
	_rebirth_modal = preload("res://scenes/rebirth_modal.gd").new()
	_rebirth_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(_rebirth_modal)
	_path_sheet = preload("res://scenes/path_sheet.gd").new()
	_path_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(_path_sheet)
	_ascension_modal = preload("res://scenes/ascension_modal.gd").new()
	_ascension_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(_ascension_modal)
	_world_sheet = preload("res://scenes/world_sheet.gd").new()
	_world_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(_world_sheet)
	EventBus.open_rebirth_confirm.connect(_rebirth_modal.show_offer)
	EventBus.open_path_sheet.connect(_path_sheet.show_sheet)
	EventBus.open_ascension_confirm.connect(_ascension_modal.show_offer)
	EventBus.open_world_sheet.connect(_world_sheet.show_world)
	EventBus.feature_unlocked.connect(_on_feature)
	EventBus.rebirth_done.connect(func(_c): _pulse())

	var args := OS.get_cmdline_user_args()
	var idx := args.find("--screenshots")
	if idx >= 0:
		_shooting = true
		_shot_dir = args[idx + 1] if idx + 1 < args.size() else "user://screenshots"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_shot_dir))
		_show_tab(0)


func _process(delta: float) -> void:
	if GameState.run == null:
		return
	if not _shooting:
		GameState.tick(delta)
		if not GameState.screenshot_mode:
			Automation.try_act(GameState.run, delta)
		SaveSystem.maybe_autosave(GameState.run, delta)
	else:
		GameState.tick(delta)
		_shot_timer += delta
		if _shot_timer >= 0.65 and not _shot_pending:
			_shot_pending = true
			RenderingServer.frame_post_draw.connect(_capture_shot, CONNECT_ONE_SHOT)
	_refresh_chrome()


func _notification(what: int) -> void:
	if GameState.screenshot_mode or GameState._test_mode():
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if GameState.run != null:
			SaveSystem.save_run(GameState.run)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		GameState.catch_up_offline()


func _build_status(theme: CBHTheme) -> void:
	var bar := PanelContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.offset_top = 0.0
	bar.offset_bottom = STATUS_H
	bar.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_BG, CBHTheme.COL_LINE, 0, 0))
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	var qi_icon := TextureRect.new()
	qi_icon.custom_minimum_size = Vector2(28, 28)
	qi_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qi_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/icons/ui/icon_qi.png"):
		qi_icon.texture = load("res://assets/icons/ui/icon_qi.png")
	row.add_child(qi_icon)
	_status_qi = Label.new()
	_status_qi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CBHTheme.style_label(_status_qi, theme.font_bold, 20, CBHTheme.COL_QI)
	row.add_child(_status_qi)
	_status_rate = Label.new()
	_status_rate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_status_rate, theme.font_sans, 16, CBHTheme.COL_MUTED)
	row.add_child(_status_rate)
	_status_rank = Label.new()
	_status_rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_rank.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	CBHTheme.style_label(_status_rank, theme.font_sans, 15, CBHTheme.COL_GOLD)
	row.add_child(_status_rank)


func _build_content() -> void:
	_content = Control.new()
	_content.anchor_left = 0.0
	_content.anchor_right = 1.0
	_content.anchor_top = 0.0
	_content.anchor_bottom = 1.0
	_content.offset_top = STATUS_H
	_content.offset_bottom = -(NAV_H + CTA_H)
	_content.clip_contents = true
	add_child(_content)


func _build_cta(theme: CBHTheme) -> void:
	_cta = MarginContainer.new()
	_cta.anchor_left = 0.0
	_cta.anchor_right = 1.0
	_cta.anchor_top = 1.0
	_cta.anchor_bottom = 1.0
	_cta.offset_top = -(NAV_H + CTA_H)
	_cta.offset_bottom = -NAV_H
	_cta.add_theme_constant_override("margin_left", 16)
	_cta.add_theme_constant_override("margin_right", 16)
	_cta.add_theme_constant_override("margin_top", 8)
	_cta.add_theme_constant_override("margin_bottom", 8)
	add_child(_cta)
	_cta_btn = Button.new()
	_cta_btn.focus_mode = Control.FOCUS_NONE
	_cta_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cta_btn.add_theme_font_override("font", theme.font_bold)
	_cta_btn.add_theme_font_size_override("font_size", 22)
	_cta_btn.add_theme_color_override("font_color", CBHTheme.COL_BG)
	var gold := CBHTheme.flat(CBHTheme.COL_GOLD, CBHTheme.COL_GOLD, 18, 0)
	var gold_dim := CBHTheme.flat(Color("2A3144"), CBHTheme.COL_LINE, 18, 1)
	_cta_btn.add_theme_stylebox_override("normal", gold)
	_cta_btn.add_theme_stylebox_override("hover", gold)
	_cta_btn.add_theme_stylebox_override("pressed", CBHTheme.flat(Color("C9A64A"), CBHTheme.COL_GOLD, 18, 0))
	_cta_btn.add_theme_stylebox_override("disabled", gold_dim)
	_cta_btn.add_theme_color_override("font_disabled_color", CBHTheme.COL_MUTED)
	_cta_btn.pressed.connect(func(): GameState.try_breakthrough())
	_cta.add_child(_cta_btn)


func _build_nav(theme: CBHTheme) -> void:
	var nav := PanelContainer.new()
	nav.anchor_left = 0.0
	nav.anchor_right = 1.0
	nav.anchor_top = 1.0
	nav.anchor_bottom = 1.0
	nav.offset_top = -NAV_H
	nav.offset_bottom = 0.0
	nav.add_theme_stylebox_override("panel", CBHTheme.flat(Color("0E1320"), CBHTheme.COL_LINE, 0, 0))
	add_child(nav)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(row)
	for i in TABS.size():
		var spec: Dictionary = TABS[i]
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 120)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_font_override("font", theme.font_sans)
		var icon_path := "res://assets/icons/tabs/%s.png" % str(spec["id"])
		if ResourceLoader.exists(icon_path):
			btn.icon = load(icon_path)
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 28)
		btn.text = str(spec["label"])
		btn.add_theme_color_override("font_color", CBHTheme.COL_TEXT)
		var index := i
		btn.pressed.connect(func(): _show_tab(index))
		row.add_child(btn)
		_tab_buttons.append(btn)


func _build_pages() -> void:
	_pages["cultivation"] = preload("res://scenes/tabs/cultivation_view.gd").new()
	_pages["upgrades"] = preload("res://scenes/tabs/upgrades_view.gd").new()
	_pages["ranks"] = preload("res://scenes/tabs/ranks_view.gd").new()
	_pages["talents"] = preload("res://scenes/tabs/talents_view.gd").new()
	_pages["artifacts"] = preload("res://scenes/tabs/artifacts_view.gd").new()
	_pages["rebirth"] = preload("res://scenes/tabs/rebirth_view.gd").new()
	_pages["research"] = preload("res://scenes/tabs/research_view.gd").new()
	for id in _pages.keys():
		var page: Control = _pages[id]
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.visible = false
		_content.add_child(page)


func _locked(title: String, blurb: String, accent: Color) -> Control:
	var view = preload("res://scenes/tabs/locked_view.gd").new()
	view.title_text = title
	view.blurb_text = blurb
	view.accent = accent
	return view


func _show_tab(index: int) -> void:
	_current = index
	var spec: Dictionary = TABS[index]
	var id := str(spec["id"])
	for key in _pages.keys():
		(_pages[key] as Control).visible = key == id
	var show_cta := bool(spec.get("cta", false))
	_cta.visible = show_cta
	_content.offset_bottom = -(NAV_H + (CTA_H if show_cta else 0.0))
	for i in _tab_buttons.size():
		var btn: Button = _tab_buttons[i]
		var spec_i: Dictionary = TABS[i]
		var open := true
		if spec_i.has("need") and GameState.run != null:
			open = GameState.run.unlocked.has(str(spec_i["need"])) or GameState.run.rebirth_count > 0 and str(spec_i["id"]) == "rebirth"
		btn.add_theme_color_override("font_color", CBHTheme.COL_TEXT if open else CBHTheme.COL_MUTED)
		var active := i == index
		var style := CBHTheme.flat(
			Color("182033") if active else Color(0, 0, 0, 0),
			CBHTheme.COL_QI if active else Color(0, 0, 0, 0),
			12,
			0
		)
		style.border_width_bottom = 3 if active else 0
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.content_margin_left = 2
		style.content_margin_right = 2
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)


func _refresh_chrome() -> void:
	var run := GameState.run
	if run == null or not Content.valid:
		return
	_status_qi.text = Economy.format_qi(run.qi)
	_status_rate.text = "%s/с" % Economy.format_qi(BigNum.from_float(GameState.last_prod))
	var rank: Dictionary = Content.data.rank_at(run.rank_index)
	_status_rank.text = str(rank.get("name_ru", ""))
	var nxt := Economy.next_rank(run, EconomyCore.STAGE_CAP)
	if nxt.is_empty():
		_cta_btn.text = "Перерождение\nскоро"
		_cta_btn.disabled = true
	else:
		var cost := BigNum.from_float(Economy.breakthrough_cost_of(run))
		_cta_btn.text = "Прорыв\n%s" % Economy.format_qi(cost)
		_cta_btn.disabled = run.qi.cmp(cost) < 0


func _pulse() -> void:
	_flash.color.a = 0.45
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.45)


func _on_feature(feature_id: String) -> void:
	if GameState.screenshot_mode or GameState.run == null:
		return
	if GameState.run.reveal_seen.has(feature_id):
		return
	if not REVEALS.has(feature_id):
		return
	GameState.run.reveal_seen[feature_id] = true
	var spec: Dictionary = REVEALS[feature_id]
	spec["id"] = feature_id
	_reveal.push(spec)
	_pulse()


const _EXTRA_SHOTS := [
	"rebirth_confirm",
	"path_select",
	"ascension_confirm",
	"world_spirit",
	"world_heavenly",
	"world_void",
	"world_chaos",
	"tab_automation",
]


func _capture_shot() -> void:
	var img := get_viewport().get_texture().get_image()
	var err := OK
	var dir := _shot_dir.trim_suffix("/")
	if _shot_i < TABS.size():
		var spec: Dictionary = TABS[_shot_i]
		err = img.save_png(dir + "/tab_%s.png" % str(spec["id"]))
		_shot_i += 1
		_shot_pending = false
		_shot_timer = 0.0
		if _shot_i < TABS.size():
			_show_tab(_shot_i)
		else:
			_prepare_extra(0)
		if err != OK:
			push_error("Screenshot failed (%s)" % error_string(err))
		return
	var extra := _shot_i - TABS.size()
	if extra < _EXTRA_SHOTS.size():
		err = img.save_png(dir + "/%s.png" % str(_EXTRA_SHOTS[extra]))
		_shot_i += 1
		_shot_pending = false
		_shot_timer = 0.0
		if _shot_i - TABS.size() < _EXTRA_SHOTS.size():
			_prepare_extra(_shot_i - TABS.size())
		else:
			get_tree().quit(0 if err == OK else 1)
		return
	get_tree().quit(0)


func _prepare_extra(index: int) -> void:
	_rebirth_modal.visible = false
	_path_sheet.visible = false
	_ascension_modal.visible = false
	_world_sheet.visible = false
	var name := str(_EXTRA_SHOTS[index])
	if name == "rebirth_confirm":
		_show_tab(5)
		_rebirth_modal.show_offer()
	elif name == "path_select":
		_show_tab(0)
		_path_sheet.show_sheet()
	elif name == "ascension_confirm":
		_path_sheet.visible = false
		_ascension_modal.show_offer()
	elif name.begins_with("world_"):
		_ascension_modal.visible = false
		var world_id: String = {
			"world_spirit": "spirit_world",
			"world_heavenly": "heavenly_world",
			"world_void": "void_dimension",
			"world_chaos": "chaos_origin",
		}[name]
		GameState.run.world_id = world_id
		if world_id == "void_dimension":
			GameState.run.world_res["void_dust"] = 24.0
			GameState.run.retain_seconds = 180.0
		elif world_id == "chaos_origin":
			GameState.run.world_res["chaos_seed"] = 3.0
		elif world_id == "heavenly_world":
			GameState.run.world_res["dao_fragments"] = 6.0
			GameState.run.stance = "defy"
			GameState.run.boon_left = 12.0
		elif world_id == "spirit_world":
			GameState.run.essence_ratio = 0.5
			GameState.run.world_res["spirit_essence"] = 40.0
		_show_tab(0)
		_world_sheet.show_world()
	elif name == "tab_automation":
		_world_sheet.visible = false
		GameState.run.world_id = "mortal_world"
		_show_tab(6)
		var page = _pages["research"]
		page.show_mode("auto")
