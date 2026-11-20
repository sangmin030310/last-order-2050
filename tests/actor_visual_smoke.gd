extends SceneTree

const SCENES := ["prologue", "chapter_one", "hospital", "recovery", "archive_room", "stockroom", "dispatch_room"]
const DIRECTIONS := [Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1), Vector2.UP, Vector2(1, -1)]
const NAMES := ["r", "fr", "f", "fl", "l", "bl", "b", "br"]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for scene_name: String in SCENES:
		var scene := (load("res://%s.tscn" % scene_name) as PackedScene).instantiate()
		root.add_child(scene)
		scene.set_physics_process(false)
		for actor_name: String in ["Player", "Companion"]:
			var body: CharacterBody2D = scene.get_node("Actors/" + actor_name)
			var visual = body.get_node("Sprite")
			visual.set_process(false)
			for index in range(8):
				body.position += DIRECTIONS[index].normalized() * 3.0
				visual._process(1.0 / 60.0)
				assert(visual.facing == NAMES[index], scene_name + ": wrong direction")
				assert(visual.texture.atlas.resource_path.ends_with("_%s.png" % NAMES[index]))
				assert(is_equal_approx(visual.texture.get_height() * visual.scale.y, visual.display_height))
				assert(not visual.flip_h)
				visual._process(1.0 / 60.0)
				assert(is_zero_approx(visual.rotation), "Idle must stop swaying")
				assert(is_equal_approx(visual.position.y, -visual.display_height * 0.5), "Idle feet must stay anchored")
		print("PASS ", scene_name, ": both actors, eight directions, size and idle")
		scene.free()
	print("All actor visual checks passed.")
	quit()
