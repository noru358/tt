# A deliberately simple player walks the journey route: hold right, jump at
# ledges and walls, dash over open gaps, bash any orb ahead toward up-right.
# Hazards and damage stay on. If this bot finishes, the main path is light.
# Second trial forbids bashing (observation only: shows which gaps need it).
# Synthetic input, not human feel.
extends Node
var world: Node2D
var grid: PackedStringArray = []
var frame: int = 0
var trial: int = 0
var bash_hold: int = 0
var results: Array = []
const LIMIT: int = 60*240

func _ready() -> void:
	process_physics_priority = -50
	Feedback.invincible = false
	_start()

func _start() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.free()
	world = preload("res://toys/journey/journey_toy.tscn").instantiate()
	add_child(world)
	world.player.controls.set_physics_process(false)
	grid = FileAccess.get_file_as_string(world.room_directory+"/"+world.rooms[0]).strip_edges(false,true).split("\n")
	frame = 0
	bash_hold = 0

func solid(col: int, row: int) -> bool:
	if row < 0 or row >= grid.size() or col < 0: return false
	var line: String = grid[row].trim_suffix("\r")
	return col < line.length() and line[col] in "#="

func _physics_process(_delta: float) -> void:
	var p: GatePlayer = world.player
	frame += 1
	if world.finished or frame >= LIMIT:
		var result: Dictionary = {"mode":"bash_allowed" if trial == 0 else "no_bash","finished":world.finished,"seconds":frame/60.0,"falls":world.log_data.deaths,"bash":world.log_data.bash_count,"reached":world.regions[world.region_index].name,"max_x_tile":int(p.position.x/32)}
		results.append(result)
		print("JOURNEY_TRIAL "+JSON.stringify(result))
		Input.action_release("toy_bash")
		trial += 1
		if trial == 2:
			var failures: int = 0 if results[0].finished else 1
			print("JOURNEY_ROUTE_RESULT checks=1 failures=%d (no-bash trial is an observation)" % failures)
			get_tree().quit(failures)
			return
		_start()
		return
	var tile: float = 32
	var col: int = int(p.position.x/tile)
	var feet_row: int = int((p.position.y+p.body_size.y/2+2)/tile)
	var ahead: int = int((p.position.x+p.body_size.x/2+10)/tile)
	var c: PlayerInput = p.controls
	c.device_id = 0
	var direction: Vector2 = Vector2.RIGHT
	c._pressed_edges.clear()
	c._released_edges.clear()
	c._press_directions.clear()
	if p.is_on_floor():
		var ledge: bool = not solid(ahead,feet_row) and not solid(ahead,feet_row+1)
		var wall: bool = solid(ahead,feet_row-1) or solid(ahead,feet_row-2)
		if ledge or wall: c._pressed_edges[&"jump"] = true
	elif p.state != GatePlayer.State.DASH and p.velocity.y > 0:
		# Falling with no ground under or just ahead: spend a dash forward and up.
		var ground_near: bool = false
		for dc: int in range(0,4):
			for dr: int in range(0,5):
				if solid(col+dc,feet_row+dr): ground_near = true
		if not ground_near and p.dash_uses < int(world.tuning.air_dash_count):
			c._pressed_edges[&"dash"] = true
			c._press_directions[&"dash"] = Vector2(1,-1).normalized() if p.dash_uses == 0 else Vector2.RIGHT
	if trial == 0:
		var target: Node2D = world.motion.nearest()
		if bash_hold > 0:
			bash_hold -= 1
			direction = Vector2(1,-1).normalized()
			if bash_hold == 0: Input.action_release("toy_bash")
		elif is_instance_valid(target) and not p.is_on_floor() and target.position.x > p.position.x-8:
			Input.action_press("toy_bash")
			bash_hold = 3
	c._current = {&"move_right":maxf(direction.x,0),&"move_left":maxf(-direction.x,0),&"aim_up":maxf(-direction.y,0),&"aim_down":maxf(direction.y,0)}
