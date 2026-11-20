extends Node2D

enum Phase { TITLE, TERMINAL, RADIO, TUNING, HANDOFF, COMPLETE }

const FONT = preload("res://art/korean.otf")
const BIRD = preload("res://art/jodari.webp")
const UI_LABEL = preload("res://ui_label.gd")
const GAME_EFFECTS = preload("res://game_effects.gd")
const OBJECTIVE_ARROW = preload("res://objective_arrow.gd")
const MENU_BUTTON = preload("res://menu_button.gd")
const MAP_SIZE := Vector2(1280, 720)
const ACCENT := Color("#84f1d2")
const TEXT := Color("#ecf6f5")
const DIM := Color("#adc2c6")
const AMBER := Color("#ffca83")
const STORM := Color("#101d26")
const SPEED := 330.0
const REACH := 56.0
const SIGNAL_CENTER := 0.62
const SIGNAL_SPEED := 0.65
const SIGNAL_TIME_LIMIT := 5.0
const SIGNAL_TRACK_WIDTH := 672.0
const PROMPT_FONT_SIZE := 14
const PROMPT_HEIGHT := 28.0

@onready var player: CharacterBody2D = $Actors/Player
@onready var companion: CharacterBody2D = $Actors/Companion
@onready var bird: Sprite2D = $Actors/Player/Sprite
@onready var tiger: Sprite2D = $Actors/Companion/Sprite
@onready var terminal: Marker2D = $Terminal
@onready var radio: Marker2D = $Radio
@onready var interface: CanvasLayer = $Interface

var phase: Phase = Phase.TITLE
var elapsed := 0.0
var radio_powered := false
var hud_chapter: Label
var mission_title: Label
var mission_detail: Label
var hud_clock: Label
var pin: Label
var interaction: Label
var overlay: Control
var overlay_action: Button
var player_start: Vector2
var companion_start: Vector2
var trail: Array[Vector2] = []
var crossing := false
var effects
var toast: Panel
var scene_fade: ColorRect
var signal_value := 0.0
var signal_direction := 1.0
var signal_attempts := 0
var signal_elapsed := 0.0
var signal_timed_out := false
var signal_needle: ColorRect
var signal_zone: ColorRect
var signal_time_fill: ColorRect
var signal_feedback: Label
var signal_timer_label: Label
var signal_lock_button: Button

func _ready() -> void:
	player_start = player.position
	companion_start = companion.position
	build_hud()
	begin()

func _physics_process(delta: float) -> void:
	elapsed += delta
	if phase == Phase.TUNING and not signal_timed_out:
		signal_elapsed += delta
		if signal_elapsed >= SIGNAL_TIME_LIMIT:
			signal_elapsed = SIGNAL_TIME_LIMIT
			signal_timed_out = true
			signal_feedback.text = "신호가 사라졌습니다. 다시 시도해 주세요."
			signal_feedback.add_theme_color_override("font_color", AMBER)
			signal_lock_button.text = "다시 시도  E / Enter"
			signal_timer_label.text = "시간 초과"
			signal_time_fill.size.x = 0.0
			return
		signal_timer_label.text = "남은 시간  %.1f초" % (SIGNAL_TIME_LIMIT - signal_elapsed)
		signal_time_fill.size.x = SIGNAL_TRACK_WIDTH * (1.0 - signal_elapsed / SIGNAL_TIME_LIMIT)
		signal_value += delta * SIGNAL_SPEED * signal_direction
		if signal_value >= 1.0:
			signal_value = 1.0
			signal_direction = -1.0
		elif signal_value <= 0.0:
			signal_value = 0.0
			signal_direction = 1.0
		if is_instance_valid(signal_needle):
			signal_needle.position.x = 43.0 + signal_value * SIGNAL_TRACK_WIDTH
	if not crossing and (phase == Phase.TERMINAL or phase == Phase.RADIO):
		update_walk(delta)
		var at := lead_body().position
		var distance := at.distance_to(target().position)
		interaction.visible = distance <= REACH
		if interaction.visible:
			place_interaction_prompt(interaction, interaction.text, at, at.y + 22.0)
		pin.position = target().position + Vector2(-85, -130)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if phase != Phase.TUNING or get_tree().paused or not event is InputEventKey:
		return
	if event.pressed and not event.echo and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		lock_signal()

func _unhandled_input(event: InputEvent) -> void:
	if not crossing and event.is_action_pressed("interact") and not event.is_echo():
		interact()

func lead_body() -> CharacterBody2D:
	return companion if Story.lead_tiger else player

func controlled_actor() -> CharacterBody2D:
	return lead_body()

func notify(message: String, detail := "진행 업데이트") -> void:
	if is_instance_valid(toast):
		toast.hide()
		toast.queue_free()
	toast = panel(interface, Vector2(550, 28), Vector2(440, 84), Color("#102e38fa"), ACCENT)
	toast.name = "ProgressNotice"
	toast.z_index = 3
	write_label(toast, detail, Vector2(16, 6), Vector2(408, 20), 12, ACCENT)
	write_label(toast, message, Vector2(16, 28), Vector2(408, 48), 19, TEXT)
	toast.modulate.a = 0.0
	var animation := toast.create_tween()
	animation.tween_property(toast, "modulate:a", 1.0, 0.16)
	animation.tween_interval(2.6)
	animation.tween_property(toast, "modulate:a", 0.0, 0.3)
	animation.tween_callback(toast.hide)

func milestone(at: Vector2, message: String, detail: String) -> void:
	effects.burst(at, ACCENT, true)
	notify(message, detail)
	var flash := ColorRect.new()
	flash.color = Color("#84f1d2")
	flash.color.a = 0.12
	flash.size = MAP_SIZE
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 2
	interface.add_child(flash)
	var fade := flash.create_tween()
	fade.tween_property(flash, "color:a", 0.0, 0.46)
	fade.tween_callback(flash.queue_free)

func actor_changed() -> void:
	if is_instance_valid(interaction):
		interaction.hide()
	var tiger_active := controlled_actor() == companion
	var actor_name := "조달호" if tiger_active else "조달이"
	var role := "현장 물류 · 시설팀 협력" if tiger_active else "조달 정보 조사 · 물자 운반"
	effects.burst(controlled_actor().position, ACCENT)
	notify(actor_name + "  ·  " + role, "조작 캐릭터 전환")

func update_walk(delta: float) -> void:
	var leader := lead_body()
	var follower := player if Story.lead_tiger else companion
	var leader_sprite := tiger if Story.lead_tiger else bird
	move_actor(delta, leader, leader_sprite, -32.0 if Story.lead_tiger else -43.0)
	if leader.get_real_velocity().length() > 4.0:
		if trail.is_empty() or trail.back().distance_to(leader.position) > 13.0:
			trail.append(leader.position)
			if trail.size() > 12:
				trail.pop_front()
	var next: Vector2 = leader.position if trail.is_empty() else trail[0]
	if trail.size() > 1 and follower.position.distance_to(next) < 13.0:
		trail.pop_front()
		next = trail[0]
	if follower.position.distance_to(leader.position) > 48.0:
		var travel_direction := next - follower.position
		follower.velocity = travel_direction.limit_length(SPEED * delta) / delta
		follower.move_and_slide()
	else:
		follower.velocity = Vector2.ZERO

func move_actor(_delta: float, body: CharacterBody2D, _sprite: Sprite2D, _base_height: float, speed := SPEED) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	body.velocity = direction * speed
	body.move_and_slide()

func target() -> Marker2D:
	return terminal if phase == Phase.TERMINAL else radio

func navigation_hint() -> Dictionary:
	if phase not in [Phase.TERMINAL, Phase.RADIO]:
		return {}
	return make_navigation_hint(lead_body(), [target().position], REACH)

func make_navigation_hint(actor: CharacterBody2D, destinations: Array, reach := 42.0) -> Dictionary:
	if destinations.is_empty():
		return {}
	var closest: Vector2 = destinations[0]
	for destination: Vector2 in destinations:
		if actor.position.distance_squared_to(destination) < actor.position.distance_squared_to(closest):
			closest = destination
	return {"actor": actor, "target": closest, "reach": reach}

func interact() -> void:
	if phase != Phase.TERMINAL and phase != Phase.RADIO:
		return
	if lead_body().position.distance_to(target().position) > REACH:
		return
	effects.burst(target().position, ACCENT)
	if phase == Phase.TERMINAL:
		phase = Phase.RADIO
		update_objective("잡음 속 병원 신호", "교차로 중계기에서 수신 신호를 맞추세요.", "현장 중계기", "E  ·  무전 신호 조정")
		notify("병원 신호가 잡혔습니다. 중계기에서 주파수를 맞추세요.", "연락망 복구")
	else:
		show_signal_tuning()

func show_signal_tuning() -> void:
	phase = Phase.TUNING
	pin.hide()
	interaction.hide()
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
	signal_value = 0.0
	signal_direction = 1.0
	signal_attempts = 0
	signal_elapsed = 0.0
	signal_timed_out = false
	overlay = Control.new()
	overlay.size = MAP_SIZE
	interface.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color("#07131bd8")
	veil.size = MAP_SIZE
	overlay.add_child(veil)
	var box := panel(overlay, Vector2(260, 145), Vector2(760, 430), Color("#0e2130fa"), Color("#3c6e75"))
	write_label(box, "현장 중계기  /  병원 무전", Vector2(40, 26), Vector2(680, 28), 16, ACCENT)
	write_label(box, "잡음 속 신호를 붙잡으세요", Vector2(40, 65), Vector2(680, 63), 32, TEXT)
	write_label(box, "움직이는 바가 초록 구간에 들어올 때 E 또는 아래 버튼을 누르세요.", Vector2(42, 145), Vector2(675, 48), 18, DIM, true)
	var time_track := ColorRect.new()
	time_track.color = Color("#294550")
	time_track.position = Vector2(43, 210)
	time_track.size = Vector2(SIGNAL_TRACK_WIDTH, 6)
	box.add_child(time_track)
	signal_time_fill = ColorRect.new()
	signal_time_fill.color = ACCENT
	signal_time_fill.position = time_track.position
	signal_time_fill.size = time_track.size
	box.add_child(signal_time_fill)
	var track := ColorRect.new()
	track.color = Color("#294550")
	track.position = Vector2(43, 242)
	track.size = Vector2(SIGNAL_TRACK_WIDTH, 30)
	box.add_child(track)
	signal_zone = ColorRect.new()
	signal_zone.color = ACCENT
	signal_zone.position = Vector2(43 + (SIGNAL_CENTER - 0.12) * SIGNAL_TRACK_WIDTH, 242)
	signal_zone.size = Vector2(0.24 * SIGNAL_TRACK_WIDTH, 30)
	box.add_child(signal_zone)
	signal_needle = ColorRect.new()
	signal_needle.color = TEXT
	signal_needle.position = Vector2(43, 235)
	signal_needle.size = Vector2(4, 44)
	box.add_child(signal_needle)
	signal_feedback = write_label(box, "신호가 강해지는 순간에 고정하세요.", Vector2(42, 284), Vector2(675, 37), 17, TEXT)
	signal_timer_label = write_label(box, "남은 시간  %.1f초" % SIGNAL_TIME_LIMIT, Vector2(490, 350), Vector2(225, 44), 17, AMBER)
	var lock_button := MENU_BUTTON.new()
	signal_lock_button = lock_button
	lock_button.text = "신호 고정  E / Enter"
	lock_button.position = Vector2(43, 343)
	lock_button.custom_minimum_size = Vector2(286, 56)
	lock_button.add_theme_font_override("font", FONT)
	lock_button.add_theme_font_size_override("font_size", 20)
	lock_button.add_theme_stylebox_override("normal", style_box(ACCENT, ACCENT, 8))
	lock_button.add_theme_stylebox_override("hover", style_box(Color("#b5ffe9"), ACCENT, 8))
	lock_button.add_theme_stylebox_override("pressed", style_box(Color("#62ccb3"), ACCENT, 8))
	for state_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		lock_button.add_theme_color_override(state_name, Color("#0b2520"))
	polish_button(lock_button)
	box.add_child(lock_button)
	lock_button.pressed.connect(lock_signal)
	lock_button.grab_focus()
	reveal_overlay()

func lock_signal() -> void:
	if phase != Phase.TUNING:
		return
	if signal_timed_out:
		signal_value = 0.0
		signal_direction = 1.0
		signal_elapsed = 0.0
		signal_timed_out = false
		signal_needle.position.x = 43.0
		signal_timer_label.text = "남은 시간  %.1f초" % SIGNAL_TIME_LIMIT
		signal_time_fill.size.x = SIGNAL_TRACK_WIDTH
		signal_lock_button.text = "신호 고정  E / Enter"
		signal_feedback.text = "신호가 다시 잡혔습니다. 초록 구간에서 고정하세요."
		signal_feedback.add_theme_color_override("font_color", TEXT)
		return
	var tolerance := 0.2 if signal_attempts >= 2 else 0.12
	if absf(signal_value - SIGNAL_CENTER) > tolerance:
		signal_attempts += 1
		signal_feedback.text = "아직 잡음이 큽니다. 초록 구간에서 다시 고정하세요."
		signal_feedback.add_theme_color_override("font_color", AMBER)
		signal_needle.color = AMBER
		create_tween().tween_property(signal_needle, "color", TEXT, 0.3)
		effects.burst(radio.position, AMBER)
		if signal_attempts == 2:
			signal_zone.position.x = 43 + (SIGNAL_CENTER - 0.2) * SIGNAL_TRACK_WIDTH
			signal_zone.size.x = 0.4 * SIGNAL_TRACK_WIDTH
		return
	phase = Phase.HANDOFF
	radio_powered = true
	milestone(radio.position, "병원 무전 연결 · 긴급 요청 수신", "신호 복구 성공")
	mission_title.text = "병원 긴급 요청 수신"
	mission_detail.text = "전력 제어부품 P-42 · 1개 · 12시간 이내"
	Story.add_field_report(&"hospital_call", "다온시 공공병원 시설팀", "비상전력은 12시간 남았습니다. P-42 또는 안전성이 검증된 호환품 1개가 필요합니다.")
	show_overlay(
		"긴급 호출  /  다온시 공공병원",
		"임시 전력 12시간",
		"“폭우 이후 비상전력이 불안정합니다. P-42 전력 제어부품 한 개가 필요합니다. 호환성과 안전이 확인된 대체품도 사용할 수 있습니다.”",
		"요청 접수",
		accept_request
	)

func begin() -> void:
	if is_instance_valid(overlay):
		overlay.hide()
	phase = Phase.TITLE
	radio_powered = false
	player.velocity = Vector2.ZERO
	player.position = player_start
	companion.position = companion_start
	trail.clear()
	hud_clock.text = "72시간"
	update_objective("끊긴 병원 무전 복구", "왼쪽 구호본부 단말기에 다가가 E를 누르세요.", "구호본부", "E  ·  단말기 가동")
	pin.hide()
	show_overlay(
		"2050년 다온시  /  조달청 재난 긴급조달 지원팀",
		"병원과 연락이 끊겼다",
		"조달이: 폭우 뒤 병원 무전이 끊겼어. 어떤 물품이 필요한지부터 알아내자.\n조달호: 내가 중계기 전원을 확인할게. 구호본부 단말기부터 켜 줘!",
		"무전 복구 시작", start_mission
	)

func start_mission() -> void:
	overlay.hide()
	phase = Phase.TERMINAL
	pin.show()
	notify("구호본부 단말기에서 병원의 긴급 수요를 확인하세요.", "긴급조달 지원팀")

func accept_request() -> void:
	phase = Phase.COMPLETE
	milestone(radio.position, "병원 긴급 요청을 접수했습니다.", "현장 무전 연결")
	hud_clock.text = "72시간"
	mission_title.text = "긴급 요청 접수 완료"
	mission_detail.text = "병원 시설팀과 부품 확보에 착수합니다."
	show_overlay(
		"프롤로그 완료  /  다음 임무",
		"1장  꺼져가는 생명의 불빛",
		"조달이: “규격과 납기를 확인해 부품을 확보하자.”\n조달호: “병원 시설팀이 안전을 검증하고 설치할 수 있도록 지원할게.”",
		"1장 시작",
		enter_chapter_one
	)

func enter_chapter_one() -> void:
	travel("res://chapter_one.tscn")

func travel(path: String) -> void:
	if crossing:
		return
	crossing = true
	interaction.hide()
	var curtain := ColorRect.new()
	curtain.size = MAP_SIZE
	curtain.color = Color("#07131b00")
	interface.add_child(curtain)
	var fade := create_tween()
	fade.tween_property(curtain, "color", Color("#07131b"), 0.22)
	await fade.finished
	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		push_error("Could not load scene: " + path)
		var restore := create_tween()
		restore.tween_property(curtain, "color:a", 0.0, 0.18)
		restore.tween_callback(curtain.queue_free)
		crossing = false
		notify("장면을 불러오지 못했습니다. 잠시 후 다시 시도하세요.", "이동 실패")

func update_objective(title: String, detail: String, marker: String, prompt: String) -> void:
	mission_title.text = title
	mission_detail.text = detail
	pin.text = marker
	pin.position = target().position + Vector2(-85, -130)
	pin.show()
	interaction.text = prompt
	interaction.hide()

func style_box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color("#020b1238")
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 3)
	return box

func polish_button(control: Button) -> void:
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var focus := style_box(Color.TRANSPARENT, ACCENT, 8)
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	control.add_theme_stylebox_override("focus", focus)

func polish_prompt(control: Label) -> void:
	var background := style_box(Color("#071b26eb"), Color("#447880"), 7)
	background.shadow_size = 2
	control.add_theme_stylebox_override("normal", background)

func place_interaction_prompt(control: Label, caption: String, actor_position: Vector2, y: float) -> void:
	if control.get_meta("prompt_caption", "") != caption:
		control.set_meta("prompt_caption", caption)
		control.text = caption
		var text_width := FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, PROMPT_FONT_SIZE).x
		var width := clampf(text_width + 32.0, 128.0, 300.0)
		control.call("configure", Vector2(width, PROMPT_HEIGHT), PROMPT_FONT_SIZE)
	var margin := 18.0
	control.position = Vector2(
		clampf(actor_position.x - control.size.x * 0.5, margin, MAP_SIZE.x - margin - control.size.x),
		clampf(y, 155.0, 615.0 - control.size.y)
	)

func write_label(parent: Node, text: String, position_at: Vector2, bounds: Vector2, font_size: int, color: Color, _wrap := false) -> Label:
	var label := UI_LABEL.new()
	# Set wrapping before text/size: otherwise the unwrapped minimum width
	# expands the control before Godot can lay out its paragraph.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.position = position_at
	label.size = bounds
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.configure(bounds, font_size)
	parent.add_child(label)
	return label

func panel(parent: Node, position_at: Vector2, bounds: Vector2, fill: Color, border: Color) -> Panel:
	var box := Panel.new()
	box.position = position_at
	box.size = bounds
	box.add_theme_stylebox_override("panel", style_box(fill, border, 10))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box

func build_hud() -> void:
	if not has_node("ObjectiveArrow"):
		var arrow := OBJECTIVE_ARROW.new()
		arrow.name = "ObjectiveArrow"
		add_child(arrow)
	if not is_instance_valid(effects):
		effects = GAME_EFFECTS.new()
		effects.name = "GameEffects"
		add_child(effects)
	var left := panel(interface, Vector2(27, 24), Vector2(495, 122), Color("#0b1925ed"), Color("#386d76"))
	hud_chapter = write_label(left, "프롤로그   /   도시가 멈추는 날", Vector2(17, 9), Vector2(410, 22), 13, ACCENT)
	mission_title = write_label(left, "다온시 긴급 대응", Vector2(17, 31), Vector2(410, 35), 25, TEXT)
	mission_detail = write_label(left, "구호본부와 병원의 연락을 복구하세요.", Vector2(17, 69), Vector2(460, 42), 15, DIM, true)
	var right := panel(interface, Vector2(1029, 24), Vector2(224, 82), Color("#0b1925ed"), Color("#766449"))
	write_label(right, "연쇄 중단 예상 시점까지", Vector2(17, 9), Vector2(190, 21), 13, DIM)
	hud_clock = write_label(right, "72시간", Vector2(17, 34), Vector2(190, 40), 30, AMBER)
	var bottom := panel(interface, Vector2(27, 651), Vector2(452, 43), Color("#0b1925e6"), Color("#37535d"))
	var lead_name := "조달호" if Story.lead_tiger else "조달이"
	write_label(bottom, "%s 팀  ·  WASD/방향키 이동  ·  E 조사  ·  Esc 메뉴" % lead_name, Vector2(15, 0), Vector2(420, 43), 14, TEXT)
	var zone := panel(interface, Vector2(1030, 652), Vector2(223, 42), Color("#0b1925e6"), Color("#37535d"))
	var locations := {"prologue": "구호본부", "chapter_one": "동부 거리", "hospital": "공공병원", "recovery": "산업 구역", "archive_room": "조달기록실", "stockroom": "비축창고", "dispatch_room": "재난 대응 상황실"}
	write_label(zone, "다온시  /  " + str(locations.get(scene_file_path.get_file().get_basename(), "현장")), Vector2(12, 0), Vector2(198, 42), 14, DIM)
	pin = write_label(interface, "", Vector2.ZERO, Vector2(170, 30), 18, AMBER)
	pin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin.add_theme_color_override("font_outline_color", STORM)
	pin.add_theme_constant_override("outline_size", 9)
	interaction = write_label(interface, "", Vector2.ZERO, Vector2(200, PROMPT_HEIGHT), PROMPT_FONT_SIZE, ACCENT)
	interaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction.add_theme_color_override("font_outline_color", STORM)
	interaction.add_theme_constant_override("outline_size", 7)
	polish_prompt(interaction)
	interaction.hide()
	# Fade the world in while the HUD remains immediately legible.
	scene_fade = ColorRect.new()
	scene_fade.size = MAP_SIZE
	scene_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_fade.color = Color("#07131b")
	scene_fade.z_index = -1
	interface.add_child(scene_fade)
	var arrival := scene_fade.create_tween()
	arrival.tween_property(scene_fade, "color:a", 0.0, 0.32)
	arrival.tween_callback(scene_fade.queue_free)

func show_overlay(kicker: String, title: String, detail: String, button_text: String, on_press: Callable) -> void:
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
	overlay = Control.new()
	overlay.size = MAP_SIZE
	interface.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color("#07131bc9")
	veil.size = MAP_SIZE
	overlay.add_child(veil)
	var box := panel(overlay, Vector2(260, 145), Vector2(760, 430), Color("#0e2130fa"), Color("#3c6e75"))
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = tiger.texture if Story.lead_tiger else BIRD
	portrait.position = Vector2(568, 24)
	portrait.size = Vector2(148, 132)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait)
	write_label(box, kicker, Vector2(40, 28), Vector2(500, 28), 15, ACCENT)
	write_label(box, title, Vector2(40, 68), Vector2(500, 86), 36 if title.length() < 13 else 30, TEXT, true)
	var body := write_label(box, detail, Vector2(40, 174), Vector2(680, 135), 19, TEXT, true)
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	overlay_action = MENU_BUTTON.new()
	overlay_action.text = button_text
	overlay_action.position = Vector2(43, 325)
	overlay_action.custom_minimum_size = Vector2(240, 56)
	overlay_action.add_theme_font_override("font", FONT)
	overlay_action.add_theme_font_size_override("font_size", 20)
	for state_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		overlay_action.add_theme_color_override(state_name, Color("#0b2520"))
	overlay_action.add_theme_stylebox_override("normal", style_box(ACCENT, ACCENT, 8))
	overlay_action.add_theme_stylebox_override("hover", style_box(Color("#b5ffe9"), ACCENT, 8))
	overlay_action.add_theme_stylebox_override("pressed", style_box(Color("#62ccb3"), ACCENT, 8))
	polish_button(overlay_action)
	overlay_action.pressed.connect(on_press)
	box.add_child(overlay_action)
	overlay_action.grab_focus()
	# A short entrance motion makes critical story updates easier to notice.
	box.position += Vector2(0, 12)
	var settle := create_tween()
	settle.tween_property(box, "position:y", box.position.y - 12, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal_overlay()

func reveal_overlay() -> void:
	overlay.modulate.a = 0.0
	var reveal := create_tween()
	reveal.tween_property(overlay, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.022, 0.087, 0.14, 0.26 if not radio_powered else 0.15))
	for i in range(52):
		var x := fposmod(float(i * 131) + elapsed * 35.0, 1310.0)
		var y := fposmod(float(i * 89) + elapsed * (164.0 + (i % 5) * 11.0), 750.0)
		draw_line(Vector2(x, y), Vector2(x + 5.0, y + 17.0), Color(0.63, 0.81, 0.9, 0.15), 1.0, true)
	if phase == Phase.TERMINAL or phase == Phase.RADIO:
		var here := target().position
		var pulse := 0.5 + sin(elapsed * 3.0) * 0.25
		draw_arc(here, 18.0 + pulse * 8.0, 0.0, TAU, 36, Color(1.0, 0.78, 0.43, pulse), 2.0, true)
		draw_circle(here, 5.0, AMBER)
