extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var story := root.get_node("Story")
	story.reset()
	var scene = load("res://prologue.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	assert(scene.phase == scene.Phase.TITLE)
	scene.start_mission()
	scene.player.position = scene.terminal.position
	scene.interact()
	assert(scene.phase == scene.Phase.RADIO and not scene.radio_powered)
	scene.player.position = scene.radio.position
	scene.interact()
	assert(scene.phase == scene.Phase.TUNING and is_instance_valid(scene.signal_needle))
	assert(is_equal_approx(scene.signal_time_fill.size.x, scene.SIGNAL_TRACK_WIDTH), "Signal timer bar starts full")
	var pause = root.get_node("PauseMenu")
	pause.open()
	var paused_signal: float = scene.signal_value
	await create_timer(0.08).timeout
	assert(is_equal_approx(scene.signal_value, paused_signal), "Signal motion must stop during pause")
	pause.close()
	scene._physics_process(scene.SIGNAL_TIME_LIMIT)
	assert(scene.signal_timed_out and scene.signal_lock_button.text.begins_with("다시 시도"), "Expired signal must stop and offer a retry")
	assert(is_zero_approx(scene.signal_time_fill.size.x), "Signal timer bar empties on timeout")
	var expired_signal: float = scene.signal_value
	scene._physics_process(0.1)
	assert(is_equal_approx(scene.signal_value, expired_signal), "Expired signal must remain stopped")
	scene.lock_signal()
	assert(not scene.signal_timed_out and is_zero_approx(scene.signal_elapsed) and is_zero_approx(scene.signal_value), "Retry must reset the timer and needle")
	assert(is_equal_approx(scene.signal_time_fill.size.x, scene.SIGNAL_TRACK_WIDTH), "Retry restores the timer bar")
	scene.set_physics_process(false)
	scene.signal_value = 0.0
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter, true)
	assert(scene.signal_attempts == 1, "Enter must lock on key press")
	enter.pressed = false
	root.push_input(enter, true)
	assert(scene.signal_attempts == 1, "Releasing Enter must not lock again")
	var interact_key := InputEventKey.new()
	interact_key.physical_keycode = KEY_E
	interact_key.pressed = true
	root.push_input(interact_key, true)
	assert(scene.phase == scene.Phase.TUNING and scene.signal_attempts == 2)
	interact_key.pressed = false
	root.push_input(interact_key, true)
	assert(scene.signal_attempts == 2, "Releasing E must not lock again")
	assert(story.city_hours == 72, "Missing the signal must not consume mission time")
	assert(scene.signal_zone.size.x > 0.24 * scene.SIGNAL_TRACK_WIDTH)
	scene.signal_value = scene.SIGNAL_CENTER
	interact_key.pressed = true
	root.push_input(interact_key, true)
	assert(scene.phase == scene.Phase.HANDOFF and scene.radio_powered)
	assert(story.field_reports.size() == 1 and is_instance_valid(scene.overlay_action))
	scene.accept_request()
	assert(scene.phase == scene.Phase.COMPLETE)
	scene.free()
	current_scene = null
	print("PASS prologue signal: exploration, retry, wider target, hospital call, chapter handoff")
	quit()
