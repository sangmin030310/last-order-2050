extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for notify_facilities in [true, false]:
		var story := root.get_node("Story")
		story.reset()
		var archive = load("res://archive_room.tscn").instantiate()
		root.add_child(archive)
		archive.set_physics_process(false)
		archive.confirm_diversification()
		assert(story.records_linked and archive.stage == archive.Stage.RECORDS)
		assert("통보하면" in report_text(archive.overlay), "The archive must explain the early warning decision")
		if notify_facilities:
			archive.send_risk_notice()
		else:
			archive.depart_without_notice()
		assert(story.risk_notice_sent == notify_facilities and archive.stage == archive.Stage.RESERVE)
		assert("risk_notice" in str(story.field_reports), "The warning choice must enter the field report")
		archive.free()
	var gate_story := root.get_node("Story")
	gate_story.reset()
	var locked = load("res://dispatch_room.tscn").instantiate()
	root.add_child(locked)
	locked.set_physics_process(false)
	locked.stage = locked.Stage.DISPATCH
	locked.refresh()
	locked.dispatch_action(locked.RELAY_CONTROL)
	assert(not locked.relay_armed and "경로 기록 필요" in report_text(locked.overlay), "Missing relay record must block the support choice")
	locked.close_dialog()
	gate_story.relay_record_found = true
	locked.refresh()
	assert(not locked.active_site(locked.RELAY_CONTROL), "Support remains unavailable before water-first dispatch")
	locked.dispatch_action(locked.RELAY_CONTROL)
	assert(not locked.relay_armed and "정수시설 우선 배차 필요" in report_text(locked.overlay), "A record alone must not reserve support")
	locked.close_dialog()
	locked.dispatch_action(locked.WATER_PORT)
	assert(locked.active_site(locked.RELAY_CONTROL), "Water-first dispatch unlocks support reservation")
	locked.dispatch_action(locked.RELAY_CONTROL)
	assert(locked.relay_armed)
	locked.dispatch_action(locked.COMMS_PORT)
	assert(not locked.relay_armed and not locked.active_site(locked.RELAY_CONTROL), "Changing the dispatch must cancel support reservation")
	locked.free()
	var cases := [
		["A", &"water_port", true, true, &"dawn", true, false, false, true],
		["B", &"water_port", true, false, &"prepared", false, false, true, true],
		["C", &"comms_port", true, false, &"partial", false, true, false, false],
		["D", &"", true, false, &"evacuation", false, true, true, true],
		["E", &"water_port", false, false, &"partial", false, false, true, false],
		["F", &"water_port", true, true, &"field", true, false, false, false],
		["G", &"comms_port", true, false, &"prepared", false, true, false, true],
		["H", &"water_port", true, false, &"partial", false, false, true, false]
	]
	for entry in cases:
		root.get_node("Story").reset()
		root.get_node("Story").relay_record_found = entry[2]
		root.get_node("Story").risk_notice_sent = entry[8]
		if entry[0] == "A":
			var story := root.get_node("Story")
			story.procurement_reviewed = true
			story.hospital_route = &"warehouse"
			story.hospital_restored = true
			story.records_linked = true
			story.factory_checked = true
			story.reserve_approved = true
			story.copper_loaded = true
		var scene = load("res://dispatch_room.tscn").instantiate()
		root.add_child(scene)
		scene.set_physics_process(false)
		assert(scene.WATER_LIMIT == 6 and scene.COMMS_LIMIT == 9)
		assert(scene.STOCK_ARRIVAL == 4 and scene.FACTORY_ARRIVAL == 12 and scene.EXTENDED_COMMS_LIMIT == 14)
		scene.loaded_destination = entry[1]
		scene.relay_armed = entry[3]
		scene.stage = scene.Stage.DISPATCH
		scene.refresh()
		if entry[0] == "A":
			scene.loaded_destination = &""
			scene.relay_armed = false
			scene.refresh()
			assert("배차 미정" in scene.water_status.text and "배차 미정" in scene.comms_status.text)
			scene.dispatch_action(scene.WATER_PORT)
			assert("기존 4시간 도착" in scene.water_status.text and "유지" in scene.water_status.text)
			assert("후속 12시간 도착" in scene.comms_status.text and "중단 예상" in scene.comms_status.text, "The unassisted facility must show its deadline risk")
			assert("기존 → 정수 4시간" in report_text(scene.toast) and "후속 → 통신 12시간" in report_text(scene.toast))
			scene.dispatch_action(scene.RELAY_CONTROL)
			assert("한계 14시간 · 유지" in scene.comms_status.text and "예약" in scene.power_status.text)
			assert("정수시설 복구 뒤" in report_text(scene.toast))
			scene.show_factory()
			assert("모듈 1개" in report_text(scene.overlay), "Factory output must be one module")
			scene.show_reserve_terminal()
			assert("후속 모듈 1개 생산" in report_text(scene.overlay), "Two copper bundles must supply one module")
		scene.preview_dispatch()
		var preview := report_text(scene.overlay)
		if entry[0] == "A":
			assert("정수시설  ·  4시간 도착 · 유지" in preview and "통신시설  ·  12시간 도착 · 유지" in preview, "The final preview must show both facilities surviving")
			assert("기존 모듈 1개 → 정수시설 · 4시간 도착" in preview and "후속 모듈 1개 → 통신시설 · 12시간 도착" in preview, "The final preview must explain the automatic opposite allocation")
		if entry[0] == "C" or entry[0] == "G":
			assert("기존 4시간 도착" in scene.comms_status.text and "후속 12시간 도착" in scene.water_status.text, "The reversed dispatch must switch both module destinations")
			assert("기존 모듈 1개 → 통신시설 · 4시간 도착" in preview and "후속 모듈 1개 → 정수시설 · 12시간 도착" in preview)
		if entry[0] == "D":
			assert("후속 모듈 수령처와 배송 계획 미정" in preview and "두 시설 모두 가동 한계를 초과" in preview and "미도착 · 중단 예상" in preview, "Withholding dispatch must explain the consequence before confirmation")
		scene.commit_dispatch()
		if entry[0] == "D":
			assert("두 시설에는 전달되지 않습니다" in str(root.get_node("Story").field_reports.back()["message"]), "The field report must distinguish production from delivery")
		assert(root.get_node("Story").ending == entry[4], "Scenario %s ending" % entry[0])
		assert(not scene.relay_active, "Support cannot be active at plan confirmation")
		scene.update_relay_state(3, 4)
		assert(not scene.relay_active, "Support cannot start before the water facility is restored")
		scene.update_relay_state(4, 4)
		assert(scene.relay_active == entry[5], "Scenario %s relay activation" % entry[0])
		assert(scene.water_offline == entry[6] and scene.comms_offline == entry[7], "Scenario %s facility outcome" % entry[0])
		scene.show_ending()
		var ending_title: String = {"dawn": "희망의 새벽", "field": "현장이 지킨 밤", "prepared": "준비된 복구", "partial": "불완전한 생존", "evacuation": "마지막 대피"}[str(entry[4])]
		assert(ending_title in report_text(scene.overlay), "Scenario %s ending screen" % entry[0])
		assert(scene.overlay.get_child(0) is TextureRect, "Scenario %s must have the city ending backdrop" % entry[0])
		assert(("정수시설  중단" if scene.water_offline else "정수시설  운영") in report_text(scene.overlay), "Scenario %s ending must show the water facility state" % entry[0])
		assert(("통신시설  중단" if scene.comms_offline else "통신시설  운영") in report_text(scene.overlay), "Scenario %s ending must show the communications facility state" % entry[0])
		if entry[4] == &"prepared" or entry[4] == &"partial":
			var expected_hour := "6시간째" if scene.water_offline else "9시간째"
			assert(expected_hour in report_text(scene.overlay), "Scenario %s must describe the actual stopped facility" % entry[0])
		if entry[0] == "A":
			scene.show_policy_summary()
			var first_page := report_text(scene.overlay)
			assert("다온시 긴급조달 결과 보고서" in first_page)
			assert("조달 정보·공급 경로" in first_page and "국가 비축·후속 생산" in first_page)
			assert("유휴 P-42 이관 / 별도 절차" in first_page)
			assert("구리 2묶음 → 후속 1개" in first_page)
			assert("S-17 발견·시설 통보" in first_page)
			assert("시설 사전 통보 완료" in first_page and "후속 모듈 1개 생산 지원" in first_page)
			var next_button: Button
			for button in scene.overlay.find_children("*", "Button", true, false):
				if button.text.begins_with("다음 기록"):
					next_button = button
			assert(is_instance_valid(next_button), "The report must expose a next-page button")
			next_button.pressed.emit()
			assert(scene.report_page == 1, "The report button must switch pages")
			var second_page := report_text(scene.overlay)
			assert("시설별 부품 도착" in second_page and "결말·공공서비스" in second_page)
			assert("예약·활성화 · 4시간부터" in second_page)
			assert("희망의 새벽 · 두 시설 유지" in second_page)
			var dispatch_report: Dictionary = root.get_node("Story").field_reports.back()
			assert("정수시설 배차" in dispatch_report["message"])
			scene.retry_dispatch()
			dispatch_report = root.get_node("Story").field_reports.back()
			assert("다시 검토" in dispatch_report["message"])
			assert(root.get_node("Story").risk_notice_sent and root.get_node("Story").relay_record_found, "Retry must preserve choices from earlier chapters")
			assert(scene.loaded_destination.is_empty() and not scene.relay_armed and root.get_node("Story").ending.is_empty(), "Retry only resets the final dispatch and its result")
		if entry[0] == "E":
			scene.show_policy_summary()
			scene.change_report_page()
			assert("미예약 · 지원 없음" in report_text(scene.overlay))
		if entry[0] == "D":
			scene.show_policy_summary()
			scene.change_report_page()
			assert("미도착 · 배차 보류" in report_text(scene.overlay), "No dispatch must not show two deliveries")
		if entry[0] == "F" or entry[0] == "B":
			scene.show_policy_summary()
			scene.change_report_page()
			assert(ending_title in report_text(scene.overlay), "Scenario %s report must match ending" % entry[0])
		if entry[0] != "A":
			scene.report_page = 1
			scene.show_policy_summary()
			assert(ending_title in report_text(scene.overlay), "Scenario %s report must match the ending" % entry[0])
			if entry[4] == &"prepared" or entry[4] == &"partial":
				var stopped_site := "정수 중단" if scene.water_offline else "통신 중단"
				assert(ending_title + " · " + stopped_site in report_text(scene.overlay), "Scenario %s report must identify the stopped facility" % entry[0])
		scene.free()
	print("PASS dispatch: eight timing paths, relay activation, five endings and facility-specific reports")
	quit()

func report_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result += node.text + "\n"
	for child in node.get_children():
		result += report_text(child)
	return result
