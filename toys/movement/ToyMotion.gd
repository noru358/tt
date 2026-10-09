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
	Engine.time_scale = Feedback.base_speed
	was_held = true
	bash_consumed = true

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
		if Time.get_ticks_msec() < float(cooldowns.get(item.get_instance_id(),0)): continue
		var d: float = player.global_position.distance_to(item.global_position)
		if d <= distance:
			distance = d
			found = item
	if is_instance_valid(found): found.highlight = true
	return found

func tick(delta: float) -> void:
	if world.panel.visible or world.respawning:
		cancel()
		return
	var held: bool = Input.is_action_pressed("toy_bash")
	var candidate: Node2D = nearest()
	if not held or not was_held: bash_consumed = false
	if held and not bash_consumed and not is_instance_valid(target) and is_instance_valid(candidate):
		bash_consumed = true
		target = candidate
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
	if player.is_on_floor(): player.dash_uses = 0
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
	if player.state != GatePlayer.State.DASH and player.controls.just_pressed(&"dash") and player.dash_cooldown <= 0 and player.dash_uses < int(t("air_dash_count")):
		launch_age = -1
		coast_remaining = 0
		player._begin_dash()
		player.dash_time = t("dash_duration")
		player.dash_speed = t("dash_distance") / player.dash_time
		player.dash_cooldown = t("dash_cooldown")
	if player.state == GatePlayer.State.DASH:
		player.dash_elapsed += delta
		player.velocity = player.dash_direction*player.dash_speed
		if player.dash_elapsed >= player.dash_time:
			player.state = GatePlayer.State.FALL
			if not player.is_on_floor() and player.dash_uses < int(t("air_dash_count")):
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
