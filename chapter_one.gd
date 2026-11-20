extends "res://prologue.gd"

enum Mission { REQUEST, SEARCH, DELIVER, FINISHED }

const HOSPITAL := &"hospital"
const WAREHOUSE := &"warehouse"
const DEPOT := &"depot"
const TERMINAL := &"terminal"
const TITLES := {
	HOSPITAL: "공공병원",
	WAREHOUSE: "공공창고",
	DEPOT: "물류거점", TERMINAL: "긴급조달 단말기"
}
const OFFERS := {
	WAREHOUSE: {
		"heading": "공공기관 보유물품 관리대장",
		"items": [
			["P-40 전력 제어부품", "검사 완료 · 2시간", "시설팀 확인 결과, P-40은 요청 규격과 맞지 않습니다."],
			["P-42 유휴 전력 제어부품", "호환·안전 확인 · 4시간", ""],
			["P-42 침수 구역 반납품", "안전 미확인 · 3시간", "규격은 맞지만 침수 이후의 안전 검사가 필요합니다."]
		],
		"part": "P-42 유휴 부품",
		"hours": 4,
		"method": "보유 기관 재고 확인·이관 협의",
		"clue": "장비 관리대장 2042-17. 정수시설도 같은 계열의 P-42 설비를 사용한다."
	},
	DEPOT: {
		"heading": "국내외 공급사 재고",
		"items": [
			["P-42 해외 원제조사 부품", "검사 완료 · 120시간", "해외 납기는 120시간입니다. 병원의 임시 전력은 12시간 남았습니다."],
			["D-42 국내 대체 모듈", "호환·안전 확인 · 7시간", ""],
			["X-42 신규 모듈", "시험 대기 · 5시간", "이 제품은 병원 시설팀의 호환성·안전 확인을 기다리고 있습니다."]
		],
		"part": "D-42 대체 모듈",
		"hours": 7,
		"method": "긴급계약 요건·절차 검토",
		"clue": "2042년 공급사 납품 명세. 여러 시설이 서로 다른 장비를 쓰지만 핵심 부품의 공급처는 같았다."
	}
}

@onready var sites: Dictionary = {HOSPITAL: $Sites/Hospital, WAREHOUSE: $Sites/Warehouse, DEPOT: $Sites/Depot, TERMINAL: $Sites/ProcurementTerminal}

var mission := Mission.REQUEST
var selected_route: StringName
var modal_open := false
var terminal_open := false
var remaining_hours := 72
var hospital_hours := 12
var clue := ""
var markers: Dictionary = {}
var stock_label: Label
var battery_label: Label

func _ready() -> void:
	player_start = player.position
	companion_start = companion.position
	build_hud()
	hud_chapter.text = "1장   /   꺼져가는 생명의 불빛"
	pin.hide()
	var stock := panel(interface, Vector2(830, 650), Vector2(180, 44), Color("#0b1925ed"), Color("#37535d"))
	stock_label = write_label(stock, "가방  /  비어 있음", Vector2(12, 0), Vector2(160, 44), 14, TEXT)
	var battery := panel(interface, Vector2(1029, 115), Vector2(224, 65), Color("#0b1925ed"), Color("#766449"))
	write_label(battery, "병원 임시 전력", Vector2(17, 6), Vector2(190, 21), 13, DIM)
	battery_label = write_label(battery, "", Vector2(17, 30), Vector2(190, 29), 23, AMBER)
	for id: StringName in sites:
		var location: Marker2D = sites[id]
		var tag_y := -112 if id == TERMINAL else -70
		var tag := write_label(interface, TITLES[id], location.position + Vector2(-75, tag_y), Vector2(150, 30), 18, AMBER)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_color_override("font_outline_color", STORM)
		tag.add_theme_constant_override("outline_size", 9)
		markers[id] = tag
	if Story.request_received:
		mission = Mission.SEARCH
	if not Story.hospital_route.is_empty():
		selected_route = Story.hospital_route
		hospital_hours = 12 - int(OFFERS[selected_route]["hours"])
		remaining_hours = Story.city_hours
		clue = Story.hospital_clue
		mission = Mission.DELIVER
	if Story.return_door == HOSPITAL:
		player.position = Vector2(955, 310)
		companion.position = Vector2(1005, 331)
		Story.return_door = &""
	refresh_mission()

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not crossing and not modal_open and mission != Mission.FINISHED:
		update_walk(delta)
		var nearby := nearby_site()
		interaction.visible = nearby != &""
		if interaction.visible:
			var prompt := "E  ·  " + str(TITLES[nearby]) + (" 입장" if nearby == HOSPITAL else " 조사")
			var at := lead_body().position
			var y := at.y + 22.0 if at.y < 600 else at.y - 98.0
			place_interaction_prompt(interaction, prompt, at, y)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if terminal_open and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close_dialog()

func nearby_site() -> StringName:
	var closest := &""
	var nearest := REACH
	for id: StringName in sites:
		var site: Marker2D = sites[id]
		var distance := lead_body().position.distance_to(site.position)
		if distance < nearest:
			nearest = distance
			closest = id
	return closest

func interact() -> void:
	if modal_open or mission == Mission.FINISHED:
		return
	var id := nearby_site()
	if id == &"":
		return
	if id == HOSPITAL:
		travel("res://hospital.tscn")
		return
	if id == TERMINAL:
		if mission == Mission.SEARCH:
			show_procurement_terminal()
		else:
			simple_dialog("나라장터 2050  /  가상 긴급조달 화면", "수요 요청 대기", "병원 시설팀의 요청서를 받은 뒤 공급 경로를 비교할 수 있습니다.", "돌아가기", close_dialog)
		return
	match mission:
		Mission.REQUEST:
			simple_dialog(TITLES[id], "보유 물품 조사", "병원 시설팀에서 요청 규격을 확인하면 사용할 수 있는 부품을 가려낼 수 있습니다.", "현장으로 돌아가기", close_dialog)
		Mission.SEARCH:
			if Story.prepared_route != id:
				simple_dialog(TITLES[id], "단말기 검토 필요", "긴급조달 단말기에서 규격·검사·납기를 비교하고 이 공급 경로를 선택하세요.", "돌아가기", close_dialog)
			else:
				show_offers(id)
		Mission.DELIVER:
			simple_dialog(TITLES[id], "필요 수량 확보 완료", "시설팀에 확보한 부품 한 개를 전달하세요.", "현장으로 돌아가기", close_dialog)

func refresh_mission() -> void:
	hud_clock.text = "%d시간" % remaining_hours
	battery_label.text = "복구 완료" if mission == Mission.FINISHED else "%d시간" % hospital_hours
	battery_label.add_theme_color_override("font_color", ACCENT if mission == Mission.FINISHED else AMBER)
	for id: StringName in markers:
		var tag: Label = markers[id]
		tag.add_theme_color_override("font_color", AMBER if is_active_site(id) else DIM)
	match mission:
		Mission.REQUEST:
			mission_title.text = "병원 긴급 요청 확인"
			mission_detail.text = "오른쪽 위 병원 문에 다가가 E로 들어가세요."
			stock_label.text = "가방  /  비어 있음"
		Mission.SEARCH:
			mission_title.text = "긴급조달 경로 검토"
			mission_detail.text = "선택한 공급처를 조사하세요." if not Story.prepared_route.is_empty() else "중앙 단말기에서 규격·안전·납기를 비교하세요."
			stock_label.text = "가방  /  긴급 요청서"
		Mission.DELIVER:
			mission_title.text = "병원 시설팀에 부품 전달"
			mission_detail.text = str(OFFERS[selected_route]["method"]) + " · 부품 1개 확보"
			stock_label.text = "가방  /  " + str(OFFERS[selected_route]["part"])
		Mission.FINISHED:
			mission_title.text = "병원 비상전력 복구 완료"
			mission_detail.text = "2042년의 조달기록에서 다음 단서가 발견됐습니다."
			stock_label.text = "가방  /  2042년 기록"

func is_active_site(id: StringName) -> bool:
	match mission:
		Mission.REQUEST, Mission.DELIVER:
			return id == HOSPITAL
		Mission.SEARCH:
			return id == TERMINAL if Story.prepared_route.is_empty() else id == Story.prepared_route
	return false

func navigation_hint() -> Dictionary:
	var destinations: Array[Vector2] = []
	for id: StringName in sites:
		if is_active_site(id):
			destinations.append(sites[id].position)
	return make_navigation_hint(lead_body(), destinations, REACH)

func simple_dialog(kicker: String, title: String, detail: String, button_text: String, callback: Callable) -> void:
	terminal_open = false
	modal_open = true
	interaction.hide()
	show_overlay(kicker, title, detail, button_text, callback)

func close_dialog() -> void:
	overlay.hide()
	terminal_open = false
	modal_open = false

func show_procurement_terminal() -> void:
	terminal_open = true
	modal_open = true
	interaction.hide()
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
	overlay = Control.new()
	overlay.size = MAP_SIZE
	interface.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color("#07131be8")
	veil.size = MAP_SIZE
	overlay.add_child(veil)
	var box := panel(overlay, Vector2(244, 86), Vector2(792, 548), Color("#0e2130fa"), Color("#3c6e75"))
	write_label(box, "나라장터 2050  /  가상 통합 조회·전자조달 화면", Vector2(28, 18), Vector2(736, 26), 15, ACCENT)
	write_label(box, "다온시 공공병원  ·  P-42 1개", Vector2(28, 48), Vector2(736, 44), 27, TEXT)
	write_label(box, "수요 요청  /  비상전력 복구 · 12시간 이내 · 규격 적합 · 안전검사 통과", Vector2(28, 97), Vector2(736, 28), 16, DIM)
	var notice := write_label(box, "나라장터는 입찰·계약 등을 전자적으로 지원합니다. 물품 이관은 별도 절차를 확인하세요.", Vector2(28, 426), Vector2(736, 47), 16, AMBER, true)
	var rows := [
		["A  유휴 P-42 · 보유물품 이관", "재고 1개 · 규격·검사 적합 · 4시간 · 재고·이관 협의", WAREHOUSE, ""],
		["B  대체 D-42 · 국내업체 조달", "시험·대체 적합 · 7시간 · 긴급계약 요건 검토", DEPOT, ""],
		["C  해외 원제조사 P-42", "120시간 · 병원 임시 전력 12시간 초과", &"", "납품 기한을 충족하지 못합니다. 긴급조달에서는 실제 공급 가능 시점도 중요합니다."],
		["D  미검증 저가 부품", "3시간 · 안전검사 미완료", &"", "가격과 납기가 유리해도 안전성과 규격이 확인되지 않은 부품은 사용할 수 없습니다."]
	]
	for index in range(rows.size()):
		var row: Array = rows[index]
		var button := make_choice(box, "%s  /  %s" % [row[0], row[1]], Vector2(28, 139 + index * 69), Vector2(736, 58))
		button.pressed.connect(review_procurement.bind(row[2], row[3], notice))
		if index == 0:
			button.grab_focus()
	var exit := make_choice(box, "현장으로 돌아가기", Vector2(28, 487), Vector2(208, 43))
	exit.pressed.connect(close_dialog)
	reveal_overlay()

func review_procurement(route: StringName, warning: String, notice: Label) -> void:
	if route.is_empty():
		notice.text = warning
		return
	Story.procurement_reviewed = true
	Story.prepared_route = route
	refresh_mission()
	simple_dialog("조달 경로 검토  /  " + str(TITLES[route]), "현장 확인 필요",
		"규격·검사·납기를 비교한 검토 결과를 기록했습니다. %s에서 실제 재고를 확인하세요. 계약 경로와 기관 보유물품 이관에는 각각 맞는 절차를 적용해야 합니다." % TITLES[route],
		"현장으로 이동", close_dialog)

func show_offers(id: StringName) -> void:
	modal_open = true
	interaction.hide()
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
	var box := panel(overlay, Vector2(290, 106), Vector2(700, 508), Color("#0e2130fa"), Color("#3c6e75"))
	var offer: Dictionary = OFFERS[id]
	write_label(box, str(TITLES[id]) + "  /  " + str(offer["method"]), Vector2(32, 21), Vector2(632, 25), 15, ACCENT)
	write_label(box, offer["heading"], Vector2(30, 50), Vector2(640, 48), 31, TEXT)
	write_label(box, "병원 요청   P-42 또는 검증된 호환품 · 1개 · 12시간 이내", Vector2(32, 105), Vector2(640, 29), 16, DIM)
	var notice := write_label(box, "부품을 선택해 규격, 안전 검사, 도착 시간을 확인하세요.", Vector2(32, 380), Vector2(632, 55), 15, AMBER, true)
	var items: Array = offer["items"]
	for i in range(items.size()):
		var item: Array = items[i]
		var option := make_choice(box, "%s   /   %s" % [item[0], item[1]], Vector2(32, 147 + i * 72), Vector2(636, 60))
		option.pressed.connect(check_offer.bind(id, item, notice))
		if i == 0:
			option.grab_focus()
	var exit := make_choice(box, "현장으로 돌아가기", Vector2(32, 448), Vector2(195, 40))
	exit.pressed.connect(close_dialog)
	reveal_overlay()

func make_choice(parent: Control, text: String, at: Vector2, bounds: Vector2) -> Button:
	var button := MENU_BUTTON.new()
	button.text = text
	button.position = at
	button.custom_minimum_size = bounds
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", style_box(Color("#162d38"), Color("#345968"), 8))
	button.add_theme_stylebox_override("hover", style_box(Color("#264a53"), ACCENT, 8))
	button.add_theme_stylebox_override("pressed", style_box(Color("#30555c"), ACCENT, 8))
	polish_button(button)
	parent.add_child(button)
	return button

func check_offer(id: StringName, item: Array, notice: Label) -> void:
	if not str(item[2]).is_empty():
		notice.text = item[2]
		return
	var offer: Dictionary = OFFERS[id]
	var hours: int = offer["hours"]
	var approval := "공공기관 보유 유휴물품입니다. 보유 기관의 재고와 이관 가능 여부를 확인한 뒤, 별도 물품 이관 절차를 진행합니다." if id == WAREHOUSE else "국내 공급업체의 대체품입니다. 시설팀이 규격·안전성을 확인하고, 수요기관은 긴급계약 가능 요건과 관련 절차를 검토합니다."
	simple_dialog("후보 검토 완료  /  " + str(offer["method"]), item[0],
		"%s\n\n정해진 기준과 절차를 공정하고 투명하게 기록합니다. 확보까지 %d시간 · 병원 임시 전력 %d시간 남음" % [approval, hours, hospital_hours - hours],
		"이 경로로 부품 확보", select_route.bind(id))
	var box: Control = overlay_action.get_parent()
	var back := make_choice(box, "다시 비교", Vector2(302, 325), Vector2(152, 56))
	back.pressed.connect(show_offers.bind(id))

func select_route(id: StringName) -> void:
	var offer: Dictionary = OFFERS[id]
	selected_route = id
	remaining_hours -= int(offer["hours"])
	hospital_hours -= int(offer["hours"])
	clue = offer["clue"]
	Story.hospital_route = selected_route
	Story.city_hours = remaining_hours
	Story.hospital_clue = clue
	var delivery_note := "공공창고 유휴 P-42를 4시간 만에 확보했습니다. 병원 임시 전력은 8시간 남았습니다. 보유 기관의 재고·이관 가능 여부를 확인한 기록을 시설팀에 전달합니다." if id == WAREHOUSE else "국내 대체 D-42를 7시간 만에 확보했습니다. 병원 임시 전력은 5시간 남았습니다. 호환성·안전검사와 긴급계약 검토 기록을 시설팀에 전달합니다."
	Story.add_field_report(&"part_secured", "긴급조달 지원팀", delivery_note)
	milestone(sites[id].position, "%s 확보 · 병원 전력 %d시간 남음" % [str(offer["part"]), hospital_hours], "공급 경로 확정")
	mission = Mission.DELIVER
	refresh_mission()
	close_dialog()

func _draw() -> void:
	var restored := mission == Mission.FINISHED
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.023, 0.079, 0.13, 0.09 if restored else 0.22))
	if not is_node_ready():
		return
	for id: StringName in sites:
		if not is_active_site(id):
			continue
		var here: Vector2 = sites[id].position
		var pulse := 0.55 + sin(elapsed * 3.0) * 0.25
		draw_arc(here, 15.0 + pulse * 8.0, 0.0, TAU, 36, Color(1.0, 0.78, 0.43, pulse), 2.0, true)
		draw_circle(here, 4.0, AMBER)
	if restored:
		for radius in [86.0, 59.0, 34.0]:
			draw_circle(Vector2(969, 190), radius, Color(1.0, 0.77, 0.28, 0.10))
		draw_arc(sites[HOSPITAL].position, 20.0, 0.0, TAU, 40, ACCENT, 2.0, true)
