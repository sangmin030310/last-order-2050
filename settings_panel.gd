extends Control
## Shared settings screen for the title and pause menus.

signal back_requested

const FONT = preload("res://art/korean.otf")
const UI_LABEL = preload("res://ui_label.gd")
const MENU_BUTTON = preload("res://menu_button.gd")
const ACCENT := Color("#84f1d2")

var mode_button: Button
var text_button: Button
var back_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme_resource := Theme.new()
	theme_resource.default_font = FONT
	theme_resource.default_font_size = 20
	theme = theme_resource
	var veil := ColorRect.new()
	veil.color = Color("#041018e8")
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := Panel.new()
	card.position = Vector2(340, 135)
	card.size = Vector2(600, 450)
	card.add_theme_stylebox_override("panel", frame(Color("#102632"), Color("#537e86")))
	add_child(card)
	label(card, "화면·글자 설정", Vector2(32, 25), Vector2(536, 50), 30, Color.WHITE)
	label(card, "설정은 다음 실행에도 유지됩니다.", Vector2(32, 78), Vector2(536, 36), 17, Color("#bfd4d9"))
	mode_button = option_button(card, Vector2(32, 137), cycle_mode)
	text_button = option_button(card, Vector2(32, 205), cycle_text)
	label(card, "화면 전체를 보여주기 위해 비율을 유지합니다.\n창 비율이 다르면 가장자리에 여백이 생길 수 있습니다.", Vector2(32, 278), Vector2(536, 68), 16, Color("#bfd4d9"))
	back_button = option_button(card, Vector2(32, 365), func(): back_requested.emit())
	back_button.text = "돌아가기"
	var buttons: Array[Button] = [mode_button, text_button, back_button]
	for index in range(buttons.size()):
		buttons[index].focus_neighbor_top = buttons[index].get_path_to(buttons[posmod(index - 1, buttons.size())])
		buttons[index].focus_neighbor_bottom = buttons[index].get_path_to(buttons[(index + 1) % buttons.size()])
		buttons[index].focus_previous = buttons[index].focus_neighbor_top
		buttons[index].focus_next = buttons[index].focus_neighbor_bottom
	GameSettings.settings_changed.connect(refresh)
	refresh()
	mode_button.grab_focus()

func frame(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	return box

func label(parent: Control, caption: String, at: Vector2, bounds: Vector2, font_size: int, color: Color) -> Label:
	var item := UI_LABEL.new()
	item.text = caption
	item.position = at
	item.add_theme_font_override("font", FONT)
	item.add_theme_color_override("font_color", color)
	item.configure(bounds, font_size)
	parent.add_child(item)
	return item

func option_button(parent: Control, at: Vector2, action: Callable) -> Button:
	var item := MENU_BUTTON.new()
	item.position = at
	item.size = Vector2(536, 54)
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_font_size_override("font_size", 20)
	parent.add_child(item)
	item.pressed.connect(action)
	return item

func refresh() -> void:
	mode_button.text = "화면 모드  ·  " + GameSettings.mode_name()
	text_button.text = "글자 크기  ·  " + ("크게" if GameSettings.large_text else "보통")

func cycle_mode() -> void:
	GameSettings.cycle_display_mode()

func cycle_text() -> void:
	GameSettings.toggle_large_text()
