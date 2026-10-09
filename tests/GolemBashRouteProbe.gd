# Scripted bot tries to beat the golem with invincibility OFF. Synthetic analog input,
# not human play: it reports how far a simple bash/pogo routine gets, round by round.
extends Node
var world: Node2D
var golem: Node2D
var held: Dictionary = {}
var edges: Dictionary = {}
var grab_frames: int = 0
var rounds: Array = []
var round_frames: int = 0
const MAX_ROUNDS: int = 5
const ROUND_FRAMES: int = 60*120

func _ready() -> void:
	process_physics_priority = -50
	Feedback.invincible = OS.get_environment("GOLEM_BASH_ROUTE_INVINCIBLE") == "1"
	world = preload("res://toys/golem_bash/golem_bash_toy.tscn").instantiate()
	add_child(world)
	golem = world.golem
	golem.rng.seed = 7
	await get_tree().physics_frame
	world.player.controls.set_physics_process(false)

func _apply() -> void:
	var c: PlayerInput = world.player.controls
	c.device_id = 0
	c._previous = c._current.duplicate()
	c._current = held.duplicate()
	c._pressed_edges = edges.duplicate()
	c._press_directions.clear()
	for action: StringName in edges: c._press_directions[action] = Vector2(c.horizontal(),c.vertical())
	edges.clear()

func steer(direction: Vector2) -> void:
	held = {&"move_right":maxf(direction.x,0),&"move_left":maxf(-direction.x,0),&"aim_up":maxf(-direction.y,0),&"aim_down":maxf(direction.y,0)}

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(world) or world.player.controls.is_physics_processing(): return
	if world.round_over:
		var entry: Dictionary = world.pending_log.duplicate()
		entry.game_seconds = round_frames/60.0
		entry.golem_hp_left = golem.hp
		rounds.append(entry)
		print("GOLEM_BASH_ROUND "+JSON.stringify(rounds.back()))
		if rounds.back().result == "win" or rounds.size() >= MAX_ROUNDS:
			_finish()
			return
		world.start_round()
		round_frames = 0
		return
	round_frames += 1
	if round_frames > ROUND_FRAMES:
		world.round_end("timeout")
		return
	_think()
	_apply()

func _think() -> void:
	var p: GatePlayer = world.player
	var motion: Node = world.motion
	var weak: Vector2 = golem.weak_center()
	held = {}
	if is_instance_valid(motion.target):
		# Launch toward a point just above the weakpoint so the fall lands a pogo.
		grab_frames += 1
		steer((weak+Vector2(0,-60)-motion.target.global_position).normalized())
		if grab_frames >= 3:
			Input.action_release("toy_bash")
			grab_frames = 0
		return
	Input.action_release("toy_bash")
	var target: Node2D = motion.nearest()
	if is_instance_valid(target) and target.has_method("set_open"):
		Input.action_press("toy_bash")
		grab_frames = 0
		return
	var to_weak: Vector2 = weak-p.position
	if golem.weak_open() and absf(to_weak.x) < 26 and to_weak.y > 0 and to_weak.y < 90:
		steer(Vector2.DOWN)
		if world.swing_cooldown <= 0: edges[&"attack"] = true
		return
	if golem.weak_open() and to_weak.y < 0:
		# Above-and-beside: drift over the weakpoint while falling.
		steer(Vector2(signf(to_weak.x) if absf(to_weak.x) > 8 else 0,0))
		if golem.state == "kneel" and absf(to_weak.x) < 30 and p.is_on_floor() and world.swing_cooldown <= 0:
			steer(Vector2.UP)
			edges[&"attack"] = true
		return
	# Wait for a springboard at a safe distance; chase open fists and falling rocks.
	var goal: Vector2 = Vector2(golem.position.x-golem.facing*-1*150,p.position.y)
	goal.x = golem.position.x+(150 if p.position.x > golem.position.x else -150)
	for node: Node in get_tree().get_nodes_in_group("toy_bashable"):
		goal = node.global_position
		break
	var dx: float = goal.x-p.position.x
	steer(Vector2(signf(dx) if absf(dx) > 10 else 0,0))
	for wave: Dictionary in golem.waves:
		if absf(wave.x-p.position.x) < 90 and signf(p.position.x-wave.x) == wave.dir and p.is_on_floor(): edges[&"jump"] = true
	if goal.y < p.position.y-60 and p.is_on_floor(): edges[&"jump"] = true
	if goal.y < p.position.y-90 and not p.is_on_floor() and p.velocity.y > -50 and p.dash_uses < 2:
		edges[&"dash"] = true
		steer((goal-p.position).normalized())

func _finish() -> void:
	var wins: int = 0
	for entry: Dictionary in rounds: if entry.result == "win": wins += 1
	print("GOLEM_BASH_ROUTE_RESULT rounds=%d wins=%d invincible=%s (synthetic bot)" % [rounds.size(),wins,Feedback.invincible])
	get_tree().quit(0)
