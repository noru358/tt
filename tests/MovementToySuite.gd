extends Node
class Target extends Node2D:
	var damage: float = 0
	func receive_hit(box: CombatHitbox) -> String:
		damage += box.damage
		return "hit"
var failures: int = 0
var checks: int = 0
var world: Node2D
func check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+note)

func _ready() -> void:
	if OS.get_environment("MOVEMENT_TEST_ROOMS").is_empty() or OS.get_environment("MOVEMENT_TEST_TUNING").is_empty():
		push_error("Scratch room and tuning paths required")
		get_tree().quit(1)
		return
	world = preload("res://toys/movement/movement_toy.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.controls.set_physics_process(false)
	check(world.rooms.size() == 8,"eight rooms")
	check(world.player.toy_movement_enabled,"opt in")
	var ordinary: GatePlayer = preload("res://scenes/player/Player.tscn").instantiate()
	check(not ordinary.toy_movement_enabled,"default off")
	ordinary.free()
	for index: int in 8:
		world.load_room(index)
		world._process(0)
		check(is_equal_approx(world.camera.zoom.x,maxf(world.get_viewport_rect().size.x/float(world.tuning.camera_view_width),world.get_viewport_rect().size.y/float(world.tuning.camera_view_height))),"fixed camera zoom %d" % index)
		check(world.room_size.x > 0 and world.triggers.size() > 0,"room load %d" % index)
		await get_tree().physics_frame
	world.load_room(0)
	await get_tree().physics_frame
	var orb: Node2D = get_tree().get_first_node_in_group("toy_bashable")
	world.player.position = orb.position+Vector2(10,0)
	check(world.motion.nearest() == orb,"nearest selection")
	world.motion.target = orb
	world.motion.aim = Vector2(0.6,-0.8)
	world.player.dash_uses = 1
	world.motion.launch()
	check(world.player.velocity.is_equal_approx(Vector2(0.6,-0.8)*float(world.tuning.bash_launch_speed)*float(world.tuning.bash_start_speed_ratio)),"continuous launch")
	check(world.player.dash_uses == 0 and world.player.dash_cooldown == 0,"recharge dash")
	check(world.motion.nearest() == null,"same target cooldown")
	check(orb.offset.x < 0 and orb.offset.y > 0,"opposite orb push")
	check(is_equal_approx(Engine.time_scale,Feedback.base_speed),"restore timescale")
	var start_speed: float = world.player.velocity.length()
	world.motion.tick(float(world.tuning.bash_launch_ramp)/2)
	check(world.player.velocity.length() > start_speed and world.player.velocity.length() < float(world.tuning.bash_launch_speed),"smooth launch midpoint")
	world.motion.tick(float(world.tuning.bash_launch_ramp)/2)
	check(world.player.velocity.is_equal_approx(Vector2(0.6,-0.8)*float(world.tuning.bash_launch_speed)+Vector2(0,float(world.tuning.gravity)*float(world.tuning.bash_launch_ramp))),"launch includes gravity during ramp")
	var peak_x: float = world.player.velocity.x
	world.motion.tick(1.0/60)
	check(world.player.velocity.x > peak_x-30 and world.player.velocity.x < peak_x,"gradual coast")
	var bullet: Node2D = world._orb(world.player.position,"bullet")
	bullet.bash(Vector2.LEFT)
	check(bullet.reflected and bullet.velocity.x < 0,"projectile reflected")
	var enemy: Target = Target.new()
	enemy.position = bullet.position-Vector2(20,0)
	world.add_child(enemy)
	var hurt: CombatHurtbox = CombatHurtbox.new()
	hurt.combatant = enemy
	hurt.team = "enemy"
	hurt.box_size = Vector2(10,10)
	enemy.add_child(hurt)
	bullet._physics_process(0.1)
	check(enemy.damage == float(world.tuning.projectile_damage),"reflected projectile enemy damage")
	enemy.queue_free()
	var room: String = world.room_directory+"/room_01.txt"
	var original: String = FileAccess.get_file_as_string(room)
	var file: FileAccess = FileAccess.open(room,FileAccess.WRITE)
	file.store_string("########\n#P.o?\n###\n")
	file.close()
	world._command("다시 읽기 F7")
	check(world.room_size == Vector2(8,3)*float(world.tuning.tile_size),"ragged unknown parser")
	check(world.log_data.f7_reloads == 1,"F7 counter")
	await get_tree().physics_frame
	orb = get_tree().get_first_node_in_group("toy_bashable")
	check(orb.position == Vector2(3.5,1.5)*float(world.tuning.tile_size),"F7 disk reload")
	file = FileAccess.open(room,FileAccess.WRITE)
	file.store_string(original)
	file.close()
	world.load_room(0)
	world.checkpoint = Vector2(80,304)
	world.player.position = Vector2(100,150)
	world.respawn()
	await get_tree().create_timer(float(world.tuning.respawn_fade)+0.1,true,false,true).timeout
	check(world.player.position == world.checkpoint and world.log_data.deaths == 1,"checkpoint respawn")
	world.player.position = Vector2(42,100)
	world.player.velocity = Vector2(-30,200)
	world.player.move_and_slide()
	world.player.controls._current = {&"move_left":1.0}
	world.player.controls._pressed_edges.clear()
	world.motion.was_held = false
	world.motion.tick(1.0/60)
	check(world.player.velocity.y <= float(world.tuning.wall_slide_speed),"wall slide cap")
	world.player.controls._current = {}
	world.player.controls._pressed_edges[&"jump"] = true
	world.motion.tick(1.0/60)
	check(world.player.velocity.x > 0 and world.player.velocity.y < 0 and world.log_data.wall_jump_count == 1,"wall jump without direction hold")
	world.player.controls._pressed_edges.clear()
	world.load_room(0)
	await get_tree().physics_frame
	orb = get_tree().get_first_node_in_group("toy_bashable")
	world.player.position = orb.position
	world.motion.was_held = false
	Input.action_press("toy_bash")
	world.player.position = orb.position+Vector2(float(world.tuning.bash_radius)+100,0)
	world.motion.tick(1.0/60)
	check(not is_instance_valid(world.motion.target),"hold outside bash range")
	world.player.position = orb.position
	world.motion.tick(1.0/60)
	check(is_instance_valid(world.motion.target) and Engine.time_scale < 1,"hold slow time")
	world.motion.held_since = Time.get_ticks_msec()-int(float(world.tuning.bash_max_hold)*1000)-1
	world.motion.tick(1.0/60)
	check(not is_instance_valid(world.motion.target) and Engine.time_scale == Feedback.base_speed,"hold timeout launch")
	world.motion.cooldowns.clear()
	world.player.position = orb.position
	world.motion.tick(1.0/60)
	check(not is_instance_valid(world.motion.target),"timeout requires release before recapture")
	Input.action_release("toy_bash")
	world._command("튜닝 F1")
	var values: VBoxContainer = world.panel.get_child(0).get_child(0)
	var slider: HSlider
	for index: int in values.get_child_count()-1:
		var child: Node = values.get_child(index)
		if child is Label and child.text.begins_with("tile_size:"):
			slider = values.get_child(index+1)
	slider.value += slider.step
	check(world.tuning.tile_size == slider.value,"F1 slider live")
	values.get_child(0).pressed.emit()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.tuning_path))
	check(saved.tile_size == slider.value,"F1 save file")
	world._command("튜닝 F1")
	world.load_room(0)
	world.player.position = Vector2(400,90)
	world.player.controls._current = {&"move_right":1.0}
	world.player.controls._pressed_edges = {&"dash":true}
	world.motion.tick(1.0/60)
	check(world.player.dash_uses == 1,"first air dash")
	world.player.controls._pressed_edges.clear()
	world.motion.tick(float(world.tuning.dash_duration))
	check(world.player.dash_cooldown == 0,"second dash ready after first")
	world.player.controls._pressed_edges = {&"dash":true}
	world.motion.tick(1.0/60)
	check(world.player.dash_uses == 2,"second air dash")
	world.player.controls._pressed_edges.clear()
	world.motion.tick(float(world.tuning.dash_duration))
	world.player.dash_cooldown = 0
	world.player.controls._pressed_edges = {&"dash":true}
	world.motion.tick(1.0/60)
	check(world.player.dash_uses == 2 and world.player.state != GatePlayer.State.DASH,"third air dash denied")
	world.player.controls._pressed_edges = {&"attack":true}
	world.swing_cooldown = 0
	world._swing(1.0/60)
	check(world.swing_time >= 0 and world.slash_age >= 0 and world.swing_kind != "","attack swings in movement rooms")
	world.player.controls._pressed_edges.clear()
	world.write_log()
	world.write_log()
	var log_path: String = OS.get_environment("MOVEMENT_TEST_LOG")
	check(FileAccess.get_file_as_string(log_path).strip_edges().split("\n").size() == 1,"single session line")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(log_path))
	check(data.bash_count == 2 and data.deaths == 1 and data.f7_reloads == 1,"log counters")
	print("MOVEMENT_TOY_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(failures)
