class_name GatePlayer
extends CharacterBody2D
signal perfect_dodge
signal parry_success
signal died
enum State {IDLE, RUN, JUMP, FALL, DASH, ATTACK, PARRY, HURT, POTION, DEAD}
@export var toy_movement_enabled: bool = false
var toy_motion: Node
@export var player_index: int = 0
@export var use_loadout: bool = false
const StatCalc = preload("res://scripts/stats/StatCalc.gd")
var stats: Dictionary = {}
var equipped_items: Array = []
var effects: Array = []
var damage_buff: float = 1.0
var damage_buff_time: float = 0.0
var state: State = State.IDLE
var controls: PlayerInput
var bow: Node2D
var body_size: Vector2
var body_color: Color
var hurtbox: CombatHurtbox
var hp: float
var potions: int
var facing: int = 1
var weapon: Dictionary
var combo_index: int = 0
var combo_remaining: float = 0.0
var attack_data: Dictionary = {}
var attack_kind: String = ""
var action_clock: float = 0.0
var input_clock: float = 0.0
var attack_spawned: bool = false
var attack_running: bool = false
var attack_facing: int = 1
var attack_hold_allowed: bool = true
var combo_display_time: float = 0.0
var combo_display_index: int = 0
var dash_elapsed: float = 0.0
var dash_reaim_remaining: float = 0.0
var parry_attack_pending: bool = false
var pogo_pending: float = 0.0
var attack_queued_until: float = 0.0
var attack_queued_direction: Vector2 = Vector2.ZERO
var attack_queued_facing: int = 1
var active_box: CombatHitbox
var coyote: float = 0.0
var jump_buffer: float = 0.0
var dash_cooldown: float = 0.0
var parry_cooldown: float = 0.0
var parry_age: float = INF
var defense_pending: Dictionary = {}
var defense_history_version: int = -1
var defense_direction: Vector2 = Vector2.ZERO
var defense_note: String = ""
var defense_note_until: int = 0
var since_dash: float = INF
var dash_time: float = 0.0
var dash_speed: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var dash_uses: int = 0
var hurt_iframe: float = 0.0
var perfect_boxes: Dictionary = {}
var last_max_hp: float
var last_potion_count: int
var total_damage_taken: float = 0.0
var total_parries: int = 0
var total_perfect: int = 0
var total_potions: int = 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_to_group("players")
	if toy_movement_enabled: add_child(HeroRig.new())
	var visual: Dictionary = DataRegistry.documents["training.json"]["player"]
	body_size = Vector2(visual["size"][0], visual["size"][1])
	body_color = Color(visual["color"][0], visual["color"][1], visual["color"][2], visual["color"][3])
	collision_layer = 2
	collision_mask = 1
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = body_size
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	controls = PlayerInput.new()
	add_child(controls)
	bow = preload("res://scripts/player/MagicBow.gd").new()
	add_child(bow)
	hurtbox = CombatHurtbox.new()
	hurtbox.combatant = self
	hurtbox.team = "player"
	hurtbox.box_size = body_size
	add_child(hurtbox)
	equipped_items = GameState.equipment() if use_loadout else []
	_recalculate()
	hp = p("max_hp")
	potions = int(p("potion_count"))
	last_max_hp = hp
	last_potion_count = potions
	Tuning.changed.connect(_tuning_changed)

func p(key: String) -> float:
	return float(stats[key]) if use_loadout else float(Tuning.player[key])

func _recalculate() -> void:
	var result: Dictionary = StatCalc.calculate(Tuning.player,equipped_items)
	stats = result["stats"]
	effects = result["effects"]
	weapon = Tuning.get_weapon(result["weapon_id"] if use_loadout else Tuning.training["player"]["weapon_id"])

func _tuning_changed() -> void:
	var old_weapon: Dictionary = weapon
	_recalculate()
	var next_weapon: Dictionary = weapon
	weapon = old_weapon
	if next_weapon["id"] != weapon["id"]:
		_cancel_attack()
		combo_index = 0
		combo_remaining = 0
		if state == State.ATTACK: _locomotion()
	weapon = next_weapon
	hp = clampf(hp + p("max_hp") - last_max_hp, 0.0, p("max_hp"))
	potions = clampi(potions + int(p("potion_count")) - last_potion_count, 0, int(p("potion_count")))
	last_max_hp = p("max_hp")
	last_potion_count = int(p("potion_count"))
	if not Tuning.player["parry_enabled"] and state == State.PARRY: _locomotion()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if toy_movement_enabled and is_instance_valid(toy_motion):
		toy_motion.tick(delta)
		queue_redraw()
		return
	if state == State.DEAD:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if hp <= 0.0:
		_die()
		return
	input_clock += delta
	combo_display_time = maxf(0,combo_display_time-delta)
	if defense_history_version != controls.history_version:
		attack_queued_until = 0
		parry_attack_pending = false
		jump_buffer = 0
	damage_buff_time = maxf(0,damage_buff_time-delta)
	if damage_buff_time <= 0: damage_buff = 1.0
	dash_cooldown = maxf(0, dash_cooldown-delta)
	parry_cooldown = maxf(0, parry_cooldown-delta)
	parry_age += delta
	hurt_iframe = maxf(0, hurt_iframe-delta)
	combo_remaining = maxf(0, combo_remaining-delta)
	since_dash += delta
	coyote = p("coyote_time") if is_on_floor() else maxf(0, coyote-delta)
	if coyote < 0.000001: coyote = 0
	jump_buffer = maxf(0, jump_buffer-delta)
	if is_on_floor(): dash_uses = 0
	if controls.just_pressed(&"jump"): jump_buffer = p("jump_buffer") + delta
	if controls.just_released(&"jump") and velocity.y < 0: velocity.y *= p("jump_cut_mult")
	var move_axis: float = controls.horizontal()
	if not controls.blocked and (not controls.pressed(&"attack") or controls.just_pressed(&"attack")): attack_hold_allowed = true
	var dash_finished: bool = false
	if state == State.ATTACK and controls.just_pressed(&"jump") and Tuning.player["attack_cancel_on_jump"] and (is_on_floor() or coyote > 0):
		_cancel_attack()
		_locomotion()
	if state == State.POTION and (move_axis != 0 or controls.just_pressed(&"jump") or controls.just_pressed(&"dash")):
		_locomotion()
	var free: bool = state in [State.IDLE,State.RUN,State.JUMP,State.FALL]
	if state != State.DASH and move_axis != 0 and not (attack_running and attack_spawned): facing = int(signf(move_axis))
	var defense_started: bool = _consume_defense()
	# One slot, bounded by the current attack; outside attacks use game-time expiry.
	if not defense_started and controls.just_pressed(&"attack") and p("attack_buffer") > 0:
		attack_queued_until = INF if attack_running else input_clock+p("attack_buffer")
		attack_queued_direction = controls.direction_at_press(&"attack")
		attack_queued_facing = facing
	if controls.just_released(&"attack") and Tuning.player["attack_release_clears_buffer"]:
		attack_queued_until = 0
		parry_attack_pending = false
	if parry_attack_pending and parry_age > p("parry_window"):
		parry_attack_pending = false
		attack_queued_until = 0
	var attack_requested: bool = not parry_attack_pending and (controls.just_pressed(&"attack") or attack_queued_until > input_clock or _repeat_attack_held())
	if not defense_started and state == State.PARRY and parry_age > p("parry_window") and Tuning.player["parry_whiff_cancel"] and (attack_requested or controls.just_pressed(&"jump")):
		_locomotion()
	# A ground dash can be interrupted by a new jump; no extra airborne jump is granted.
	if not _whiff_locked() and not defense_started and state == State.DASH and jump_buffer > 0 and (is_on_floor() or coyote > 0):
		_cancel_attack()
		velocity = Vector2(move_axis*p("move_speed"),0)
		_locomotion()
	if _whiff_locked(): jump_buffer = 0
	free = state in [State.IDLE,State.RUN,State.JUMP,State.FALL] and not defense_started and not _whiff_locked()
	if free:
		if jump_buffer > 0 and (is_on_floor() or coyote > 0):
			velocity.y = -p("jump_velocity")
			if not controls.pressed(&"jump"): velocity.y *= p("jump_cut_mult")
			jump_buffer = 0
			coyote = 0
		if attack_requested: _begin_attack()
		elif controls.just_pressed(&"potion") and potions > 0 and hp < p("max_hp"):
			state = State.POTION
			action_clock = 0
	action_clock += delta
	match state:
		State.DASH:
			# Dash trajectory is captured on entry; attack aiming remains independent.
			if Tuning.player["attack_during_dash"] and parry_age > p("parry_window") and not _whiff_locked() and not attack_running and attack_requested: _begin_attack()
			if attack_running: _tick_attack(delta,move_axis,false)
			if dash_reaim_remaining > 0:
				var aim: Vector2 = Vector2(controls.horizontal(),controls.vertical()).normalized()
				if aim != Vector2.ZERO:
					_set_dash_direction(aim)
					dash_reaim_remaining = 0
				else: dash_reaim_remaining = maxf(0,dash_reaim_remaining-delta)
			dash_elapsed += delta
			velocity = dash_direction * dash_speed
			if dash_elapsed >= dash_time:
				# Clamp last tick so the integrated dash length equals the data distance.
				velocity *= clampf((dash_time-dash_elapsed+delta)/delta, 0.0, 1.0)
				dash_finished = true
		State.ATTACK:
			_tick_attack(delta, move_axis)
		State.PARRY, State.POTION, State.HURT:
			if state == State.PARRY:
				if _whiff_locked(): velocity.x = 0
				else: _move_horizontal(move_axis,delta)
			elif state != State.HURT: velocity.x = 0
			_gravity(delta)
			if state == State.PARRY and action_clock >= p("parry_window") + p("parry_whiff_recovery"): _locomotion()
			elif state == State.HURT and action_clock >= p("hurt_recovery"): _locomotion()
			elif state == State.POTION and action_clock >= p("potion_channel"):
				hp = minf(p("max_hp"), hp+p("potion_heal"))
				potions -= 1
				total_potions += 1
				message("회복 +%s" % p("potion_heal"), Color.GREEN)
				_locomotion()
		_:
			_move_horizontal(move_axis,delta)
			_gravity(delta)
			_locomotion()
	move_and_slide()
	if dash_finished:
		velocity = Vector2(move_axis*p("move_speed"),-pogo_pending)
		pogo_pending = 0
		if attack_running and not Tuning.player["dash_attack_continues_after_dash"]: _cancel_attack()
		if attack_running: state = State.ATTACK
		elif _whiff_locked():
			state = State.PARRY
			action_clock = parry_age
		else: _locomotion()
	if is_on_floor(): dash_uses = 0
	bow.tick(delta)
	queue_redraw()

func _consume_defense() -> bool:
	var now: float = input_clock
	if defense_history_version != controls.history_version:
		defense_pending.clear()
		defense_history_version = controls.history_version
	if controls.blocked or not controls._focused:
		defense_pending.clear()
		return false
	for action: StringName in [&"dash",&"parry"]:
		if controls.just_pressed(action):
			defense_pending[action] = now + p("defense_buffer")
			if action == &"dash":
				defense_direction = controls.direction_at_press(action).normalized()
				if defense_direction == Vector2.ZERO: defense_direction = Vector2(controls.horizontal(),controls.vertical()).normalized()
	var began: bool = false
	for action: StringName in [&"dash",&"parry"]:
		if not defense_pending.has(action): continue
		if now > float(defense_pending[action]):
			defense_pending.erase(action)
			continue
		var reason: String = ""
		if state == State.HURT and not Tuning.player["defense_cancel_hurt"]: reason = "피격 경직"
		elif action == &"dash":
			if _whiff_locked() and not Tuning.player["parry_whiff_dash_cancel"]: reason = "헛패리 후딜"
			elif state == State.DASH: reason = "대시 진행 중"
			elif dash_cooldown > 0: reason = "대시 대기 %.2f초" % dash_cooldown
			elif not is_on_floor() and dash_uses >= int(p("air_dash_count")): reason = "공중 대시 소진 · 착지/포고 필요"
			elif state == State.ATTACK and not Tuning.player["attack_cancel_on_dash"] and not ("dash_cancel" in weapon["flags"] and _attack_recovery()): reason = "공격 대시 취소 꺼짐"
		else:
			if not Tuning.player["parry_enabled"]:
				reason = "패리 사용 꺼짐"
				defense_pending.erase(action)
			elif parry_cooldown > 0: reason = "패리 대기 %.2f초" % parry_cooldown
		if not reason.is_empty():
			# Only a near-ready cooldown/ongoing dash is a bufferable constraint.
			if reason.begins_with("공중") or reason in ["피격 경직","헛패리 후딜"] or reason.contains("꺼짐"):
				defense_pending.erase(action)
			elif action == &"dash" and dash_cooldown > p("defense_buffer"): defense_pending.erase(action)
			elif action == &"parry" and parry_cooldown > p("defense_buffer"): defense_pending.erase(action)
			defense_note = reason
			defense_note_until = Time.get_ticks_msec() + int(float(Tuning.training["feedback"]["message_duration"])*1000)
			continue
		defense_pending.erase(action)
		if action == &"dash": _begin_dash(defense_direction)
		else: _begin_parry()
		began = true
		defense_note = "대시 발동" if action == &"dash" else "패리 발동"
		defense_note_until = Time.get_ticks_msec() + int(float(Tuning.training["feedback"]["message_duration"])*1000)
	return began

func _begin_parry() -> void:
	_cancel_attack()
	parry_age = 0
	if controls.just_pressed(&"attack"):
		parry_attack_pending = true
		attack_queued_until = INF
		attack_queued_direction = controls.direction_at_press(&"attack")
		attack_queued_facing = facing
		attack_hold_allowed = false
	parry_cooldown = p("parry_cooldown")
	if state != State.DASH:
		state = State.PARRY
		action_clock = 0
		velocity.x = 0

func _move_horizontal(axis: float, delta: float, multiplier: float = 1.0) -> void:
	var desired: float = axis*p("move_speed")*multiplier
	if Tuning.player["instant_move"]:
		velocity.x = desired
	else:
		var rate: float = p("ground_accel") if is_on_floor() else p("air_accel")
		if axis == 0: rate = p("ground_decel") if is_on_floor() else p("air_decel")
		velocity.x = move_toward(velocity.x,desired,rate*delta)

func clear_action_intent() -> void:
	if is_instance_valid(bow): bow.cancel()
	defense_pending.clear()
	parry_age = INF
	attack_hold_allowed = false
	pogo_pending = 0
	attack_queued_until = 0
	jump_buffer = 0
	_cancel_attack()
	if state != State.DEAD: _locomotion()
	velocity = Vector2.ZERO

func _gravity(delta: float) -> void:
	if not is_on_floor() or velocity.y < 0:
		velocity.y = minf(p("max_fall_speed"), velocity.y + p("gravity") * (p("fall_gravity_mult") if velocity.y > 0 else 1.0) * delta)

func _locomotion() -> void:
	state = (State.RUN if absf(velocity.x) > 0 else State.IDLE) if is_on_floor() else (State.JUMP if velocity.y < 0 else State.FALL)

func _begin_dash(direction: Vector2 = Vector2.ZERO) -> void:
	_cancel_attack()
	attack_hold_allowed = false
	state = State.DASH
	if not attack_running: action_clock = 0
	dash_elapsed = 0
	since_dash = 0
	dash_cooldown = p("dash_cooldown")
	dash_time = maxf(p("dash_duration"), 1.0/Engine.physics_ticks_per_second)
	dash_speed = p("dash_distance") / dash_time
	dash_direction = direction if direction != Vector2.ZERO else Vector2(controls.horizontal(),controls.vertical()).normalized()
	dash_reaim_remaining = p("dash_direction_grace") if dash_direction == Vector2.ZERO else 0.0
	_set_dash_direction(dash_direction if dash_direction != Vector2.ZERO else Vector2(facing,0))
	dash_uses += 1
	perfect_boxes.clear()

func _set_dash_direction(direction: Vector2) -> void:
	dash_direction = direction
	if is_on_floor() and is_zero_approx(dash_direction.x) and dash_direction.y > 0: dash_direction = Vector2(facing,0)
	if dash_direction.x != 0: facing = int(signf(dash_direction.x))

func _begin_attack(chain: bool = false) -> void:
	var previous_combo: bool = attack_kind == "combo"
	attack_running = true
	if state != State.DASH: state = State.ATTACK
	action_clock = 0
	attack_spawned = false
	var queued: bool = attack_queued_until > input_clock
	var direction: Vector2 = attack_queued_direction if queued else controls.direction_at_press(&"attack")
	attack_kind = _attack_kind_for_direction(direction)
	attack_facing = int(signf(direction.x)) if direction.x != 0 else (attack_queued_facing if queued else facing)
	attack_queued_until = 0
	if state != State.DASH: facing = attack_facing
	if attack_kind == "combo":
		combo_index = (combo_index+1) % weapon["combo"].size() if (chain and previous_combo) or combo_remaining > 0 else 0
		attack_data = weapon["combo"][combo_index]
	else:
		_reset_combo()
		attack_data = weapon[attack_kind]

func _reset_combo() -> void:
	combo_index = 0
	combo_remaining = 0
	combo_display_time = 0

func _requested_attack_kind() -> String:
	return _attack_kind_for_direction(Vector2(controls.horizontal(),controls.vertical()))

func _attack_kind_for_direction(direction: Vector2) -> String:
	var airborne: bool = not is_on_floor() or velocity.y < 0
	if direction.y < 0: return "up_attack"
	if airborne and direction.y > 0: return "down_attack"
	return "air_attack" if airborne else "combo"

func _attack_recovery() -> bool:
	return action_clock >= float(attack_data["startup"]) + float(attack_data["active"])

func _repeat_attack_held() -> bool:
	return attack_hold_allowed and Tuning.player["attack_hold_repeat"] and controls.pressed(&"attack")

func _tick_attack(delta: float, move_axis: float, affect_motion: bool = true) -> void:
	# Aim can change during startup without restarting its clock or adding delay.
	if not attack_spawned and Tuning.player["attack_direction_chain"] and (controls.pressed(&"attack") or controls.horizontal() != 0 or controls.vertical() != 0):
		if move_axis != 0: attack_facing = int(signf(move_axis))
		var requested: String = _requested_attack_kind() if controls.vertical() != 0 else attack_kind
		if requested != attack_kind:
			attack_kind = requested
			if requested != "combo": _reset_combo()
			attack_data = weapon["combo"][combo_index % weapon["combo"].size()] if requested == "combo" else weapon[requested]
	# A held attack with a new direction is current intent, never a stored queue.
	# Finish the active strike, then cancel recovery into the requested direction.
	var directional: bool = controls.pressed(&"attack") and (_requested_attack_kind() != attack_kind or (move_axis != 0 and int(signf(move_axis)) != attack_facing))
	var fresh: bool = controls.just_pressed(&"attack") and action_clock > delta
	if _chain_ready() and (fresh or attack_queued_until > input_clock or _repeat_attack_held() or (Tuning.player["attack_direction_chain"] and directional)):
		# Preserve the one queued direction until _begin_attack consumes it.
		if is_instance_valid(active_box): active_box.queue_free()
		_begin_attack(true)
	if affect_motion:
		_gravity(delta)
		_move_horizontal(move_axis,delta,p("attack_move_mult"))
	if affect_motion and is_on_floor():
		var startup: float = maxf(float(attack_data["startup"]), delta)
		var portion: float = clampf(minf(action_clock,startup)-minf(action_clock-delta,startup),0.0,delta)
		velocity.x += attack_facing * float(attack_data.get("lunge",0)) / startup * portion / delta
	if not attack_spawned and action_clock >= float(attack_data["startup"]):
		attack_spawned = true
		_spawn_attack()
	if action_clock >= float(attack_data["startup"])+float(attack_data["active"])+float(attack_data["recovery"]):
		combo_remaining = float(weapon["combo_window"]) if attack_kind == "combo" else 0.0
		var fresh_press: bool = controls.just_pressed(&"attack") and action_clock > delta
		if attack_queued_until > input_clock or fresh_press or _repeat_attack_held(): _begin_attack(true)
		else:
			attack_running = false
			if state != State.DASH: _locomotion()

func attack_rect() -> Rect2:
	var size: Vector2 = Vector2(attack_data["reach"],attack_data["height"])
	var center: Vector2 = Vector2(attack_facing*(body_size.x+size.x)/2,0)
	if attack_kind in ["up_attack","down_attack"]: center = Vector2(0,(-1 if attack_kind == "up_attack" else 1)*(body_size.y+size.y)/2)
	return Rect2(center-size/2,size)

func _spawn_attack() -> void:
	if attack_kind == "combo":
		combo_display_index = combo_index
		combo_display_time = float(weapon["combo_window"])+float(attack_data["active"])+float(attack_data["recovery"])
	active_box = CombatHitbox.new()
	active_box.source = self
	active_box.team = "player"
	active_box.damage = float(attack_data["damage"])*float(stats.get("damage_mult",1))*damage_buff
	active_box.knockback = attack_data.get("knockback",0)
	active_box.duration = attack_data["active"]
	active_box.attack_id = attack_kind
	var rect: Rect2 = attack_rect()
	active_box.box_size = rect.size
	active_box.position = rect.get_center()
	var color: Array = DataRegistry.documents["training.json"]["feedback"]["attack_color"]
	active_box.tint = Color(color[0],color[1],color[2],color[3])
	add_child(active_box)

func _cancel_attack() -> void:
	parry_attack_pending = false
	attack_running = false
	if is_instance_valid(active_box): active_box.queue_free()
	attack_queued_until = 0

func dealt_hit(_target: Node2D, box: CombatHitbox) -> void:
	if box.attack_id == "down_attack":
		if Tuning.player["pogo_resets_air_dash"]: dash_uses = 0
		# Preserve a running dash. Apply the bounce when its trajectory finishes.
		if state == State.DASH: pogo_pending = float(weapon["down_attack"]["pogo_velocity"])
		else: velocity.y = -float(weapon["down_attack"]["pogo_velocity"])

func receive_hit(box: CombatHitbox) -> String:
	if state == State.DEAD: return "ignored"
	if Tuning.player["parry_enabled"] and parry_age <= p("parry_window") and box.parriable:
		total_parries += 1
		parry_success.emit()
		for effect: Dictionary in effects:
			if effect["type"] == "on_parry_heal": hp = minf(p("max_hp"),hp+float(effect["amount"]))
		Feedback.trigger("parry")
		message("패리", Color.CYAN)
		if is_instance_valid(box.source) and box.source.has_method("on_parried"): box.source.on_parried()
		parry_age = INF
		if state == State.PARRY: _locomotion()
		if parry_attack_pending:
			parry_attack_pending = false
			_begin_attack()
		return "reflected" if box.reflect(self) else "parried"
	if since_dash <= p("dash_iframe"):
		if since_dash <= p("perfect_dodge_window") and not perfect_boxes.has(box.get_instance_id()):
			perfect_boxes[box.get_instance_id()] = true
			total_perfect += 1
			perfect_dodge.emit()
			for effect: Dictionary in effects:
				if effect["type"] == "on_perfect_dodge_damage_buff":
					damage_buff = maxf(damage_buff,float(effect["mult"]))
					damage_buff_time = maxf(damage_buff_time,float(effect["duration"]))
			message("완벽 회피", Color.GOLD)
		return "ignored"
	if hurt_iframe > 0 or Feedback.invincible: return "ignored"
	bow.cancel()
	hp = maxf(0, hp-box.damage)
	total_damage_taken += box.damage
	hurt_iframe = p("hurt_iframe")
	_cancel_attack()
	parry_age = INF
	pogo_pending = 0
	Feedback.trigger("player_hurt")
	if Tuning.feedback["damage_numbers"]: message("−%s" % box.damage, Color.SALMON)
	if hp <= 0:
		_die()
	else:
		state = State.HURT
		action_clock = 0
		velocity.x = (-1 if box.global_position.x > global_position.x else 1) * p("hurt_knockback")
	return "hit"

func _die() -> void:
	bow.cancel()
	state = State.DEAD
	_cancel_attack()
	died.emit()

func message(text: String, color: Color) -> void:
	var node: Node2D = load("res://scripts/combat/FloatingText.gd").new()
	var data: Dictionary = DataRegistry.documents["training.json"]["feedback"]
	node.text = text
	node.tint = color
	node.remaining = data["message_duration"]
	node.rise = data["number_rise_speed"]
	get_parent().add_child(node)
	node.global_position = global_position - Vector2(0,body_size.y/2)

func _draw() -> void:
	var tint: Color = body_color
	if state == State.DEAD: tint = Color.DIM_GRAY
	elif state == State.HURT: tint = Color.SALMON
	elif state == State.DASH: tint = Color(0.5,1,1,0.65)
	elif state == State.PARRY: tint = Color.DEEP_SKY_BLUE
	elif state == State.POTION: tint = Color.LIME_GREEN
	if hurt_iframe > 0: tint.a = 0.6
	if toy_movement_enabled:
		# The fennec cutout rig (HeroRig child) draws the body; keep the hitbox visible on F2.
		if Feedback.boxes_visible: draw_rect(Rect2(-body_size/2,body_size),Color.YELLOW,false)
	else:
		draw_rect(Rect2(-body_size/2,body_size),tint)
	var aim: Vector2 = Vector2(0,signf(controls.vertical())) if controls.vertical() != 0 else Vector2(facing,0)
	if attack_running:
		aim = Vector2.UP if attack_kind == "up_attack" else (Vector2.DOWN if attack_kind == "down_attack" else Vector2(attack_facing,0))
	var tip: Vector2 = aim*(body_size.y/2+12)
	draw_colored_polygon(PackedVector2Array([tip,tip-aim*14+aim.orthogonal()*9,tip-aim*14-aim.orthogonal()*9]),Color.WHITE)
	_draw_swing()
	if since_dash <= p("dash_iframe"): draw_rect(Rect2(-body_size/2-Vector2(5,5),body_size+Vector2(10,10)),Color.CYAN,false,3)
	if state == State.DASH:
		draw_line(-dash_direction*75,Vector2.ZERO,Color.CYAN,5)
	if Tuning.player["parry_enabled"] and parry_age <= p("parry_window"):
		draw_arc(Vector2.ZERO,body_size.y/2+8,0,TAU,32,Color.DEEP_SKY_BLUE,4)
	if Feedback.boxes_visible and Tuning.player["parry_enabled"] and state == State.PARRY:
		draw_rect(Rect2(-body_size/2,body_size),Color.BLUE,false,4)

# Geometry follows the actual attack rectangle, facing and action clock.
func _draw_swing() -> void:
	var palette: Array[Color] = [Color("67e8f9"),Color("a5b4fc"),Color("e879f9"),Color("ffd166")]
	if combo_display_time > 0:
		var color: Color = palette[combo_display_index % 4]
		for i: int in weapon["combo"].size():
			draw_circle(Vector2((i-(weapon["combo"].size()-1)*0.5)*18,-66),5,color if i <= combo_display_index else Color(0.2,0.25,0.3))
		draw_string(ThemeDB.fallback_font,Vector2(-42,-84),"%d / %d%s" % [combo_display_index+1,weapon["combo"].size()," FINISH" if combo_display_index == weapon["combo"].size()-1 else ""],HORIZONTAL_ALIGNMENT_LEFT,-1,20,color)
	if not attack_running: return
	var stage: int = combo_index % 4 if attack_kind == "combo" else 0
	var tint: Color = palette[stage]
	var rect: Rect2 = attack_rect()
	var startup: float = float(attack_data["startup"])
	var active: float = float(attack_data["active"])
	var progress: float = clampf((action_clock-startup)/active,0,1)
	if action_clock > startup+active:
		tint.a = clampf(1-(action_clock-startup-active)/maxf(float(attack_data["recovery"]),0.001),0,1)*0.45
	elif not attack_spawned: tint.a = 0.4
	var horizontal: bool = attack_kind not in ["up_attack","down_attack"]
	var points: PackedVector2Array = []
	for i: int in 25:
		var t: float = float(i)/24
		var forward: float = sin(t*PI)
		var cross: float = lerpf(-0.48,0.48,t)
		if stage == 1: cross = -cross
		if stage == 2: forward = t; cross = sin(t*PI)*0.12
		if stage == 3: forward = sin(t*PI)*0.96; cross *= 1.0
		var point: Vector2
		if horizontal:
			point = Vector2(attack_facing*(body_size.x/2+forward*rect.size.x),cross*rect.size.y)
		else:
			point = Vector2(cross*rect.size.x,(-1 if attack_kind == "up_attack" else 1)*(body_size.y/2+forward*rect.size.y))
		points.append(point)
	draw_polyline(points,Color(tint,tint.a*0.2),2,true)
	var count: int = clampi(int(progress*24)+2,2,25)
	if not attack_spawned: count = 2
	draw_polyline(points.slice(0,count),tint,8 if stage == 3 else 4,true)
	var tip: Vector2 = points[count-1]
	draw_line(Vector2.ZERO,tip,Color(1,1,1,tint.a),5 if stage == 3 else 3,true)
	draw_circle(tip,7 if stage == 3 else 4,tint)
	if stage == 3 and attack_spawned:
		draw_polyline(Transform2D(0,Vector2(0,8))*points.slice(0,count),Color(tint, tint.a*0.5),3,true)

func _chain_ready() -> bool:
	var recovery: float = float(attack_data["recovery"])
	var chain_at: float = clampf(float(attack_data["chain_at"]),0,recovery)
	return action_clock >= float(attack_data["startup"])+float(attack_data["active"])+chain_at

func _whiff_locked() -> bool:
	return not Tuning.player["parry_whiff_cancel"] and parry_age > p("parry_window") and parry_age < p("parry_window")+p("parry_whiff_recovery")
