extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://main_menu.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var exit: Button = scene.menu.get_child(4)
	exit.pressed.emit()
	exit.pressed.emit()
	assert(scene.closing and scene.has_node("ExitFade"))
	assert(exit.disabled)
	root.tree_exiting.connect(func(): print("PASS exit: click guard, fade, clean game shutdown"))
	await create_timer(1.0).timeout
	printerr("FAIL: Exit button did not close the game")
	quit(1)
