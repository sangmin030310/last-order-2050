extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://stockroom.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var effects = scene.effects
	effects.set_physics_process(false)
	effects.set_process(false)
	effects._physics_process(1.0 / 60.0)
	assert(effects.particles.is_empty(), "No footsteps while standing still")
	scene.player.position += Vector2(26, 0)
	effects._physics_process(1.0 / 60.0)
	assert(effects.particles.size() == 2, "Walking emits small footstep puffs")
	effects._process(2.0)
	assert(effects.particles.is_empty(), "Footsteps expire")
	scene.player.position += Vector2(100, 0)
	effects._physics_process(1.0 / 60.0)
	assert(effects.particles.is_empty(), "Teleport must not emit footsteps")
	scene.active_tiger = false
	root.get_node("Story").reserve_approved = true
	scene.circuit = scene.Circuit.SCAN
	scene.cargo = scene.COPPER_A
	scene.stockroom_action(scene.SCANNER)
	assert(effects.rings.size() == 1 and effects.rings[0].success, "Copper inspection emits success effect")
	for index in range(30):
		effects.burst(Vector2(640, 360), Color.WHITE, true)
	assert(effects.particles.size() <= 96 and effects.rings.size() <= 12, "Effects are bounded")
	effects._process(2.0)
	assert(effects.particles.is_empty() and effects.rings.is_empty(), "All effects clean up")
	print("PASS effects: idle, movement, teleport, inspection, limits and cleanup")
	quit()
