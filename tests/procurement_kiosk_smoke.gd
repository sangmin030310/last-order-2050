extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://chapter_one.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await physics_frame
	await physics_frame
	var body: StaticBody2D = scene.get_node("Actors/ProcurementKiosk")
	assert(body.get_node("Collision").shape is RectangleShape2D)
	assert(scene.player.test_move(Transform2D(0.0, Vector2(590, 488)), Vector2(120, 0)), "Player must not pass through the kiosk")
	assert(scene.player.test_move(Transform2D(0.0, Vector2(650, 540)), Vector2(0, -80)), "Player must not pass through the kiosk from below")
	assert(scene.companion.test_move(Transform2D(0.0, Vector2(590, 488)), Vector2(120, 0)), "Companion must not pass through the kiosk")
	scene.player.position = Vector2(650, 540)
	assert(scene.nearby_site() == scene.TERMINAL, "Interaction must remain reachable beside the kiosk")
	print("PASS procurement kiosk: solid footprint and reachable interaction")
	quit()
