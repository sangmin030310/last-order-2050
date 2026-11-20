extends Control

const TITLE := "마지막 발주"
const FONT = preload("res://art/korean.otf")
const BACKGROUND = preload("res://art/daon.webp")
const JODARI = preload("res://art/jodari_f.png")
const JODALHO = preload("res://art/jodalho_f.png")
const ACCENT := Color("#84f1d2")
const INK := Color("#eef7f5")
const MUTED := Color("#bfd4d9")
const UI_LABEL = preload("res://ui_label.gd")
const MENU_BUTTON = preload("res://menu_button.gd")
const SETTINGS_PANEL = preload("res://settings_panel.gd")

var menu: VBoxContainer
var popup: Control
var return_focus: Button
var starting := false
var closing := false
var menu_hint: Label

func _ready() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 22
	theme = ui_theme
	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("#06151d78")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color("#071722ed"), Color("#0b26386b"), Color("#06121bf5")])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0, 0)
	gradient_texture.fill_to = Vector2(1, 0)
	var atmosphere := TextureRect.new()
	atmosphere.texture = gradient_texture
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hero := Control.new()
	hero.name = "TitleAndTeam"
	hero.size = Vector2(780, 720)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero)
	text(hero, "2050  /  다온시 긴급 복구 작전", Rect2(72, 82, 660, 28), 17, ACCENT).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text(hero, TITLE, Rect2(68, 119, 680, 92), 64, INK).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var title_rule := ColorRect.new()
	title_rule.position = Vector2(74, 226)
	title_rule.size = Vector2(54, 3)
	title_rule.color = ACCENT
	title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(title_rule)
	text(hero, "끊어진 공급망을 잇고,\n도시의 불빛을 되찾으세요.", Rect2(74, 244, 660, 64), 22, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_character(JODARI, Rect2(144, 328, 240, 274), "조달이", hero)
	add_character(JODALHO, Rect2(430, 328, 240, 274), "조달호", hero)
	text(hero, "두 동료의 협동으로 완성하는 마지막 공급계획", Rect2(74, 662, 680, 26), 16, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var launch := Panel.new()
	launch.name = "LaunchPanel"
	launch.position = Vector2(852, 66)
	launch.size = Vector2(356, 588)
	var launch_style := style(Color("#0c202cf2"), Color("#436975"))
	launch_style.set_border_width_all(1)
	launch_style.set_corner_radius_all(18)
	launch_style.shadow_color = Color("#02090e80")
	launch_style.shadow_size = 18
	launch.add_theme_stylebox_override("panel", launch_style)
	add_child(launch)
	text(launch, "출동 준비", Rect2(28, 28, 300, 44), 28, INK).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu_hint = text(launch, "함께 다온시의 내일을 이어가세요.", Rect2(28, 82, 300, 36), 16, MUTED)
	menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu = VBoxContainer.new()
	menu.position = Vector2(28, 140)
	menu.size = Vector2(300, 340)
	menu.add_theme_constant_override("separation", 9)
	launch.add_child(menu)
	var start := button(menu, "게임 시작", begin_opening, true)
	var controls := button(menu, "조작법", show_controls)
	var description := button(menu, "설명", show_description)
	var settings := button(menu, "화면·글자 설정", show_settings)
	var exit := button(menu, "종료", quit_game)
	var main_buttons: Array[Button] = [start, controls, description, settings, exit]
	var hints := ["오프닝을 보고 다온시 복구 작전에 출동합니다.", "이동·조사·캐릭터 전환 방법을 확인합니다.", "다온시의 이야기와 복구 목표를 알아봅니다.", "화면 모드와 글자 크기를 바꿉니다.", "게임을 종료합니다."]
	for index in range(main_buttons.size()):
		var current := main_buttons[index]
		current.focus_entered.connect(update_menu_hint.bind(hints[index]))
		current.focus_neighbor_top = current.get_path_to(main_buttons[posmod(index - 1, main_buttons.size())])
		current.focus_neighbor_bottom = current.get_path_to(main_buttons[(index + 1) % main_buttons.size()])
		current.focus_previous = current.focus_neighbor_top
		current.focus_next = current.focus_neighbor_bottom
	add_menu_logo()
	var divider := ColorRect.new()
	divider.position = Vector2(28, 492)
	divider.size = Vector2(300, 1)
	divider.color = Color("#31505c")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	launch.add_child(divider)
	text(launch, "방향키로 선택  ·  Enter로 확인", Rect2(28, 511, 300, 28), 15, MUTED)
	text(launch, "1인 플레이  /  2D 스토리 탐험", Rect2(28, 546, 300, 24), 13, Color("#839fa9"))
	start.grab_focus()
	for content: Control in [hero, launch]:
		content.modulate.a = 0.0
		create_tween().tween_property(content, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)

func add_menu_logo() -> void:
	var holder := Control.new()
	holder.name = "AgencyLogo"
	holder.custom_minimum_size = Vector2(144, 34)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(holder)
	var source := preload("res://art/pps_logo.png")
	var used := source.get_image().get_used_rect()
	var emblem := AtlasTexture.new()
	emblem.atlas = source
	emblem.region = Rect2i(used.position, Vector2i(int(source.get_width() * 0.43) - used.position.x, used.size.y))
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture = emblem
	picture.size = Vector2(34, 34)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(picture)
	var wordmark := text(holder, "조달청", Rect2(42, 0, 102, 34), 26, Color.WHITE)
	wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func add_character(portrait: Texture2D, bounds: Rect2, character_name: String, parent: Node = self) -> void:
	var glow := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#84f1d228"), Color("#84f1d200")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.texture = texture
	glow.position = Vector2(bounds.position.x - 10, bounds.end.y - 26)
	glow.size = Vector2(bounds.size.x + 20, 48)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glow)
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture = portrait
	picture.position = bounds.position
	picture.size = bounds.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	text(parent, character_name, Rect2(bounds.position.x, bounds.end.y + 8, bounds.size.x, 30), 19, ACCENT)

func button(parent: Node, caption: String, action: Callable, primary := false) -> Button:
	var control := MENU_BUTTON.new()
	control.text = caption
	control.custom_minimum_size = Vector2(0, 52)
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_color_override("font_color", Color("#092721") if primary else INK)
	control.add_theme_color_override("font_hover_color", Color("#092721") if primary else INK)
	control.add_theme_color_override("font_pressed_color", Color("#092721") if primary else INK)
	control.add_theme_color_override("font_focus_color", Color("#092721") if primary else INK)
	control.add_theme_stylebox_override("normal", style(ACCENT if primary else Color("#132b38"), Color("#476d77")))
	control.add_theme_stylebox_override("hover", style(Color("#bcffec") if primary else Color("#234550"), ACCENT))
	control.add_theme_stylebox_override("pressed", style(Color("#60bfa7") if primary else Color("#10232e"), ACCENT))
	var focus := style(Color.TRANSPARENT, ACCENT)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	control.add_theme_stylebox_override("focus", focus)
	parent.add_child(control)
	control.pressed.connect(activate_button.bind(control, action))
	return control

func update_menu_hint(hint: String) -> void:
	menu_hint.text = hint

func activate_button(control: Button, action: Callable) -> void:
	if starting or closing or control.disabled:
		return
	if control.get_parent() == menu:
		return_focus = control
	action.call()

func style(fill: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(2)
	result.set_corner_radius_all(10)
	return result

func text(parent: Node, caption: String, bounds: Rect2, font_size: int, color: Color) -> Label:
	var label := UI_LABEL.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = caption
	label.position = bounds.position
	label.size = bounds.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.configure(bounds.size, font_size)
	parent.add_child(label)
	return label

func show_controls() -> void:
	if is_instance_valid(popup):
		return
	menu.hide()
	popup = Control.new()
	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color("#061019ed")
	popup.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Panel.new()
	panel.position = Vector2(170, 62)
	panel.size = Vector2(940, 596)
	var frame := style(Color("#0e222eff"), Color("#4c777e"))
	frame.shadow_color = Color("#00070d80")
	frame.shadow_size = 18
	panel.add_theme_stylebox_override("panel", frame)
	popup.add_child(panel)
	text(panel, "조작법", Rect2(32, 24, 876, 48), 34, INK).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text(panel, "세 가지 기본 조작으로 도시를 탐험하세요.", Rect2(34, 78, 872, 28), 18, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text(panel, "기본 조작", Rect2(34, 122, 416, 26), 16, ACCENT).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text(panel, "선택과 메뉴", Rect2(490, 122, 416, 26), 16, Color("#ffcd95")).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	control_card(panel, Rect2(32, 158, 420, 96), "WASD", "캐릭터 이동", "방향키로도 움직일 수 있어요.", ACCENT)
	control_card(panel, Rect2(32, 266, 420, 96), "E", "조사 · 상호작용", "문 통과, 물자 들기와 내려놓기", ACCENT)
	control_card(panel, Rect2(32, 374, 420, 96), "Tab", "캐릭터 전환", "병원·비축창고에서 조달이 ↔ 조달호", ACCENT)
	var warm := Color("#ffcd95")
	control_card(panel, Rect2(488, 158, 420, 69), "1 / 2", "출동 캐릭터 선택", "오프닝 영상이 끝난 뒤 선택", warm)
	control_card(panel, Rect2(488, 239, 420, 69), "1 / 2 / 3", "분전반 장치 선택", "비축창고에서 전력을 보낼 장치 선택", warm)
	control_card(panel, Rect2(488, 320, 420, 69), "Enter", "버튼 선택 · 확인", "마우스로 클릭해도 돼요.", warm)
	control_card(panel, Rect2(488, 401, 420, 69), "Esc", "건너뛰기 · 닫기", "오프닝 영상 건너뛰기 / 이 창 닫기", warm)
	var divider := ColorRect.new()
	divider.position = Vector2(32, 492)
	divider.size = Vector2(876, 1)
	divider.color = Color("#31505b")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)
	text(panel, "목적지 근처에서는 화면의 E 안내를 확인하세요.", Rect2(34, 516, 540, 46), 16, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var back := button(panel, "돌아가기", close_information, true)
	back.position = Vector2(660, 516)
	back.size = Vector2(248, 56)
	back.grab_focus()

func show_settings() -> void:
	if is_instance_valid(popup):
		return
	menu.hide()
	popup = SETTINGS_PANEL.new()
	add_child(popup)
	popup.back_requested.connect(close_information)

func control_card(parent: Control, bounds: Rect2, key: String, heading: String, description: String, accent: Color) -> void:
	var card := Panel.new()
	card.position = bounds.position
	card.size = bounds.size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := style(Color("#152e3b"), Color("#294853"))
	background.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", background)
	parent.add_child(card)
	var keycap := Panel.new()
	keycap.position = Vector2(14, (bounds.size.y - 42) * 0.5)
	keycap.size = Vector2(88, 42)
	keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_style := style(Color("#203f4b"), accent.darkened(0.3))
	key_style.border_width_bottom = 4
	key_style.set_corner_radius_all(7)
	keycap.add_theme_stylebox_override("panel", key_style)
	card.add_child(keycap)
	text(keycap, key, Rect2(4, 2, 80, 34), 17, accent)
	var roomy := bounds.size.y > 80
	text(card, heading, Rect2(118, 15 if roomy else 9, 286, 26), 20 if roomy else 18, INK).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text(card, description, Rect2(118, 43 if roomy else 36, 286, 39 if roomy else 25), 16 if roomy else 15, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func show_description() -> void:
	show_information("게임 설명", "폭우로 공급망이 끊어진 2050년의 다온시.\n조달이와 조달호가 도시의 불빛을 되찾기 위해 출동합니다.\n\n병원의 비상전력을 복구하고, 과거 조달기록을 조사하세요.\n비축 원자재를 확보하고 정수·통신시설의 공급계획을 세우세요.\n\n두 캐릭터의 역할을 활용하는 1인용 2D 탐험 게임입니다.\n여러분의 마지막 발주가 도시의 내일을 결정합니다.")

func show_information(heading: String, body: String) -> void:
	if is_instance_valid(popup):
		return
	menu.hide()
	popup = Control.new()
	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color("#061019dd")
	popup.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Panel.new()
	panel.position = Vector2(220, 92)
	panel.size = Vector2(840, 536)
	panel.add_theme_stylebox_override("panel", style(Color("#102632"), Color("#4e8289")))
	popup.add_child(panel)
	text(panel, heading, Rect2(32, 24, 776, 50), 32, ACCENT)
	text(panel, body, Rect2(32, 92, 776, 326), 21, INK)
	var back := button(panel, "돌아가기", close_information, true)
	back.position = Vector2(270, 446)
	back.size = Vector2(300, 56)
	back.grab_focus()

func close_information() -> void:
	if not is_instance_valid(popup):
		return
	popup.hide()
	popup.queue_free()
	popup = null
	menu.show()
	if is_instance_valid(return_focus):
		return_focus.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if starting or closing:
		return
	if is_instance_valid(popup) and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_information()

func begin_opening() -> void:
	if starting or closing or is_instance_valid(popup):
		return
	starting = true
	lock_menu()
	await fade_out()
	var result := get_tree().change_scene_to_file("res://intro.tscn")
	if result != OK:
		starting = false
		for child in menu.get_children():
			if child is Button:
				child.disabled = false
		get_node("ExitFade").queue_free()
		menu_hint.text = "오프닝을 불러오지 못했습니다. 다시 시도해 주세요."
		if is_instance_valid(return_focus):
			return_focus.grab_focus()

func quit_game() -> void:
	if starting or closing or is_instance_valid(popup):
		return
	closing = true
	lock_menu()
	await fade_out()
	get_tree().quit()

func lock_menu() -> void:
	for child in menu.get_children():
		if child is Button:
			child.disabled = true
			child.refresh_feedback()

func fade_out() -> void:
	var curtain := ColorRect.new()
	curtain.name = "ExitFade"
	curtain.color = Color("#06121b00")
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fade := create_tween()
	fade.tween_property(curtain, "color:a", 1.0, 0.24)
	await fade.finished
