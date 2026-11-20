extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func click(control: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func run() -> void:
	var scene = load("res://main_menu.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var launch: Panel = scene.get_node("LaunchPanel")
	assert(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(launch.get_global_rect()))
	var buttons: Array[Button] = []
	for child in scene.menu.get_children():
		if child is Button:
			buttons.append(child)
	assert(buttons.size() == 5)
	assert(buttons[0].text == "게임 시작" and buttons[3].text == "화면·글자 설정" and buttons[4].text == "종료")
	assert(buttons[0].has_focus())
	for button in buttons:
		assert(launch.get_global_rect().encloses(button.get_global_rect()))
	var logo: Control = scene.menu.get_node("AgencyLogo")
	assert(logo.get_global_rect().position.y >= buttons[4].get_global_rect().end.y + 8)
	assert(launch.get_global_rect().encloses(logo.get_global_rect()))
	var hover := InputEventMouseMotion.new()
	hover.position = buttons[1].get_global_rect().get_center()
	hover.global_position = hover.position
	root.push_input(hover, true)
	await process_frame
	assert(buttons[1].has_focus(), "Mouse hover must update keyboard focus")
	assert("전환" in scene.menu_hint.text, "Hover must update the menu description")
	click(buttons[1])
	assert(not scene.menu.visible)
	assert(scene.return_focus == buttons[1])
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	scene._unhandled_input(cancel)
	assert(scene.menu.visible)
	assert(buttons[1].has_focus(), "Esc must restore the original button")
	buttons[2].grab_focus()
	var confirm := InputEventAction.new()
	confirm.action = "ui_accept"
	confirm.pressed = true
	root.push_input(confirm, true)
	confirm = InputEventAction.new()
	confirm.action = "ui_accept"
	confirm.pressed = false
	root.push_input(confirm, true)
	assert(is_instance_valid(scene.popup))
	for back in scene.popup.find_children("*", "Button", true, false):
		if back.text == "돌아가기":
			click(back)
	assert(not is_instance_valid(scene.popup) and buttons[2].has_focus())
	click(buttons[3])
	assert(is_instance_valid(scene.popup) and scene.popup.mode_button.text.begins_with("화면 모드"))
	assert(scene.popup.mode_button.has_focus())
	scene._unhandled_input(cancel)
	assert(not is_instance_valid(scene.popup) and buttons[3].has_focus())
	assert(buttons[4].get_node(buttons[4].focus_neighbor_bottom) == buttons[0], "Navigation wraps to Start")
	assert(buttons[0].get_node(buttons[0].focus_neighbor_top) == buttons[4], "Navigation wraps to Exit")
	click(buttons[0])
	buttons[0].pressed.emit()
	assert(scene.starting and scene.has_node("ExitFade"))
	for button in buttons:
		assert(button.disabled, "Transition must block double activation")
	await create_timer(0.4).timeout
	assert(current_scene.scene_file_path == "res://intro.tscn", "Start must open the existing movie scene")
	print("PASS main menu: hover, focus, descriptions, popup buttons, Esc, navigation, duplicate-click guard, movie transition")
	quit()
