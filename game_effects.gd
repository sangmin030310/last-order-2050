extends Node2D
## Small, bounded effects for exploration and equipment feedback.

var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var footsteps: Dictionary = {}
var random := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 5
	process_physics_priority = 20
	random.randomize()
	for actor in get_parent().get_node("Actors").get_children():
		if actor is CharacterBody2D:
			footsteps[actor] = {"position": actor.position, "distance": 0.0}

func _physics_process(_delta: float) -> void:
	for actor: CharacterBody2D in footsteps:
		var state: Dictionary = footsteps[actor]
		var movement: Vector2 = actor.position - state.position
		state.position = actor.position
		if movement.length() < 0.05 or movement.length() > 30.0:
			state.distance = 0.0
			continue
		state.distance += movement.length()
		if state.distance >= 25.0:
			state.distance = fmod(state.distance, 25.0)
			for index in range(2):
				add_particle(actor.position + Vector2(random.randf_range(-5, 5), 1), -movement.normalized() * 10 + Vector2(random.randf_range(-7, 7), -5), Color("#bfd4d9"), 0.32, 2.2, false)

func add_particle(at: Vector2, velocity: Vector2, color: Color, lifetime: float, radius: float, spark: bool) -> void:
	if particles.size() >= 96:
		particles.pop_front()
	particles.append({"position": at, "velocity": velocity, "color": color, "life": lifetime, "duration": lifetime, "radius": radius, "spark": spark})

func burst(at: Vector2, color: Color, success := false) -> void:
	if rings.size() >= 12:
		rings.pop_front()
	rings.append({"position": at, "color": color, "life": 0.7, "success": success})
	for index in range(16 if success else 8):
		var angle := random.randf_range(0, TAU)
		var velocity := Vector2.from_angle(angle) * random.randf_range(18, 48)
		add_particle(at + Vector2(0, -8), velocity, color, random.randf_range(0.4, 0.75), 2.0, true)

func _process(delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[index]
		particle.life -= delta
		if particle.life <= 0:
			particles.remove_at(index)
			continue
		particle.position += particle.velocity * delta
		particle.velocity *= exp(-2.0 * delta)
	for index in range(rings.size() - 1, -1, -1):
		rings[index].life -= delta
		if rings[index].life <= 0:
			rings.remove_at(index)
	queue_redraw()

func _draw() -> void:
	for ring: Dictionary in rings:
		var progress: float = 1.0 - ring.life / 0.7
		var color: Color = ring.color
		color.a = (1.0 - progress) * 0.65
		draw_set_transform(ring.position, 0, Vector2(1, 0.48))
		draw_arc(Vector2.ZERO, lerpf(12, 48 if ring.success else 32, progress), 0, TAU, 40, color, 2.0, true)
	draw_set_transform(Vector2.ZERO)
	for particle: Dictionary in particles:
		var fade: float = particle.life / particle.duration
		var color: Color = particle.color
		color.a = fade * (0.85 if particle.spark else 0.3)
		var at: Vector2 = particle.position
		if particle.spark:
			draw_line(at - Vector2(3, 0) * fade, at + Vector2(3, 0) * fade, color, 1.2, true)
			draw_line(at - Vector2(0, 3) * fade, at + Vector2(0, 3) * fade, color, 1.2, true)
		else:
			draw_circle(at, particle.radius * (1.5 - fade * 0.5), color)
