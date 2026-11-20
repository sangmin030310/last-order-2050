extends "res://prologue.gd"

enum Stage { RECORDS, RESERVE, DISPATCH, ENDING }
enum Circuit { OFF, SCAN, RACK, RELAY }

const OFFICE := &"office"
const FACTORY := &"factory"
const STOCK := &"stock"
const CONTROL := &"control"
const EXIT := &"exit"
const WATER_DOC := &"water_doc"
const COMMS_DOC := &"comms_doc"
const COPPER_A := &"copper_a"
const COPPER_B := &"copper_b"
const ALUMINUM := &"aluminum"
const SCANNER := &"scanner"
const WATER_PORT := &"water_port"
const COMMS_PORT := &"comms_port"
const LATCH := &"latch"
const POWER_PAD := &"power_pad"
const RELAY_LOG := &"relay_log"
const RELAY_CONTROL := &"relay_control"
const RESERVE_TERMINAL := &"reserve_terminal"
const WATER_LIMIT := 6
const COMMS_LIMIT := 9
const EXTENDED_COMMS_LIMIT := 14
const STOCK_ARRIVAL := 4
const FACTORY_ARRIVAL := 12
const CIRCUIT_NAMES := ["꺼짐", "출고 스캐너", "잠긴 보관대 B", "재난망 단말기"]

@export_enum("Street", "Archive", "Stockroom", "Dispatch") var room := 0
const SITE_NAMES := {
	OFFICE: "조달기록실", FACTORY: "국내 제조사", STOCK: "원자재 비축시설", CONTROL: "재난 대응 상황실",
	EXIT: "거리 출구", WATER_DOC: "정수시설 기록", COMMS_DOC: "통신시설 기록",
	COPPER_A: "보관대 A", COPPER_B: "보관대 B", ALUMINUM: "보관대 C", SCANNER: "출고 스캐너",
	WATER_PORT: "정수시설 배차", COMMS_PORT: "통신시설 배차", LATCH: "최종 발주 단말기",
	POWER_PAD: "보조전원 분전반", RELAY_LOG: "재난망 단말기", RELAY_CONTROL: "비상전력 제어반", RESERVE_TERMINAL: "비축물자 관리 단말기"
}
const DOCS := {
	&"water": "정수시설  /  전력 제어부품 P-42\n완제품 공급사  해진시스템\n핵심 제어모듈 공급처  S-17",
	&"comms": "통신시설  /  전력 제어부품 C-42\n완제품 공급사  세림전자\n핵심 제어모듈 공급처  S-17"
}
const ARCHIVE_EVIDENCE := {
	&"water": {&"maker": "해진시스템", &"spec": "P-42", &"supplier": "S-17"},
	&"comms": {&"maker": "세림전자", &"spec": "C-42", &"supplier": "S-17"}
}
var sites: Dictionary = {}
var cargo := &""
var scanned_copper: Array[StringName]
var loaded_destination := &""
var markers: Dictionary = {}
var stage := Stage.RECORDS
var modal_open := false
var read_docs: Array[StringName]
var supply_label: Label
var scanner_status: Label
var active_tiger := false
var circuit := Circuit.OFF
var circuit_panel: Panel
var network_flash: Control
var flash_until := 0.0
var relay_armed := false
var relay_possible := false
var relay_active := false
var water_offline := false
var comms_offline := false
var report_page := 0
var archive_selection: Array[StringName] = [&"", &""]
var archive_buttons: Dictionary = {}
var archive_notice: Label
var city_status_panel: Panel
var water_status: Label
var comms_status: Label
var power_status: Label

func _ready() -> void:
	active_tiger = Story.lead_tiger
	read_docs = Story.archive_docs
	scanned_copper = Story.copper_scans
	if Story.copper_loaded:
		stage = Stage.DISPATCH
	elif Story.records_linked:
		stage = Stage.RESERVE
	match room:
		0:
			sites = {OFFICE: $Sites/Office, FACTORY: $Sites/Factory, STOCK: $Sites/Stock, CONTROL: $Sites/Control}
			if sites.has(Story.return_door):
				var door: Marker2D = sites[Story.return_door]
				var offset := 46.0 if Story.return_door == OFFICE else -15.0
				player.position = door.position + Vector2(0, offset)
				companion.position = door.position + Vector2(40, offset)
				Story.return_door = &""
		1:
			sites = {WATER_DOC: $Sites/A, COMMS_DOC: $Sites/B, OFFICE: $Sites/C, EXIT: $Sites/Exit}
		2:
			sites = {COPPER_A: $Sites/A, COPPER_B: $Sites/B, ALUMINUM: $Sites/C, SCANNER: $Sites/D, EXIT: $Sites/Exit, POWER_PAD: $Sites/PowerPad, RELAY_LOG: $Sites/RelayLog, RESERVE_TERMINAL: $Sites/ReserveTerminal}
		3:
			sites = {WATER_PORT: $Sites/A, COMMS_PORT: $Sites/B, LATCH: $Sites/C, EXIT: $Sites/Exit, RELAY_CONTROL: $Sites/RelayControl}
	player_start = player.position
	companion_start = companion.position
	build_hud()
	pin.hide()
	var status := panel(interface, Vector2(500, 651), Vector2(500, 43), Color("#0b1925ed"), Color("#37535d"))
	supply_label = write_label(status, "", Vector2(15, 0), Vector2(470, 43), 15, TEXT)
	for id: StringName in sites:
		var site: Marker2D = sites[id]
		var tag := write_label(interface, SITE_NAMES[id], site.position + Vector2(-88, -74 if id != EXIT else 21), Vector2(176, 32), 18, DIM)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_color_override("font_outline_color", STORM)
		tag.add_theme_constant_override("outline_size", 8)
		markers[id] = tag
	if room == 3:
		build_city_status()
	if room == 2:
		scanner_status = write_label(interface, "", sites[SCANNER].position + Vector2(-88, -43), Vector2(176, 28), 16, ACCENT)
		scanner_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scanner_status.add_theme_color_override("font_outline_color", STORM)
		scanner_status.add_theme_constant_override("outline_size", 8)
		var preview := panel(interface, Vector2(427, 151), Vector2(426, 74), Color("#112e38ef"), Color("#84f1d2"))
		network_flash = preview
		var signal_label := write_label(preview, "재난망 신호 포착\n정수시설 → 통신시설", Vector2(15, 4), Vector2(396, 66), 19, ACCENT)
		signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview.hide()
	refresh()
	if room == 0 and stage == Stage.RECORDS and Story.hospital_restored and not Story.hospital_clue.is_empty() and not Story.records_intro_seen:
		open_intro()

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not crossing and not modal_open and stage != Stage.ENDING:
		if room == 2:
			move_stockroom_actors(delta)
		else:
			update_walk(delta)
		var id := nearby_site()
		var at := controlled_body().position
		interaction.visible = id != &""
		if interaction.visible:
			var prompt := "E  ·  " + str(SITE_NAMES[id]) + (" 입장" if room == 0 and id in [OFFICE, STOCK, CONTROL] else "")
			var y := at.y + 20 if at.y < 587 else at.y - 94
			place_interaction_prompt(interaction, prompt, at, y)
	if room == 2:
		network_flash.visible = elapsed < flash_until
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(circuit_panel) and circuit_panel.is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_3:
			var destination: Circuit = [Circuit.SCAN, Circuit.RACK, Circuit.RELAY][event.physical_keycode - KEY_1]
			select_circuit(destination)
			get_viewport().set_input_as_handled()
			return
	if room == 2 and not crossing and not modal_open and not event.is_echo() and event.is_action_pressed("switch_actor"):
		active_tiger = not active_tiger
		refresh()
		actor_changed()
		return
	super._unhandled_input(event)

func controlled_body() -> CharacterBody2D:
	if room == 2:
		return companion if active_tiger else player
	return lead_body()

func controlled_actor() -> CharacterBody2D:
	return controlled_body()

func navigation_hint() -> Dictionary:
	if stage == Stage.ENDING:
		return {}
	var destinations: Array[Vector2] = []
	match room:
		0:
			var id := OFFICE
			if stage == Stage.RESERVE:
				id = STOCK if Story.factory_checked else FACTORY
			elif stage == Stage.DISPATCH:
				id = CONTROL
			destinations.append(sites[id].position)
		1:
			if Story.records_linked:
				destinations.append(sites[EXIT].position)
			elif read_docs.size() == 2:
				destinations.append(sites[OFFICE].position)
			else:
				if not read_docs.has(&"water"):
					destinations.append(sites[WATER_DOC].position)
				if not read_docs.has(&"comms"):
					destinations.append(sites[COMMS_DOC].position)
		2:
			if Story.copper_loaded:
				destinations.append(sites[EXIT].position)
			elif not Story.reserve_approved:
				destinations.append(sites[RESERVE_TERMINAL].position)
			elif active_tiger or circuit == Circuit.OFF:
				destinations.append(sites[POWER_PAD].position)
			elif not cargo.is_empty():
				destinations.append(sites[SCANNER if circuit == Circuit.SCAN else POWER_PAD].position)
			elif not scanned_copper.has(COPPER_A):
				destinations.append(sites[COPPER_A].position)
			elif circuit == Circuit.RELAY and not Story.relay_record_found:
				destinations.append(sites[RELAY_LOG].position)
			elif circuit == Circuit.RACK and not scanned_copper.has(COPPER_B):
				destinations.append(sites[COPPER_B].position)
			elif not scanned_copper.has(COPPER_B):
				destinations.append(sites[POWER_PAD].position)
		3:
			if loaded_destination.is_empty():
				# Both allocations are valid player choices; do not reveal the ending.
				destinations = [sites[WATER_PORT].position, sites[COMMS_PORT].position]
			else:
				destinations.append(sites[LATCH].position)
	return make_navigation_hint(controlled_body(), destinations, REACH)

func move_stockroom_actors(delta: float) -> void:
	var sprite := tiger if active_tiger else bird
	var speed := SPEED * 0.84 if not active_tiger and not cargo.is_empty() else SPEED
	move_actor(delta, controlled_body(), sprite, -32.0 if active_tiger else -43.0, speed)

func nearby_site() -> StringName:
	var at := controlled_body().position
	var closest := &""
	var nearest := REACH
	for id: StringName in sites:
		var distance := at.distance_to(sites[id].position)
		if distance < nearest:
			nearest = distance
			closest = id
	return closest

func active_site(id: StringName) -> bool:
	if room == 1:
		if Story.records_linked:
			return id == EXIT
		if read_docs.size() == 2:
			return id == OFFICE
		return (id == WATER_DOC and not read_docs.has(&"water")) or (id == COMMS_DOC and not read_docs.has(&"comms"))
	if room == 2:
		if id == RESERVE_TERMINAL:
			return true
		if not Story.reserve_approved:
			return id == EXIT
		if id == POWER_PAD:
			return not Story.relay_record_found or not Story.copper_loaded
		if id == RELAY_LOG:
			return not scanned_copper.is_empty() and not Story.relay_record_found
		if Story.copper_loaded:
			return id == EXIT
		if not cargo.is_empty():
			return id == SCANNER
		return id in [COPPER_A, COPPER_B, ALUMINUM] and not scanned_copper.has(id)
	if room == 3:
		return stage != Stage.ENDING and (id in [WATER_PORT, COMMS_PORT, LATCH] or (id == RELAY_CONTROL and can_reserve_relay()))
	match stage:
		Stage.RECORDS:
			return id == OFFICE
		Stage.RESERVE:
			return id == FACTORY or id == STOCK
		Stage.DISPATCH:
			return id == CONTROL
	return false

func refresh() -> void:
	hud_clock.text = "%d시간" % Story.city_hours
	for id: StringName in markers:
		markers[id].add_theme_color_override("font_color", AMBER if active_site(id) else DIM)
	match stage:
		Stage.RECORDS:
			hud_chapter.text = "2장   /   2042년의 계약서"
			mission_title.text = "두 시설의 계약기록 대조"
			mission_detail.text = "양쪽 선반에서 기록을 찾아 대조 단말기로 가져가세요." if room == 1 else "왼쪽 위 조달기록실 문에 다가가세요."
			supply_label.text = "확보한 문서  /  %d개" % read_docs.size()
		Stage.RESERVE:
			hud_chapter.text = "3장   /   사라진 공급망"
			mission_title.text = "대체 부품 생산경로 확보"
			mission_detail.text = "보관대에서 구리를 들고 스캐너로 운반하세요." if room == 2 else "제조사와 비축시설을 방문하세요."
			supply_label.text = ("스캔한 구리  %d / 2    운반 중  %s" % [scanned_copper.size(), cargo_name()]) if room == 2 else ("검증된 부품  /  1개 확보" if Story.factory_checked else "생산 조건  /  확인 필요")
		Stage.DISPATCH:
			hud_chapter.text = "최종장   /   마지막 발주"
			mission_title.text = "긴급 공급계획 확정"
			if room == 3:
				if loaded_destination.is_empty():
					mission_detail.text = "기존 모듈을 보낼 곳을 고르세요. 후속 모듈은 반대편에 자동 배정됩니다."
				elif can_reserve_relay() and not relay_armed:
					mission_detail.text = "통신시설은 9시간 한계를 넘습니다. 비상전력 지원을 예약할 수 있습니다."
				else:
					mission_detail.text = "오른쪽 예상 결과를 보고 중앙 발주 단말기에서 계획을 확인하세요."
			else:
				mission_detail.text = "오른쪽 아래 상황실로 이동하세요."
			if room == 3 and not loaded_destination.is_empty():
				supply_label.text = "기존 → %s 4시간   /   후속 → %s 12시간" % ["정수" if loaded_destination == WATER_PORT else "통신", "통신" if loaded_destination == WATER_PORT else "정수"]
			else:
				supply_label.text = "기존 모듈 1개  /  " + ("우선 배차 미정" if loaded_destination.is_empty() else str(SITE_NAMES[loaded_destination]))
		Stage.ENDING:
			hud_chapter.text = "에필로그   /   무너지지 않은 내일"
			mission_title.text = "최종 공급계획 전달 완료"
			mission_detail.text = "현장기관의 복구 결과를 확인하세요."
			supply_label.text = "현장 기록  /  2050년 다온시"
	if room == 2:
		refresh_stock_hud()
	if room == 3:
		refresh_city_status()

func build_city_status() -> void:
	city_status_panel = panel(interface, Vector2(1029, 115), Vector2(224, 184), Color("#0b1925ed"), Color("#386d76"))
	write_label(city_status_panel, "다온시  /  예상 배차", Vector2(13, 8), Vector2(198, 25), 15, ACCENT)
	water_status = write_label(city_status_panel, "", Vector2(13, 36), Vector2(198, 47), 15, TEXT, true)
	comms_status = write_label(city_status_panel, "", Vector2(13, 86), Vector2(198, 47), 15, TEXT, true)
	power_status = write_label(city_status_panel, "", Vector2(13, 137), Vector2(198, 37), 14, DIM, true)

func refresh_city_status() -> void:
	if not is_instance_valid(city_status_panel):
		return
	city_status_panel.visible = stage == Stage.DISPATCH
	if not city_status_panel.visible:
		return
	if loaded_destination.is_empty():
		water_status.text = "정수시설 · 한계 6시간\n배차 미정 · 중단 예상"
		comms_status.text = "통신시설 · 한계 9시간\n배차 미정 · 중단 예상"
		water_status.add_theme_color_override("font_color", DIM)
		comms_status.add_theme_color_override("font_color", DIM)
	else:
		var water_arrival := STOCK_ARRIVAL if loaded_destination == WATER_PORT else FACTORY_ARRIVAL
		var comms_arrival := STOCK_ARRIVAL if loaded_destination == COMMS_PORT else FACTORY_ARRIVAL
		var comms_limit := EXTENDED_COMMS_LIMIT if relay_armed and Story.relay_record_found and loaded_destination == WATER_PORT else COMMS_LIMIT
		water_status.text = "정수 · %s %d시간 도착\n한계 6시간 · %s" % ["기존" if loaded_destination == WATER_PORT else "후속", water_arrival, "유지" if water_arrival <= WATER_LIMIT else "중단 예상"]
		comms_status.text = "통신 · %s %d시간 도착\n한계 %d시간 · %s" % ["기존" if loaded_destination == COMMS_PORT else "후속", comms_arrival, comms_limit, "유지" if comms_arrival <= comms_limit else "중단 예상"]
		water_status.add_theme_color_override("font_color", ACCENT if water_arrival <= WATER_LIMIT else AMBER)
		comms_status.add_theme_color_override("font_color", ACCENT if comms_arrival <= comms_limit else AMBER)
	power_status.text = "비상전력  예약 · 정수 복구 후" if relay_armed else ("비상전력  경로 기록 필요" if not Story.relay_record_found else ("비상전력  정수 우선 배차 필요" if loaded_destination != WATER_PORT else "비상전력  예약 가능"))
	power_status.add_theme_color_override("font_color", ACCENT if relay_armed else DIM)

func refresh_stock_hud() -> void:
	var actor := "조달호" if active_tiger else "조달이"
	supply_label.text = "%s · Tab 전환    검사 %d/2    전력 → %s" % [actor, scanned_copper.size(), CIRCUIT_NAMES[circuit]]
	scanner_status.text = "검수 완료  2/2" if scanned_copper.size() == 2 else "검사  %d/2  ·  %s" % [scanned_copper.size(), "전원 연결" if circuit == Circuit.SCAN else "전원 대기"]
	scanner_status.add_theme_color_override("font_color", ACCENT if circuit == Circuit.SCAN or scanned_copper.size() == 2 else AMBER)
	if Story.copper_loaded:
		mission_title.text = "비축 구리 출고 완료"
		mission_detail.text = "비상전력 기록을 챙겼습니다. 상황실로 이동하세요." if Story.relay_record_found else "재난망 기록을 확인하거나 출구로 이동하세요."
	elif not Story.reserve_approved:
		mission_title.text = "비축 구리 긴급 공급 요청"
		mission_detail.text = "비축물자 관리 단말기에서 구리 두 묶음의 공급 승인을 받으세요."
	elif circuit == Circuit.OFF:
		mission_detail.text = "조달호로 분전반에 접근해 E를 누르세요." if active_tiger else "Tab으로 조달호로 바꿔 분전반에서 E를 누르세요."
	elif active_tiger:
		mission_detail.text = "분전반에서 E로 장치를 고르면 조달이로 전환합니다."
	elif not cargo.is_empty():
		mission_detail.text = "%s 운반 중. 조달호로 스캐너 전력을 연결하세요." % cargo_name() if circuit != Circuit.SCAN else "%s 운반 중. 스캐너에서 검사하세요." % cargo_name()
	elif not scanned_copper.has(COPPER_A):
		mission_detail.text = "보관대 A에서 구리를 가져오세요."
	elif circuit == Circuit.RACK:
		mission_detail.text = "보관대 B가 열렸습니다. 조달이로 구리를 가져오세요."
	else:
		mission_detail.text = "보관대 B를 열려면 조달호로 전력을 옮기세요."

func simple_dialog(kicker: String, title: String, detail: String, action: String, callback: Callable) -> void:
	modal_open = true
	interaction.hide()
	show_overlay(kicker, title, detail, action, callback)

func close_dialog() -> void:
	overlay.hide()
	modal_open = false

func open_intro() -> void:
	Story.records_intro_seen = true
	var clue: String = Story.hospital_clue
	if clue.is_empty():
		clue = "정수시설과 통신시설에서도 병원과 유사한 고장이 보고됐습니다."
	simple_dialog("2장  /  2042년의 계약서", "고장은 한 곳이 아니었다",
		"병원은 살아났지만, 정수시설과 통신시설이 흔들리고 있습니다.\n\n1장의 단서  |  " + clue,
		"기록실로 이동", close_dialog)

func interact() -> void:
	if modal_open or stage == Stage.ENDING:
		return
	var id := nearby_site()
	if id.is_empty():
		return
	if id == EXIT:
		Story.return_door = [ &"", OFFICE, STOCK, CONTROL ][room]
		travel("res://recovery.tscn")
		return
	match room:
		0: street_action(id)
		1: archive_action(id)
		2: stockroom_action(id)
		3: dispatch_action(id)

func street_action(id: StringName) -> void:
	match id:
		OFFICE:
			travel("res://archive_room.tscn")
		FACTORY:
			if not Story.records_linked:
				simple_dialog("국내 제조사", "공급 기록 확인 중", "두 시설의 부품 정보를 기록실에서 먼저 찾아 주세요.", "돌아가기", close_dialog)
			else:
				show_factory()
		STOCK:
			if Story.factory_checked:
				travel("res://stockroom.tscn")
			else:
				simple_dialog("조달청 비축시설", "제조사 요청 대기 중", "어떤 원자재가 몇 묶음 필요한지 국내 제조사에서 먼저 확인하세요.", "돌아가기", close_dialog)
		CONTROL:
			if Story.copper_loaded:
				travel("res://dispatch_room.tscn")
			else:
				simple_dialog("재난 대응 상황실", "후속 생산 경로 확인 중", "제조사 요청과 비축 원자재 공급이 확인되면 배차를 시작할 수 있습니다.", "돌아가기", close_dialog)

func archive_action(id: StringName) -> void:
	if id == OFFICE:
		if Story.records_linked:
			simple_dialog("조달기록실", "공통 공급처 S-17", "두 기록의 분석을 마쳤습니다. 출구를 통해 제조사로 이동하세요.", "확인", close_dialog)
		elif read_docs.size() == 2:
			show_archive()
		else:
			simple_dialog("대조 단말기", "두 기록이 필요합니다", "기록실 왼쪽과 오른쪽 선반을 각각 조사하세요.", "계속 조사", close_dialog)
		return
	var key := &"water" if id == WATER_DOC else &"comms"
	if not read_docs.has(key):
		read_docs.append(key)
		notify("시설 기록 확보  %d / 2" % read_docs.size(), "조달기록실")
		effects.burst(sites[id].position, ACCENT)
		refresh()
	simple_dialog("2042년 납품 기록", SITE_NAMES[id], DOCS[key], "기록 챙기기", close_dialog)

func cargo_name() -> String:
	if cargo == &"":
		return "없음"
	return "알루미늄 1묶음" if cargo == ALUMINUM else "구리 1묶음"

func stockroom_action(id: StringName) -> void:
	if id == RESERVE_TERMINAL:
		show_reserve_terminal()
		return
	if not Story.reserve_approved:
		mission_detail.text = "먼저 비축물자 관리 단말기에서 공급 승인을 받으세요."
		return
	if id == POWER_PAD:
		if not active_tiger:
			mission_detail.text = "Tab으로 조달호에게 전환해 분전반을 조작하세요."
			return
		show_power_panel()
		return
	if active_tiger:
		mission_detail.text = "조달이가 운반과 단말기 조작을 맡습니다. Tab으로 전환하세요."
		return
	if id == RELAY_LOG:
		if circuit != Circuit.RELAY or scanned_copper.is_empty():
			mission_detail.text = "첫 구리를 검사한 뒤 재난망 단말기에 전력을 보내세요."
			return
		Story.relay_record_found = true
		Story.add_field_report(&"relay_route", "재난망 운전 기록", "정수시설 복구 후 통신시설에 전력을 지원할 수 있는 경로가 남아 있습니다. 상황실에서 예약하고 운영 기관이 실행해야 합니다.")
		milestone(sites[RELAY_LOG].position, "비상전력 연결 경로 발견", "재난망 기록 확보")
		refresh()
		simple_dialog("재난망  /  정전 직전 운전 기록", "살아 있는 비상 연결",
			"정수시설이 먼저 복구되면 전력 지원을 요청할 수 있습니다. 상황실에서 예약한 뒤 시설팀과 전력 운영 기관이 실행하면 통신시설은 14시간까지 버팁니다.",
			"전력 연결 기록 챙기기", close_dialog)
		return
	if Story.copper_loaded:
		return
	if id == SCANNER:
		if circuit != Circuit.SCAN:
			mission_detail.text = "분전반에서 출고 스캐너로 전력을 돌려주세요."
			return
		if cargo.is_empty():
			mission_detail.text = "보관대에서 원자재를 가져오세요."
			return
		if cargo == ALUMINUM:
			notify("요구 재질과 다릅니다. 공공조달에서는 규격과 품질을 확인해야 합니다.", "검사 반려")
			effects.burst(sites[SCANNER].position, AMBER)
			cargo = &""
			refresh()
			mission_detail.text = "스캐너가 알루미늄을 반려했습니다. 제조사 요청은 구리입니다."
			return
		scanned_copper.append(cargo)
		notify("구리 검사 완료  %d / 2" % scanned_copper.size(), "원자재 검증")
		effects.burst(sites[SCANNER].position, ACCENT, true)
		cargo = &""
		refresh()
		scanner_status.pivot_offset = scanner_status.size * 0.5
		var scan_pulse := create_tween()
		scan_pulse.tween_property(scanner_status, "scale", Vector2.ONE * 1.14, 0.12)
		scan_pulse.tween_property(scanner_status, "scale", Vector2.ONE, 0.18)
		if scanned_copper.size() == 1 and not Story.relay_record_found:
			flash_until = elapsed + 4.5
			Story.add_field_report(&"first_copper", "비축시설 검사 담당", "첫 구리 묶음이 검사에 통과했습니다. 두 번째 묶음을 출고하려면 보관대 전력을 전환해야 합니다. 재난망에도 신호가 잡힙니다.")
		if scanned_copper.size() == 2:
			approve_reserve()
		return
	if scanned_copper.has(id):
		mission_detail.text = "이미 스캔한 구리입니다. 다른 보관대를 확인하세요."
		return
	if not cargo.is_empty() and cargo != id:
		mission_detail.text = "한 번에 한 묶음만 들 수 있습니다."
		return
	if cargo == id:
		cargo = &""
		refresh()
		return
	if id == COPPER_B and circuit != Circuit.RACK:
		mission_detail.text = "보관대 B가 잠겼습니다. 분전반에서 B에 전력을 보내세요."
		return
	cargo = id
	effects.burst(sites[id].position, AMBER)
	refresh()

func show_power_panel() -> void:
	var box := workspace("조달청 비축창고  /  내부 물류설비", "전력을 보낼 장치를 고르세요",
		"현재 연결: %s. 숫자키 1·2·3 또는 클릭으로 장치 한 곳을 고르세요. 선택 후 조달이가 움직입니다." % CIRCUIT_NAMES[circuit])
	circuit_panel = box
	var details := ["운반한 구리의 재질 검사", "두 번째 구리 묶음이 있는 보관대 잠금 해제", "첫 검사에서 포착한 시설 간 연결 확인"]
	for index in range(3):
		var circuit_id: Circuit = [Circuit.SCAN, Circuit.RACK, Circuit.RELAY][index]
		var caption := "%d  %s  ·  %s%s" % [circuit_id, CIRCUIT_NAMES[circuit_id], details[index], "  (현재 연결)" if circuit == circuit_id else ""]
		var destination := choice(box, caption, 32, 171 + index * 69, 744, select_circuit.bind(circuit_id), circuit == circuit_id)
		if index == 0:
			destination.grab_focus()
	choice(box, "돌아가기", 32, 462, 165, close_dialog)

func show_reserve_terminal() -> void:
	var current := "자격·조건 확인 대기" if not Story.reserve_checked else ("담당 승인 결과 대기" if not Story.reserve_approved else ("구리 2묶음 검수·출고 완료" if Story.copper_loaded else "출고 승인 · 검사 %d/2" % scanned_copper.size()))
	var box := workspace("조달청  /  게임 속 비축물자 관리", "구리 긴급 공급 요청",
		"비축물자는 무상 지급되지 않습니다. 공급 대상과 가격·한도 등 조건을 확인합니다.")
	write_label(box, "신청 업체  국내 제조사 · 실수요·이용 자격 " + ("적격 확인" if Story.reserve_checked else "검토 전"), Vector2(32, 166), Vector2(746, 35), 17, TEXT)
	write_label(box, "신청 내역  구리 2묶음 · 후속 모듈 1개 생산", Vector2(32, 207), Vector2(746, 35), 17, TEXT)
	write_label(box, "비축 재고  구리 2묶음 · 공급 가능량 확인", Vector2(32, 248), Vector2(746, 35), 17, TEXT)
	write_label(box, "공급 조건  판매가격·한도 및 관련 절차 확인", Vector2(32, 289), Vector2(746, 35), 17, TEXT)
	write_label(box, "현재 상태  /  " + current, Vector2(32, 345), Vector2(746, 43), 20, ACCENT)
	if not Story.reserve_checked:
		choice(box, "신청 자격·공급 조건 확인", 32, 433, 273, check_reserve_request, true).grab_focus()
	elif not Story.reserve_approved:
		choice(box, "담당 승인 결과 확인", 32, 433, 240, approve_reserve_request, true).grab_focus()
	else:
		choice(box, "작업 계속하기", 32, 433, 205, close_dialog, true).grab_focus()
	choice(box, "현장으로 돌아가기", 322, 433, 205, close_dialog)

func check_reserve_request() -> void:
	if not Story.factory_checked:
		simple_dialog("조달청 비축시설", "제조사 신청 내역 필요",
			"국내 제조사의 생산 요청과 신청 원자재를 먼저 확인하세요.",
			"현장으로 돌아가기", close_dialog)
		return
	Story.reserve_checked = true
	show_reserve_terminal()

func approve_reserve_request() -> void:
	if not Story.reserve_checked:
		show_reserve_terminal()
		return
	Story.reserve_approved = true
	Story.add_field_report(&"reserve_approval", "비축시설 공급 담당", "제조사 이용 자격, 구리 신청량·재고, 공급 조건을 확인했습니다. 담당 승인에 따라 구리 2묶음을 출고·검사합니다.")
	refresh()
	simple_dialog("조달청 비축시설  /  공급 조건 확인", "구리 2묶음 출고 승인",
		"조달이: 제조사의 이용 자격과 구리 신청량, 재고·공급 조건을 확인했어.\n조달호: 비축 원자재가 공급망 위기에도 생산을 잇는 데 도움이 되겠네.\n\n담당 승인에 따라 출고하고, 창고 스캐너에서 재질을 검사하세요.",
		"구리 검수 시작", close_dialog)

func select_circuit(destination: Circuit) -> void:
	circuit = destination
	effects.burst(sites[POWER_PAD].position, ACCENT)
	var destination_site: StringName = [SCANNER, COPPER_B, RELAY_LOG][destination - 1]
	effects.burst(sites[destination_site].position, ACCENT, true)
	active_tiger = false
	var result := "조달호가 검사대 전원을 연결했습니다. 조달이로 구리를 검사하세요."
	if destination == Circuit.RACK:
		result = "조달호가 보관대 B를 열었습니다. 조달이로 두 번째 구리를 옮기세요."
	elif destination == Circuit.RELAY:
		result = "조달호가 재난망에 전력을 보냈습니다. 조달이로 기록을 확인하세요."
	notify(result, "동료 협력 · " + CIRCUIT_NAMES[destination])
	refresh()
	close_dialog()

func can_reserve_relay() -> bool:
	return Story.relay_record_found and loaded_destination == WATER_PORT

func dispatch_action(id: StringName) -> void:
	match id:
		LATCH:
			preview_dispatch()
		RELAY_CONTROL:
			if not Story.relay_record_found:
				simple_dialog("상황실  /  비상전력 제어반", "경로 기록 필요",
					"정전 직전의 전력 연결 기록이 필요합니다. 비축창고의 재난망 단말기에서 확인할 수 있습니다.",
					"배차 구역으로 돌아가기", close_dialog)
				return
			if not can_reserve_relay():
				simple_dialog("상황실  /  비상전력 제어반", "정수시설 우선 배차 필요",
					"지원 전력은 정수시설이 먼저 복구되어야 사용할 수 있습니다. 기존 부품을 정수시설로 배차한 뒤 예약하세요.",
					"배차 구역으로 돌아가기", close_dialog)
				return
			relay_armed = not relay_armed
			effects.burst(sites[RELAY_CONTROL].position, ACCENT if relay_armed else AMBER)
			refresh()
			mission_detail.text = "시설팀·전력 운영 기관에 지원을 예약했습니다. 정수시설 복구 후 활성화됩니다." if relay_armed else "비상전력 지원 예약을 취소했습니다."
			var relay_message := "전력 운영 기관: 지원 예약 접수. 정수시설 복구 뒤 활성화합니다." if relay_armed else "전력 운영 기관: 비상전력 지원 예약을 취소했습니다."
			Story.set_field_report(&"dispatch_brief", "다온시 상황실 · 현장 무전", relay_message)
			notify(relay_message, "비상전력 연락")
		_:
			loaded_destination = &"" if loaded_destination == id else id
			var cancelled_relay := relay_armed and loaded_destination != WATER_PORT
			if cancelled_relay:
				relay_armed = false
			effects.burst(sites[id].position, ACCENT)
			refresh()
			var site_message := "상황실: 기존 재고 배차가 보류됐습니다. 후속 모듈의 수령처도 미정입니다."
			var choice_message := "기존·후속 모듈 모두 배차 미정"
			if loaded_destination == WATER_PORT:
				site_message = "정수시설 시설팀: 기존 모듈을 4시간에 받겠습니다. 후속 모듈은 통신시설에 12시간 도착 예정입니다."
				choice_message = "기존 → 정수 4시간  /  후속 → 통신 12시간"
			elif loaded_destination == COMMS_PORT:
				site_message = "통신시설 현장팀: 기존 모듈을 4시간에 받겠습니다. 후속 모듈은 정수시설에 12시간 도착 예정입니다."
				choice_message = "기존 → 통신 4시간  /  후속 → 정수 12시간"
			if cancelled_relay:
				site_message += " 정수시설 우선 배차가 풀려 비상전력 예약도 취소됐습니다."
			Story.set_field_report(&"dispatch_brief", "다온시 상황실 · 현장 무전", site_message)
			notify(choice_message, "배차 결과 · 반대편 자동 배정")

func workspace(kicker: String, heading: String, detail: String, detail_color: Color = DIM) -> Panel:
	modal_open = true
	interaction.hide()
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
	overlay = Control.new()
	overlay.size = MAP_SIZE
	interface.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color("#07131bd4")
	veil.size = MAP_SIZE
	overlay.add_child(veil)
	var box := panel(overlay, Vector2(235, 92), Vector2(810, 536), Color("#0e2130fa"), Color("#3c6e75"))
	write_label(box, kicker, Vector2(32, 20), Vector2(740, 26), 15, ACCENT)
	write_label(box, heading, Vector2(30, 48), Vector2(750, 52), 32, TEXT)
	write_label(box, detail, Vector2(32, 104), Vector2(746, 52), 17, detail_color, true)
	reveal_overlay()
	return box

func choice(parent: Control, title: String, x: float, y: float, width: float, callback: Callable, primary := false) -> Button:
	var button := MENU_BUTTON.new()
	button.text = title
	button.position = Vector2(x, y)
	button.custom_minimum_size = Vector2(width, 48)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 17)
	var ink := Color("#082820") if primary else TEXT
	for style in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(style, ink)
	button.add_theme_stylebox_override("normal", style_box(ACCENT if primary else Color("#162d38"), Color("#487480"), 8))
	button.add_theme_stylebox_override("hover", style_box(Color("#aaffea") if primary else Color("#264a53"), ACCENT, 8))
	button.add_theme_stylebox_override("pressed", style_box(Color("#60bfa7") if primary else Color("#203e48"), ACCENT, 8))
	polish_button(button)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func show_archive() -> void:
	archive_buttons.clear()
	var box := workspace("다온시 조달기록실  /  2042년 계약기록", "두 기록의 연결점", "각 시설에서 항목을 하나씩 골라 같은 공급 경로가 있는지 비교하세요.")
	var fields: Array[StringName] = [&"maker", &"spec", &"supplier"]
	var field_names := ["완제품 공급사", "부품 규격", "핵심 모듈 공급처"]
	for side in range(2):
		var key := &"water" if side == 0 else &"comms"
		var heading := "정수시설  /  P-42" if side == 0 else "통신시설  /  C-42"
		var x := 32 + side * 396
		write_label(box, heading, Vector2(x, 162), Vector2(350, 29), 18, ACCENT)
		for row in range(fields.size()):
			var field: StringName = fields[row]
			var value: String = ARCHIVE_EVIDENCE[key][field]
			var caption := "%s  ·  %s" % [field_names[row], value]
			var button := choice(box, caption, x, 201 + row * 58, 350, select_archive_evidence.bind(side, field))
			archive_buttons[archive_button_key(side, field)] = button
			if archive_selection[side] == field:
				highlight_archive_selection(side, field)
			if side == 0 and row == 0:
				button.grab_focus()
	var notice := "정수시설과 통신시설에서 각각 하나씩 선택하세요."
	if archive_selection[0] == &"supplier" and archive_selection[1] == &"supplier":
		notice = "두 기록의 핵심 모듈 공급처 S-17을 확인했습니다."
	elif not archive_selection[0].is_empty() or not archive_selection[1].is_empty():
		notice = "선택한 항목을 유지했습니다. 반대편에서 같은 항목을 골라 보세요."
	archive_notice = write_label(box, notice, Vector2(32, 385), Vector2(746, 50), 16, AMBER, true)
	choice(box, "기록실로 돌아가기", 32, 462, 207, close_dialog)

func select_archive_evidence(side: int, field: StringName) -> void:
	if not is_instance_valid(archive_notice):
		return
	if not archive_selection[side].is_empty():
		clear_archive_selection(side)
	archive_selection[side] = field
	highlight_archive_selection(side, field)
	var facility := "정수시설" if side == 0 else "통신시설"
	var other_side := 1 - side
	if archive_selection[other_side].is_empty():
		var key := &"water" if side == 0 else &"comms"
		var field_name := "완제품 공급사" if field == &"maker" else ("부품 규격" if field == &"spec" else "핵심 모듈 공급처")
		archive_notice.text = "%s의 %s · %s 선택. 반대편에서 같은 항목을 고르세요." % [facility, field_name, ARCHIVE_EVIDENCE[key][field]]
		return
	if archive_selection[0] == &"supplier" and archive_selection[1] == &"supplier":
		discover_supplier()
		return
	if archive_selection[0] == &"supplier" or archive_selection[1] == &"supplier":
		clear_archive_selection(0 if archive_selection[0] != &"supplier" else 1)
		archive_notice.text = "핵심 모듈 공급처 선택은 유지했습니다. 다른 시설에서 같은 항목을 골라 보세요."
		return
	clear_archive_selection(0)
	clear_archive_selection(1)
	archive_notice.text = "두 기록의 공통 공급 경로가 아닙니다. 핵심 모듈 공급처를 비교해 보세요."

func highlight_archive_selection(side: int, field: StringName) -> void:
	var button = archive_buttons[archive_button_key(side, field)]
	button.add_theme_stylebox_override("normal", button.palette(button.ACTIVE_FILL, button.ACCENT))
	button.add_theme_stylebox_override("hover", button.palette(button.ACTIVE_FILL, button.ACCENT))
	button.add_theme_color_override("font_color", button.ACTIVE_INK)
	button.add_theme_color_override("font_hover_color", button.ACTIVE_INK)
	button.set_meta("archive_selected", true)

func archive_button_key(side: int, field: StringName) -> String:
	return "%d_%s" % [side, field]

func clear_archive_selection(side: int) -> void:
	var field := archive_selection[side]
	if field.is_empty():
		return
	archive_selection[side] = &""
	var button = archive_buttons[archive_button_key(side, field)]
	button.set_meta("archive_selected", false)
	button.keyboard_focus_armed = false
	button.apply_palette()
	if button.is_hovered():
		button.add_theme_stylebox_override("hover", button.palette(button.NORMAL_FILL, button.NORMAL_BORDER))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.mouse_exited.connect(restore_archive_hover.bind(side, field), CONNECT_ONE_SHOT)

func restore_archive_hover(side: int, field: StringName) -> void:
	if archive_selection[side] == field:
		return
	var key := archive_button_key(side, field)
	if archive_buttons.has(key) and is_instance_valid(archive_buttons[key]):
		archive_buttons[key].apply_palette()

func discover_supplier() -> void:
	Story.add_field_report(&"shared_supplier", "조달기록실", "두 납품 기록에서 핵심 모듈 공급처 S-17이 반복됩니다. 완제품 업체가 달라도 공급 중단 위험은 연결돼 있습니다.")
	effects.burst(sites[OFFICE].position, ACCENT, true)
	show_supply_strategy()

func show_supply_strategy() -> void:
	var box := workspace("공급망 위험 분석  /  2042년 계약기록", "공통 공급처 S-17 발견", "완제품 업체가 달라도 핵심 모듈은 한 공급처에 집중돼 있습니다. 다음 대응을 선택하세요.")
	var notice := write_label(box, "정수시설과 통신시설의 동시 중단 위험을 줄일 방안을 선택하세요.", Vector2(32, 405), Vector2(746, 48), 16, AMBER, true)
	choice(box, "A  기존 공급처만 기다린다", 32, 177, 746, reject_strategy.bind(notice, "한 공급처의 납품이 끊기면 두 시설이 함께 멈출 수 있습니다."))
	choice(box, "B  검증된 대체 공급처를 확보한다", 32, 249, 746, confirm_diversification, true).grab_focus()
	choice(box, "C  미검증 저가 부품으로 교체한다", 32, 321, 746, reject_strategy.bind(notice, "가격이 낮아도 규격과 안전성을 검증하지 않은 부품은 사용할 수 없습니다."))
	choice(box, "계약 기록 다시 보기", 32, 462, 215, show_archive)

func reject_strategy(notice: Label, reason: String) -> void:
	notice.text = reason

func confirm_diversification() -> void:
	Story.records_linked = true
	Story.add_field_report(&"supply_risk", "조달이 · 공급망 분석", "S-17 한 곳에 집중된 핵심 모듈 공급이 끊겼습니다. 검증된 국내 대체품과 필요한 원자재를 확인합니다.")
	show_risk_notice_decision()

func show_risk_notice_decision() -> void:
	var box := workspace("조달기록실  /  공급망 위험 연락", "두 시설에 먼저 알릴까요?",
		"S-17의 중단이 두 시설에 영향을 줍니다. 조달이가 위험을 통보하면 현장기관이 비상 대응을 준비할 수 있습니다.")
	choice(box, "조달이  ·  정수·통신시설에 위험 통보", 32, 194, 746, send_risk_notice).grab_focus()
	choice(box, "위험 통보는 보류하고 제조사 조사", 32, 270, 746, depart_without_notice)
	write_label(box, "통보 여부는 복구 결과와 보고서에 반영됩니다.", Vector2(32, 371), Vector2(746, 48), 16, AMBER)

func send_risk_notice() -> void:
	Story.risk_notice_sent = true
	Story.set_field_report(&"risk_notice", "조달이 · 공급망 위험 통보", "S-17 공통 공급 경로의 중단 위험을 정수시설과 통신시설에 알렸습니다. 현장기관이 비상 급수·연락 대응을 준비합니다.")
	effects.burst(sites[OFFICE].position, ACCENT)
	finish_record_analysis()

func depart_without_notice() -> void:
	Story.risk_notice_sent = false
	Story.set_field_report(&"risk_notice", "조달이 · 공급망 위험 통보", "제조사 조사를 먼저 진행했습니다. 두 시설에 공통 공급 경로 중단 위험을 미리 알리지는 못했습니다.")
	effects.burst(sites[OFFICE].position, AMBER)
	finish_record_analysis()

func finish_record_analysis() -> void:
	stage = Stage.RESERVE
	milestone(sites[OFFICE].position, "공급망 공통 위험 발견 · 대체 경로 조사", "2장 목표 완료")
	refresh()
	simple_dialog("3장  /  사라진 공급망", "공급처 S-17",
		("조달호: 두 시설이 다른 부품을 쓰는데 공급처는 하나였어?\n조달이: 두 시설에 위험을 알렸어. 이제 검증된 대체품과 생산 시간을 확인하자." if Story.risk_notice_sent else "조달호: 두 시설이 다른 부품을 쓰는데 공급처는 하나였어?\n조달이: 먼저 대체품을 찾자. 두 시설에 위험을 미리 알리지는 못했어.") + "\n\n국내 제조사의 시험 기록을 조사하세요.",
		"기록실 출구로 이동", close_dialog)

func show_factory() -> void:
	if stage == Stage.DISPATCH:
		simple_dialog("국내 제조사", "후속 생산 준비 완료", "검사된 구리 2묶음으로 공용 대체 모듈 1개를 생산합니다. 기존 재고 1개와 합쳐 두 시설에 각각 1개씩 공급할 수 있습니다.", "현장으로 돌아가기", close_dialog)
		return
	simple_dialog("국내 제조사  /  기술 담당자", "대체품 재고 1개",
		"기술 담당: 검증된 공용 모듈은 1개뿐입니다. 두 시설을 살리려면 하나를 더 만들어야 해요.\n조달호: 필요한 재료는요?\n기술 담당: 검사된 구리 2묶음입니다.",
		"생산 조건 기록", register_factory)

func register_factory() -> void:
	Story.factory_checked = true
	Story.add_field_report(&"factory_request", "국내 제조사 기술 담당", "시험을 마친 공용 대체 모듈 1개가 있습니다. 후속 모듈 1개 생산에는 검사된 구리 2묶음이 필요합니다.")
	milestone(sites[FACTORY].position, "후속 생산 조건 확인 · 구리 2묶음 필요", "제조사 요청 확보")
	refresh()
	close_dialog()

func approve_reserve() -> void:
	Story.copper_loaded = true
	stage = Stage.DISPATCH
	Story.add_field_report(&"module_ready", "국내 제조사 기술 담당", "검사된 구리 2묶음으로 후속 모듈 1개를 생산합니다. 기존 재고 1개와 함께 두 시설의 가동 한계에 맞춰 배차해 주세요.")
	milestone(sites[SCANNER].position, "구리 2묶음 검수 완료 · 후속 생산 시작", "3장 목표 완료")
	refresh()
	simple_dialog("구리 2묶음 검수·출고 완료", "국가 원자재 비축정책",
		"조달호: 이제 두 시설에 필요한 모듈이 각각 하나씩 생기는 거지?\n조달이: 맞아. 먼저 도착할 재고를 어디로 보낼지가 중요해.\n\n조달청 비축 원자재는 정해진 요건과 절차에 따라 공급돼 위기 때 생산을 잇는 데 도움을 줍니다.",
		"창고로 돌아가기", close_dialog)

func preview_dispatch() -> void:
	var destination := "보류" if loaded_destination.is_empty() else ("정수시설" if loaded_destination == WATER_PORT else "통신시설")
	var followup_destination := "수령처 미정" if loaded_destination.is_empty() else ("통신시설" if loaded_destination == WATER_PORT else "정수시설")
	var power := "예약됨" if relay_armed else ("경로 미확인" if not Story.relay_record_found else ("정수 우선 배차 필요" if loaded_destination != WATER_PORT else "미예약"))
	var briefing := "기존 모듈 배차 보류 · 후속 모듈 수령처와 배송 계획 미정\n이대로 확정하면 두 시설 모두 가동 한계를 초과합니다." if loaded_destination.is_empty() else "기존 모듈은 선택한 시설에 4시간, 후속 모듈은 반대편에 자동 배정돼 12시간에 도착합니다."
	var box := workspace("다온시  /  긴급 공공조달 종합계획", "최종 공급계획 검토", briefing, AMBER if loaded_destination.is_empty() else DIM)
	var water_arrival := STOCK_ARRIVAL if loaded_destination == WATER_PORT else FACTORY_ARRIVAL
	var comms_arrival := STOCK_ARRIVAL if loaded_destination == COMMS_PORT else FACTORY_ARRIVAL
	var comms_limit := EXTENDED_COMMS_LIMIT if relay_armed and can_reserve_relay() else COMMS_LIMIT
	var water_forecast := "미도착 · 중단 예상" if loaded_destination.is_empty() else "%d시간 도착 · %s" % [water_arrival, "유지" if water_arrival <= WATER_LIMIT else "중단 후 복구"]
	var comms_forecast := "미도착 · 중단 예상" if loaded_destination.is_empty() else "%d시간 도착 · %s" % [comms_arrival, "유지" if comms_arrival <= comms_limit else "중단 후 복구"]
	var rows := [
		"병원  ·  " + (("유휴 부품 이관" if Story.hospital_route == &"warehouse" else "대체품 긴급계약") + " · 시설팀 복구" if Story.hospital_restored else "복구 기록 확인 필요"),
		"조달이 위험 통보 %s  /  조달호 전력 지원 %s" % ["완료" if Story.risk_notice_sent else "미실시", power],
		"정수시설  ·  %s  /  가동 한계 %d시간" % [water_forecast, WATER_LIMIT],
		"통신시설  ·  %s  /  가동 한계 %d시간" % [comms_forecast, comms_limit],
		"기존 모듈 1개 → %s" % ("배차 보류" if loaded_destination.is_empty() else "%s · 4시간 도착" % destination),
		"후속 모듈 1개 → %s" % ("수령처·배송 미정" if loaded_destination.is_empty() else "%s · 12시간 도착 (반대편 자동 배정)" % followup_destination)
	]
	for index in range(rows.size()):
		var row := panel(box, Vector2(32, 160 + index * 46), Vector2(746, 40), Color("#17313b"), Color("#355761"))
		write_label(row, rows[index], Vector2(14, 0), Vector2(718, 40), 16, TEXT)
	choice(box, "배차 보류로 확정" if loaded_destination.is_empty() else "이 계획으로 발주 지원", 32, 446, 250, commit_dispatch, true).grab_focus()
	choice(box, "현장 배차 다시 하기", 298, 446, 226, close_dialog)

func commit_dispatch() -> void:
	var water_arrival := STOCK_ARRIVAL if loaded_destination == WATER_PORT else FACTORY_ARRIVAL
	var comms_arrival := STOCK_ARRIVAL if loaded_destination == COMMS_PORT else FACTORY_ARRIVAL
	water_offline = water_arrival > WATER_LIMIT
	relay_possible = relay_armed and Story.relay_record_found and loaded_destination == WATER_PORT and water_arrival <= WATER_LIMIT and water_arrival < COMMS_LIMIT
	relay_active = false
	var comms_limit := EXTENDED_COMMS_LIMIT if relay_possible else COMMS_LIMIT
	comms_offline = comms_arrival > comms_limit
	if not water_offline and not comms_offline:
		Story.ending = &"dawn" if Story.risk_notice_sent else &"field"
	elif water_offline and comms_offline:
		Story.ending = &"evacuation"
	else:
		Story.ending = &"prepared" if Story.risk_notice_sent else &"partial"
	stage = Stage.ENDING
	var delivery_record := "기존 모듈 배차와 후속 모듈 수령처가 미정입니다. 후속 모듈은 생산되지만 두 시설에는 전달되지 않습니다." if loaded_destination.is_empty() else "기존 모듈은 %s로 배차했습니다. 후속 모듈은 다른 시설에 12시간째 도착 예정입니다." % SITE_NAMES[loaded_destination]
	Story.set_field_report(&"dispatch_result", "다온시 재난 대응 상황실", "%s 비상전력 지원은 %s, 사전 위험 통보는 %s." % [delivery_record, "예약" if relay_armed else "미예약", "완료" if Story.risk_notice_sent else "미실시"])
	milestone(sites[LATCH].position, "배차 보류 전달 · 현장 대피 대응" if loaded_destination.is_empty() else "긴급 공급계획 전달 · 시설 복구 추적", "최종 계획 확정")
	refresh()
	overlay.hide()
	overlay.queue_free()
	show_recovery_sequence(water_arrival, comms_arrival, comms_limit)

func show_recovery_sequence(water_arrival: int, comms_arrival: int, comms_limit: int) -> void:
	# With no dispatch, the simulated 12-hour production does not deliver a part to either site.
	var water_display_arrival := -1 if loaded_destination.is_empty() else water_arrival
	var comms_display_arrival := -1 if loaded_destination.is_empty() else comms_arrival
	var view := Control.new()
	view.size = MAP_SIZE
	interface.add_child(view)
	overlay = view
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = preload("res://art/city_recovery.webp")
	picture.size = MAP_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	view.add_child(picture)

	var water_shadow := facility_shadow(view, Vector2(313, 332), "WaterShadow")
	var comms_shadow := facility_shadow(view, Vector2(1001, 329), "CommsShadow")
	var water_light := facility_glow(view, Vector2(316, 330))
	var comms_light := facility_glow(view, Vector2(1003, 327))
	var header := panel(view, Vector2(32, 27), Vector2(515, 107), Color("#0b1925f5"), Color("#427178"))
	write_label(header, "최종 발주  /  다온시 복구 현황", Vector2(18, 9), Vector2(476, 26), 16, ACCENT)
	var clock := write_label(header, "", Vector2(18, 40), Vector2(475, 45), 27, TEXT)
	var water := recovery_card(view, Vector2(105, 434), "정수시설")
	var comms := recovery_card(view, Vector2(865, 434), "통신시설")
	var water_node := Vector2(382, 363)
	var comms_node := Vector2(923, 362)
	var path := PackedVector2Array([water_node, Vector2(475, 289), Vector2(807, 287), comms_node])
	var wire := Line2D.new()
	wire.points = path
	wire.width = 3.0
	wire.default_color = Color("#85ffe7d9")
	wire.antialiased = true
	view.add_child(wire)
	var power := panel(view, Vector2(427, 464), Vector2(426, 41), Color("#173d39f5"), ACCENT)
	var link_label := write_label(power, "정수시설  →  비상전력  →  통신시설", Vector2(0, 0), Vector2(426, 41), 16, ACCENT)
	link_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var caption := panel(view, Vector2(167, 570), Vector2(946, 105), Color("#0b1925f5"), Color("#427178"))
	var event := write_label(caption, "", Vector2(19, 8), Vector2(908, 55), 19, TEXT, true)
	var progress := ProgressBar.new()
	progress.position = Vector2(19, 75)
	progress.size = Vector2(908, 8)
	progress.show_percentage = false
	progress.max_value = FACTORY_ARRIVAL
	progress.add_theme_stylebox_override("background", style_box(Color("#27444c"), Color("#27444c"), 4))
	progress.add_theme_stylebox_override("fill", style_box(ACCENT, ACCENT, 4))
	caption.add_child(progress)

	var update := func(hour: int) -> void:
		clock.text = "발주 후  %02d시간" % hour
		update_facility(water, hour, water_display_arrival, WATER_LIMIT, false)
		update_relay_state(hour, water_arrival)
		var link_active := relay_active and hour < comms_display_arrival
		var water_state := "restored" if water_display_arrival >= 0 and hour >= water_display_arrival else ("offline" if hour >= WATER_LIMIT else "waiting")
		var comms_state := "restored" if comms_display_arrival >= 0 and hour >= comms_display_arrival else ("supported" if link_active else ("offline" if hour >= COMMS_LIMIT else "waiting"))
		set_facility_atmosphere(water_shadow, water_light, water_state)
		set_facility_atmosphere(comms_shadow, comms_light, comms_state)
		power.visible = link_active
		wire.visible = link_active
		update_facility(comms, hour, comms_display_arrival, comms_limit, link_active)
		progress.value = hour
		if hour >= FACTORY_ARRIVAL:
			event.text = "상황실: 후속 모듈 생산 완료. 배차가 없어 현장 복구는 지연됩니다." if loaded_destination.is_empty() else ("상황실: 후속 부품 도착. 두 시설이 중단 없이 운영을 이어갑니다." if not water_offline and not comms_offline else "상황실: 후속 부품 도착. 중단됐던 시설의 복구를 시작합니다.")
		elif comms_offline and hour >= COMMS_LIMIT:
			event.text = "대응본부: 두 시설이 멈춰 일부 구역의 대피를 준비합니다." if water_offline else "통신시설 현장팀: 연락망이 멈췄습니다. 후속 부품을 기다립니다."
		elif hour >= COMMS_LIMIT and water_offline:
			event.text = "정수시설 시설팀: 비상 급수를 이어가는 중입니다. 통신은 아직 살아 있습니다."
		elif water_offline and hour >= WATER_LIMIT:
			event.text = "정수시설 시설팀: 설비가 멈췄습니다. 현장기관이 비상 급수를 시작합니다."
		elif link_active:
			event.text = "전력 운영 기관: 정수시설 복구 확인. 통신시설 지원 전력을 활성화합니다."
		elif not loaded_destination.is_empty() and hour >= STOCK_ARRIVAL:
			event.text = "정수시설 시설팀: 부품 도착. 급수 설비를 복구합니다." if loaded_destination == WATER_PORT else "통신시설 현장팀: 부품 도착. 연락망을 복구합니다."
		else:
			event.text = "조달청 비축 구리를 받은 국내 제조사가 후속 부품을 생산 중입니다."
	update.call(0)
	var timeline := create_tween()
	timeline.tween_method(update, 0, FACTORY_ARRIVAL, 4.0)
	timeline.tween_interval(1.0)
	timeline.tween_callback(show_ending)

func update_relay_state(hour: int, water_arrival: int) -> void:
	if relay_possible and hour >= water_arrival:
		relay_active = true

func facility_shadow(parent: Control, center: Vector2, shadow_name: String) -> TextureRect:
	var shadow := TextureRect.new()
	shadow.name = shadow_name
	shadow.position = center - Vector2(278, 200)
	shadow.size = Vector2(556, 400)
	shadow.modulate.a = 0.30
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#07121be8"), Color("#07121b00")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	shadow.texture = texture
	parent.add_child(shadow)
	return shadow

func set_facility_atmosphere(shadow: TextureRect, glow: TextureRect, state: String) -> void:
	if shadow.get_meta("facility_state", "") == state:
		return
	shadow.set_meta("facility_state", state)
	var shadow_alpha := 0.30
	var glow_alpha := 0.0
	match state:
		"offline":
			shadow_alpha = 0.90
		"supported":
			shadow_alpha = 0.10
			glow_alpha = 0.70
		"restored":
			shadow_alpha = 0.0
			glow_alpha = 1.0
	create_tween().tween_property(shadow, "modulate:a", shadow_alpha, 0.30)
	create_tween().tween_property(glow, "modulate:a", glow_alpha, 0.30)

func facility_glow(parent: Control, center: Vector2) -> TextureRect:
	var halo := TextureRect.new()
	halo.position = center - Vector2(120, 80)
	halo.size = Vector2(240, 160)
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#90fadc56"), Color("#90fadc00")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	halo.texture = texture
	halo.modulate.a = 0.0
	parent.add_child(halo)
	return halo

func recovery_card(parent: Control, at: Vector2, name_of_facility: String) -> Label:
	var card := panel(parent, at, Vector2(310, 92), Color("#0b1925f5"), Color("#427178"))
	write_label(card, name_of_facility, Vector2(14, 8), Vector2(281, 31), 21, TEXT)
	return write_label(card, "", Vector2(14, 43), Vector2(281, 37), 17, ACCENT)

func update_facility(status: Label, hour: int, arrival: int, deadline: int, linked: bool) -> void:
	var color := DIM
	if arrival >= 0 and hour >= arrival:
		if not status.has_meta("arrival_effect"):
			status.set_meta("arrival_effect", true)
			var restored_card: Control = status.get_parent()
			restored_card.self_modulate = Color("#84f1d2")
			create_tween().tween_property(restored_card, "self_modulate", Color.WHITE, 0.7)
		status.text = "●  운영 중  ·  부품 도착"
		color = ACCENT
	elif hour >= deadline:
		status.text = "■  운영 중단  ·  부품 대기"
		color = AMBER
	elif linked:
		status.text = "◆  비상전력으로 운영 중"
		color = ACCENT
	else:
		status.text = "○  임시 운전  ·  %d시간 남음" % (deadline - hour)
	status.add_theme_color_override("font_color", color)
	var card: Panel = status.get_parent()
	card.add_theme_stylebox_override("panel", style_box(Color("#0b1925f5"), color, 10))

func show_ending() -> void:
	report_page = 0
	var title := "희망의 새벽"
	var detail := "조달이가 두 시설에 S-17 위험을 미리 알렸습니다. 4시간째 정수시설이 복구되고 조달호가 분전반에서 연결한 비상전력 경로가 통신시설을 지켰습니다."
	var atmosphere := Color("#ffe3ae")
	var veil_color := Color("#081824ad")
	match Story.ending:
		&"field":
			title = "현장이 지킨 밤"
			detail = "조달호의 분전반 조작으로 확보한 비상전력 경로 덕분에 두 시설이 멈추지 않았습니다. S-17 공급 위험의 사전 통보는 다음 과제로 남았습니다."
			atmosphere = Color("#9bdbc9")
		&"prepared":
			title = "준비된 복구"
			atmosphere = Color("#f2cf91")
			if water_offline:
				detail = "통신시설을 먼저 복구했지만 정수시설은 6시간째 멈췄습니다. 사전 통보로 비상 급수를 준비했습니다. 정수 복구 전에는 통신 지원 전력도 활성화될 수 없습니다."
			else:
				detail = "정수시설은 지켰지만 통신시설은 9시간째 멈췄습니다. 사전 통보를 받은 현장기관이 대체 연락망을 준비해 후속 부품을 기다립니다."
		&"partial":
			title = "불완전한 생존"
			atmosphere = Color("#9bb2c8")
			if water_offline:
				detail = "통신시설에 먼저 배차해 정수시설이 6시간째 멈췄습니다. 비상 급수가 늦어졌고, 정수 복구 전에는 통신 지원 전력도 활성화될 수 없습니다."
			elif Story.relay_record_found:
				detail = "정수시설은 지켰지만 통신시설은 9시간째 멈췄습니다. 전력 지원 경로를 확인했다면 상황실에서 예약해야 활성화됩니다."
			else:
				detail = "정수시설은 지켰지만 통신시설은 9시간째 멈췄습니다. 비축창고 재난망 기록을 확인하지 못해 전력 지원을 요청할 수 없었습니다."
		&"evacuation":
			title = "마지막 대피"
			detail = "배차가 정해지지 않아 두 시설이 가동 한계를 넘겼습니다. 대응본부가 일부 구역의 대피를 진행합니다. 후속 모듈은 생산됐지만 현장 복구에는 별도 배차가 필요합니다."
			atmosphere = Color("#d7a0a0")
			veil_color = Color("#130f1bd1")
	var box := workspace("에필로그  /  다온시 복구 기록", title, detail)
	var backdrop := TextureRect.new()
	backdrop.texture = preload("res://art/city_recovery.webp")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.size = MAP_SIZE
	backdrop.modulate = atmosphere
	backdrop.modulate.a = 0.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(backdrop)
	overlay.move_child(backdrop, 0)
	var veil: ColorRect = overlay.get_child(1)
	veil.color = veil_color
	create_tween().tween_property(backdrop, "modulate:a", 1.0, 0.5)
	box.add_theme_stylebox_override("panel", style_box(Color("#0e2130f5"), atmosphere, 10))
	for child in box.get_children():
		if child is Label and child.text == title:
			child.add_theme_color_override("font_color", atmosphere)
	var route := "병원 부품 기록 없음"
	if Story.hospital_route == &"warehouse":
		route = "공공창고 유휴 부품 이관"
	elif Story.hospital_route == &"depot":
		route = "국내 대체품 긴급계약"
	var rows := [
		"병원  ·  " + route,
		"후속 생산  ·  비축 구리 2묶음 → 국내 제조사 → 모듈 1개",
		"후속 모듈 생산 시점 · 도시 대응 잔여  %d시간" % maxi(0, Story.city_hours - 12)
	]
	for i in range(rows.size()):
		var row := panel(box, Vector2(32, 178 + i * 57), Vector2(746, 47), Color("#17313b"), Color("#355761"))
		write_label(row, rows[i], Vector2(14, 0), Vector2(718, 47), 17, TEXT)
	var lesson := ""
	match Story.ending:
		&"dawn":
			lesson = "조달이의 사전 통보와 조달호의 현장 전력 경로, 적시 배차가 함께 도시의 일상을 지켰습니다."
		&"field":
			lesson = "현장 전력 지원은 성공했습니다. 공통 공급 위험을 미리 알리는 일도 다음 위기에 대비하는 데 필요합니다."
		&"prepared":
			lesson = "정수시설 중단에도 사전 통보가 비상 급수 준비로 이어졌습니다." if water_offline else "통신시설 중단에도 사전 통보가 대체 연락망 준비로 이어졌습니다."
		&"partial":
			lesson = "통신시설 우선 배차로 정수시설이 6시간 한계를 넘었습니다." if water_offline else "정수시설 우선 배차만으로는 통신시설의 9시간 한계를 지키지 못했습니다."
		&"evacuation":
			lesson = "긴급 수요의 납기와 시설별 우선순위에 맞는 배차가 공공서비스 유지에 영향을 줍니다."
		_:
			lesson = "시설별 가동 한계와 배차 순서, 비상전력 지원 여부를 다시 확인해 보세요."
	write_label(box, lesson, Vector2(32, 360), Vector2(744, 55), 15, DIM, true)
	var facility_result := "정수시설  %s     /     통신시설  %s" % ["중단" if water_offline else "운영", "중단" if comms_offline else "운영"]
	write_label(box, facility_result, Vector2(32, 419), Vector2(744, 23), 14, atmosphere)
	choice(box, "프롤로그부터 다시 시작", 32, 445, 249, restart_story, true).grab_focus()
	var retry := choice(box, "마지막 계획 다시 선택", 296, 445, 232, retry_dispatch)
	retry.tooltip_text = "사전 통보와 재난망 기록은 유지됩니다. 배차와 전력 예약만 다시 고릅니다."
	choice(box, "조달정책 성과 보기", 544, 445, 234, show_policy_summary)

func show_policy_summary() -> void:
	var box := workspace("에필로그  /  조달정책 성과", "다온시 긴급조달 결과 보고서", "실제 진행과 배차 결과를 확인하세요. 해당 없음은 기록되지 않은 항목입니다.")
	var hospital_ok := not Story.hospital_route.is_empty() and Story.hospital_restored
	var water_arrival := STOCK_ARRIVAL if loaded_destination == WATER_PORT else FACTORY_ARRIVAL
	var comms_arrival := STOCK_ARRIVAL if loaded_destination == COMMS_PORT else FACTORY_ARRIVAL
	var comms_limit := EXTENDED_COMMS_LIMIT if relay_possible else COMMS_LIMIT
	var route_result := "해당 없음 · 공급 경로 기록 없음"
	if hospital_ok and Story.hospital_route == &"warehouse":
		route_result = "달성 · 유휴 P-42 이관 / 별도 절차"
	elif hospital_ok and Story.hospital_route == &"depot":
		route_result = "달성 · 대체 D-42 긴급계약 검토"
	var reserve_result := "미달성 · 구리 공급 기록 없음"
	if Story.reserve_approved and Story.copper_loaded:
		reserve_result = "달성 · 구리 2묶음 → 후속 1개"
	var power_result := "미예약 · 지원 없음"
	if relay_armed:
		power_result = "예약·활성화 · 4시간부터" if relay_active else "예약 · 활성화 조건 미충족"
	var dispatch_result := "기존 배차 보류 · 후속 수령처 미정" if loaded_destination.is_empty() else "기존 → %s 4시간 · 후속 → %s 12시간" % ["정수" if loaded_destination == WATER_PORT else "통신", "통신" if loaded_destination == WATER_PORT else "정수"]
	var water_result := "미도착 · 배차 보류" if loaded_destination.is_empty() else ("달성 · %d시간 도착 / 6시간 한계" % water_arrival if not water_offline else "위험 발생 · 6시간 한계 초과")
	var comms_result := "미도착 · 배차 보류" if loaded_destination.is_empty() else ("달성 · %d시간 도착 / %d시간 한계" % [comms_arrival, comms_limit] if not comms_offline else "위험 발생 · %d시간 한계 초과" % comms_limit)
	var rows := [
		["조달 정보·공급 경로", route_result if Story.procurement_reviewed else "해당 없음 · 단말기 기록 없음", ""],
		["병원 부품·검수", "달성 · 1개 인계·안전 확인" if hospital_ok else "미달성 · 인계 기록 없음", ""],
		["공급망 위험 분석", ("달성 · S-17 발견·시설 통보" if Story.risk_notice_sent else "달성 · S-17 발견·통보 보류") if Story.records_linked else "미달성 · 분석 기록 없음", "시설 사전 통보 완료" if Story.risk_notice_sent else "시설 사전 통보 미실시"],
		["대체 공급처 확보", "달성 · 국내 제조사 확인" if Story.factory_checked else "미달성 · 제조사 기록 없음", ""],
		["국가 비축·후속 생산", reserve_result, "후속 모듈 1개 생산 지원" if Story.reserve_approved and Story.copper_loaded else "공급 조건·출고 기록 확인 필요"],
		["시설별 부품 도착", dispatch_result, "생산 완료와 별개로 배송은 미확정" if loaded_destination.is_empty() else "기존 재고 4시간 · 후속 모듈 12시간"],
		["비상전력 지원", power_result, "정수시설 복구 후 통신시설 지원" if relay_active else ""],
		["정수시설 가동", water_result, ""],
		["통신시설 가동", comms_result, ""],
		["결말·공공서비스", ending_report_text(), ""]
	]
	for index in range(report_page * 5, mini((report_page + 1) * 5, rows.size())):
		var entry: Array = rows[index]
		var local_index := index % 5
		var card := panel(box, Vector2(32, 160 + local_index * 55), Vector2(746, 50), Color("#17313b"), Color("#355761"))
		write_label(card, entry[0], Vector2(14, 4), Vector2(205, 42), 15, ACCENT)
		var value: String = entry[1]
		var result_color := AMBER if "미달성" in value or "위험" in value or "미도착" in value or "보류" in value else TEXT
		var has_detail := not str(entry[2]).is_empty()
		write_label(card, value, Vector2(226, 3 if has_detail else 8), Vector2(502, 24 if has_detail else 34), 16, result_color)
		if has_detail:
			write_label(card, entry[2], Vector2(226, 29), Vector2(502, 18), 13, DIM)
	if report_page == 1:
		write_label(box, "공공조달은 적합한 물품을 제때 확보해 시민의 일상을 뒷받침합니다.", Vector2(32, 439), Vector2(710, 17), 12, DIM)
	choice(box, "결말 화면으로", 32, 456, 208, show_ending).grab_focus()
	choice(box, "다음 기록  2 / 2" if report_page == 0 else "이전 기록  1 / 2", 256, 456, 207, change_report_page, true)

func ending_report_text() -> String:
	match Story.ending:
		&"dawn": return "희망의 새벽 · 두 시설 유지"
		&"field": return "현장이 지킨 밤 · 두 시설 유지"
		&"prepared": return "준비된 복구 · 정수 중단" if water_offline else "준비된 복구 · 통신 중단"
		&"partial": return "불완전한 생존 · 정수 중단" if water_offline else "불완전한 생존 · 통신 중단"
		&"evacuation": return "마지막 대피 · 두 시설 중단"
		_: return "결과 확인 필요"

func change_report_page() -> void:
	report_page = 1 - report_page
	show_policy_summary()

func restart_story() -> void:
	Story.reset()
	travel("res://intro.tscn")

func retry_dispatch() -> void:
	Story.set_field_report(&"dispatch_result", "다온시 재난 대응 상황실", "이전 배차 계획을 다시 검토합니다. 시설별 가동 한계와 비상전력 예약 조건을 확인해 주세요.")
	Story.set_field_report(&"dispatch_brief", "다온시 상황실 · 현장 무전", "배차 계획을 다시 검토 중입니다. 기존 재고 목적지와 지원 예약을 확인해 주세요.")
	loaded_destination = &""
	relay_armed = false
	relay_possible = false
	relay_active = false
	water_offline = false
	comms_offline = false
	Story.ending = &""
	stage = Stage.DISPATCH
	refresh()
	close_dialog()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.02, 0.07, 0.13, 0.18 if stage != Stage.ENDING else 0.03))
	if not is_node_ready():
		return
	for id: StringName in sites:
		if active_site(id):
			var here: Vector2 = sites[id].position
			var pulse := 0.52 + sin(elapsed * 3.0) * 0.24
			draw_arc(here, 17.0 + pulse * 8.0, 0.0, TAU, 36, Color(1.0, 0.78, 0.43, pulse), 2.0, true)
			draw_circle(here, 4.0, AMBER)
	if room == 2:
		var panel_position: Vector2 = sites[POWER_PAD].position
		var panel_color := AMBER if circuit == Circuit.OFF else ACCENT
		draw_arc(panel_position, 24.0, 0.0, TAU, 36, panel_color, 2.5, true)
		draw_arc(controlled_body().position, 16.0, 0.0, TAU, 30, ACCENT, 2.0, true)
		if circuit != Circuit.OFF:
			var destination: Vector2 = sites[[SCANNER, COPPER_B, RELAY_LOG][circuit - 1]].position
			draw_line(panel_position, destination, Color(ACCENT, 0.5), 3.0, true)
			var signal_at := panel_position.lerp(destination, fposmod(elapsed * 0.8, 1.0))
			draw_circle(signal_at, 4.0, ACCENT)
		var rack: Vector2 = sites[COPPER_B].position
		if circuit != Circuit.RACK and not scanned_copper.has(COPPER_B) and cargo != COPPER_B:
			draw_line(rack + Vector2(-25, -12), rack + Vector2(25, -12), AMBER, 4.0, true)
		for checked_id: StringName in [COPPER_A, COPPER_B]:
			if scanned_copper.has(checked_id):
				var check_at: Vector2 = sites[checked_id].position + Vector2(0, -27)
				draw_circle(check_at, 11.0, Color("#0e2830"))
				draw_arc(check_at, 10.0, 0.0, TAU, 24, ACCENT, 2.0, true)
				draw_polyline(PackedVector2Array([check_at + Vector2(-5, 0), check_at + Vector2(-1, 4), check_at + Vector2(6, -5)]), ACCENT, 2.0, true)
	if room == 3 and relay_armed:
		var water: Vector2 = sites[WATER_PORT].position
		var relay: Vector2 = sites[RELAY_CONTROL].position
		var comms: Vector2 = sites[COMMS_PORT].position
		draw_polyline(PackedVector2Array([water, relay, comms]), Color(ACCENT, 0.6), 2.0, true)
	if room == 2 and not cargo.is_empty():
		var bob := sin(elapsed * 7.0) * 1.5 if player.velocity.length() > 2.0 else 0.0
		var parcel := Rect2(player.position + Vector2(10, -25 + bob), Vector2(25, 18))
		var metal := Color("#bd8a59") if cargo != ALUMINUM else Color("#8faab4")
		draw_rect(parcel, Color("#172b34"))
		draw_rect(Rect2(parcel.position + Vector2(2, 2), parcel.size - Vector2(4, 4)), metal)
		draw_line(parcel.position + Vector2(8, 2), parcel.position + Vector2(8, 16), Color("#e1c69d") if cargo != ALUMINUM else TEXT, 2.0)
		draw_line(parcel.position + Vector2(17, 2), parcel.position + Vector2(17, 16), Color("#e1c69d") if cargo != ALUMINUM else TEXT, 2.0)
		draw_rect(parcel, STORM, false, 2.0)
	if stage == Stage.ENDING and room == 3:
		for id: StringName in [WATER_PORT, COMMS_PORT, LATCH]:
			var here: Vector2 = sites[id].position
			var interrupted := (id == WATER_PORT and water_offline) or (id == COMMS_PORT and comms_offline)
			var light_color := AMBER if interrupted else ACCENT
			draw_arc(here, 23, 0.0, TAU, 36, light_color, 3.0, true)
