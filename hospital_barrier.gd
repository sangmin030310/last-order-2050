extends Node2D
## Raised steel partition; its base follows the existing collision footprint.

const FONT = preload("res://art/korean.otf")
const AMBER := Color("#ffc36b")
const GREEN := Color("#84f1d2")
var opening := 0.0
@onready var gate: CollisionShape2D = get_node("../../Barrier/Gate")

func _ready() -> void:
	opening = 1.0 if gate.disabled else 0.0

func _process(delta: float) -> void:
	opening = move_toward(opening, 1.0 if gate.disabled else 0.0, delta * 5.0)
	queue_redraw()

func wall_section(left: float, right: float) -> void:
	var width := right - left
	# Floor shadow, thick front face, and beveled top give the wall volume.
	draw_rect(Rect2(left - 3, 0, width + 6, 12), Color("#040c1480"))
	draw_rect(Rect2(left, -54, width, 54), Color("#263945"))
	draw_rect(Rect2(left, -64, width, 10), Color("#6a818a"))
	draw_rect(Rect2(left, -54, width, 4), Color("#a0b1b7"))
	draw_rect(Rect2(left, -3, width, 3), Color("#101d27"))
	for x in range(int(left) + 9, int(right) - 24, 64):
		var panel_width := minf(54.0, right - x - 7)
		draw_rect(Rect2(x, -43, panel_width, 24), Color("#344b57"))
		draw_rect(Rect2(x, -43, panel_width, 24), Color("#526976"), false, 1.0)
		draw_circle(Vector2(x + 4, -38), 1.5, Color("#9aafb8"))
		draw_circle(Vector2(x + panel_width - 4, -24), 1.5, Color("#9aafb8"))
	draw_rect(Rect2(left + 4, -14, width - 8, 10), Color("#18232b"))
	for x in range(int(left) + 8, int(right) - 18, 28):
		draw_colored_polygon(PackedVector2Array([Vector2(x, -4), Vector2(x + 9, -14), Vector2(x + 21, -14), Vector2(x + 12, -4)]), AMBER)

func _draw() -> void:
	wall_section(135, 565)
	wall_section(715, 1150)
	# Inset doorway and rails remain visible when both door leaves retract.
	draw_rect(Rect2(565, -58, 150, 62), Color("#07151b80"))
	draw_line(Vector2(565, -58), Vector2(715, -58), Color("#8da3ac"), 4.0)
	draw_line(Vector2(565, 2), Vector2(715, 2), Color("#6c818c"), 3.0)
	var leaf_width := 75.0 * (1.0 - opening)
	if leaf_width > 0.5:
		for left in [565.0, 715.0 - leaf_width]:
			draw_rect(Rect2(left, -54, leaf_width, 54), Color("#455965"))
			draw_rect(Rect2(left, -54, leaf_width, 54), Color("#8da3ac"), false, 2.0)
			draw_rect(Rect2(left + 2, -14, maxf(0.0, leaf_width - 4), 10), AMBER)
		if opening < 0.1:
			draw_line(Vector2(640, -50), Vector2(640, -4), Color("#0a151e"), 3.0)
	var light := GREEN if gate.disabled else AMBER
	for x in [559.0, 715.0]:
		draw_rect(Rect2(x, -60, 6, 64), Color("#15242e"))
		draw_rect(Rect2(x + 1, -46, 4, 28), light)
	draw_rect(Rect2(562, -90, 156, 24), Color("#101f2bf2"))
	draw_rect(Rect2(562, -90, 156, 24), light, false, 1.0)
	var caption := "통로 개방" if gate.disabled else "방화문 잠김"
	var caption_width := FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(FONT, Vector2(640 - caption_width * 0.5, -73), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, light)
