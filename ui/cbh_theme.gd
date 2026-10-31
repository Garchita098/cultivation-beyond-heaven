class_name CBHTheme
extends RefCounted
## Dark eastern palette from docs/ART_DIRECTION.md. Built in code so the theme stays diffable.

const COL_BG := Color("0B0E17")
const COL_PANEL := Color("141A2A")
const COL_LINE := Color("1E2A44")
const COL_QI := Color("5CE1FF")
const COL_JADE := Color("3DDBA0")
const COL_GOLD := Color("F0C75E")
const COL_DAO := Color("A78BFA")
const COL_DANGER := Color("E85D5D")
const COL_TEXT := Color("E8EEF8")
const COL_MUTED := Color("8B97B0")
const COL_BG_RAISED := Color("1A2236")

var theme: Theme
var font_sans: Font
var font_bold: Font
var font_serif: Font

static var _shared: CBHTheme


static func shared() -> CBHTheme:
	if _shared == null:
		_shared = CBHTheme.new()
	return _shared


func _init() -> void:
	font_sans = load("res://assets/fonts/NotoSans-Regular.ttf")
	font_bold = load("res://assets/fonts/NotoSans-Bold.ttf")
	font_serif = load("res://assets/fonts/NotoSerif-Bold.ttf")
	theme = Theme.new()
	theme.default_font = font_sans
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", COL_TEXT)
	theme.set_color("font_color", "Button", COL_TEXT)
	theme.set_font("font", "Button", font_bold)
	theme.set_font_size("font_size", "Button", 18)
	var normal := flat(COL_BG_RAISED, COL_LINE, 14, 1)
	var hover := flat(Color("243049"), COL_QI, 14, 1)
	var pressed := flat(Color("101624"), COL_QI, 14, 1)
	var disabled := flat(Color("121826"), COL_LINE, 14, 1)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), COL_QI, 14, 1))
	theme.set_color("font_disabled_color", "Button", COL_MUTED)
	theme.set_color("font_hover_color", "Button", COL_TEXT)
	theme.set_color("font_pressed_color", "Button", COL_TEXT)


static func flat(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func path_color(path_id: String) -> Color:
	match path_id:
		"heavenly_sword":
			return Color("F0C75E")
		"demon_emperor":
			return Color("E85D5D")
		"immortal":
			return Color("3DDBA0")
		"world_devourer":
			return Color("C084FC")
		"time_lord":
			return Color("5CE1FF")
		_:
			return COL_DAO


static func style_label(label: Label, font: Font, size: int, color: Color) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
