extends "res://prologue.gd"

const PAD := Vector2(402, 524)
const DESK := Vector2(640, 316)
const EXIT := Vector2(640, 610)
const RELEASE := Vector2(738, 348)
const PAD_RADIUS := 33.0

@onready var gate: CollisionShape2D = $Barrier/Gate

var active_tiger := false
var unlocked := false
var modal := false
var nearby_hint: Label
var pad_text: Label
var desk_text: Label
var exit_text: Label
var release_text: Label
var controls_text: Label
var wrong_pad_seen := false
var power_indicator: Panel
var power_indicator_text: Label
var restored_light := 0.0

func _ready() -> void:
	active_tiger = Story.lead_tiger
	unlocked = Story.hospital_open
	restored_light = 1.0 if Story.hospital_restored else 0.0
	build_hud()
	pin.hide()
	hud_chapter.text = "1장  /  다온시 공공병원 내부"
	var keys := panel(interface, Vector2(480, 650), Vector2(516, 44), Color("#0b1925ed"), Color("#37535d"))
	controls_text = write_label(keys, "", Vector2(13, 0), Vector2(489, 44), 16, TEXT)
	pad_text = tag("조달호 보조 발판", PAD)
	desk_text = tag("시설팀 단말기", DESK)
	exit_text = tag("거리로 나가기", EXIT + Vector2(0, 60))
	release_text = tag("문 고정 스위치", RELEASE + Vector2(45, 0))
	power_indicator = panel(interface, Vector2(1029, 114), Vector2(224, 44), Color("#0b1925e8"), Color("#766449"))
	power_indicator_text = write_label(power_indicator, "", Vector2(12, 0), Vector2(200, 44), 16, AMBER)
	nearby_hint = write_label(interface, "", Vector2(420, 600), Vector2(200, PROMPT_HEIGHT), PROMPT_FONT_SIZE, ACCENT)
	nearby_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nearby_hint.add_theme_color_override("font_outline_color", STORM)
	nearby_hint.add_theme_constant_override("outline_size", 7)
	polish_prompt(nearby_hint)
	refresh_hospital()
	sync_gate()

func tag(title: String, at: Vector2) -> Label:
	var label := write_label(interface, title, at + Vector2(-103, -106), Vector2(206, 31), 15, DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", STORM)
	label.add_theme_constant_override("outline_size", 8)
	return label

func _unhandled_input(event: InputEvent) -> void:
	if crossing or modal or event.is_echo():
		return
	if event.is_action_pressed("switch_actor"):
		active_tiger = not active_tiger
		refresh_hospital()
		actor_changed()
	elif event.is_action_pressed("interact"):
		interact()

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not crossing and not modal:
		var body := companion if active_tiger else player
		var sprite := tiger if active_tiger else bird
		move_actor(delta, body, sprite, -32.0 if active_tiger else -43.0)
		sync_gate()
		update_pad_feedback()
		if not unlocked:
			if pad_pressed():
				mission_detail.text = "Tab으로 조달이를 전환해 문 너머 스위치에 E."
			else:
				mission_detail.text = "조달호로 왼쪽 전력 발판에 올라가세요." if active_tiger else "Tab으로 조달호를 조작해 왼쪽 발판에 세우세요."
		var prompt := available_action()
		nearby_hint.visible = not prompt.is_empty()
		if nearby_hint.visible:
			var label_y := body.position.y - 95 if body.position.y > 565 else body.position.y + 16
			place_interaction_prompt(nearby_hint, prompt, body.position, label_y)
	queue_redraw()

func sync_gate() -> void:
	var in_gate := Rect2(552, 388, 176, 43)
	var occupied := in_gate.has_point(player.position) or in_gate.has_point(companion.position)
	var open := unlocked or pad_pressed() or (gate.disabled and occupied)
	if gate.disabled != open:
		gate.set_deferred("disabled", open)
		effects.burst(Vector2(640, 418), ACCENT if open else AMBER)

func pad_pressed() -> bool:
	return companion.position.distance_to(PAD) <= PAD_RADIUS

func wrong_actor_on_pad() -> bool:
	return not unlocked and not active_tiger and not pad_pressed() and player.position.distance_to(PAD) <= PAD_RADIUS

func update_pad_feedback() -> void:
	var wrong_pad := wrong_actor_on_pad()
	if wrong_pad and not wrong_pad_seen:
		wrong_pad_seen = true
		notify("이 발판은 조달호가 맡아야 해요. Tab으로 전환하세요.", "조작 캐릭터 확인")
		effects.burst(PAD, AMBER)
	elif not wrong_pad:
		wrong_pad_seen = false

func controlled_actor() -> CharacterBody2D:
	return companion if active_tiger else player

func navigation_hint() -> Dictionary:
	var actor := companion if active_tiger else player
	var destination := DESK
	if not unlocked:
		if not pad_pressed():
			return make_navigation_hint(actor, [PAD], PAD_RADIUS) if active_tiger else {}
		if active_tiger:
			return {} # Keep the tiger on the pad while the player switches actors.
		destination = RELEASE
	elif Story.request_received and Story.hospital_route.is_empty():
		destination = EXIT
	# Route cross-room travel through the actual doorway, not through the wall.
	if (actor.position.y - 410.0) * (destination.y - 410.0) < 0:
		var approach := Vector2(640, 450 if actor.position.y > 410 else 370)
		if absf(actor.position.x - 640) > 35:
			destination = approach
		else:
			destination = Vector2(640, 365 if actor.position.y > 410 else 455)
	return make_navigation_hint(actor, [destination], 25.0 if destination == PAD else 38.0)

func refresh_hospital() -> void:
	controls_text.text = "조작 중  %s  ·  Tab 전환" % ("조달호" if active_tiger else "조달이")
	power_indicator.add_theme_stylebox_override("panel", style_box(Color("#0b1925e8"), ACCENT if Story.hospital_restored else AMBER, 10))
	power_indicator_text.text = "●  비상전력 정상" if Story.hospital_restored else "○  비상전력 불안정"
	power_indicator_text.add_theme_color_override("font_color", ACCENT if Story.hospital_restored else AMBER)
	hud_clock.text = "%d시간" % Story.city_hours
	pad_text.visible = not unlocked and not pad_pressed()
	release_text.visible = not unlocked and pad_pressed()
	desk_text.visible = unlocked and not Story.hospital_restored
	exit_text.visible = true
	if Story.hospital_restored:
		mission_title.text = "병원 비상전력 복구 완료"
		mission_detail.text = "시설팀이 장비를 다시 가동했습니다."
	elif not unlocked:
		mission_title.text = "시설팀 지정 보조장치로 통로 열기"
		mission_detail.text = "Tab으로 조달호 전환 → 허가된 발판에 세우기"
	elif Story.hospital_route.is_empty():
		mission_title.text = "병원 시설팀의 요청 확인"
		mission_detail.text = "시설팀 단말기를 조사하고 밖으로 나가세요."
	else:
		mission_title.text = "검증된 부품 인계"
		mission_detail.text = "시설팀 단말기로 가져온 부품을 전달하세요."

func available_action() -> String:
	var at := companion.position if active_tiger else player.position
	if wrong_actor_on_pad():
		return "Tab  ·  조달호로 전환"
	if not unlocked and not active_tiger and at.distance_to(RELEASE) <= 47:
		return "E  ·  방화문 열림 고정"
	if unlocked and at.distance_to(DESK) <= 52:
		return "E  ·  시설팀 단말기"
	if at.distance_to(EXIT) <= 42:
		return "E  ·  거리로 나가기"
	return ""

func interact() -> void:
	var at := companion.position if active_tiger else player.position
	if wrong_actor_on_pad():
		update_pad_feedback()
		return
	if not unlocked and not active_tiger and at.distance_to(RELEASE) <= 47:
		unlocked = true
		Story.hospital_open = true
		notify("방화문 열림 상태를 고정했습니다.", "협동 목표 완료")
		effects.burst(RELEASE, ACCENT, true)
		refresh_hospital()
		return
	if unlocked and at.distance_to(DESK) <= 52:
		modal = true
		nearby_hint.hide()
		if Story.hospital_route.is_empty():
			show_overlay("시설팀  /  긴급 요청서", "임시 전력 12시간",
				"요청: 다온시 공공병원 · P-42 1개\n용도: 비상전력 설비 복구\n기한: 12시간 · 규격·안전검사 적합\n\n시설팀 허가 통로입니다. 밖의 단말기에서 공급 경로를 비교하세요.",
				"요청서 받기", close_request)
		else:
			var delivery_note := "시설팀: 요청 규격과 검사 기록이 맞습니다. 유휴 물품 이관 확인도 받았어요. 임시 전력은 8시간 남았습니다. 설치는 저희가 맡겠습니다." if Story.hospital_route == &"warehouse" else "시설팀: 대체 D-42의 호환성과 안전검사를 확인했습니다. 임시 전력은 5시간 남았습니다. 설치는 저희가 맡겠습니다."
			show_overlay("시설팀  /  검수 기록", "부품 인계",
				delivery_note,
				"시설팀에 인계", restore_hospital)
		return
	if at.distance_to(EXIT) <= 42:
		Story.return_door = &"hospital"
		travel("res://chapter_one.tscn")

func close_request() -> void:
	Story.request_received = true
	notify("병원 요청서 확보 · 거리의 긴급조달 단말기를 확인하세요.", "다음 목표")
	overlay.hide()
	modal = false

func restore_hospital() -> void:
	Story.hospital_restored = true
	Story.add_field_report(&"hospital_restored", "공공병원 시설팀", "검수한 부품으로 비상전력이 복구됐습니다. 의료진은 진료를 이어갑니다. 정수·통신시설의 고장 신고도 확인해 주세요.")
	milestone(DESK, "병원 비상전력 복구 · 진료 계속", "1장 목표 완료")
	refresh_hospital()
	overlay.hide()
	var reveal := create_tween()
	reveal.tween_property(self, "restored_light", 1.0, 0.8)
	reveal.parallel().tween_property(power_indicator, "self_modulate", Color("#9fffe2"), 0.18)
	reveal.tween_property(power_indicator, "self_modulate", Color.WHITE, 0.5)
	reveal.tween_interval(0.55)
	reveal.tween_callback(show_restoration_result)

func show_restoration_result() -> void:
	show_overlay("1장 완료  /  병원 비상전력 복구", "불빛이 돌아왔다",
		"조달호: 병원 창문에 불이 돌아왔어!\n조달이: 시설팀이 검수한 부품을 설치했어. 그런데 정수·통신시설에서도 같은 고장이 보고됐어.\n\n새 단서  |  " + Story.hospital_clue,
		"조달기록실로 이동", travel.bind("res://recovery.tscn"))

func _draw() -> void:
	if not is_node_ready():
		return
	var shadow_alpha := lerpf(0.23 + sin(elapsed * 1.8) * 0.02, 0.10, restored_light)
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.04, 0.09, 0.14, shadow_alpha))
	if not unlocked:
		var pad_color := ACCENT if pad_pressed() else AMBER
		draw_circle(PAD, PAD_RADIUS, Color(pad_color, 0.27))
		draw_arc(PAD, PAD_RADIUS, 0, TAU, 40, pad_color, 3.0, true)
		draw_arc(RELEASE, 14, 0, TAU, 32, ACCENT, 2.5, true)
	if restored_light > 0.0:
		for radius in [102.0, 75.0, 43.0]:
			draw_circle(DESK + Vector2(0, -30), radius, Color(1.0, 0.78, 0.36, 0.12 * restored_light))
	draw_arc(EXIT, 22, 0, TAU, 34, ACCENT, 2.0, true)
