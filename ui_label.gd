extends Label
## Preserve each label's allotted rectangle, including when HUD text changes.
var layout_size := Vector2.ZERO
var preferred_font_size := 20
var last_text := ""

func _ready() -> void:
	# Parent themes are available after the label enters the scene tree.
	GameSettings.settings_changed.connect(fit_text)
	fit_text()

func configure(bounds: Vector2, font_size: int) -> void:
	layout_size = bounds
	preferred_font_size = font_size
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	fit_text()

func _process(_delta: float) -> void:
	if text != last_text:
		fit_text()

func fit_text() -> void:
	last_text = text
	var requested_size := preferred_font_size + (2 if GameSettings.large_text else 0)
	for font_size in range(requested_size, 11, -1):
		add_theme_font_size_override("font_size", font_size)
		size = layout_size
		if get_minimum_size().y <= layout_size.y:
			break
	size = layout_size
