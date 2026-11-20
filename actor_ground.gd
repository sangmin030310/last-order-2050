extends Node2D
## Feet stay grounded; the softly lit ring identifies the controlled actor.

var emphasis := 0.0

func _ready() -> void:
	z_index = -1

func _process(delta: float) -> void:
	var scene := get_parent().get_parent().get_parent()
	var active: bool = scene.controlled_actor() == get_parent()
	emphasis = move_toward(emphasis, 1.0 if active else 0.0, delta * 6.0)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.38))
	for radius in range(20, 5, -3):
		draw_circle(Vector2.ZERO, float(radius), Color(0.015, 0.035, 0.05, 0.065))
	if emphasis > 0.01:
		draw_arc(Vector2.ZERO, 22, 0, TAU, 48, Color(0.52, 0.95, 0.82, emphasis * 0.65), 1.5, true)
	draw_set_transform(Vector2.ZERO)
