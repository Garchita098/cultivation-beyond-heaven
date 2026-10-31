extends Control
## One-shot unlock moment. A title, a line, and a jump to the new tab.

var _queue: Array = []
var _title: Label
var _line: Label
var _orb: ColorRect
var _current: Dictionary = {}


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.08, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var theme := CBHTheme.shared()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 420)
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, CBHTheme.COL_GOLD, 28, 2))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	_orb = ColorRect.new()
	_orb.custom_minimum_size = Vector2(120, 120)
	_orb.color = CBHTheme.COL_GOLD
	box.add_child(_orb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_title, theme.font_serif, 36, CBHTheme.COL_GOLD)
	box.add_child(_title)

	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(_line, theme.font_sans, 18, CBHTheme.COL_TEXT)
	box.add_child(_line)

	var open := Button.new()
	open.text = "Открыть"
	open.custom_minimum_size = Vector2(280, 76)
	open.focus_mode = Control.FOCUS_NONE
	var gold := CBHTheme.flat(CBHTheme.COL_GOLD, CBHTheme.COL_GOLD, 18, 0)
	open.add_theme_stylebox_override("normal", gold)
	open.add_theme_stylebox_override("hover", gold)
	open.add_theme_stylebox_override("pressed", gold)
	open.add_theme_color_override("font_color", CBHTheme.COL_BG)
	open.add_theme_font_override("font", theme.font_bold)
	open.pressed.connect(_accept)
	box.add_child(open)


func push(spec: Dictionary) -> void:
	for item in _queue:
		if int(item.get("tab", -1)) == int(spec.get("tab", -2)):
			return
	if visible and int(_current.get("tab", -1)) == int(spec.get("tab", -2)):
		return
	_queue.append(spec)
	if not visible:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		visible = false
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child in get_children():
		if child is Control:
			(child as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_current = _queue.pop_front()
	_title.text = str(_current.get("title", ""))
	_line.text = str(_current.get("line", ""))
	_orb.color = _current.get("color", CBHTheme.COL_GOLD)
	visible = true


func _accept() -> void:
	var id := str(_current.get("id", ""))
	if GameState.run != null and id != "":
		GameState.run.reveal_seen[id] = true
	var tab := int(_current.get("tab", 0))
	visible = false
	if has_meta("on_open"):
		(get_meta("on_open") as Callable).call(tab)
	_show_next()
