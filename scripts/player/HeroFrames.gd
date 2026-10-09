# Full-body frame animation for the fennec hero (docs/plan/HERO_FRAMES_PLAN.md).
# Each frame PNG is a canvas whose bottom center is the hero's sole point, so the
# sprite only flips and scales; the drawing itself carries the motion.
# Until the remaining strips arrive, states without frames borrow idle or the
# airborne run stride.
class_name HeroFrames
extends Sprite2D

const DIR: String = "res://assets/hero/frames/"
# Crown-to-sole height of the body inside a frame texture (ears stick out above it).
const BODY_TEXTURE_HEIGHT: float = 238.0
const ANIMS: Dictionary = {"idle":4,"run":6}
const IDLE_FPS: float = 5.0
const RUN_FPS: float = 12.0
const AIR_FRAME: int = 3

var frames: Dictionary = {}
var anim: String = "idle"
var clock: float = 0.0
var state_name: String = "idle"

func _ready() -> void:
	name = "HeroFrames"
	show_behind_parent = true
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for key: String in ANIMS:
		var list: Array[Texture2D] = []
		for i: int in ANIMS[key]: list.append(load(DIR+"%s_%d.png" % [key,i]))
		frames[key] = list
	_show("idle",0)

func _process(delta: float) -> void:
	var player: GatePlayer = get_parent() as GatePlayer
	if player == null: return
	var speed: float = absf(player.velocity.x)
	var on_floor: bool = player.is_on_floor()
	var dashing: bool = player.state == GatePlayer.State.DASH
	var dead: bool = player.state == GatePlayer.State.DEAD
	if dead: state_name = "dead"
	elif dashing: state_name = "dash"
	elif not on_floor: state_name = "air"
	elif speed > 20: state_name = "run"
	else: state_name = "idle"
	match state_name:
		"run":
			clock += delta*RUN_FPS*clampf(speed/230.0,0.6,1.3)
			_show("run",int(clock) % ANIMS.run)
		"air","dash":
			_show("run",AIR_FRAME)
		_:
			clock += delta*IDLE_FPS
			_show("idle",0 if dead else int(clock) % ANIMS.idle)
	var height: float = player.body_size.y
	scale = Vector2(player.facing,1)*height/BODY_TEXTURE_HEIGHT
	position = Vector2(0,height/2)
	modulate = Color(0.55,0.55,0.6) if dead else (Color(1.1,1.15,1.25) if dashing else (Color(1,0.6,0.6) if player.hurt_iframe > 0 and fmod(player.hurt_iframe,0.12) < 0.06 else Color.WHITE))

func _show(key: String, index: int) -> void:
	anim = key
	texture = frames[key][index]
	offset = Vector2(-texture.get_width()/2.0,-texture.get_height())
