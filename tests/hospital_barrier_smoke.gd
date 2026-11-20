extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://hospital.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await physics_frame
	await physics_frame
	var player: CharacterBody2D = scene.player
	var crossing := Transform2D(0.0, Vector2(640, 450))
	assert(player.test_move(Transform2D(0.0, Vector2(300, 450)), Vector2(0, -80)), "Left wall must block")
	assert(player.test_move(Transform2D(0.0, Vector2(950, 450)), Vector2(0, -80)), "Right wall must block")
	assert(player.test_move(crossing, Vector2(0, -80)), "Locked door must block")
	player.position = scene.PAD
	scene.update_pad_feedback()
	assert("조달호로 전환" in scene.available_action(), "Wrong actor must receive a switch hint")
	assert(is_instance_valid(scene.toast), "The pad must respond when Jodari steps on it")
	var first_warning = scene.toast
	scene.update_pad_feedback()
	assert(scene.toast == first_warning, "The warning must not repeat every frame")
	player.position = Vector2(530, 530)
	scene.update_pad_feedback()
	player.position = scene.PAD
	scene.update_pad_feedback()
	assert(scene.toast != first_warning, "The warning can reappear after leaving and returning")
	player.position = crossing.origin
	scene.companion.position = scene.PAD
	scene.sync_gate()
	await physics_frame
	await physics_frame
	assert(scene.gate.disabled, "Pressure pad must open the door")
	assert(not player.test_move(crossing, Vector2(0, -80)), "Open passage must be traversable")
	var visual = scene.get_node("Actors/SteelPartition")
	visual._process(0.25)
	assert(is_equal_approx(visual.opening, 1.0))
	scene.companion.position = Vector2(735, 535)
	scene.sync_gate()
	await physics_frame
	await physics_frame
	assert(not scene.gate.disabled, "Leaving the pad must close the door")
	scene.unlocked = true
	scene.sync_gate()
	await physics_frame
	await physics_frame
	assert(scene.gate.disabled, "Fixed switch must keep the door open")
	print("PASS hospital: solid walls, locked door, pressure pad, sliding visual, fixed switch")
	quit()
