extends Node2D
const Arrow = preload("res://scripts/combat/MagicArrow.gd")
var player: GatePlayer
var queued_charge: float = 0.0
var charging: bool = false
var charge_time: float = 0.0
var cooldown: float = 0.0
var target: CombatHurtbox
var aim: Vector2 = Vector2.RIGHT
var history: int = -1
var release_flash: float = 0.0
var release_charge: float = 0.0
var shots_fired: int = 0
var last_arrow: MagicArrow

func _ready() -> void:
	player = get_parent() as GatePlayer
	z_index = 5

func ratio() -> float:
	return clampf(charge_time/maxf(player.p("bow_charge_time"),0.001),0,1)

func cancel() -> void:
	queued_charge = 0
	charging = false
	charge_time = 0
	target = null
	release_flash = 0
	queue_redraw()

func tick(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	release_flash = maxf(0,release_flash-delta)
	var input: PlayerInput = player.controls
	if history != input.history_version:
		cancel()
		history = input.history_version
	if input.blocked or not input._focused or player.state in [GatePlayer.State.DEAD,GatePlayer.State.HURT,GatePlayer.State.POTION,GatePlayer.State.PARRY] or player._whiff_locked() or player.parry_age <= player.p("parry_window"):
		cancel()
		return
	queued_charge = maxf(0,queued_charge-delta)
	if input.just_released(&"magic_bow"): queued_charge = 0
	if input.just_pressed(&"magic_bow") and cooldown > 0 and cooldown <= player.p("bow_input_buffer"):
		queued_charge = player.p("bow_input_buffer")
	if (input.just_pressed(&"magic_bow") or (queued_charge > 0 and input.pressed(&"magic_bow"))) and cooldown <= 0:
		queued_charge = 0
		charging = true
		charge_time = 0
		target = acquire_target()
	if charging:
		if not Arrow.targetable(target): target = acquire_target()
		aim = (target.aim_point()-global_position).normalized() if Arrow.targetable(target) else Vector2(player.facing,0)
		if input.pressed(&"magic_bow"): charge_time = minf(player.p("bow_charge_time"),charge_time+delta)
		if input.just_released(&"magic_bow") or not input.pressed(&"magic_bow"): fire()
	queue_redraw()

func acquire_target() -> CombatHurtbox:
	var selected: CombatHurtbox
	var best: float = INF
	for node: Node in get_tree().get_nodes_in_group("hurtboxes"):
		var box: CombatHurtbox = node as CombatHurtbox
		if not Arrow.targetable(box): continue
		var distance: float = global_position.distance_to(box.aim_point())
		if distance > player.p("bow_lock_range"): continue
		# Bosses win over incidental enemies; otherwise choose the nearest target.
		var score: float = distance-float(box.aim_priority)*player.p("bow_lock_range")-(player.p("bow_lock_range") if box.combatant.has_signal("died") else 0.0)
		if score < best:
			selected = box
			best = score
	return selected

func fire() -> void:
	var power: float = ratio()
	var arrow: MagicArrow = Arrow.new()
	arrow.source = player
	arrow.team = "player"
	arrow.target = target
	arrow.charge = power
	arrow.damage = lerpf(player.p("bow_damage_min"),player.p("bow_damage_max"),power)*float(player.stats.get("damage_mult",1))*player.damage_buff
	arrow.speed = lerpf(player.p("bow_speed_min"),player.p("bow_speed_max"),power)
	arrow.turn_rate = player.p("bow_turn_rate")
	arrow.duration = player.p("bow_lifetime")
	arrow.box_size = Vector2.ONE*player.p("bow_hit_size")
	arrow.attack_id = "magic_arrow"
	arrow.motion = aim
	player.get_parent().add_child(arrow)
	# Read the live player position after movement, including any future blink.
	arrow.global_position = player.global_position
	last_arrow = arrow
	shots_fired += 1
	cooldown = player.p("bow_cooldown")
	charging = false
	release_flash = 0.22
	release_charge = power
	queue_redraw()

func status_text() -> String:
	if charging: return "마법 활 완충 · 떼면 발사" if ratio() >= 1 else "마법 활 충전 %d%%" % int(ratio()*100)
	if cooldown > 0: return "마법 활 %.1f초" % cooldown
	return "마법 활 준비 · U / RB"

func _draw() -> void:
	if not charging and release_flash <= 0: return
	var power: float = ratio() if charging else release_charge
	var color: Color = Color(0.35,0.85,1).lerp(Color(1,0.85,0.35),power)
	var alpha: float = 1.0 if charging else release_flash/0.22
	if charging and Arrow.targetable(target):
		var center: Vector2 = to_local(target.aim_point())
		draw_arc(center,34,0,TAU,28,Color(color,0.75),2,true)
		for i: int in 4:
			var ray: Vector2 = Vector2.RIGHT.rotated(i*PI/2)
			draw_line(center+ray*29,center+ray*42,color,3,true)
	draw_set_transform(Vector2.ZERO,aim.angle())
	var curve: PackedVector2Array = []
	for i: int in 21:
		var t: float = float(i)/20
		curve.append(Vector2(28+sin(t*PI)*(20+power*14),(t-0.5)*(82+power*20)))
	draw_polyline(curve,Color(color,alpha*0.18),13,true)
	draw_polyline(curve,Color(color,alpha),3+power*2,true)
	var pull: Vector2 = Vector2(18-power*30,0)
	draw_polyline(PackedVector2Array([curve[0],pull,curve[-1]]),Color(0.9,1,1,alpha),2,true)
	draw_line(pull,Vector2(64,0),Color(color,alpha),3+power*3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(76,0),Vector2(59,-7-power*4),Vector2(59,7+power*4)]),Color(color,alpha))
	if power >= 1:
		draw_arc(Vector2(66,0),15,0,TAU,24,Color.WHITE,2,true)
	if not charging:
		for i: int in 6:
			var ray: Vector2 = Vector2.RIGHT.rotated(i*TAU/6)
			var center: Vector2 = Vector2(35,0)+ray*(1-alpha)*70
			draw_line(center,center+ray*12,Color(color,alpha),3,true)
	draw_set_transform(Vector2.ZERO)
