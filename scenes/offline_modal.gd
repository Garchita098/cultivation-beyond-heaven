extends Control
## "While you were away". Gains are already applied; the button only dismisses.

var _time: Label
var _gain: Label
var _note: Label


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var theme := CBHTheme.shared()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 360)
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_GOLD, 24, 1))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Пока вас не было"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(title, theme.font_serif, 32, CBHTheme.COL_GOLD)
	box.add_child(title)

	_time = Label.new()
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_time, theme.font_sans, 18, CBHTheme.COL_MUTED)
	box.add_child(_time)

	_gain = Label.new()
	_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_gain, theme.font_bold, 40, CBHTheme.COL_QI)
	box.add_child(_gain)

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_note, theme.font_sans, 15, CBHTheme.COL_MUTED)
	box.add_child(_note)

	var claim := Button.new()
	claim.text = "Забрать"
	claim.custom_minimum_size = Vector2(280, 72)
	claim.focus_mode = Control.FOCUS_NONE
	var gold := CBHTheme.flat(Color("3A3118"), CBHTheme.COL_GOLD, 16, 1)
	claim.add_theme_stylebox_override("normal", gold)
	claim.add_theme_stylebox_override("hover", CBHTheme.flat(Color("4A3E1E"), CBHTheme.COL_GOLD, 16, 1))
	claim.add_theme_stylebox_override("pressed", CBHTheme.flat(Color("2A2414"), CBHTheme.COL_GOLD, 16, 1))
	claim.pressed.connect(_dismiss)
	box.add_child(claim)


func show_summary(summary: Dictionary) -> void:
	if summary.is_empty():
		return
	_time.text = _format_absent(float(summary.get("absent_sec", 0.0)))
	_gain.text = "+ %s Ци" % str(summary.get("gained_text", "0"))
	var eff := float(summary.get("efficiency", 0.75))
	var note := "Эффективность %d%%" % int(round(eff * 100.0))
	if bool(summary.get("hard_capped", false)):
		note += "  ·  учтено 24 ч"
	elif bool(summary.get("soft_capped", false)):
		note += "  ·  после 8 ч тише"
	if bool(summary.get("chunked", false)):
		note += "  ·  авто"
	_note.text = note
	visible = true


func _dismiss() -> void:
	visible = false
	GameState.pending_offline = {}


func _format_absent(sec: float) -> String:
	var s := int(max(0.0, sec))
	if s < 60:
		return "%d с" % s
	if s < 3600:
		return "%d мин" % int(round(float(s) / 60.0))
	return "%.1f ч" % (float(s) / 3600.0)
