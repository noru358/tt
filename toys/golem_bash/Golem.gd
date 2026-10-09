# Toy-only golem: drives the original cutout rig (unchanged) and turns each attack
# into a bash springboard. All numbers come from golem_bash_tuning.json via world.tuning.
extends Node2D
const BashTarget = preload("res://toys/golem_bash/BashTarget.gd")
# Rig-local timing of the original animations: windup end, impact, punish end, length.
const MOVES: Dictionary = {
	"slam": {"windup":0.6,"impact":0.7,"punish":1.1,"length":1.4,"hit":Rect2(140,-60,160,60)},
	"sweep": {"windup":0.7,"impact":0.76,"punish":1.2,"length":1.5,"hit":Rect2(40,-150,290,150)},
	"stomp": {"windup":0.55,"impact":0.62,"punish":1.0,"length":1.3,"hit":Rect2(-150,-50,410,50)},
}
const SWEEP_DAMAGE_TIME: float = 0.12
const SLAM_RADIUS: float = 46.0
var world: Node2D
var rig: Node2D
var torso: Node2D
var animator: AnimationPlayer
var torso_rest: Vector2
var platform: StaticBody2D
var platform_shape: RectangleShape2D
var platform_off: float = 0
var hand: Node2D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var facing: int = -1
var hp: float = 0
var stagger: float = 0
var weak_hits: int = 0
var kneels: int = 0
var state: String = "idle"
var cooldown: float = 0
var attack_id: String = ""
var last_attack: String = ""
var clock: float = 0
var segments: Array = []
var impacted: bool = false
var damage_dealt: bool = false
var kneel_left: float = 0
var kneel_amount: float = 0
var ride_time: float = 0
var shake_left: float = 0
var contact_cooldown: float = 0
var flash: float = 0
var idle_clock: float = 0
var rocks: Array = []
var waves: Array = []
var forced_attack: String = ""

func t(key: String) -> float:
	return float(world.tuning[key])

func _ready() -> void:
	z_index = -1
	rig = preload("res://scenes/boss/golem/GolemRig.tscn").instantiate()
	rig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Weakpoint, waves and telegraph draw over the rig.
	rig.show_behind_parent = true
	add_child(rig)
	torso = rig.get_node("Torso")
	torso_rest = torso.position
	animator = rig.get_node("AnimationPlayer")
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	platform = StaticBody2D.new()
	platform.collision_layer = 4
	platform.collision_mask = 0
	platform_shape = RectangleShape2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = platform_shape
	collision.one_way_collision = true
	platform.add_child(collision)
	platform.top_level = true
	add_child(platform)
	hand = BashTarget.new()
	hand.world = world
	hand.golem = self
	hand.top_level = true
	add_child(hand)
	reset()

func reset() -> void:
	hp = t("golem_max_hp")
	stagger = 0
	weak_hits = 0
	kneels = 0
	state = "idle"
	cooldown = t("golem_attack_interval")
	attack_id = ""
	kneel_left = 0
	kneel_amount = 0
	ride_time = 0
	shake_left = 0
	platform_off = 0
	flash = 0
	hand.set_open(false)
	for rock: Node2D in rocks: if is_instance_valid(rock): rock.queue_free()
	rocks.clear()
	waves.clear()
	_pose(0)

func scale_value() -> float:
	return t("golem_scale")

func _pose(delta: float) -> void:
	rig.scale = Vector2(facing,1)*scale_value()
	if state == "attack":
		animator.play(attack_id)
		animator.seek(_anim_time(),true)
	else:
		idle_clock += delta
		animator.play("idle")
		animator.seek(fmod(idle_clock,animator.get_animation("idle").length),true)
	# Kneel and shake layer on top of whatever the animation set this frame.
	var bob: Vector2 = torso.position-torso_rest
	torso.position = torso_rest+bob+Vector2(0,t("kneel_drop")*kneel_amount)
	torso.rotation += 0.35*kneel_amount+(sin(shake_left*60)*0.08 if shake_left > 0 else 0.0)
	hand.global_position = fist_center()

func _anim_time() -> float:
	var elapsed: float = clock
	for segment: Array in segments:
		var duration: float = segment[0]
		if elapsed <= duration or segment == segments.back():
			return lerpf(segment[1],segment[2],clampf(elapsed/maxf(duration,0.0001),0,1))
		elapsed -= duration
	return 0

func fist_center() -> Vector2:
	var fist: Sprite2D = rig.get_node("Torso/ArmFront_Upper/ArmFront_Lower/FistFront")
	return fist.to_global(fist.offset+fist.texture.get_size()/2)

func weak_center() -> Vector2:
	return torso.to_global(Vector2(-55,-215))

func weak_open() -> bool:
	if state == "dead": return false
	if kneel_amount > 0.5: return true
	var window: float = t("weak_open_after_bash")
	return window <= 0 or world.game_time-world.last_bash_time <= window

# Axis-aligned boxes around visible parts; used for contact, body hits and rocks.
func body_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for path: String in ["Torso/TorsoSkin","Torso/Head","Torso/LegFront_Upper","Torso/LegFront_Upper/LegFront_Lower","Torso/LegBack_Upper/LegBack_Lower"]:
		var sprite: Sprite2D = rig.get_node(path)
		var local: Rect2 = sprite.get_rect().grow(-10)
		var box: Rect2 = Rect2(sprite.to_global(local.position),Vector2.ZERO)
		for corner: Vector2 in [Vector2(local.end.x,local.position.y),local.end,Vector2(local.position.x,local.end.y)]: box = box.expand(sprite.to_global(corner))
		rects.append(box)
	return rects

func top_y() -> float:
	return torso.to_global(Vector2(18,-235)).y

func _physics_process(delta: float) -> void:
	if world.paused(): return
	flash = maxf(0,flash-delta)
	contact_cooldown = maxf(0,contact_cooldown-delta)
	_update_waves(delta)
	_update_rocks(delta)
	if state == "dead":
		_pose(delta)
		_place_platform(delta)
		return
	var player: GatePlayer = world.player
	var dx: float = player.position.x-position.x
	match state:
		"idle":
			# Turn only when the player is clearly to one side, so riding the back keeps the weakpoint still.
			if absf(dx) > t("turn_distance"): facing = int(signf(dx))
			cooldown -= delta
			if absf(dx) > t("golem_attack_range")*0.5:
				position.x = clampf(position.x+facing*t("golem_walk_speed")*delta,world.golem_margin(),world.arena_size.x-world.golem_margin())
			if cooldown <= 0 and absf(dx) <= t("golem_attack_range"):
				var options: Array = ["slam","stomp","sweep"]
				options.erase(last_attack)
				begin_attack(forced_attack if forced_attack != "" else options[rng.randi_range(0,options.size()-1)])
		"attack":
			clock += delta
			_attack_tick()
			if clock >= _total_time():
				_end_attack()
		"kneel":
			kneel_left -= delta
			if kneel_left <= 0:
				state = "idle"
				cooldown = t("golem_attack_interval")
				weak_hits = 0
				stagger = 0
	var kneel_target: float = 1.0 if state == "kneel" else 0.0
	kneel_amount = move_toward(kneel_amount,kneel_target,delta/(0.25 if kneel_target > 0 else 0.4))
	shake_left = maxf(0,shake_left-delta)
	_pose(delta)
	_place_platform(delta)
	_contact()

func _total_time() -> float:
	var total: float = 0
	for segment: Array in segments: total += segment[0]
	return total

func begin_attack(id: String) -> void:
	var move: Dictionary = MOVES[id]
	attack_id = id
	last_attack = id
	state = "attack"
	clock = 0
	impacted = false
	damage_dealt = false
	var hold: float = 0.3
	if id == "slam": hold = t("fist_bash_window")
	elif id == "sweep": hold = maxf(t("arm_bash_window"),SWEEP_DAMAGE_TIME)
	elif id == "stomp": hold = maxf(0.3,t("rock_hover_time"))
	segments = [
		[t("telegraph_time"),0.0,move.windup],
		[move.impact-move.windup,move.windup,move.impact],
		[hold,move.impact,move.punish],
		[move.length-move.punish,move.punish,move.length]]
	world.golem_attacks[id] = int(world.golem_attacks.get(id,0))+1

func _impact_time() -> float:
	return segments[0][0]+segments[1][0]

func _attack_tick() -> void:
	var impact: float = _impact_time()
	var hold_end: float = impact+segments[2][0]
	var player: GatePlayer = world.player
	if attack_id == "sweep":
		# The arm is a springboard while it swings and briefly after.
		hand.kind = "arm"
		hand.set_open(clock >= segments[0][0] and clock < hold_end)
		if clock >= segments[0][0] and clock < impact+SWEEP_DAMAGE_TIME and not damage_dealt:
			if hit_rect().intersects(world.player_rect()):
				damage_dealt = true
				world.hurt_player(t("player_hit_damage"),position.x)
	if not impacted and clock >= impact:
		impacted = true
		Feedback.shake_strength = maxf(Feedback.shake_strength,6.0)
		if attack_id == "slam":
			if fist_center().distance_to(player.position) < SLAM_RADIUS+player.body_size.y/2:
				world.hurt_player(t("player_hit_damage"),fist_center().x)
		elif attack_id == "stomp":
			waves.append({"x":position.x,"dir":-1,"hit":false})
			waves.append({"x":position.x,"dir":1,"hit":false})
			_spawn_rocks()
	if attack_id == "slam":
		hand.kind = "fist"
		hand.set_open(clock >= impact and clock < hold_end)

func hit_rect() -> Rect2:
	var local: Rect2 = MOVES[attack_id].hit
	var box: Rect2 = Rect2(rig.to_global(local.position),Vector2.ZERO)
	box = box.expand(rig.to_global(local.end))
	return box

func _end_attack() -> void:
	hand.set_open(false)
	if world.motion.target == hand: return
	state = "idle"
	attack_id = ""
	cooldown = t("golem_attack_interval")

func _spawn_rocks() -> void:
	var count: int = int(t("rock_count"))
	for i: int in count:
		var rock: Node2D = BashTarget.new()
		rock.world = world
		rock.golem = self
		rock.kind = "rock"
		rock.top_level = true
		var spread: float = (i-(count-1)/2.0)*70+facing*60
		rock.global_position = Vector2(position.x+spread,world.floor_y-t("rock_radius"))
		rock.velocity = Vector2(spread*0.4,-t("rock_launch_speed")*(1.0-0.08*absf(i-(count-1)/2.0)))
		rock.hover = t("rock_hover_time")
		add_child(rock)
		rocks.append(rock)

func _update_rocks(delta: float) -> void:
	for rock: Node2D in rocks.duplicate():
		if not is_instance_valid(rock):
			rocks.erase(rock)
			continue
		if world.motion.target == rock: continue
		rock.age += delta
		if rock.flying:
			var next: Vector2 = rock.global_position+rock.velocity*delta
			var hit_golem: bool = false
			for box: Rect2 in body_rects():
				if box.grow(t("rock_radius")).has_point(next): hit_golem = true
			if hit_golem and state != "dead":
				world.log_data.rock_hits += 1
				take_damage(t("rock_damage_to_golem"))
				add_stagger(t("rock_stagger"))
				_remove_rock(rock)
				continue
			var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(rock.global_position,next,1)
			if not get_world_2d().direct_space_state.intersect_ray(query).is_empty() or rock.age > 4:
				_remove_rock(rock)
				continue
			rock.global_position = next
			continue
		if rock.velocity.y < 0:
			rock.velocity.y += world.tuning.gravity*delta
			if rock.velocity.y >= 0: rock.velocity = Vector2.ZERO
		elif rock.hover > 0:
			rock.hover -= delta
			rock.velocity = Vector2.ZERO
		else: rock.velocity.y += world.tuning.gravity*0.6*delta
		rock.set_open(rock.velocity.y >= 0)
		rock.global_position += rock.velocity*delta
		if rock.global_position.y >= world.floor_y-t("rock_radius") and rock.velocity.y > 0: _remove_rock(rock)

func _remove_rock(rock: Node2D) -> void:
	rocks.erase(rock)
	rock.set_open(false)
	if world.motion.target == rock: return
	rock.queue_free()

func _update_waves(delta: float) -> void:
	var player: GatePlayer = world.player
	for wave: Dictionary in waves.duplicate():
		wave.x += wave.dir*t("shockwave_speed")*delta
		if wave.x < 0 or wave.x > world.arena_size.x:
			waves.erase(wave)
			continue
		var feet: float = player.position.y+player.body_size.y/2
		if not wave.hit and absf(player.position.x-wave.x) < 12+player.body_size.x/2 and feet > world.floor_y-t("shockwave_height"):
			wave.hit = true
			world.hurt_player(t("player_hit_damage"),wave.x-wave.dir*10)

func on_bashed(target: Node2D, direction: Vector2) -> void:
	world.last_bash_time = world.game_time
	world.log_data.bash_by_source[target.kind] = int(world.log_data.bash_by_source.get(target.kind,0))+1
	match target.kind:
		"fist":
			target.set_open(false)
			flash = 0.15
			add_stagger(t("fist_bash_stagger"))
		"arm":
			target.set_open(false)
		"rock":
			target.set_open(false)
			target.flying = true
			target.age = 0
			target.velocity = direction*t("rock_bash_speed")
			if not rocks.has(target): rocks.append(target)

func add_stagger(amount: float) -> void:
	if state == "dead": return
	stagger += amount
	_check_kneel()

func take_damage(amount: float) -> void:
	if state == "dead": return
	hp = maxf(0,hp-amount)
	flash = 0.12
	if hp <= 0:
		state = "dead"
		hand.set_open(false)
		world.round_end("win")

func _check_kneel() -> void:
	if state in ["kneel","dead"]: return
	if weak_hits >= int(t("weak_hits_to_stagger")) or stagger >= t("stagger_threshold"):
		hand.set_open(false)
		state = "kneel"
		attack_id = ""
		kneel_left = t("kneel_duration")
		kneels += 1
		world.log_data.kneels += 1

# Returns "weak", "body" or "" for one player swing rectangle.
func receive_player_hit(rect: Rect2) -> String:
	if state == "dead": return ""
	var weak: Vector2 = weak_center()
	var closest: Vector2 = Vector2(clampf(weak.x,rect.position.x,rect.end.x),clampf(weak.y,rect.position.y,rect.end.y))
	if closest.distance_to(weak) <= t("weak_radius") and weak_open():
		weak_hits += 1
		world.log_data.weak_hits += 1
		take_damage(t("weak_hit_damage"))
		_check_kneel()
		return "weak"
	for box: Rect2 in body_rects():
		if box.intersects(rect):
			take_damage(t("weak_hit_damage")*t("body_damage_mult"))
			return "body"
	return ""

func _place_platform(delta: float) -> void:
	var top: Vector2 = torso.to_global(Vector2(18,-235))
	platform.global_position = top
	platform_shape.size = Vector2(234*0.8*scale_value(),8)
	platform_off = maxf(0,platform_off-delta)
	platform.process_mode = Node.PROCESS_MODE_INHERIT
	var shape: CollisionShape2D = platform.get_child(0)
	shape.disabled = platform_off > 0 or state == "dead"
	var player: GatePlayer = world.player
	var feet: float = player.position.y+player.body_size.y/2
	var riding: bool = player.is_on_floor() and absf(feet-top.y) < 10 and absf(player.position.x-top.x) < platform_shape.size.x/2+player.body_size.x/2
	ride_time = ride_time+delta if riding else 0.0
	if riding and ride_time >= t("shake_off_time"):
		ride_time = 0
		platform_off = 0.5
		shake_left = 0.4
		player.velocity = Vector2(signf(player.position.x-top.x+0.01)*280,-360)
		world.motion.launch_age = -1

func on_platform() -> bool:
	var player: GatePlayer = world.player
	var feet: float = player.position.y+player.body_size.y/2
	return absf(feet-top_y()) < 12 and absf(player.position.x-platform.global_position.x) < platform_shape.size.x/2+player.body_size.x/2

func _contact() -> void:
	if contact_cooldown > 0 or on_platform() or state == "dead": return
	var rect: Rect2 = world.player_rect()
	for box: Rect2 in body_rects():
		if box.intersects(rect):
			contact_cooldown = t("contact_interval")
			world.hurt_player(t("contact_damage"),position.x)
			return

func _process(_delta: float) -> void:
	var tint: Color = Color.WHITE
	if state == "dead": tint = Color(0.4,0.4,0.4)
	elif flash > 0: tint = Color(1.7,1.7,1.7)
	elif state == "attack" and clock < segments[0][0]: tint = Color(1,0.75+0.25*sin(clock*30),0.6)
	elif state == "kneel": tint = Color(0.85,0.95,1.2)
	rig.modulate = tint
	queue_redraw()

func _draw() -> void:
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	if state != "dead":
		var weak: Vector2 = weak_center()
		var r: float = t("weak_radius")
		var open: bool = weak_open()
		draw_circle(weak,r,Color(1,0.85,0.3,0.95) if open else Color(0.55,0.45,0.3,0.8))
		if open: draw_arc(weak,r+4+2*sin(Time.get_ticks_msec()/80.0),0,TAU,32,Color(1,0.95,0.6),2)
	for wave: Dictionary in waves:
		draw_rect(Rect2(wave.x-10,world.floor_y-t("shockwave_height"),20,t("shockwave_height")),Color(0.9,0.75,0.5,0.85))
	if state == "attack" and clock < segments[0][0]:
		var head: Vector2 = torso.to_global(Vector2(100,-260))
		draw_string(ThemeDB.fallback_font,head+Vector2(-6,-6),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color.ORANGE)
	if Feedback.boxes_visible:
		for box: Rect2 in body_rects(): draw_rect(box,Color.GREEN,false,1)
		draw_rect(Rect2(platform.global_position-platform_shape.size/2,platform_shape.size),Color.SKY_BLUE,false,2)
		if state == "attack": draw_rect(hit_rect(),Color.RED,false,2)
		draw_arc(weak_center(),t("weak_radius"),0,TAU,24,Color.MAGENTA,2)
