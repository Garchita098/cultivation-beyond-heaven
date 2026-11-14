extends Control

var title_text: String = ""
var blurb_text: String = ""
var accent: Color = CBHTheme.COL_DAO


func _ready() -> void:
	var theme := CBHTheme.shared()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 280)
	panel.add_theme_stylebox_override("panel", CBHTheme.flat(CBHTheme.COL_PANEL, accent.lerp(CBHTheme.COL_LINE, 0.4), 24, 1))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var lock := Label.new()
	lock.text = "Закрыто"
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(lock, theme.font_sans, 14, accent)
	box.add_child(lock)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CBHTheme.style_label(title, theme.font_serif, 32, CBHTheme.COL_TEXT)
	box.add_child(title)

	var blurb := Label.new()
	blurb.text = blurb_text
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(400, 0)
	CBHTheme.style_label(blurb, theme.font_sans, 18, CBHTheme.COL_MUTED)
	box.add_child(blurb)
