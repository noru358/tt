extends Node
var world: Node2D
var checks: int = 0
var failures: int = 0
var directions: Array[Vector2] = [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,-1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]
var shift_down: bool = false
var automatic: bool = OS.get_environment("MOVEMENT_AUTO_INPUT") == "1"
func key(code: int, down: bool) -> void:
	if code == KEY_SHIFT: shift_down = down
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	event.shift_pressed = shift_down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func release_all() -> void:
	key(KEY_SHIFT,false)
	for code: int in [KEY_W,KEY_A,KEY_S,KEY_D]: key(code,false)
func direction(value: Vector2) -> void:
	if value.x > 0: key(KEY_D,true)
	if value.x < 0: key(KEY_A,true)
	if value.y < 0: key(KEY_W,true)
	if value.y > 0: key(KEY_S,true)
func tick() -> void:
	await get_tree().physics_frame
	if automatic:
		await get_tree().process_frame
		return
	world.player.controls._physics_process(1.0/60)
	world.motion.tick(1.0/60)
func reset_case() -> void:
	release_all()
	# Synthetic event tests run independently of which desktop window is frontmost.
	world.player.controls._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	world.load_room(0)
	world.player.position = Vector2(600,140)
	await tick()
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+note)
func _ready() -> void:
	world = preload("res://toys/movement/movement_toy.tscn").instantiate()
	add_child(world)
	world.set_physics_process(false)
	if not automatic:
		world.player.set_physics_process(false)
		world.player.controls.set_physics_process(false)
	await get_tree().create_timer(0.5,true,false,true).timeout
	for first: Vector2 in directions:
		for second: Vector2 in directions:
			await reset_case()
			direction(first)
			key(KEY_SHIFT,true)
			await tick()
			check(world.player.state == GatePlayer.State.DASH and world.player.dash_direction.is_equal_approx(first.normalized()),"first input %s" % first)
			release_all()
			direction(second)
			key(KEY_SHIFT,true)
			# A rapid tap can release both direction and Shift before the physics tick.
			release_all()
			await tick()
			check(world.player.dash_uses == 2 and world.player.dash_direction.is_equal_approx(second.normalized()) and world.player.dash_elapsed < 0.03,"immediate %s -> %s" % [first,second])
			direction(Vector2.RIGHT)
			key(KEY_SHIFT,true)
			await tick()
			check(world.player.dash_uses == 2 and world.player.dash_direction.is_equal_approx(second.normalized()),"third press blocked %s -> %s" % [first,second])
	for first: Vector2 in [Vector2.RIGHT,Vector2.LEFT]:
		for second: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2(1,-1),Vector2(-1,-1)]:
			await reset_case()
			world.player.position = Vector2(160,306)
			for i: int in 3: await tick()
			direction(first)
			key(KEY_SHIFT,true)
			await tick()
			release_all()
			direction(second)
			key(KEY_SHIFT,true)
			await tick()
			check(world.player.dash_uses == 2 and world.player.dash_direction.is_equal_approx(second.normalized()),"ground immediate %s -> %s" % [first,second])
	# Reproduce the reported full sequence: floor -> jump -> horizontal dash -> redirect.
	for old_dir: Vector2 in [Vector2.RIGHT,Vector2.LEFT]:
		for new_dir: Vector2 in [-old_dir,Vector2(old_dir.x,-1),Vector2(-old_dir.x,-1)]:
			for late_frames: int in [0,1,2]:
				await reset_case()
				world.player.position = Vector2(160,306)
				for i: int in 3: await tick()
				key(KEY_SPACE,true)
				await tick()
				key(KEY_SPACE,false)
				for i: int in 4: await tick()
				direction(old_dir)
				key(KEY_SHIFT,true)
				await tick()
				key(KEY_SHIFT,false)
				for i: int in 3: await tick()
				key(KEY_SHIFT,true)
				for i: int in late_frames: await tick()
				direction(new_dir)
				if new_dir.x != old_dir.x: key(KEY_D if old_dir.x > 0 else KEY_A,false)
				await tick()
				check(world.player.dash_uses == 2 and world.player.dash_direction.is_equal_approx(new_dir.normalized()),"jump horizontal redirect %s -> %s late=%d" % [old_dir,new_dir,late_frames])
	# Natural overlap: Shift edge can arrive just before the new direction key.
	for old_dir: Vector2 in [Vector2.RIGHT,Vector2.LEFT]:
		for new_dir: Vector2 in [-old_dir,Vector2(old_dir.x,-1)]:
			await reset_case()
			direction(old_dir)
			key(KEY_SHIFT,true)
			await tick()
			key(KEY_SHIFT,false)
			key(KEY_SHIFT,true)
			direction(new_dir)
			if new_dir.x != old_dir.x: key(KEY_D if old_dir.x > 0 else KEY_A,false)
			await tick()
			check(world.player.dash_uses == 2 and world.player.dash_direction.is_equal_approx(new_dir.normalized()),"Shift before new direction with old held %s -> %s" % [old_dir,new_dir])
	await reset_case()
	direction(Vector2.RIGHT)
	key(KEY_SHIFT,true)
	for i: int in 20: await tick()
	check(world.player.dash_uses == 1,"holding Shift never auto-repeats")
	release_all()
	print("IMMEDIATE_DASH_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(failures)
