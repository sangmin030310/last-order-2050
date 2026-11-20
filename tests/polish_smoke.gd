extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func audit_text(node: Node) -> void:
	if node is Label and node.is_visible_in_tree() and node.has_method("fit_text"):
		node.fit_text()
		assert(node.get_minimum_size().y <= node.layout_size.y + 1, "Polished UI must fit")
		if node.get_parent() is Panel:
			assert(Rect2(Vector2.ZERO, node.get_parent().size).encloses(node.get_rect()))
	for child in node.get_children():
		audit_text(child)

func run() -> void:
	var story = root.get_node("Story")
	var pause = root.get_node("PauseMenu")
	story.reset()
	var scene = load("res://hospital.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var controls_visible := false
	for label in scene.interface.find_children("*", "Label", true, false):
		if "Esc 메뉴" in label.text:
			label.fit_text()
			assert(label.get_theme_font_size("font_size") >= 13, "Persistent controls must remain readable")
			controls_visible = true
	assert(controls_visible, "Exploration HUD must show the menu shortcut")
	scene.active_tiger = true
	assert(scene.controlled_actor() == scene.companion)
	scene.companion.get_node("Ground")._process(0.2)
	assert(scene.companion.get_node("Ground").emphasis > 0.9)
	scene.player.get_node("Ground")._process(0.2)
	assert(is_zero_approx(scene.player.get_node("Ground").emphasis))
	scene.actor_changed()
	assert(is_instance_valid(scene.toast))
	scene.place_interaction_prompt(scene.nearby_hint, "E  ·  방화문 열림 고정", Vector2(640, 420), 440)
	assert(scene.nearby_hint.size.y == 28 and scene.nearby_hint.size.x < 300, "Nearby prompts should be compact")
	scene.place_interaction_prompt(scene.nearby_hint, "E  ·  방화문 열림 고정", Vector2(10, 700), 700)
	assert(scene.nearby_hint.position.x >= 18 and scene.nearby_hint.position.y + scene.nearby_hint.size.y <= 615, "Interaction prompts must stay clear of the screen edge and lower HUD")
	scene.place_interaction_prompt(scene.nearby_hint, "E  ·  방화문 열림 고정", Vector2(640, 30), 30)
	assert(scene.nearby_hint.position.y >= 155, "Interaction prompts must stay clear of the upper HUD")
	audit_text(scene.nearby_hint)
	audit_text(scene)
	scene.show_overlay("시설팀", "일시정지 검사", "복귀 후 대화를 이어갈 수 있습니다.", "확인", func(): pass)
	scene.overlay_action.grab_focus()
	pause.open()
	assert(paused and pause.opened)
	var saved_position: Vector2 = scene.player.position
	var saved_elapsed: float = scene.elapsed
	await create_timer(0.08).timeout
	assert(scene.player.position == saved_position and is_equal_approx(scene.elapsed, saved_elapsed))
	pause.toggle_help()
	assert(pause.heading.text == "조작법")
	audit_text(pause.surface)
	pause.toggle_help()
	assert("현재 목표" in pause.detail.text)
	pause.cycle_policy()
	assert("조달청의 역할" in pause.detail.text)
	story.request_received = true
	pause.cycle_policy()
	assert("나라장터" in pause.detail.text)
	story.add_field_report(&"hospital_call", "공공병원 시설팀", "전력 12시간 남음")
	story.add_field_report(&"hospital_call", "중복", "표시되면 안 됨")
	story.add_field_report(&"factory_request", "국내 제조사", "구리 2묶음 필요")
	pause.cycle_report()
	assert("공공병원 시설팀" in pause.detail.text and "전력 12시간 남음" in pause.detail.text)
	pause.cycle_report()
	assert("국내 제조사" in pause.detail.text and story.field_reports.size() == 2)
	audit_text(pause.surface)
	pause.close()
	assert(not paused and scene.overlay_action.has_focus())
	pause.open()
	pause.return_to_menu()
	await process_frame
	await process_frame
	assert(not paused and current_scene.scene_file_path == "res://main_menu.tscn")
	assert(not pause.can_open(), "Pause must not intercept main menu")
	current_scene.free()
	current_scene = null
	story.reset()
	scene = load("res://archive_room.tscn").instantiate()
	root.add_child(scene)
	scene.read_docs.append(&"water")
	assert(not scene.active_site(scene.WATER_DOC) and scene.active_site(scene.COMMS_DOC))
	scene.read_docs.append(&"comms")
	assert(scene.active_site(scene.OFFICE))
	scene.place_interaction_prompt(scene.interaction, "E  ·  비축물자 관리 단말기", Vector2(640, 420), 440)
	assert(scene.interaction.size.y == 28 and scene.interaction.size.x <= 300, "Long interaction prompts should fit the compact layout")
	audit_text(scene.interaction)
	scene.notify("검사 완료", "목표 업데이트")
	var old_toast = scene.toast
	scene.notify("다음 목표", "알림 교체")
	assert(scene.toast != old_toast and not old_toast.visible)
	audit_text(scene)
	scene.free()
	print("PASS polish: active rings, notices, text bounds, pause freezes gameplay, help, focus restore, menu return, archive markers")
	quit()
