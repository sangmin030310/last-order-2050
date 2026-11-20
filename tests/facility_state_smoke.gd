extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var story = root.get_node("Story")
	story.reset()
	story.hospital_route = &"warehouse"
	story.hospital_open = true
	story.hospital_clue = "시설 두 곳에서 같은 고장이 보고됐습니다."
	var hospital = load("res://hospital.tscn").instantiate()
	root.add_child(hospital)
	current_scene = hospital
	await process_frame
	hospital.set_physics_process(false)
	assert(hospital.power_indicator.position == Vector2(1029, 114), "Power status must sit below the upper-right countdown")
	assert("불안정" in hospital.power_indicator_text.text)
	hospital.modal = true
	hospital.show_overlay("시설팀", "부품 인계", "검수 완료", "시설팀에 인계", hospital.restore_hospital)
	hospital.restore_hospital()
	assert(story.hospital_restored)
	assert("정상" in hospital.power_indicator_text.text)
	assert(not hospital.overlay.visible, "The room must be visible before the completion dialog")
	await create_timer(2.0).timeout
	assert(hospital.restored_light > 0.99 and hospital.overlay.visible, "Lights must return before the completion dialog")
	hospital.free()
	current_scene = null
	story.reset()
	story.copper_loaded = true
	var dispatch = load("res://dispatch_room.tscn").instantiate()
	root.add_child(dispatch)
	current_scene = dispatch
	await process_frame
	dispatch.set_physics_process(false)
	dispatch.loaded_destination = dispatch.WATER_PORT
	dispatch.preview_dispatch()
	dispatch.commit_dispatch()
	var water_shadow: TextureRect = dispatch.overlay.get_node("WaterShadow")
	var comms_shadow: TextureRect = dispatch.overlay.get_node("CommsShadow")
	assert(water_shadow.get_meta("facility_state") == "waiting")
	assert(comms_shadow.get_meta("facility_state") == "waiting")
	await create_timer(1.85).timeout
	assert(water_shadow.get_meta("facility_state") == "restored", "Water plant must light up after the four-hour delivery")
	assert(comms_shadow.get_meta("facility_state") == "waiting")
	await create_timer(1.35).timeout
	assert(comms_shadow.get_meta("facility_state") == "offline", "Communications building must darken after its nine-hour limit")
	await create_timer(0.95).timeout
	assert(comms_shadow.get_meta("facility_state") == "restored", "The delayed module must light the communications building again")
	dispatch.free()
	current_scene = null
	story.reset()
	print("PASS facility state: hospital reveal and timed water/comms lighting")
	quit()
