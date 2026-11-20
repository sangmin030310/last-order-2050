extends Sprite2D
## Shared by both actors in every scene inherited from prologue.tscn.
## Each supplied image is one direction, so walking uses a gentle bob and sway.

@export_enum("jodari", "jodalho") var character := "jodari"
@export var display_height := 86.0

const DIRECTIONS := ["r", "fr", "f", "fl", "l", "bl", "b", "br"]
var poses: Dictionary = {}
var facing := "f"
var previous_position := Vector2.ZERO
var step := 0.0

func _ready() -> void:
	for direction: String in DIRECTIONS:
		var source := load("res://art/%s_%s.png" % [character, direction]) as Texture2D
		var cropped := AtlasTexture.new()
		cropped.atlas = source
		cropped.region = source.get_image().get_used_rect()
		poses[direction] = cropped
	previous_position = get_parent().global_position
	apply_pose(0.0, 0.0)

func _process(_delta: float) -> void:
	var current: Vector2 = get_parent().global_position
	var movement := current - previous_position
	previous_position = current
	# Scene entry/teleports should not play a step or change the facing.
	var moving := movement.length() > 0.05 and movement.length() < 30.0
	if moving:
		var sector := posmod(roundi(movement.angle() / (PI / 4.0)), 8)
		facing = DIRECTIONS[sector]
		step += movement.length() * 0.08
	else:
		step = 0.0
	apply_pose(absf(sin(step)) * 2.5 if moving else 0.0,
		sin(step) * 0.018 if moving else 0.0)

func apply_pose(bob: float, sway: float) -> void:
	texture = poses[facing]
	flip_h = false
	flip_v = false
	centered = true
	var factor := display_height / float(texture.get_height())
	scale = Vector2.ONE * factor
	# The collision body stays at the feet regardless of image resolution.
	position = Vector2(0.0, -display_height * 0.5 - bob)
	rotation = sway
