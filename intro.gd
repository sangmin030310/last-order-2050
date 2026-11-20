extends Control

const FILM_PATH := "res://cinematics/opening.ogv"
const FONT = preload("res://art/korean.otf")
const BACKDROP = preload("res://art/camp.webp")
const BIRD = preload("res://art/jodari.webp")
const TIGER = preload("res://art/jodalho.webp")
const ACCENT := Color("#84f1d2")
const INK := Color("#eef7f5")
const SECONDARY := Color("#bfd4d9")
const UI_LABEL = preload("res://ui_label.gd")
const MENU_BUTTON = preload("res://menu_button.gd")

var selection_open := false
var starting := false
var video: VideoStreamPlayer
var skip: Button
var role_heading: Label
var role_body: Label
var character_cards: Array[Panel] = []

func _ready() -> void:
	if not ResourceLoader.exists(FILM_PATH):
		show_selection()
		return
	video = make_video()
	skip = MENU_BUTTON.new()
	skip.text = "건너뛰기  Esc"
	skip.add_theme_font_override("font", FONT)
	skip.add_theme_font_size_override("font_size", 18)
	skip.position = Vector2(1092, 648)
	skip.custom_minimum_size = Vector2(156, 43)
	skip.pressed.connect(show_selection)
	add_child(skip)
	video.play()

func make_video() -> VideoStreamPlayer:
	var film := VideoStreamPlayer.new()
	film.stream = load(FILM_PATH)
	film.expand = true
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film.finished.connect(show_selection)
	add_child(film)
	return film

func _input(event: InputEvent) -> void:
	if not selection_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		show_selection()
	elif selection_open and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1 or event.physical_keycode == KEY_2:
			get_viewport().set_input_as_handled()
			start_game(event.physical_keycode == KEY_2)

func show_selection() -> void:
	if selection_open:
		return
	selection_open = true
	if is_instance_valid(video):
		video.hide()
		video.stop()
		video.queue_free()
		skip.hide()
		skip.queue_free()
	var picture := TextureRect.new()
	picture.texture = BACKDROP
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(picture)
	var shade := ColorRect.new()
	shade.color = Color("#07151ddd")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	label(self, "2050: 마지막 발주  /  다온시", Vector2(0, 69), Vector2(1280, 28), 18, ACCENT)
	label(self, "누가 먼저 출동할까요?", Vector2(0, 106), Vector2(1280, 58), 38, INK)
	label(self, "선택한 캐릭터가 앞장서고, 동료는 함께 이동합니다.", Vector2(0, 172), Vector2(1280, 36), 19, SECONDARY)
	var role_panel := Panel.new()
	role_panel.position = Vector2(283, 600)
	role_panel.size = Vector2(714, 76)
	role_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role_panel.add_theme_stylebox_override("panel", box(Color("#0b202eff"), ACCENT))
	add_child(role_panel)
	role_heading = label(role_panel, "", Vector2(16, 6), Vector2(682, 27), 19, ACCENT)
	role_body = label(role_panel, "", Vector2(16, 35), Vector2(682, 32), 17, INK)
	var first := character_card(false, BIRD, "조달이", "조달 정보 조사 · 물자 운반", "1  조달이로 출동", 283)
	character_card(true, TIGER, "조달호", "현장 물류 · 시설팀 협력", "2  조달호로 출동", 659)
	label(self, "협동 구간에서는 Tab으로 두 캐릭터를 바꿔 조작할 수 있습니다.", Vector2(0, 683), Vector2(1280, 28), 16, SECONDARY)
	first.grab_focus()

func character_card(tiger_lead: bool, portrait: Texture2D, actor_name: String, role: String, button_text: String, x: float) -> Button:
	var card := Panel.new()
	card.position = Vector2(x, 218)
	card.size = Vector2(338, 366)
	card.set_meta("accent", Color("#ffc889") if tiger_lead else ACCENT)
	character_cards.append(card)
	card.add_theme_stylebox_override("panel", box(Color("#132730f8"), Color("#4c7074")))
	add_child(card)
	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture = portrait
	sprite.position = Vector2(24, 14)
	sprite.size = Vector2(290, 278)
	sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	sprite.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sprite.mouse_entered.connect(highlight_role.bind(tiger_lead, card))
	sprite.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			sprite.accept_event()
			start_game(tiger_lead)
	)
	card.add_child(sprite)
	var button := MENU_BUTTON.new()
	button.text = button_text
	button.position = Vector2(30, 307)
	button.custom_minimum_size = Vector2(278, 45)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 19)
	var accent: Color = card.get_meta("accent")
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_focus_color", accent)
	button.add_theme_color_override("font_hover_color", Color("#10232b"))
	button.add_theme_color_override("font_pressed_color", Color("#10232b"))
	var normal := box(Color("#102c38"), accent.darkened(0.35))
	normal.shadow_color = Color("#020b1240")
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", box(accent, accent.lightened(0.2)))
	button.add_theme_stylebox_override("pressed", box(accent.darkened(0.15), accent))
	var focus := box(Color.TRANSPARENT, accent)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(start_game.bind(tiger_lead))
	button.mouse_entered.connect(highlight_role.bind(tiger_lead, card))
	button.focus_entered.connect(highlight_role.bind(tiger_lead, card))
	card.add_child(button)
	return button

func highlight_role(tiger_lead: bool, card: Panel) -> void:
	for other: Panel in character_cards:
		other.add_theme_stylebox_override("panel", box(Color("#132730f8"), Color("#4c7074")))
	var accent: Color = card.get_meta("accent")
	role_heading.text = "조달호  |  현장 물류 · 시설팀 협력" if tiger_lead else "조달이  |  조달 정보 조사 · 물자 운반"
	role_body.text = "시설팀 안내에 따라 병원 보조 발판과 창고 내부 물류 분전반을 조작합니다." if tiger_lead else "물품 수요와 공급 경로를 조사하고, 검사할 원자재를 운반합니다."
	role_heading.add_theme_color_override("font_color", accent)
	card.add_theme_stylebox_override("panel", box(Color("#1b3943"), accent))

func label(parent: Node, text: String, at: Vector2, bounds: Vector2, font_size: int, color: Color) -> Label:
	var title := UI_LABEL.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text = text
	title.position = at
	title.size = bounds
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_color_override("font_color", color)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.configure(bounds, font_size)
	parent.add_child(title)
	return title

func box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.shadow_color = Color("#020b1238")
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	return style

func start_game(tiger_lead: bool) -> void:
	if starting:
		return
	starting = true
	Story.reset()
	Story.lead_tiger = tiger_lead
	get_tree().change_scene_to_file.call_deferred("res://prologue.tscn")
