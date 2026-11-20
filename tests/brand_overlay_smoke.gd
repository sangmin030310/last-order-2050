extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var image := (load("res://art/pps_logo.png") as Texture2D).get_image()
	assert(image.get_pixel(0, 0).a == 0, "Logo background must be transparent")
	var brand = root.get_node("BrandOverlay")
	for scene_name in ["main_menu", "intro", "hospital", "stockroom", "dispatch_room"]:
		var scene = load("res://%s.tscn" % scene_name).instantiate()
		root.add_child(scene)
		current_scene = scene
		await process_frame
		await process_frame
		assert(brand.badge.visible == (scene_name != "main_menu"), "Corner logo must be hidden only on the main menu")
		var rect: Rect2 = brand.badge.get_global_rect()
		assert(root.get_visible_rect().encloses(rect), "Logo must remain inside viewport")
		assert(brand.badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Logo must not intercept clicks")
		assert(is_equal_approx(rect.end.y, root.get_visible_rect().end.y - 2))
		assert(is_equal_approx(rect.end.x, root.get_visible_rect().end.x - 16))
		assert(rect.size.y <= 24 and not brand.badge is Panel, "Only a slim transparent logo, no backing plate")
		var wordmark: Label = brand.badge.get_node("Wordmark")
		assert(wordmark.text == "조달청", "Wordmark must spell 조달청 exactly")
		assert(wordmark.get_theme_color("font_color") == Color.WHITE)
		assert(Rect2(Vector2.ZERO, brand.badge.size).encloses(wordmark.get_rect()))
		current_scene = null
		scene.free()
	print("PASS logo: hidden on main menu, visible in story, viewport bounds, click-through")
	quit()
