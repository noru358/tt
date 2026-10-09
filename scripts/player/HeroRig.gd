# Cutout rig for the fennec hero (HERO_ART_PLAN steps 4-5). Nineteen parts cut from
# assets/hero/raw/parts_sheet.png plus the step 3b extras (expression heads, grip and far
# hands, half-open fan) from parts_sheet_extra.png, posed every frame from the player's state.
# Lengths are parts-sheet pixels; the parts PNGs are exported at SHEET_SCALE, and the
# root scales the figure so crown-to-sole matches the hitbox height.
# Limb angles are written "forward positive": a limb hanging down swings toward the
# facing direction for positive values. Upright parts (torso, head) lean forward for positive values.
class_name HeroRig
extends Node2D

const DIR: String = "res://assets/hero/parts/"
const SHEET_SCALE: float = 0.3
const BODY_HEIGHT: float = 770.0
const FAR_TINT: Color = Color(0.72,0.72,0.78)
const SWING_TIME: float = 0.3
const HURT_TIME: float = 0.32
const DUST_TIME: float = 0.35

# part: [pivot, axis end (limbs are turned so this axis hangs straight down) or null, z, far side]
const PARTS: Dictionary = {
	"tail": [Vector2(335,105),null,0,false],
	"ear_far": [Vector2(100,300),null,1,true],
	"arm_far_upper": [Vector2(55,20),Vector2(65,125),2,true],
	"arm_far_lower": [Vector2(30,40),Vector2(145,145),3,true],
	"paw_far": [Vector2(25,40),Vector2(95,70),4,true],
	"thigh_far": [Vector2(150,75),Vector2(20,85),5,true],
	"shin_far": [Vector2(55,15),Vector2(60,130),6,true],
	"thigh_near": [Vector2(25,75),Vector2(165,85),7,false],
	"shin_near": [Vector2(55,15),Vector2(60,130),8,false],
	"skirt": [Vector2(150,15),null,9,false],
	"torso": [Vector2(100,215),null,10,false],
	"sash_knot": [Vector2(110,35),null,11,false],
	"head": [Vector2(125,235),null,12,false],
	"ear_near": [Vector2(110,300),null,13,false],
	"arm_near_upper": [Vector2(85,45),Vector2(75,140),14,false],
	"arm_near_lower": [Vector2(30,40),Vector2(135,130),15,false],
	"fan_closed": [Vector2(30,30),Vector2(235,45),16,false],
	"fan_open": [Vector2(190,190),Vector2(190,10),16,false],
	"fan_half": [Vector2(25,158),Vector2(165,156),16,false],
	"paw_grip": [Vector2(9,66),Vector2(76,52.5),17,false],
	"paw_fist": [Vector2(9.5,51.6),Vector2(56,46.7),4,true],
	"paw_open": [Vector2(8.9,85.8),Vector2(63.8,69.8),4,true],
}
# The grip fist holds the fan shaft in its hole, this far from the wrist.
const GRIP_REACH: float = 68.0
const FACES: Array = ["head_blink","head_hurt","head_shout","head_focus"]
# bone: [parent, position in parent, part drawn on it]
const BONES: Array = [
	["pelvis","",Vector2(0,-290),""],
	["torso","pelvis",Vector2(5,-55),"torso"],
	["neck","torso",Vector2(-5,-205),"head"],
	["ear_near","neck",Vector2(45,-165),"ear_near"],
	["ear_far","neck",Vector2(0,-155),"ear_far"],
	["sh_far","torso",Vector2(-5,-165),"arm_far_upper"],
	["el_far","sh_far",Vector2(0,105),"arm_far_lower"],
	["wr_far","el_far",Vector2(0,150),"paw_far"],
	["sh_near","torso",Vector2(20,-160),"arm_near_upper"],
	["el_near","sh_near",Vector2(0,96),"arm_near_lower"],
	["wr_near","el_near",Vector2(0,132),"paw_grip"],
	["fan","wr_near",Vector2(0,GRIP_REACH),""],
	["sash","torso",Vector2(85,-10),"sash_knot"],
	["skirt","pelvis",Vector2(5,-65),"skirt"],
	["tail","pelvis",Vector2(-75,-70),"tail"],
	["hip_near","pelvis",Vector2(15,0),"thigh_near"],
	["knee_near","hip_near",Vector2(0,138),"shin_near"],
	["hip_far","pelvis",Vector2(-20,-5),"thigh_far"],
	["knee_far","hip_far",Vector2(0,128),"shin_far"],
]
# Joints posed from state; everything else is secondary motion.
const JOINTS: Array = ["lean","torso","neck","sh_near","el_near","wr_near","fan","sh_far","el_far","hip_near","knee_near","hip_far","knee_far","fan_open","crouch"]

var bones: Dictionary = {}
var sprites: Dictionary = {}
var wisps: Array[Sprite2D] = []
var pose: Dictionary = {}
var springs: Dictionary = {"ear_near":[0.0,0.0],"ear_far":[0.0,0.0],"tail":[0.0,0.0],"skirt":[0.0,0.0],"sash":[0.0,0.0]}
var clock: float = 0.0
var run_phase: float = 0.0
var swing_t: float = -1.0
var swing_kind: String = ""
var hurt_t: float = -1.0
var last_swing_time: float = -1.0
var last_iframe: float = 0.0
var wisp_pos: Array[Vector2] = [Vector2(-150,-860),Vector2(-185,-720)]
var state_name: String = "idle"
var face: String = "head"
var faces: Dictionary = {}
var blink_at: float = 2.5
var was_dash: bool = false
var was_floor: bool = true
var fall_speed: float = 0.0
# Tests and capture probes set this to drive the rig without a live player.
var override: Dictionary = {}
# Where the hitbox center sits in the parent; the rig's feet go to its bottom edge.
var anchor: Vector2 = Vector2.ZERO

func _ready() -> void:
	name = "HeroRig"
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for row: Array in BONES:
		var bone: Node2D = Node2D.new()
		bone.name = row[0]
		bone.position = row[2]
		(self if row[1] == "" else bones[row[1]]).add_child(bone)
		bones[row[0]] = bone
		if row[3] != "": _add_sprite(row[3],bone)
	_add_sprite("fan_closed",bones["fan"])
	_add_sprite("fan_open",bones["fan"])
	_add_sprite("fan_half",bones["fan"])
	_add_sprite("paw_fist",bones["wr_far"])
	_add_sprite("paw_open",bones["wr_far"])
	sprites["fan_open"].scale *= 1.1
	sprites["fan_half"].scale *= 0.88
	faces["head"] = sprites["head"].texture
	for key: String in FACES: faces[key] = load(DIR+key+".png")
	sprites["tail"].scale *= 1.45
	for i: int in 2:
		var wisp: Sprite2D = Sprite2D.new()
		wisp.texture = load(DIR+"wisp.png")
		wisp.scale = Vector2.ONE/SHEET_SCALE
		wisp.z_index = 20
		add_child(wisp)
		wisps.append(wisp)
	for joint: String in JOINTS: pose[joint] = 0.0
	_apply(_targets(_read_state()),1.0,0.0)

func _add_sprite(part: String, bone: Node2D) -> void:
	var data: Array = PARTS[part]
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = part
	sprite.texture = load(DIR+part+".png")
	sprite.centered = false
	sprite.offset = -data[0]*SHEET_SCALE
	sprite.scale = Vector2.ONE/SHEET_SCALE
	sprite.position = Vector2.ZERO
	if data[1] != null:
		var axis: Vector2 = data[1]-data[0]
		sprite.rotation = PI/2-axis.angle()
	sprite.z_as_relative = false
	sprite.z_index = data[2]
	if data[3]: sprite.modulate = FAR_TINT
	bone.add_child(sprite)
	sprites[part] = sprite

# Everything the rig needs, gathered in one place so probes can fake it.
func _read_state() -> Dictionary:
	if not override.is_empty(): return override
	var player: GatePlayer = get_parent() as GatePlayer
	var s: Dictionary = {"facing":1,"vel":Vector2.ZERO,"floor":true,"wall":false,"dash":false,"dash_dir":Vector2.RIGHT,"swing_kind":"","swing_start":false,"hurt_start":false,"bash_hold":false,"aim":Vector2.UP,"launch":false,"launch_dir":Vector2.UP,"air_left":2,"height":46.0,"dead":false}
	if player == null: return s
	s.facing = player.facing
	s.vel = player.velocity
	s.floor = player.is_on_floor()
	s.wall = player.is_on_wall() and not s.floor
	s.dash = player.state == GatePlayer.State.DASH
	s.dash_dir = player.dash_direction
	s.dead = player.state == GatePlayer.State.DEAD
	s.height = player.body_size.y
	s.hurt_start = player.hurt_iframe > last_iframe+0.05
	last_iframe = player.hurt_iframe
	var motion: Node = player.toy_motion
	if is_instance_valid(motion):
		s.bash_hold = is_instance_valid(motion.target)
		s.aim = motion.aim
		s.launch = motion.launch_age >= 0
		s.launch_dir = motion.launch_direction
		var world: Node = motion.world
		if is_instance_valid(world):
			if "swing_time" in world:
				var time: float = world.swing_time
				s.swing_start = time >= 0 and (last_swing_time < 0 or time < last_swing_time)
				s.swing_kind = world.swing_kind
				last_swing_time = time
			if "tuning" in world: s.air_left = maxi(0,int(world.tuning.air_dash_count)-player.dash_uses)
	return s

func _process(delta: float) -> void:
	var s: Dictionary = _read_state()
	clock += delta
	if s.swing_start:
		swing_t = 0.0
		swing_kind = s.swing_kind
	if s.hurt_start: hurt_t = 0.0
	if override.is_empty():
		if s.dash and not was_dash: _dust("puff",Vector2(-s.dash_dir.x*14.0,s.height*0.5-8),s.dash_dir.x < 0)
		if s.floor and not was_floor and fall_speed > 260: _dust("land",Vector2(0,s.height*0.5-6),false)
	was_dash = s.dash
	was_floor = s.floor
	fall_speed = s.vel.y
	if swing_t >= 0:
		swing_t += delta/SWING_TIME
		if swing_t >= 1: swing_t = -1
	if hurt_t >= 0:
		hurt_t += delta/HURT_TIME
		if hurt_t >= 1: hurt_t = -1
	if s.floor and absf(s.vel.x) > 20: run_phase += absf(s.vel.x)*delta/115.0*PI
	modulate = Color(1.1,1.15,1.25) if s.dash else (Color(0.55,0.55,0.6) if s.dead else Color.WHITE)
	_apply(_targets(s),1.0-exp(-delta*(28.0 if swing_t >= 0 or s.dash else 16.0)),delta,s)

# Dust left in the world (not on the hero): a puff when a dash starts, a burst on hard landings.
func _dust(kind: String, at: Vector2, flip: bool) -> void:
	var dust: Sprite2D = Sprite2D.new()
	dust.texture = load("res://assets/hero/fx/"+kind+".png")
	dust.top_level = true
	dust.z_index = -1
	dust.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	dust.flip_h = flip
	dust.offset = Vector2(0,-dust.texture.get_height()*0.5)
	add_child(dust)
	dust.global_position = get_parent().global_position+at
	var size: float = 0.07 if kind == "puff" else 0.08
	var tween: Tween = dust.create_tween().set_parallel()
	tween.tween_property(dust,"scale",Vector2.ONE*size*1.4,DUST_TIME).from(Vector2.ONE*size*0.7)
	tween.tween_property(dust,"modulate:a",0.0,DUST_TIME).from(0.9)
	tween.chain().tween_callback(dust.queue_free)

# Target joint angles for the current state.
func _targets(s: Dictionary) -> Dictionary:
	var vel: Vector2 = s.vel
	var p: Dictionary = {"lean":0.0,"torso":0.03,"neck":0.0,"sh_near":0.15,"el_near":0.3,"wr_near":0.1,"fan":0.75,"sh_far":-0.05,"el_far":0.25,"hip_near":0.04,"knee_near":0.0,"hip_far":-0.06,"knee_far":0.0,"fan_open":0.0,"crouch":sin(clock*2.4)*4.0}
	state_name = "idle"
	if s.dead:
		state_name = "dead"
		p.merge({"torso":0.5,"neck":0.4,"sh_near":0.2,"sh_far":0.2,"hip_near":0.9,"knee_near":1.6,"hip_far":0.7,"knee_far":1.6,"crouch":60.0},true)
	elif s.bash_hold:
		state_name = "bash_hold"
		p.merge({"lean":_aim_lean(s.aim,s.facing)*0.35,"torso":0.45,"neck":-0.2,"sh_near":0.9,"el_near":1.6,"sh_far":0.7,"el_far":1.6,"hip_near":1.3,"knee_near":2.0,"hip_far":1.0,"knee_far":2.0,"crouch":70.0},true)
	elif s.launch:
		state_name = "launch"
		p.merge({"lean":_aim_lean(s.launch_dir,s.facing),"torso":0.1,"neck":-0.15,"sh_near":2.7,"el_near":0.1,"sh_far":2.5,"el_far":0.2,"hip_near":-0.15,"knee_near":0.3,"hip_far":-0.35,"knee_far":0.5,"fan":0.0},true)
	elif s.dash:
		state_name = "dash"
		var tilt: float = clampf(-s.dash_dir.y,-1,1)*0.6
		p.merge({"lean":-tilt*0.6,"torso":0.65,"neck":-0.35,"sh_near":0.35,"el_near":1.4,"sh_far":-1.1,"el_far":0.4,"hip_near":-0.4,"knee_near":1.0,"hip_far":-0.9,"knee_far":1.4,"fan":0.2,"crouch":10.0},true)
	elif s.wall and vel.y >= 0:
		state_name = "wall"
		p.merge({"torso":-0.15,"neck":-0.15,"sh_near":2.2,"el_near":0.5,"sh_far":1.6,"el_far":0.6,"hip_near":0.9,"knee_near":1.5,"hip_far":0.4,"knee_far":1.1},true)
	elif not s.floor:
		var rise: float = clampf(-vel.y/450.0,-1,1)
		if rise > 0:
			state_name = "jump"
			p.merge({"torso":0.12,"neck":-0.1,"sh_near":-0.5*rise+0.2,"el_near":0.5,"sh_far":1.0*rise,"el_far":0.4,"hip_near":0.95*rise,"knee_near":1.3*rise,"hip_far":0.15,"knee_far":0.9*rise,"crouch":-10.0*rise},true)
		else:
			state_name = "fall"
			var f: float = -rise
			p.merge({"torso":-0.05,"neck":0.1,"sh_near":1.4*f+0.2,"el_near":0.4,"sh_far":1.7*f,"el_far":0.4,"hip_near":0.35,"knee_near":0.55,"hip_far":-0.2,"knee_far":0.35},true)
	elif absf(vel.x) > 20:
		state_name = "run"
		var a: float = sin(run_phase)
		var speed: float = clampf(absf(vel.x)/230.0,0.3,1.0)
		p.merge({"torso":0.2*speed,"neck":-0.1*speed,"sh_near":(-a*0.6+0.1)*speed,"el_near":0.7,"sh_far":a*0.6*speed,"el_far":0.6,
			"hip_near":a*0.8*speed,"knee_near":(maxf(0,-cos(run_phase))*1.2+0.15)*speed,"hip_far":-a*0.8*speed,"knee_far":(maxf(0,cos(run_phase))*1.2+0.15)*speed,
			"crouch":(absf(sin(run_phase))*-14.0+8.0)*speed},true)
	if hurt_t >= 0 and not s.dead:
		state_name = "hurt"
		var k: float = sin(hurt_t*PI)
		p.merge({"torso":-0.45*k,"neck":-0.35*k,"sh_near":1.0*k,"el_near":0.7,"sh_far":1.2*k,"hip_near":0.3*k,"hip_far":-0.3*k},true)
	if swing_t >= 0 and not s.dead:
		state_name = "swing_"+swing_kind
		var t: float = swing_t
		var strike: float = smoothstep(0.15,0.45,t)
		var opened: float = smoothstep(0.12,0.3,t)*(1.0-smoothstep(0.7,0.95,t))
		match swing_kind:
			"up":
				p.merge({"torso":-0.15,"neck":-0.35,"sh_near":lerpf(0.6,3.1,strike),"el_near":lerpf(1.2,0.1,strike),"wr_near":0.0,"fan":lerpf(0.4,0.0,strike),"fan_open":opened},true)
			"down":
				p.merge({"torso":0.35,"neck":0.25,"sh_near":lerpf(2.9,0.2,strike),"el_near":lerpf(0.6,0.1,strike),"wr_near":0.0,"fan":lerpf(0.2,-0.2,strike),"fan_open":0.0,"hip_near":1.1,"knee_near":1.6,"hip_far":0.7,"knee_far":1.5},true)
			_:
				p.merge({"torso":lerpf(-0.1,0.3,strike),"neck":-0.05,"sh_near":lerpf(-1.4,1.5,strike),"el_near":lerpf(0.9,0.05,strike),"wr_near":0.0,"fan":lerpf(1.2,1.4,strike),"fan_open":opened,"sh_far":lerpf(0.6,-0.6,strike)},true)
	return p

# Rotation (in rig space, facing already applied) that turns the body's up axis toward a world direction.
func _aim_lean(direction: Vector2, facing: int) -> float:
	if direction == Vector2.ZERO: return 0.0
	return atan2(direction.x*facing,-direction.y)

func _apply(target: Dictionary, blend: float, delta: float, s: Dictionary = {}) -> void:
	for joint: String in JOINTS: pose[joint] = lerpf(pose[joint],target[joint],blend)
	var facing: int = s.get("facing",1)
	var height: float = s.get("height",46.0)
	scale = Vector2(facing,1)*height/BODY_HEIGHT
	position = anchor+Vector2(0,height/2)
	bones["pelvis"].position = Vector2(0,-290+pose.crouch)
	bones["pelvis"].rotation = pose.lean
	bones["torso"].rotation = pose.torso
	bones["neck"].rotation = pose.neck-pose.torso*0.5
	for side: String in ["near","far"]:
		bones["sh_"+side].rotation = -pose["sh_"+side]-pose.torso
		bones["el_"+side].rotation = -pose["el_"+side]
		bones["hip_"+side].rotation = -pose["hip_"+side]
		bones["knee_"+side].rotation = pose["knee_"+side]
	bones["wr_near"].rotation = -pose.wr_near
	bones["fan"].rotation = -pose.fan
	sprites["fan_open"].visible = pose.fan_open > 0.7
	sprites["fan_half"].visible = pose.fan_open > 0.25 and not sprites["fan_open"].visible
	sprites["fan_closed"].visible = pose.fan_open <= 0.25
	# Far hand: a fist when moving or striking, an open paw pressed on walls.
	var far_hand: String = "paw_open" if state_name == "wall" else ("paw_fist" if state_name in ["run","dash","launch","bash_hold"] or state_name.begins_with("swing") else "paw_far")
	for hand: String in ["paw_far","paw_fist","paw_open"]: sprites[hand].visible = hand == far_hand
	_face(s)
	_secondary(delta,s)

# Expression heads swap onto the head sprite; idle blinks every few seconds.
func _face(s: Dictionary) -> void:
	var want: String = "head"
	if s.get("dead",false): want = "head_blink"
	elif state_name == "hurt": want = "head_hurt"
	elif state_name in ["bash_hold","launch"] or (state_name.begins_with("swing") and swing_t > 0.12 and swing_t < 0.6): want = "head_shout"
	elif state_name in ["dash","wall"] or state_name.begins_with("swing"): want = "head_focus"
	elif clock >= blink_at:
		want = "head_blink"
		if clock >= blink_at+0.12: blink_at = clock+randf_range(2.2,4.5)
	if s.has("face"): want = s.face
	if want != face:
		face = want
		sprites["head"].texture = faces[want]

# Ears, tail, skirt and sash trail the body; wisps follow the head and show remaining air dashes.
func _secondary(delta: float, s: Dictionary) -> void:
	var vel: Vector2 = s.get("vel",Vector2.ZERO)
	var forward: float = vel.x*s.get("facing",1)
	var drag: float = clampf(forward/230.0,-1,1)
	var lift: float = clampf(vel.y/450.0,-1,1)
	var dashing: bool = s.get("dash",false) or s.get("launch",false)
	var targets: Dictionary = {
		"ear_near":-0.25*drag+0.2*lift-(0.7 if dashing else 0.0)+sin(clock*1.3)*0.03,
		"ear_far":0.14-0.25*drag+0.2*lift-(0.6 if dashing else 0.0)+sin(clock*1.3+0.6)*0.03,
		"tail":1.05-0.35*drag-0.35*lift-(0.5 if dashing else 0.0)+sin(clock*1.7)*0.07,
		"skirt":0.12*drag-0.1*lift,
		"sash":0.3*drag-0.25*lift+sin(clock*2.1)*0.04,
	}
	for key: String in springs:
		var spring: Array = springs[key]
		if delta <= 0:
			spring[0] = targets[key]
			spring[1] = 0.0
		else:
			spring[1] += ((targets[key]-spring[0])*90.0-spring[1]*11.0)*delta
			spring[0] += spring[1]*delta
	bones["ear_near"].rotation = springs.ear_near[0]
	bones["ear_far"].rotation = springs.ear_far[0]
	bones["tail"].rotation = springs.tail[0]
	bones["skirt"].rotation = springs.skirt[0]
	bones["sash"].rotation = springs.sash[0]
	var head: Vector2 = to_local(bones["neck"].global_position)
	var air_left: int = s.get("air_left",2)
	for i: int in wisps.size():
		var want: Vector2 = head+Vector2(-290-30*i,-400+170*i)+Vector2(0,sin(clock*3.0+i*1.7)*12.0)
		wisp_pos[i] = want if delta <= 0 else wisp_pos[i].lerp(want,1.0-exp(-delta*(6.0-i*1.5)))
		wisps[i].position = wisp_pos[i]
		wisps[i].visible = i < air_left
		wisps[i].scale = Vector2(1,1+sin(clock*9.0+i)*0.06)/SHEET_SCALE*0.9
