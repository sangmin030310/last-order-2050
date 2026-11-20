extends CanvasLayer
## Available only during exploration; no extra soundtrack or tooltips.

const FONT = preload("res://art/korean.otf")
const UI_LABEL = preload("res://ui_label.gd")
const MENU_BUTTON = preload("res://menu_button.gd")
const SETTINGS_PANEL = preload("res://settings_panel.gd")
const ACCENT := Color("#84f1d2")
const GAME_SCENES := ["prologue", "chapter_one", "hospital", "recovery", "archive_room", "stockroom", "dispatch_room"]

var surface: Control
var heading: Label
var detail: Label
var help_button: Button
var policy_button: Button
var report_button: Button
var settings_button: Button
var settings_screen: Control
var previous_focus: Control
var showing_help := false
var showing_policy := false
var showing_report := false
var policy_index := 0
var report_index := 0
var opened := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if opened:
			if is_instance_valid(settings_screen):
				close_settings()
			else:
				close()
		elif can_open():
			open()
		else:
			return
		get_viewport().set_input_as_handled()

func can_open() -> bool:
	var scene := get_tree().current_scene
	return is_instance_valid(scene) and scene.scene_file_path.get_file().get_basename() in GAME_SCENES and not scene.crossing and not get_tree().paused

func open() -> void:
	if opened or not can_open():
		return
	previous_focus = get_viewport().gui_get_focus_owner()
	opened = true
	showing_help = false
	showing_policy = false
	showing_report = false
	policy_index = 0
	report_index = 0
	surface = Control.new()
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = FONT
	surface.theme = theme
	var veil := ColorRect.new()
	veil.color = Color("#041018dc")
	surface.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := Panel.new()
	card.position = Vector2(340, 45)
	card.size = Vector2(600, 630)
	card.add_theme_stylebox_override("panel", style(Color("#102632"), Color("#537e86")))
	surface.add_child(card)
	heading = make_label(card, "잠시 쉬어가기", Rect2(32, 24, 536, 42), 30, Color.WHITE)
	detail = make_label(card, "", Rect2(32, 82, 536, 160), 18, Color("#bfd4d9"))
	detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var buttons := VBoxContainer.new()
	buttons.position = Vector2(32, 250)
	buttons.size = Vector2(536, 306)
	buttons.add_theme_constant_override("separation", 8)
	card.add_child(buttons)
	var resume := make_button(buttons, "계속하기", close)
	help_button = make_button(buttons, "조작법", toggle_help)
	policy_button = make_button(buttons, "조달정책 기록", cycle_policy)
	report_button = make_button(buttons, "현장 무전 기록", cycle_report)
	settings_button = make_button(buttons, "화면·글자 설정", show_settings)
	var menu_return := make_button(buttons, "시작 화면으로", return_to_menu)
	var menu_buttons: Array[Button] = [resume, help_button, policy_button, report_button, settings_button, menu_return]
	for index in range(menu_buttons.size()):
		var current := menu_buttons[index]
		current.focus_neighbor_top = current.get_path_to(menu_buttons[posmod(index - 1, menu_buttons.size())])
		current.focus_neighbor_bottom = current.get_path_to(menu_buttons[(index + 1) % menu_buttons.size()])
		current.focus_previous = current.focus_neighbor_top
		current.focus_next = current.focus_neighbor_bottom
	make_label(card, "Esc를 누르면 바로 게임으로 돌아갑니다.", Rect2(32, 584, 536, 24), 14, Color("#9db5bd"))
	update_detail()
	get_tree().paused = true
	resume.grab_focus()

func make_label(parent: Node, caption: String, bounds: Rect2, font_size: int, color: Color) -> Label:
	var label := UI_LABEL.new()
	label.text = caption
	label.position = bounds.position
	label.add_theme_font_override("font", FONT)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.configure(bounds.size, font_size)
	parent.add_child(label)
	return label

func style(fill: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(12)
	return result

func make_button(parent: Node, caption: String, action: Callable) -> Button:
	var button := MENU_BUTTON.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color.WHITE)
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("#102b31"))
	button.add_theme_stylebox_override("normal", style(Color("#183441"), Color("#446b76")))
	button.add_theme_stylebox_override("hover", style(Color("#aaffea"), ACCENT))
	button.add_theme_stylebox_override("pressed", style(Color("#60bfa7"), ACCENT))
	button.add_theme_stylebox_override("focus", style(Color("#aaffea"), ACCENT))
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func toggle_help() -> void:
	showing_help = not showing_help
	showing_policy = false
	showing_report = false
	help_button.text = "현재 목표" if showing_help else "조작법"
	update_detail()

func policy_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		{"title": "조달청의 역할", "body": "공공기관이 필요한 물품과 서비스를 적절하게 확보하도록 지원합니다.\n게임: 병원의 긴급 수요를 확인합니다.\n생활: 필요한 공공서비스가 이어지도록 돕습니다."}
	]
	if Story.request_received:
		entries.append({"title": "나라장터", "body": "나라장터는 공공조달의 입찰·계약 등을 전자적으로 지원합니다. 공공기관 사이의 물품 이관은 별도 절차를 확인합니다.\n게임: P-42 공급 경로를 비교합니다."})
	if Story.hospital_restored:
		entries.append({"title": "공공조달과 품질관리", "body": "공공기관의 수요에 맞춰 물품을 확보할 때는 가격뿐 아니라 규격·안전·납기와 정해진 절차를 확인합니다.\n게임: 시설팀 검수 후 병원 전력이 복구됐습니다."})
	if Story.records_linked:
		entries.append({"title": "공급망 위험", "body": "핵심 부품을 한 공급처에만 의존하면 여러 시설이 함께 흔들릴 수 있습니다.\n게임: S-17 집중을 찾아 대체 경로를 검토합니다."})
	if Story.reserve_approved:
		entries.append({"title": "국가 원자재 비축", "body": "주요 원자재를 비축하고, 이용 자격과 공급 조건을 확인해 정해진 절차에 따라 공급합니다.\n게임: 구리 2묶음의 출고·검수를 진행합니다."})
	if Story.copper_loaded:
		entries.append({"title": "긴급 공급계획", "body": "확보한 재고와 후속 생산 시간을 시설의 가동 한계에 맞춰 배분합니다.\n게임: 정수·통신시설의 배차 순서를 결정합니다."})
	return entries

func cycle_policy() -> void:
	var entries := policy_entries()
	policy_index = (policy_index + 1) % entries.size() if showing_policy else 0
	showing_policy = true
	showing_report = false
	showing_help = false
	help_button.text = "조작법"
	update_detail()

func cycle_report() -> void:
	var entries: Array[Dictionary] = Story.field_reports
	report_index = (report_index + 1) % entries.size() if showing_report and not entries.is_empty() else 0
	showing_report = true
	showing_policy = false
	showing_help = false
	help_button.text = "조작법"
	update_detail()

func update_detail() -> void:
	policy_button.text = "조달정책 기록"
	report_button.text = "현장 무전 기록"
	if showing_report:
		var entries: Array[Dictionary] = Story.field_reports
		if entries.is_empty():
			heading.text = "현장 무전 기록"
			detail.text = "아직 수신된 현장 무전이 없습니다.\n임무를 진행하면 현장 기록이 이곳에 쌓입니다."
		else:
			var entry: Dictionary = entries[report_index]
			heading.text = "현장 무전  %d / %d" % [report_index + 1, entries.size()]
			detail.text = str(entry["sender"]) + "\n\n" + str(entry["message"])
			report_button.text = "다음 무전 보기"
	elif showing_policy:
		var entries := policy_entries()
		var entry: Dictionary = entries[policy_index]
		heading.text = "조달정책 기록  %d / %d" % [policy_index + 1, entries.size()]
		detail.text = str(entry["title"]) + "\n\n" + str(entry["body"])
		policy_button.text = "다음 기록 보기"
	elif showing_help:
		heading.text = "조작법"
		policy_button.text = "조달정책 기록"
		detail.text = "WASD / 방향키  ·  이동\nE  ·  조사, 문 통과, 물자 들기·내려놓기\nTab  ·  병원·비축창고에서 캐릭터 전환\n1 / 2 / 3  ·  비축창고 분전반 장치 선택\nEnter / 마우스 클릭  ·  버튼 확인"
	else:
		heading.text = "잠시 쉬어가기"
		policy_button.text = "조달정책 기록"
		var scene := get_tree().current_scene
		detail.text = "현재 목표\n\n" + scene.mission_title.text + "\n" + scene.mission_detail.text

func show_settings() -> void:
	if is_instance_valid(settings_screen):
		return
	settings_screen = SETTINGS_PANEL.new()
	surface.add_child(settings_screen)
	settings_screen.back_requested.connect(close_settings)

func close_settings() -> void:
	if not is_instance_valid(settings_screen):
		return
	settings_screen.hide()
	settings_screen.queue_free()
	settings_screen = null
	settings_button.grab_focus()

func close() -> void:
	if not opened:
		return
	if is_instance_valid(settings_screen):
		settings_screen.queue_free()
		settings_screen = null
	opened = false
	get_tree().paused = false
	surface.hide()
	surface.queue_free()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()

func return_to_menu() -> void:
	if not opened:
		return
	close()
	get_tree().change_scene_to_file.call_deferred("res://main_menu.tscn")
