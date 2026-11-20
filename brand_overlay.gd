extends CanvasLayer
## Corner logo during the story; the main menu has its own logo in the launch panel.

var badge: Control

func _ready() -> void:
	layer = 16
	var surface := Control.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge = Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -128
	badge.offset_right = -16
	badge.offset_top = -26
	badge.offset_bottom = -2
	var logo := TextureRect.new()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var source := load("res://art/pps_logo.png") as Texture2D
	var trimmed := AtlasTexture.new()
	trimmed.atlas = source
	var used := source.get_image().get_used_rect()
	# Keep the cutout emblem, using the clear gap before the raster lettering.
	trimmed.region = Rect2i(used.position, Vector2i(int(source.get_width() * 0.43) - used.position.x, used.size.y))
	logo.texture = trimmed
	badge.add_child(logo)
	logo.position = Vector2.ZERO
	logo.size = Vector2(28, 24)
	# Native text stays legible at this small size and spells the name exactly.
	var wordmark := preload("res://ui_label.gd").new()
	wordmark.name = "Wordmark"
	wordmark.text = "조달청"
	wordmark.position = Vector2(34, 0)
	wordmark.add_theme_font_override("font", preload("res://art/korean.otf"))
	wordmark.add_theme_color_override("font_color", Color.WHITE)
	wordmark.add_theme_color_override("font_outline_color", Color("#07131b99"))
	wordmark.add_theme_constant_override("outline_size", 1)
	wordmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wordmark.configure(Vector2(78, 24), 20)
	badge.add_child(wordmark)
	badge.hide()

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	badge.visible = scene.scene_file_path.get_file().get_basename() != "main_menu"
