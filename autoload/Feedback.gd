extends Node
var camera: Camera2D
var base_speed: float = 1.0
var shake_strength: float = 0.0
var stop_until_ms: float = 0.0
var stop_generation: int = 0
var boxes_visible: bool = false
var invincible: bool = false
var debug_used: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func hitstop(duration: float) -> void:
	if duration <= 0.0: return
	var deadline: float = Time.get_ticks_msec() + duration * 1000.0
	if deadline <= stop_until_ms: return
	stop_until_ms = deadline
	stop_generation += 1
	var generation: int = stop_generation
	Engine.time_scale = Tuning.feedback["hitstop_time_scale"]
	await get_tree().create_timer(duration, true, false, true).timeout
	if generation == stop_generation:
		stop_until_ms = 0.0
		Engine.time_scale = base_speed

func set_speed(value: float, mark_debug: bool = true) -> void:
	base_speed = value
	if mark_debug: debug_used = true
	if stop_until_ms <= Time.get_ticks_msec(): Engine.time_scale = base_speed

func trigger(kind: String) -> void:
	hitstop(Tuning.feedback["hitstop_on_" + kind])
	shake_strength = maxf(shake_strength, Tuning.feedback["shake_on_" + kind])

func _process(delta: float) -> void:
	if is_instance_valid(camera):
		camera.offset = Vector2(randf_range(-1,1), randf_range(-1,1)) * shake_strength
	if not Tuning.feedback.is_empty():
		shake_strength = move_toward(shake_strength, 0.0, float(Tuning.feedback["shake_decay"]) * delta)

func clear_transients() -> void:
	stop_generation += 1
	stop_until_ms = 0.0
	shake_strength = 0.0
	Engine.time_scale = base_speed
