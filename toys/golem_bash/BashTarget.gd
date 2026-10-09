# Bash target the shared ToyMotion can grab: a golem fist, a swinging arm or a rock.
# Only nodes in "toy_bashable" are grabbable, so windows open and close by group membership.
extends Node2D
var world: Node2D
var golem: Node2D
var kind: String = "fist"
var highlight: bool = false
var open: bool = false
var velocity: Vector2 = Vector2.ZERO
var hover: float = 0
var flying: bool = false
var age: float = 0

func set_open(value: bool) -> void:
	# A grabbed target stays valid until the launch consumes it.
	if not value and is_instance_valid(world.motion) and world.motion.target == self: return
	open = value
	if open: add_to_group("toy_bashable")
	else:
		remove_from_group("toy_bashable")
		highlight = false

func bash(direction: Vector2) -> void:
	golem.on_bashed(self,direction)

func _draw() -> void:
	var radius: float = float(world.tuning.rock_radius) if kind == "rock" else 18.0
	if kind == "rock": draw_circle(Vector2.ZERO,radius,Color("8a7a66") if not flying else Color("d8b26a"))
	if open:
		draw_arc(Vector2.ZERO,radius+4,0,TAU,32,Color.WHITE,3 if highlight else 2)
		if highlight: draw_arc(Vector2.ZERO,radius+8,0,TAU,32,Color(1,1,1,0.5),2)

func _process(_delta: float) -> void:
	queue_redraw()
