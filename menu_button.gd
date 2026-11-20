extends Button
## Consistent pointer/keyboard feedback without changing container layout.

const NORMAL_FILL := Color("#183441")
const NORMAL_BORDER := Color("#446b76")
const ACTIVE_FILL := Color("#aaffea")
const ACTIVE_INK := Color("#102b31")
const ACCENT := Color("#84f1d2")

var feedback: Tween
var keyboard_focus_armed := false
var base_font_size := 20

func _ready() -> void:
	base_font_size = get_theme_font_size("font_size")
	GameSettings.settings_changed.connect(update_text_size)
	update_text_size()
	apply_palette()
	resized.connect(update_pivot)
	mouse_entered.connect(func():
		if not disabled:
			grab_focus()
		refresh_feedback()
	)
	mouse_exited.connect(refresh_feedback)
	focus_entered.connect(refresh_feedback)
	focus_exited.connect(refresh_feedback)
	button_down.connect(func(): animate_scale(0.98))
	button_up.connect(refresh_feedback)
	update_pivot()

func update_text_size() -> void:
	add_theme_font_size_override("font_size", base_font_size + (2 if GameSettings.large_text else 0))

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseMotion:
		if keyboard_focus_armed:
			keyboard_focus_armed = false
			update_focus_style()
			refresh_feedback()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
			if not keyboard_focus_armed:
				keyboard_focus_armed = true
				update_focus_style()
				refresh_feedback()

func apply_palette() -> void:
	add_theme_color_override("font_color", Color.WHITE)
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, ACTIVE_INK)
	add_theme_stylebox_override("normal", palette(NORMAL_FILL, NORMAL_BORDER))
	add_theme_stylebox_override("hover", palette(ACTIVE_FILL, ACCENT))
	add_theme_stylebox_override("pressed", palette(Color("#60bfa7"), ACCENT))
	add_theme_stylebox_override("hover_pressed", palette(Color("#60bfa7"), ACCENT))
	update_focus_style()

func update_focus_style() -> void:
	add_theme_color_override("font_focus_color", ACTIVE_INK if keyboard_focus_armed else Color.WHITE)
	var focus := palette(ACTIVE_FILL if keyboard_focus_armed else Color.TRANSPARENT, ACCENT if keyboard_focus_armed else Color.TRANSPARENT)
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	add_theme_stylebox_override("focus", focus)

func palette(fill: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(9)
	return result

func update_pivot() -> void:
	pivot_offset = size * 0.5

func refresh_feedback() -> void:
	animate_scale(1.015 if not disabled and (is_hovered() or (has_focus() and keyboard_focus_armed)) else 1.0)

func animate_scale(target: float) -> void:
	if is_instance_valid(feedback):
		feedback.kill()
	feedback = create_tween()
	feedback.tween_property(self, "scale", Vector2.ONE * target, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
