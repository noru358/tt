extends Node
var player: GatePlayer
var world: Node2D
var lock_time: float = 0
var target: Node2D
var aim: Vector2 = Vector2.UP
var held_since: int = 0
var cooldowns: Dictionary = {}
var was_held: bool = false
var bash_consumed: bool = false
var bash_active: bool = false
var dash_pending: float = 0
var pending_dash_direction: Vector2 = Vector2.ZERO
var input_history: int = -1
var dash_received: int = 0
var dash_started: int = 0
var dash_note: String = "준비"
var jump_pending: float = 0
var wall_grace: float = 0
var wall_normal: Vector2 = Vector2.ZERO
var direct_aim: bool = true
var flash_remaining: float = 0
var launch_origin: Vector2
var launch_age: float = -1
var coast_remaining: float = 0
var launch_direction: Vector2

func t(key: String) -> float:
	return float(world.tuning[key])

func cancel() -> void:
	target = null
	bash_active = false
	dash_pending = 0
	jump_pending = 0
	Engine.time_scale = Feedback.base_speed
	was_held = true
	bash_consumed = true

func reset_motion() -> void:
	cancel()
	lock_time = 0
	wall_grace = 0
	wall_normal = Vector2.ZERO
	launch_age = -1
	coast_remaining = 0
	flash_remaining = 0
	cooldowns.clear()
	player.controls.clear_history()
	input_history = player.controls.history_version
	player.reset_physics_interpolation()

func launch() -> void:
	if not is_instance_valid(target):
		cancel()
		return
	player.velocity = aim * t("bash_launch_speed") * t("bash_start_speed_ratio")
	launch_age = 0
	coast_remaining = t("bash_coast_time")
	flash_remaining = t("bash_flash_time")
	launch_origin = target.global_position
	launch_direction = aim
	target.bash(-aim)
	cooldowns[target.get_instance_id()] = Time.get_ticks_msec() + t("bash_same_target_cooldown") * 1000
	player.dash_uses = 0
	player.dash_cooldown = 0
	player.state = GatePlayer.State.JUMP
	lock_time = t("bash_air_control_delay")
	world.log_data.bash_count += 1
	cancel()

func nearest() -> Node2D:
	var found: Node2D
	var distance: float = t("bash_radius")
	for item: Node in get_tree().get_nodes_in_group("toy_bashable"):
		item.highlight = false
		if item.is_queued_for_deletion(): continue
		if Time.get_ticks_msec() < float(cooldowns.get(item.get_instance_id(),0)): continue
		var d: float = player.global_position.distance_to(item.global_position)
		if d <= distance:
			var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(player.global_position,item.global_position,1)
			if not player.get_world_2d().direct_space_state.intersect_ray(query).is_empty(): continue
			distance = d
			found = item
	if is_instance_valid(found): found.highlight = true
	return found

func tick(delta: float) -> void:
	if world.panel.visible or world.respawning or player.controls.blocked or not player.controls._focused:
		cancel()
		return
	if input_history != player.controls.history_version:
		dash_pending = 0
		jump_pending = 0
		input_history = player.controls.history_version
	if bash_active and not is_instance_valid(target): cancel()
	var held: bool = Input.is_action_pressed("toy_bash")
	var candidate: Node2D = nearest()
	if not held or not was_held: bash_consumed = false
	if held and not bash_consumed and not is_instance_valid(target) and is_instance_valid(candidate):
		bash_consumed = true
		target = candidate
		bash_active = true
		dash_pending = 0
		jump_pending = 0
		held_since = Time.get_ticks_msec()
		aim = Vector2.UP
		player.velocity = Vector2.ZERO
		launch_age = -1
		coast_remaining = 0
		Engine.time_scale = t("bash_time_scale") * Feedback.base_speed
	was_held = held
	if is_instance_valid(target):
		var direction: Vector2 = Vector2.ZERO
		if player.controls.device_id >= 0:
			direction = Vector2(player.controls.horizontal(),player.controls.vertical())
		elif direct_aim:
			direction = Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		else:
			direction = Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
		if direction.length() > 0: aim = direction.normalized()
		if not held or (Time.get_ticks_msec()-held_since)/1000.0 >= t("bash_max_hold"): launch()
		return
	lock_time = maxf(0,lock_time-delta)
	player.dash_cooldown = maxf(0,player.dash_cooldown-delta)
	player.since_dash += delta
	player.hurt_iframe = maxf(0,player.hurt_iframe-delta)
	var axis: float = player.controls.horizontal()
	if axis != 0: player.facing = int(signf(axis))
	if player.is_on_floor() and player.state != GatePlayer.State.DASH: player.dash_uses = 0
	var wall: bool = player.is_on_wall() and not player.is_on_floor() and axis * player.get_wall_normal().x < 0
	jump_pending = maxf(0,jump_pending-delta)
	wall_grace = maxf(0,wall_grace-delta)
	if player.is_on_wall() and not player.is_on_floor() and lock_time <= 0:
		wall_normal = player.get_wall_normal()
		wall_grace = t("wall_jump_grace")
	if player.controls.just_pressed(&"jump"): jump_pending = t("wall_jump_buffer")
	if jump_pending > 0:
		if wall_grace > 0 and not player.is_on_floor():
			jump_pending = 0
			wall_grace = 0
			player.velocity = Vector2(wall_normal.x*t("wall_jump_push_x"),-t("wall_jump_push_y"))
			lock_time = t("wall_jump_lock_time")
			player.state = GatePlayer.State.JUMP
			launch_age = -1
			coast_remaining = 0
			player.dash_uses = 0
			player.dash_cooldown = 0
			world.log_data.wall_jump_count += 1
		elif player.is_on_floor():
			jump_pending = 0
			player.velocity.y = -t("jump_velocity")
			player.state = GatePlayer.State.JUMP
			launch_age = -1
			coast_remaining = 0
			dash_pending = 0
	dash_pending = maxf(0,dash_pending-delta)
	if player.controls.just_pressed(&"dash"):
		dash_received += 1
		if player.dash_uses >= int(t("air_dash_count")):
			player.dash_reaim_remaining = 0
			dash_note = "횟수 소진"
	if player.controls.just_pressed(&"dash") and player.dash_uses < int(t("air_dash_count")):
		dash_pending = t("dash_input_buffer")
		pending_dash_direction = player.controls.direction_at_press(&"dash").normalized()
		for action: StringName in [&"move_left",&"move_right",&"aim_up",&"aim_down"]:
			if player.controls.just_pressed(action):
				var fresh: Vector2 = player.controls.recent_direction()
				if fresh != Vector2.ZERO: pending_dash_direction = fresh
				break
		if pending_dash_direction == Vector2.ZERO: pending_dash_direction = Vector2(player.facing,0)
	# A new press spends the next charge immediately, even during the first dash.
	# Each press owns its direction; remaining first-dash time is discarded.
	if dash_pending > 0 and (player.dash_cooldown <= 0 or player.dash_uses > 0) and player.dash_uses < int(t("air_dash_count")):
		dash_pending = 0
		launch_age = -1
		coast_remaining = 0
		player._begin_dash(pending_dash_direction)
		dash_started += 1
		dash_note = direction_label(player.dash_direction)
		player.dash_time = t("dash_duration")
		player.dash_speed = t("dash_distance") / player.dash_time
		player.dash_cooldown = t("dash_cooldown")
		player.dash_reaim_remaining = t("dash_aim_grace")
	if player.state == GatePlayer.State.DASH:
		if player.dash_reaim_remaining > 0:
			for action: StringName in [&"move_left",&"move_right",&"aim_up",&"aim_down"]:
				if player.controls.just_pressed(action):
					var fresh: Vector2 = player.controls.recent_direction()
					if fresh != Vector2.ZERO:
						player._set_dash_direction(fresh)
						dash_note = direction_label(player.dash_direction)
					break
			player.dash_reaim_remaining = maxf(0,player.dash_reaim_remaining-delta)
		var remaining: float = maxf(0,player.dash_time-player.dash_elapsed)
		player.dash_elapsed += delta
		player.velocity = player.dash_direction*player.dash_speed*minf(1,remaining/delta)
		if player.dash_elapsed >= player.dash_time or is_equal_approx(player.dash_elapsed,player.dash_time):
			player.state = GatePlayer.State.FALL
			if player.dash_uses < int(t("air_dash_count")):
				player.dash_cooldown = 0
	else:
		if launch_age >= 0:
			launch_age = minf(launch_age+delta,t("bash_launch_ramp"))
			var progress: float = smoothstep(0,1,launch_age/t("bash_launch_ramp"))
			player.velocity = launch_direction*t("bash_launch_speed")*lerpf(t("bash_start_speed_ratio"),1,progress)
			player.velocity.y += t("gravity")*launch_age
			if launch_age >= t("bash_launch_ramp"): launch_age = -1
		else:
			coast_remaining = maxf(0,coast_remaining-delta)
			if player.is_on_floor(): coast_remaining = 0
			var coast: float = coast_remaining/t("bash_coast_time")
			var control: float = t("wall_control_mult") if lock_time > 0 else 1.0
			var acceleration: float = lerpf(t("air_control_accel"),t("bash_coast_accel"),coast)
			player.velocity.x = move_toward(player.velocity.x,axis*t("move_speed"),acceleration*control*delta)
			if coast_remaining > 0 and player.velocity.y > t("max_fall_speed"):
				player.velocity.y = move_toward(player.velocity.y,t("max_fall_speed"),acceleration*delta)
			else:
				player.velocity.y += t("gravity")*delta
				if lock_time <= 0: player.velocity.y = minf(t("max_fall_speed"),player.velocity.y)
		if wall and player.velocity.y > t("wall_slide_speed"): player.velocity.y = t("wall_slide_speed")
		player._locomotion()
	player.move_and_slide()
	for index: int in player.get_slide_collision_count():
		if player.get_slide_collision(index).get_normal().dot(launch_direction) < 0: launch_age = -1

func direction_label(value: Vector2) -> String:
	if value.y < 0: return "↖" if value.x < 0 else ("↗" if value.x > 0 else "↑")
	if value.y > 0: return "↙" if value.x < 0 else ("↘" if value.x > 0 else "↓")
	return "←" if value.x < 0 else "→"
