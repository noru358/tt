# Four full routes plus bounded no-bash bypass searches. This is synthetic
# analog input, not physical controller play or an exhaustive path search.
extends Node
# Scripted input probes: ordinary physics, hazards and damage stay enabled.
var world: Node2D
var frame: int = 0
var trial: int = 0
var results: Array = []
var minimum_y: float = INF
var maximum_x: float = 0
var bash_release: bool = false
var goals: Array[Vector2] = [Vector2(144,144),Vector2(1200,304),Vector2(1552,208),Vector2(368,112)]
func _ready() -> void:
	world = preload("res://toys/movement/movement_toy.tscn").instantiate()
	add_child(world)
	world.player.controls.set_physics_process(false)
	process_physics_priority = -50
	Feedback.invincible = false
	world.load_room(4)
func _physics_process(_delta: float) -> void:
	var room: int = 4+trial%4
	var p: GatePlayer = world.player
	if world.room_index != room or frame >= 1800:
		results.append({"room":room+1,"mode":"no_bash" if trial>=4 else "bash_allowed","goal":world.room_index!=room,"frames":frame,"deaths":world.log_data.deaths,"bash":world.log_data.bash_count,"wall_jumps":world.log_data.wall_jump_count,"min_y":minimum_y,"max_x":maximum_x})
		print("ROOM_SET_TRIAL "+JSON.stringify(results.back()))
		trial += 1
		if trial == 8:
			print("ROOM_SET_RESULT "+JSON.stringify(results))
			var failures: int = 0
			for index: int in 4:
				if not results[index].goal: failures += 1
			print("ROOM_SET_ROUTE_RESULT checks=4 failures=%d (no-bash searches are observations only)" % failures)
			get_tree().quit(failures)
			return
		room = 4+trial%4
		Input.action_release("toy_bash")
		world.load_room(room)
		world.log_data.deaths = 0
		world.log_data.bash_count = 0
		world.log_data.wall_jump_count = 0
		frame = 0
		minimum_y = INF
		maximum_x = 0
	frame += 1
	minimum_y = minf(minimum_y,p.position.y)
	maximum_x = maxf(maximum_x,p.position.x)
	var destination: Vector2 = goals[room-4]
	if room == 4 and p.position.y > 440: destination = Vector2(288,410)
	if room == 7 and p.position.y > 860: destination = Vector2(384,830)
	if room == 7 and p.position.y > 440 and p.position.y <= 860: destination = Vector2(384,400)
	if room == 4 and p.position.y <= 440:
		if p.position.y > 270: destination = Vector2(336,208)
		else: destination = Vector2(72,112)
	if room == 6:
		destination = Vector2(1552,170)
	var direction: Vector2 = (destination-p.position).normalized()
	# Stay near the safe shaft centre; use vertical dashes before touching spike bands.
	if room == 4 and p.position.y > 450 or room == 7 and p.position.y > 860:
		var center_x: float = 288 if room == 4 else 384
		direction = Vector2(signf(center_x-p.position.x) if absf(center_x-p.position.x)>12 else 0,-1).normalized()
		if p.dash_uses >= 2:
			direction.x = -1 if p.position.x < center_x else 1
	if room == 4 and p.position.y < 230:
		# Room 5 goal sits on the ledge at row 4 (moved down one row for the unified movement).
		direction = (Vector2(-1,-1).normalized() if p.position.y > 135 else Vector2.LEFT) if p.position.x > 120 else Vector2(0,1)
	if room == 6:
		direction = Vector2.RIGHT if p.position.y < 165 else Vector2(1,-0.2).normalized()
	var c: PlayerInput = p.controls
	c.device_id = 0 # Exercise the supported vector aim path, not direct launch().
	c._current = {&"move_right":maxf(direction.x,0),&"move_left":maxf(-direction.x,0),&"aim_up":maxf(-direction.y,0),&"aim_down":maxf(direction.y,0)}
	c._pressed_edges.clear()
	c._released_edges.clear()
	c._press_directions.clear()
	if p.is_on_floor() or p.is_on_wall() and frame%8==0 and p.position.y > 440:
		c._pressed_edges[&"jump"] = true
	if (room == 4 or room == 6) and p.state == GatePlayer.State.DASH and p.dash_direction.y < -0.1 and p.position.y < 115 and p.dash_uses < 2:
		c._pressed_edges[&"dash"] = true
		c._press_directions[&"dash"] = Vector2.LEFT if room == 4 else Vector2.RIGHT
	var target: Node2D = world.motion.nearest()
	if trial<4 and is_instance_valid(target) and not bash_release:
		Input.action_press("toy_bash")
		bash_release = true
	elif bash_release:
		if is_instance_valid(world.motion.target): print("BASH_INPUT room=",room+1," position=",p.position," direction=",direction," kind=",world.motion.target.kind)
		Input.action_release("toy_bash")
		bash_release = false
	elif frame > 5 and not p.is_on_floor() and p.state != GatePlayer.State.DASH and p.velocity.y >= -50 and frame%4==0:
		c._pressed_edges[&"dash"] = true
		c._press_directions[&"dash"] = direction
