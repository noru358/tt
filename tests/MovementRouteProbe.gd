extends Node
var world: Node2D
var frame: int = 0
var previous_jump: bool = false
var previous_dash: bool = false
var visited: Dictionary = {}
var route_results: Array = []
var probe_room: int = 0
var max_x: float = 0
var min_y: float = INF
func _ready() -> void:
	world = preload("res://toys/movement/movement_toy.tscn").instantiate()
	add_child(world)
	world.player.controls.set_physics_process(false)
	process_physics_priority = -50
	world.load_room(probe_room)
func _physics_process(_delta: float) -> void:
	var p: GatePlayer = world.player
	if world.room_index != probe_room or frame >= 900:
		route_results.append({"room":probe_room+1,"goal_reached":world.room_index != probe_room,"deaths":world.log_data.deaths,"max_x":max_x,"min_y":min_y})
		probe_room += 1
		if probe_room >= 4:
			print("MOVEMENT_ROUTES "+JSON.stringify(route_results))
			get_tree().quit()
			return
		world.load_room(probe_room)
		world.log_data.deaths = 0
		visited.clear()
		frame = 0
		max_x = 0
		min_y = INF
	frame += 1
	max_x = maxf(max_x,p.position.x)
	min_y = minf(min_y,p.position.y)
	var destination: Vector2 = Vector2(world.room_size.x-48,world.room_size.y-80)
	if probe_room == 1: destination = Vector2(256,48)
	var candidate: Node2D
	var best: float = INF
	for orb: Node in get_tree().get_nodes_in_group("toy_bashable"):
		if orb.kind == "bullet" or visited.has(orb.get_instance_id()): continue
		var distance: float = p.position.distance_to(orb.position)
		if distance < best:
			best = distance
			candidate = orb
	if candidate: destination = candidate.position
	var direction: Vector2 = (destination-p.position).normalized()
	var jump: bool = p.is_on_floor() and (absf(destination.x-p.position.x)<450 or probe_room==2)
	var dash: bool = not p.is_on_floor() and p.state != GatePlayer.State.DASH and p.dash_uses == 0 and p.velocity.y < 0 and frame%8==0
	var controls: PlayerInput = p.controls
	controls._current = {&"move_right":maxf(direction.x,0),&"move_left":maxf(-direction.x,0),&"aim_up":maxf(-direction.y,0),&"aim_down":maxf(direction.y,0)}
	controls._pressed_edges.clear()
	controls._released_edges.clear()
	if jump and not previous_jump: controls._pressed_edges[&"jump"] = true
	if dash and not previous_dash: controls._pressed_edges[&"dash"] = true
	previous_jump = jump
	previous_dash = dash
	if candidate and best < float(world.tuning.bash_radius):
		# Exercise the same launch path once legally in range; aim is scripted, not a human playtest.
		world.motion.target = candidate
		world.motion.aim = Vector2(1,-0.35).normalized() if probe_room != 1 else Vector2(-0.3,-1).normalized()
		if probe_room == 1:
			var next_point: Vector2 = Vector2(256,48)
			var next_distance: float = INF
			for orb: Node in get_tree().get_nodes_in_group("toy_bashable"):
				if orb == candidate or visited.has(orb.get_instance_id()) or orb.position.y >= candidate.position.y: continue
				var distance: float = candidate.position.distance_to(orb.position)
				if distance < next_distance:
					next_distance = distance
					next_point = orb.position
			world.motion.aim = (next_point-p.position).normalized()
		world.motion.launch()
		visited[candidate.get_instance_id()] = true
