extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var settings = root.get_node("GameSettings")
	var original_mode: int = settings.display_mode
	var original_large: bool = settings.large_text
	var settings_path: String = ProjectSettings.globalize_path(settings.SETTINGS_PATH)
	var existed := FileAccess.file_exists(settings_path)
	var original_bytes := FileAccess.get_file_as_bytes(settings_path) if existed else PackedByteArray()
	var menu = load("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var button: Button = menu.menu.get_child(0)
	var label: Label = load("res://ui_label.gd").new()
	label.text = "글자 크기 확인"
	label.configure(Vector2(300, 80), 20)
	menu.add_child(label)
	var button_size := button.get_theme_font_size("font_size")
	var label_size := label.get_theme_font_size("font_size")
	settings.toggle_large_text()
	assert(settings.large_text != original_large)
	assert(button.get_theme_font_size("font_size") == button_size + (2 if settings.large_text else -2))
	assert(label.get_theme_font_size("font_size") == label_size + (2 if settings.large_text else -2))
	var config := ConfigFile.new()
	assert(config.load(settings.SETTINGS_PATH) == OK)
	assert(config.get_value("display", "large_text") == settings.large_text)
	settings.cycle_display_mode()
	assert(settings.display_mode == (original_mode + 1) % 3)
	assert(config.load(settings.SETTINGS_PATH) == OK)
	assert(config.get_value("display", "mode") == settings.display_mode)
	assert(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP)
	menu.free()
	settings.display_mode = original_mode
	settings.large_text = original_large
	settings.settings_changed.emit()
	if existed:
		var file := FileAccess.open(settings_path, FileAccess.WRITE)
		assert(file != null)
		file.store_buffer(original_bytes)
		file.close()
	else:
		assert(DirAccess.remove_absolute(settings_path) == OK)
	print("PASS settings: display mode, large text, persistence, aspect ratio")
	quit()
