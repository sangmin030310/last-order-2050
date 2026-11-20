extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func open_scene(scene_name: String) -> Node:
	root.get_node("Story").reset()
	var scene = load("res://%s.tscn" % scene_name).instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	return scene

func run() -> void:
	var scene = open_scene("prologue")
	var arrow = scene.get_node("ObjectiveArrow")
	assert(scene.phase == scene.Phase.TITLE and scene.overlay.visible, "Show the procurement mission before exploration")
	scene.start_mission()
	arrow._process(0.016)
	assert(arrow.visible and scene.navigation_hint().target == scene.terminal.position)
	scene.player.position = scene.terminal.position
	arrow._process(0.016)
	assert(not arrow.visible, "Hide on arrival")
	scene.phase = scene.Phase.RADIO
	assert(scene.navigation_hint().target == scene.radio.position)
	scene.show_overlay("안내", "목표", "설명", "확인", func(): pass)
	arrow._process(0.016)
	assert(not arrow.visible, "Hide during dialogue")
	scene.free()
	scene = open_scene("chapter_one")
	assert(scene.navigation_hint().target == scene.sites[scene.HOSPITAL].position)
	scene.mission = scene.Mission.SEARCH
	assert(scene.navigation_hint().target == scene.sites[scene.TERMINAL].position)
	scene.review_procurement(&"", "기한 초과", scene.mission_detail)
	assert(root.get_node("Story").prepared_route.is_empty(), "Reject late or unverified supplies")
	assert(not root.get_node("Story").procurement_reviewed, "Opening the terminal or rejecting a route is not a completed review")
	scene.review_procurement(scene.WAREHOUSE, "", scene.mission_detail)
	assert(root.get_node("Story").procurement_reviewed, "A valid comparison records the procurement review")
	assert(scene.navigation_hint().target == scene.sites[scene.WAREHOUSE].position)
	scene.free()
	scene = open_scene("hospital")
	scene.active_tiger = true
	assert(scene.navigation_hint().target == scene.PAD)
	scene.companion.position = scene.PAD
	assert(scene.navigation_hint().is_empty(), "Do not lead tiger off the pressure pad")
	scene.active_tiger = false
	scene.player.position = Vector2(850, 500)
	assert(scene.navigation_hint().target == Vector2(640, 450), "Approach the doorway instead of the wall")
	scene.unlocked = true
	root.get_node("Story").request_received = true
	assert(scene.navigation_hint().target == scene.EXIT)
	scene.free()
	scene = open_scene("archive_room")
	scene.read_docs.append(&"water")
	assert(scene.navigation_hint().target == scene.sites[scene.COMMS_DOC].position)
	scene.read_docs.append(&"comms")
	assert(scene.navigation_hint().target == scene.sites[scene.OFFICE].position)
	assert(root.get_node("Story").field_reports.is_empty(), "The common supplier must remain the player's discovery")
	scene.show_archive()
	scene.select_archive_evidence(0, &"maker")
	scene.select_archive_evidence(1, &"maker")
	assert(root.get_node("Story").field_reports.is_empty() and scene.archive_selection[0].is_empty() and scene.archive_selection[1].is_empty(), "Different manufacturers must not reveal the shared supplier")
	scene.select_archive_evidence(0, &"spec")
	scene.select_archive_evidence(1, &"supplier")
	assert(root.get_node("Story").field_reports.is_empty() and scene.archive_selection[0].is_empty() and scene.archive_selection[1] == &"supplier", "Wrong left choice clears while correct right choice stays selected")
	var right_button = scene.archive_buttons[scene.archive_button_key(1, &"supplier")]
	assert(right_button.get_theme_stylebox("normal").bg_color == right_button.ACTIVE_FILL, "Correct selection remains highlighted")
	var wrong_button = scene.archive_buttons[scene.archive_button_key(0, &"spec")]
	assert(wrong_button.get_theme_stylebox("normal").bg_color == wrong_button.NORMAL_FILL, "Wrong selection returns to the neutral color")
	scene.show_archive()
	assert(scene.archive_selection[1] == &"supplier", "Reopening the records keeps the selected evidence")
	right_button = scene.archive_buttons[scene.archive_button_key(1, &"supplier")]
	assert(right_button.get_theme_stylebox("normal").bg_color == right_button.ACTIVE_FILL, "Reopened evidence stays highlighted")
	scene.select_archive_evidence(0, &"supplier")
	assert(not root.get_node("Story").records_linked, "Supplier match alone must not finish the risk analysis")
	assert(root.get_node("Story").field_reports.size() == 1, "Record the supplier only after the player finds it")
	scene.confirm_diversification()
	assert(root.get_node("Story").records_linked and scene.stage == scene.Stage.RECORDS and not root.get_node("Story").risk_notice_sent)
	scene.send_risk_notice()
	assert(root.get_node("Story").risk_notice_sent and scene.stage == scene.Stage.RESERVE)
	scene.free()
	scene = open_scene("stockroom")
	scene.check_reserve_request()
	assert(not root.get_node("Story").reserve_checked, "Missing manufacturer request cannot pass eligibility review")
	scene.free()
	scene = open_scene("stockroom")
	root.get_node("Story").factory_checked = true
	assert(scene.navigation_hint().target == scene.sites[scene.RESERVE_TERMINAL].position)
	scene.show_reserve_terminal()
	scene.approve_reserve_request()
	assert(not root.get_node("Story").reserve_approved, "Approval requires eligibility and supply-condition review")
	scene.check_reserve_request()
	assert(root.get_node("Story").reserve_checked and not root.get_node("Story").reserve_approved)
	scene.approve_reserve_request()
	assert(root.get_node("Story").reserve_approved, "Reviewed request can be approved")
	scene.close_dialog()
	scene.active_tiger = true
	scene.select_circuit(scene.Circuit.RACK)
	assert(scene.circuit == scene.Circuit.RACK and not scene.active_tiger, "Tiger routes power and control returns to the carrier")
	assert("전원 대기" in scene.scanner_status.text)
	scene.cargo = scene.COPPER_A
	scene.circuit = scene.Circuit.SCAN
	scene.refresh()
	assert("전원 연결" in scene.scanner_status.text)
	assert(scene.navigation_hint().target == scene.sites[scene.SCANNER].position)
	scene.active_tiger = true
	assert(scene.navigation_hint().actor == scene.companion)
	assert(scene.navigation_hint().target == scene.sites[scene.POWER_PAD].position)
	scene.active_tiger = false
	scene.cargo = scene.ALUMINUM
	scene.stockroom_action(scene.SCANNER)
	assert(scene.cargo.is_empty() and scene.scanned_copper.is_empty(), "Aluminum must be rejected")
	scene.cargo = scene.COPPER_A
	scene.stockroom_action(scene.SCANNER)
	assert(scene.scanned_copper.size() == 1 and not root.get_node("Story").copper_loaded)
	assert("1/2" in scene.scanner_status.text)
	assert(scene.navigation_hint().target == scene.sites[scene.POWER_PAD].position, "After the first scan, lead the player to power routing")
	scene.circuit = scene.Circuit.RACK
	assert(scene.navigation_hint().target == scene.sites[scene.COPPER_B].position, "Rack power must lead to the second copper bundle")
	scene.stockroom_action(scene.COPPER_B)
	assert(scene.navigation_hint().target == scene.sites[scene.POWER_PAD].position, "Carrying copper with scanner power off must lead back to the panel")
	scene.circuit = scene.Circuit.SCAN
	scene.stockroom_action(scene.SCANNER)
	assert(scene.scanned_copper.size() == 2 and root.get_node("Story").copper_loaded, "Two copper scans start one-module production")
	assert("검수 완료" in scene.scanner_status.text)
	var policy_popup: Control = scene.overlay
	scene.stockroom_action(scene.SCANNER)
	assert(scene.overlay == policy_popup, "The reserve-policy popup must not repeat after completion")
	assert(scene.navigation_hint().target == scene.sites[scene.EXIT].position)
	scene.free()
	scene = open_scene("recovery")
	scene.stage = scene.Stage.RESERVE
	assert(scene.navigation_hint().target == scene.sites[scene.FACTORY].position)
	root.get_node("Story").factory_checked = true
	assert(scene.navigation_hint().target == scene.sites[scene.STOCK].position)
	scene.free()
	scene = open_scene("dispatch_room")
	scene.loaded_destination = scene.WATER_PORT
	assert(scene.navigation_hint().target == scene.sites[scene.LATCH].position)
	scene.stage = scene.Stage.ENDING
	assert(scene.navigation_hint().is_empty())
	scene.free()
	var story := root.get_node("Story")
	story.reset()
	story.hospital_restored = true
	story.hospital_clue = "정수시설 기록"
	scene = load("res://recovery.tscn").instantiate()
	root.add_child(scene)
	assert(story.records_intro_seen and is_instance_valid(scene.overlay), "Show the next chapter's briefing once")
	scene.free()
	scene = load("res://recovery.tscn").instantiate()
	root.add_child(scene)
	assert(not is_instance_valid(scene.overlay), "Returning to the street must not repeat the briefing")
	scene.free()
	print("PASS navigation: 7 scenes, arrival, dialogue, door routing, actor switch, changing objectives")
	quit()
