extends Node
## Display and readability preferences shared by every scene.

signal settings_changed

const SETTINGS_PATH := "user://display_settings.cfg"
const WINDOW_SIZE := Vector2i(1152, 648)
const MODE_NAMES := ["창 모드", "최대화", "전체 화면"]

var display_mode := 1
var large_text := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		display_mode = clampi(int(config.get_value("display", "mode", 1)), 0, 2)
		large_text = bool(config.get_value("display", "large_text", false))
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	apply_display_mode.call_deferred()

func mode_name() -> String:
	return MODE_NAMES[display_mode]

func cycle_display_mode() -> void:
	display_mode = (display_mode + 1) % MODE_NAMES.size()
	apply_display_mode()
	save_settings()
	settings_changed.emit()

func toggle_large_text() -> void:
	large_text = not large_text
	save_settings()
	settings_changed.emit()

func apply_display_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_tree().root
	match display_mode:
		0:
			window.mode = Window.MODE_WINDOWED
			window.size = WINDOW_SIZE
			window.move_to_center()
		1:
			window.mode = Window.MODE_MAXIMIZED
		2:
			window.mode = Window.MODE_FULLSCREEN

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "mode", display_mode)
	config.set_value("display", "large_text", large_text)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("화면 설정을 저장하지 못했습니다.")
