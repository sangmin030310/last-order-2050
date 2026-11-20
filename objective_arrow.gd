extends Node2D
## A small world-space pointer that follows the currently controlled actor.

var time := 0.0
var direction := Vector2.RIGHT

func _ready() -> void:
	z_index = 8

func _process(delta: float) -> void:
	time += delta
	var scene := get_parent()
	visible = false
	if scene.crossing or (is_instance_valid(scene.overlay) and scene.overlay.visible):
		return
	var hint: Dictionary = scene.navigation_hint()
	if hint.is_empty():
		return
	var actor: CharacterBody2D = hint.actor
	var offset: Vector2 = hint.target - actor.position
	if offset.length() <= hint.reach:
		return
	direction = offset.normalized()
	# Keep the arrow outside the character silhouette, including upward travel.
	position = actor.position + Vector2(0, -38) + direction * (62.0 + sin(time * 3.0) * 2.0)
	position.x = clampf(position.x, 18, 1262)
	position.y = clampf(position.y, 165, 630)
	rotation = lerp_angle(rotation, direction.angle(), 1.0 - exp(-14.0 * delta))
	visible = true
	queue_redraw()

func _draw() -> void:
	var points := PackedVector2Array([Vector2(9, 0), Vector2(-6, -6), Vector2(-2, 0), Vector2(-6, 6)])
	draw_colored_polygon(points, Color("#84f1d2"))
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color("#0b2533"), 1.5, true)
