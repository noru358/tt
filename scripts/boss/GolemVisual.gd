extends Node2D
signal impact(move_id: String, location: Vector2)
var boss: Node2D
var rig: Node2D
var animator: AnimationPlayer
var settings: Dictionary
var attack_settings: Dictionary = {}
var attack_id: String = ""
var elapsed: float = 0.0
var idle_clock: float = 0.0
var box: CombatHitbox
var landed: bool = false
var active: bool = false
var locked_facing: int = 1
var impact_flash: float = 0.0

func _ready() -> void:
	boss = get_parent()
	settings = Tuning.golem.duplicate(true)
	rig = preload("res://scenes/boss/golem/GolemRig.tscn").instantiate()
	rig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(rig)
	animator = rig.get_node("AnimationPlayer")
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animator.add_animation_library("runtime",AnimationLibrary.new())
	_build_body_parts(rig)
	Tuning.changed.connect(_settings_changed)
	_update_transform()
	idle(0)

func _settings_changed() -> void:
	# A tuning edit cancels the old timed action so old/new windows cannot mix.
	boss.interrupt()
	settings = Tuning.golem.duplicate(true)
	_update_transform()
	idle(0)

func _update_transform() -> void:
	position = Vector2(0,boss.body_size.y/2)
	var facing: int = locked_facing if active else boss.facing
	rig.scale = Vector2(facing,1)*float(settings["scale"])

func idle(delta: float) -> void:
	if active: return
	idle_clock += delta
	_update_transform()
	rig.get_node("Torso/LegFront_Upper").position = Vector2(6,-10)
	rig.get_node("Torso/LegBack_Upper").position = Vector2(-16,-10)
	animator.play("RESET")
	animator.seek(0,true)
	animator.play("idle")
	animator.seek(fmod(idle_clock,animator.get_animation("idle").length),true)
	_update_hurtbox()

func begin(move_id: String) -> void:
	cancel()
	attack_id = move_id
	attack_settings = settings["moves"][move_id].duplicate(true)
	if move_id == "slam" and boss.phase_index > 0:
		var shift: float = float(settings["phase2_windup"])-float(attack_settings["windup"])
		attack_settings["windup"] += shift
		for key: String in ["active_start","active_end","punish_end","duration"]: attack_settings[key] += shift
	var animation: Animation = animator.get_animation(attack_settings["animation"]).duplicate(true)
	var shift: float = float(attack_settings["windup"])-float(attack_settings["source_windup"])
	for track: int in animation.get_track_count():
		var keys: Array = []
		for key: int in animation.track_get_key_count(track):
			var time: float = animation.track_get_key_time(track,key)
			keys.append([time+shift if time > 0 else time,animation.track_get_key_value(track,key),animation.track_get_key_transition(track,key)])
		for key: int in range(animation.track_get_key_count(track)-1,-1,-1): animation.track_remove_key(track,key)
		for key: Array in keys: animation.track_insert_key(track,key[0],key[1],key[2])
	animation.length += shift
	var library: AnimationLibrary = animator.get_animation_library("runtime")
	if library.has_animation("attack"): library.remove_animation("attack")
	library.add_animation("attack",animation)
	locked_facing = boss.facing
	active = true
	elapsed = 0
	landed = false
	_update_transform()
	animator.play("runtime/attack")
	animator.seek(0,true)
	_update_hurtbox()

func advance(delta: float) -> bool:
	elapsed += delta
	_update_transform()
	animator.seek(minf(elapsed,animator.get_animation("runtime/attack").length),true)
	var start: float = attack_settings["active_start"]
	var end: float = attack_settings["active_end"]
	if not landed and elapsed+0.000001 >= start:
		landed = true
		impact_flash = 0.25
		Feedback.shake_strength = maxf(Feedback.shake_strength,float(attack_settings["shake"]))
		impact.emit(attack_id,attack_rect().get_center())
		if attack_id == "stomp" and boss.phase_index > 0 and settings["phase2_shockwave"]:
			# Spawn at the same impact tick, not after recovery.
			var step: RefCounted = preload("res://scripts/boss/steps/shockwave.gd").new()
			step.setup(boss,{"type":"shockwave","direction":"both","speed":settings["shockwave_speed"],"height":settings["shockwave_height"],"damage":settings["shockwave_damage"],"parriable":false})
			step.begin()
	if elapsed+0.000001 >= start and elapsed < end-0.000001:
		if not is_instance_valid(box):
			box = CombatHitbox.new()
			boss._configure_box(box,{"size":[1,1],"damage":attack_settings["damage"],"knockback":attack_settings["knockback"],"parriable":attack_settings["parriable"]},INF)
			box.attack_id = "golem."+attack_id
			add_child(box)
			boss._track(box)
		var rect: Rect2 = attack_rect()
		box.global_position = rect.get_center()
		box.box_size = rect.size
	else: _clear_box()
	_update_hurtbox()
	queue_redraw()
	return elapsed+0.000001 >= float(attack_settings["duration"])

func attack_rect() -> Rect2:
	var c: Dictionary = attack_settings
	return rig.global_transform*Rect2(c["hitbox_x"],c["hitbox_y"],c["hitbox_width"],c["hitbox_height"])

func _update_hurtbox() -> void:
	if is_instance_valid(boss.weakbox):
		var weak: Rect2 = weakpoint_bounds()
		boss.weakbox.box_size = weak.size
		boss.weakbox.global_position = weak.get_center()

func weakpoint_bounds() -> Rect2:
	if not active or not settings["weakpoint_enabled"] or elapsed < float(attack_settings["active_start"]) or elapsed >= float(attack_settings["punish_end"]): return Rect2()
	var fist: Node2D = rig.get_node("Torso/ArmFront_Upper/ArmFront_Lower/FistFront")
	var size: Vector2 = Vector2.ONE*float(settings["weakpoint_size"])*float(settings["scale"])
	return Rect2(fist.global_position-size/2,size)

func _clear_box() -> void:
	if is_instance_valid(box):
		box.set_physics_process(false)
		box.queue_free()
	box = null

func cancel() -> void:
	_clear_box()
	active = false
	attack_id = ""
	if is_instance_valid(animator): idle(0)

func _process(delta: float) -> void:
	impact_flash = maxf(0,impact_flash-delta)
	if is_instance_valid(rig):
		rig.modulate = Color(0.4,0.4,0.4) if boss.hp <= 0 else (Color(1.6,1.6,1.6) if boss.flash > 0 else Color.WHITE)
	queue_redraw()

func _draw() -> void:
	if impact_flash > 0 and not attack_settings.is_empty():
		var center: Vector2 = to_local(attack_rect().get_center())
		center.y = 0
		for i: int in 9:
			var t: float = 0.25-impact_flash
			var dir: Vector2 = Vector2(-1+i/4.0,-1-absf(i-4)*0.1)
			draw_circle(center+dir*t*180,3+impact_flash*15,Color(0.65,0.55,0.4,impact_flash*3))
	if Feedback.boxes_visible and active:
		var rect: Rect2 = attack_rect()
		draw_rect(Rect2(to_local(rect.position),rect.size),Color.RED if is_instance_valid(box) else Color(1,0.8,0,0.5),false,2)

# One outline per visible part, generated once from supplied PNG alpha.
# Convex outlines avoid a giant body rectangle hitting empty limb gaps.
var body_parts: Array[CombatHurtbox] = []
var walk_clock: float = 0.0
static var outline_cache: Dictionary = {}

func _build_body_parts(node: Node) -> void:
	if node is Sprite2D:
		var sprite: Sprite2D = node as Sprite2D
		var path: String = sprite.texture.resource_path
		if not outline_cache.has(path):
			var bitmap: BitMap = BitMap.new()
			bitmap.create_from_image_alpha(sprite.texture.get_image(),0.15)
			var points: PackedVector2Array = []
			for polygon: PackedVector2Array in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,bitmap.get_size()),2.0): points.append_array(polygon)
			outline_cache[path] = Geometry2D.convex_hull(points)
		var part: CombatHurtbox = CombatHurtbox.new()
		part.name = "BodyHurtbox"
		part.combatant = boss
		part.team = "enemy"
		part.outline = outline_cache[path].duplicate()
		for i: int in part.outline.size(): part.outline[i] += sprite.get_rect().position
		part.box_size = sprite.texture.get_size()
		part.aim_priority = 1 if sprite.name == "TorsoSkin" else 0
		sprite.add_child(part)
		body_parts.append(part)
		if sprite.name == "TorsoSkin":
			boss.hurtbox.box_size = Vector2.ZERO
			boss.hurtbox = part
	for child: Node in node.get_children():
		if not child is CombatHurtbox: _build_body_parts(child)

func body_overlaps(rect: Rect2) -> bool:
	for part: CombatHurtbox in body_parts:
		if part.overlaps(rect): return true
	return false

func walk(delta: float, distance: float) -> void:
	if active: return
	idle(delta)
	var stride: float = float(settings["walk_stride"])
	walk_clock = fmod(walk_clock+absf(distance)/float(settings["scale"])/(stride*2),1.0)
	var torso: Node2D = rig.get_node("Torso")
	torso.position.y = -250+sin(walk_clock*TAU*2)*3
	for side: String in ["Front","Back"]:
		var cycle: float = fmod(walk_clock+(0.5 if side == "Back" else 0.0),1.0)
		var stance: bool = cycle < 0.5
		var fraction: float = cycle*2 if stance else (cycle-0.5)*2
		var foot_x: float = lerpf(stride/2,-stride/2,fraction) if stance else lerpf(-stride/2,stride/2,fraction)
		var lift: float = 0.0 if stance else sin(fraction*PI)*float(settings["walk_lift"])
		var upper: Node2D = torso.get_node("Leg"+side+"_Upper")
		var lower: Node2D = upper.get_node("Leg"+side+"_Lower")
		var hip: Vector2 = torso.position+upper.position
		var goal: Vector2 = Vector2(upper.position.x+foot_x,-lift)-hip
		var a: float = lower.position.y
		var b: float = 164.12
		var length: float = clampf(goal.length(),absf(a-b)+0.1,a+b-0.1)
		var bend: float = acos(clampf((a*a+length*length-b*b)/(2*a*length),-1,1))
		upper.rotation = goal.angle()-PI/2-bend
		var knee: Vector2 = hip+Vector2(0,a).rotated(upper.rotation)
		lower.rotation = (Vector2(upper.position.x+foot_x,-lift)-knee).angle()-PI/2-upper.rotation
		# Foot is part of the shin artwork: keep the lowest sole point on ground.
		var hull: PackedVector2Array = (lower.get_node("BodyHurtbox") as CombatHurtbox).world_outline()
		var bottom: float = -INF
		for point: Vector2 in hull: bottom = maxf(bottom,rig.to_local(point).y)
		upper.position.y -= bottom+lift
	var sway: float = sin(walk_clock*TAU)*0.13
	torso.get_node("ArmFront_Upper").rotation = -0.12+sway
	torso.get_node("ArmBack_Upper").rotation = 0.22-sway
	_update_hurtbox()
