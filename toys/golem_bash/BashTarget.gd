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
		# Pulsing ring plus a "K" badge so a grabbable part reads at a glance.
		var pulse: float = 0.5+0.5*sin(Time.get_ticks_msec()/90.0)
		var ring: float = radius+(14 if kind != "rock" else 6)+4*pulse
		draw_arc(Vector2.ZERO,ring,0,TAU,40,Color(0.5,1,1,0.9) if highlight else Color(1,1,1,0.85),4 if highlight else 3)
		draw_arc(Vector2.ZERO,ring+6,0,TAU,40,Color(1,1,1,0.25+0.25*pulse),2)
		var badge: Vector2 = Vector2(0,-ring-16)
		draw_circle(badge,10,Color(0.1,0.15,0.2,0.85))
		draw_string(ThemeDB.fallback_font,badge+Vector2(-5,6),"K",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.5,1,1) if highlight else Color.WHITE)

func _process(_delta: float) -> void:
	queue_redraw()
