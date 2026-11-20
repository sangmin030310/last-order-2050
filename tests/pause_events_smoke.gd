extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func click_button(button: Button) -> void:
	var at: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	root.push_input(down, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	root.push_input(up, true)

func run() -> void:
	var scene = load("res://prologue.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var pause = root.get_node("PauseMenu")
	pause.open()
	await process_frame
	var buttons: Array = pause.policy_button.get_parent().get_children()
	for button: Button in buttons:
		assert((button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Color("#183441"))
		assert(button.get_theme_color("font_color") == Color.WHITE)
		assert((button.get_theme_stylebox("hover") as StyleBoxFlat).bg_color == Color("#aaffea"))
		assert((button.get_theme_stylebox("focus") as StyleBoxFlat).bg_color == Color.TRANSPARENT)
		assert(button.get_theme_color("font_focus_color") == Color.WHITE)
	var navigate := InputEventKey.new()
	navigate.keycode = KEY_DOWN
	navigate.pressed = true
	root.push_input(navigate, true)
	await process_frame
	var keyboard_focus_visible := false
	for button: Button in buttons:
		if button.has_focus() and (button.get_theme_stylebox("focus") as StyleBoxFlat).bg_color == Color("#aaffea"):
			assert(button.get_theme_color("font_focus_color") == Color("#102b31"))
			keyboard_focus_visible = true
	assert(keyboard_focus_visible, "Keyboard input must reveal focus")
	click_button(buttons[1])
	await process_frame
	assert(pause.heading.text == "조작법", "Help button must respond to a mouse click while paused")
	click_button(buttons[2])
	await process_frame
	assert(pause.showing_policy, "Policy button must respond to a mouse click while paused")
	click_button(buttons[4])
	await process_frame
	assert(is_instance_valid(pause.settings_screen) and pause.settings_screen.mode_button.has_focus())
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	pause._unhandled_input(cancel)
	assert(not is_instance_valid(pause.settings_screen) and pause.settings_button.has_focus())
	click_button(buttons[0])
	await process_frame
	assert(not pause.opened and not paused, "Continue must resume the game")
	pause.open()
	await process_frame
	buttons = pause.policy_button.get_parent().get_children()
	assert(buttons[0].focus_neighbor_bottom == buttons[0].get_path_to(buttons[1]))
	assert(buttons.back().focus_neighbor_bottom == buttons.back().get_path_to(buttons[0]))
	click_button(buttons.back())
	await process_frame
	await process_frame
	assert(not pause.opened and current_scene.scene_file_path == "res://main_menu.tscn", "Menu button must change scenes")
	print("PASS pause events: help, policy, resume, menu mouse clicks and keyboard focus order")
	quit()
