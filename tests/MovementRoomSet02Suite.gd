extends Node
var world: Node2D
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func _ready() -> void:
	world = preload("res://toys/movement/movement_toy.tscn").instantiate()
	add_child(world)
	world.player.controls.set_physics_process(false)
	Feedback.invincible = false
	for index: int in range(4,8):
		world.load_room(index)
		await get_tree().physics_frame
		var lines: PackedStringArray = FileAccess.get_file_as_string(world.room_directory+"/"+world.rooms[index]).strip_edges().split("\n")
		var valid: bool = true
		var starts: int = 0
		var goals: int = 0
		for row: String in lines:
			for col: int in row.length():
				var c: String = row[col]
				if c == "P": starts += 1
				if c == "G": goals += 1
				if c == "T": valid = valid and col+1 < row.length() and row[col+1] in "<>AV"
				elif c in "<>AV": valid = valid and col>0 and row[col-1]=="T"
				else: valid = valid and c in "#=.P^omG "
		check(valid,"valid map tokens room %d" % (index+1))
		# A goal may span stacked cells (room 5 uses a two-tile goal so a flying pass still counts).
		check(starts==1 and goals>=1,"one spawn and a goal room %d" % (index+1))
	# Local geometry checks use explicit setup positions; they are not full routes.
	for at: Vector2 in [Vector2(80,208),Vector2(464,182)]:
		world.load_room(6)
		world.player.position = at
		world.player.controls._current = {}
		world.player.controls._pressed_edges.clear()
		for frame: int in 8: await get_tree().physics_frame
		check(world.player.is_on_floor(),"jump setup on floor/platform")
		world.player.controls._pressed_edges[&"jump"] = true
		await get_tree().physics_frame
		world.player.controls._pressed_edges.clear()
		var top: float = world.player.position.y
		var deaths: int = world.log_data.deaths
		for frame: int in 65:
			await get_tree().physics_frame
			top = minf(top,world.player.position.y)
		print("ROOM7_JUMP start=",at," apex_center_y=",top," clearance=",top-14-64)
		check(world.log_data.deaths==deaths and top-14>64,"ordinary jump clears ceiling")
	world.load_room(4)
	await get_tree().physics_frame
	world.player.position = Vector2(336,152)
	world.player.velocity = Vector2.ZERO
	world.player.controls.device_id = 0
	world.player.controls._current = {&"aim_up":1.0}
	world.player.controls._pressed_edges.clear()
	await get_tree().physics_frame
	Input.action_press("toy_bash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(is_instance_valid(world.motion.target),"top orb legally captured within radius")
	Input.action_release("toy_bash")
	var deaths: int = world.log_data.deaths
	for frame: int in 80: await get_tree().physics_frame
	check(world.log_data.deaths>deaths,"vertical bash hits room5 ceiling spikes from upper capture point")
	world.load_room(4)
	await get_tree().physics_frame
	world.player.position = Vector2(336,148)
	world.player.velocity = Vector2.ZERO
	world.player.controls._current = {&"move_left":1.0,&"aim_up":1.0}
	await get_tree().physics_frame
	Input.action_press("toy_bash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("toy_bash")
	deaths = world.log_data.deaths
	for frame: int in 18: await get_tree().physics_frame
	world.player.controls._current = {&"move_left":1.0}
	world.player.controls._pressed_edges[&"dash"] = true
	world.player.controls._press_directions[&"dash"] = Vector2.LEFT
	await get_tree().physics_frame
	world.player.controls._pressed_edges.clear()
	for frame: int in 25: await get_tree().physics_frame
	check(world.room_index==5 and world.log_data.deaths==deaths,"diagonal bash plus horizontal dash reaches room5 goal ledge")
	print("ROOM_SET_LOCAL_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(failures)
