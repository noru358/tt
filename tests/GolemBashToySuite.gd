# Golem bash toy contract checks. Inputs are injected into PlayerInput like the
# movement probes; physics, hazards and damage stay real unless a check says otherwise.
extends Node
var failures: int = 0
var checks: int = 0
var world: Node2D
var golem: Node2D
var held: Dictionary = {}
var edges: Dictionary = {}

func check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+note)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(world): return
	var c: PlayerInput = world.player.controls
	c.device_id = 0
	c._previous = c._current.duplicate()
	c._current = held.duplicate()
	c._pressed_edges = edges.duplicate()
	c._press_directions.clear()
	for action: StringName in edges: c._press_directions[action] = Vector2(c.horizontal(),c.vertical())
	edges.clear()

func frames(count: int) -> void:
	for i: int in count: await get_tree().physics_frame

func press(action: StringName) -> void:
	edges[action] = true

func bash_release(direction: Vector2) -> void:
	held = {&"move_right":maxf(direction.x,0),&"move_left":maxf(-direction.x,0),&"aim_up":maxf(-direction.y,0),&"aim_down":maxf(direction.y,0)}
	await frames(2)
	Input.action_release("toy_bash")
	await frames(1)
	held = {}

func _ready() -> void:
	process_physics_priority = -50
	for key: String in ["GOLEM_BASH_TEST_TUNING","GOLEM_BASH_TEST_LOG","MOVEMENT_TEST_TUNING"]:
		if OS.get_environment(key).is_empty():
			push_error("Scratch tuning and log paths required: "+key)
			get_tree().quit(1)
			return
	Feedback.invincible = false
	world = preload("res://toys/golem_bash/golem_bash_toy.tscn").instantiate()
	add_child(world)
	golem = world.golem
	await frames(2)
	world.player.controls.set_physics_process(false)
	check(world.player.toy_movement_enabled and world.motion.get_script() == preload("res://toys/movement/ToyMotion.gd"),"reuses movement toy player and motion")
	check(world.tuning.bash_launch_speed == JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("MOVEMENT_TEST_TUNING"))).bash_launch_speed,"reads approved movement tuning")
	check(world.golem_spawn.y == world.floor_y and world.arena_size == Vector2(60,12)*32,"arena B marks golem feet on floor")
	var height: float = world.floor_y-golem.top_y()
	check(height > 150 and height < 200,"golem about five tiles tall (%.0f px)" % height)
	await _reach_without_bash()
	await _slam()
	await _stomp_rock()
	await _sweep_arm()
	await _pogo_and_kneel()
	await _platform_and_shake()
	await _tuning_and_log()
	print("GOLEM_BASH_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(failures)

func _reset(at: Vector2) -> void:
	world.start_round()
	golem.cooldown = INF
	world.player.position = at
	world.player.reset_physics_interpolation()
	await frames(2)

# Condition 1: jump and both air dashes straight up, then swing at the weakpoint.
func _reach_without_bash() -> void:
	await _reset(Vector2(golem.position.x+golem.facing*-60,world.floor_y-14))
	golem.facing = -1 if world.player.position.x < golem.position.x else 1
	var weak: Vector2 = golem.weak_center()
	world.player.position.x = weak.x
	await frames(1)
	press(&"jump")
	held = {&"aim_up":1.0}
	var top: float = INF
	for i: int in 70:
		if i == 12 or i == 28:
			press(&"dash")
		await frames(1)
		top = minf(top,world.player.position.y-world.player.body_size.y/2)
	held = {}
	print("GOLEM_BASH_REACH head_top=%.1f weak_y=%.1f floor=%.1f" % [top,weak.y,world.floor_y])
	check(top < weak.y,"observation: jump+two up dashes can rise above the weakpoint (%.0f < %.0f)" % [top,weak.y])
	check(not golem.weak_open(),"weakpoint closed without a recent bash")
	var hp: float = golem.hp
	check(golem.receive_player_hit(Rect2(weak-Vector2(10,10),Vector2(20,20))) != "weak","closed weakpoint does not take weak hits")
	check(golem.hp > hp-float(world.tuning.weak_hit_damage),"closed weakpoint deals at most body damage")
	world.last_bash_time = world.game_time
	check(golem.weak_open(),"weakpoint opens right after a bash")
	world.last_bash_time = world.game_time-float(world.tuning.weak_open_after_bash)-0.05
	check(not golem.weak_open(),"weakpoint closes after the bash window")

func _slam() -> void:
	await _reset(Vector2(golem.position.x-200,world.floor_y-14))
	golem.facing = -1
	golem.begin_attack("slam")
	var impact: float = golem._impact_time()
	var opened: float = -1
	var closed: float = -1
	while golem.state == "attack":
		var was: bool = golem.hand.open
		await frames(1)
		if golem.hand.open and not was: opened = golem.clock
		if was and not golem.hand.open: closed = golem.clock
		if golem.clock > 5: break
	check(golem.hand.kind == "fist" and opened >= impact-0.02 and opened <= impact+0.04,"fist opens at slam impact (%.2f vs %.2f)" % [opened,impact])
	check(closed-opened >= float(world.tuning.fist_bash_window)-0.04 and closed-opened <= float(world.tuning.fist_bash_window)+0.04,"fist open for fist_bash_window (%.2f)" % (closed-opened))
	# Grab the fist through ToyMotion and launch up-left.
	await _reset(Vector2(golem.position.x-200,world.floor_y-14))
	golem.facing = -1
	golem.begin_attack("slam")
	while not golem.hand.open and golem.clock < 5: await frames(1)
	check(world.floor_y-golem.fist_center().y < 50,"slammed fist rests near the floor (%.0f px up)" % (world.floor_y-golem.fist_center().y))
	world.player.position = golem.fist_center()+Vector2(-40,-20)
	world.player.velocity = Vector2.ZERO
	world.player.hurt_iframe = 5
	Input.action_press("toy_bash")
	await frames(1)
	check(world.motion.target == golem.hand,"ToyMotion grabs the open fist")
	var stagger: float = golem.stagger
	await bash_release(Vector2(-1,-1).normalized())
	check(world.player.velocity.y < 0 and world.player.velocity.x < 0,"fist bash launches player along aim")
	check(golem.stagger >= stagger+float(world.tuning.fist_bash_stagger)-0.01,"fist bash adds stagger")
	check(world.log_data.bash_by_source.fist == 1 and world.log_data.bash_count == 1,"fist bash logged by source")
	check(golem.weak_open(),"bash opens the weakpoint")
	# Auto-aim: grabbing the fist without aim input launches toward the weakpoint.
	await _reset(Vector2(golem.position.x-200,world.floor_y-14))
	golem.facing = -1
	golem.begin_attack("slam")
	while not golem.hand.open and golem.clock < 5: await frames(1)
	world.player.position = golem.fist_center()+Vector2(-40,-20)
	world.player.velocity = Vector2.ZERO
	world.player.hurt_iframe = 5
	Input.action_press("toy_bash")
	await frames(2)
	var to_weak: Vector2 = golem.weak_center()-golem.hand.global_position
	check(world.motion.aim.x*to_weak.x > 0 and world.motion.aim.y < 0 and world.motion.aim != Vector2.UP,"grabbing a golem part pre-aims toward the weakpoint")
	await bash_release(Vector2.ZERO)
	var closest: float = INF
	var above: bool = false
	for i: int in 90:
		await frames(1)
		var gap: Vector2 = world.player.position-golem.weak_center()
		closest = minf(closest,gap.length())
		if absf(gap.x) < float(world.tuning.weak_radius) and gap.y < 0 and gap.y > -90: above = true
	print("GOLEM_BASH_AUTO_AIM closest=%.0f above=%s" % [closest,above])
	check(above,"auto-aimed fist launch passes over the weakpoint for a pogo (closest %.0f px)" % closest)

func _stomp_rock() -> void:
	await _reset(Vector2(golem.position.x-260,world.floor_y-14))
	golem.facing = -1
	golem.begin_attack("stomp")
	while not golem.impacted: await frames(1)
	await frames(1)
	check(golem.rocks.size() == int(world.tuning.rock_count),"stomp throws rock_count rocks")
	check(golem.waves.size() == 2,"stomp sends shockwaves both ways")
	var rock: Node2D = golem.rocks[0]
	check(not rock.open,"rising rock is not bashable")
	while is_instance_valid(rock) and not rock.open: await frames(1)
	check(is_instance_valid(rock) and rock.open,"rock becomes bashable at the top")
	golem.waves.clear()
	var hp: float = golem.hp
	var stagger: float = golem.stagger
	world.player.position = rock.global_position+Vector2(-30,0)
	world.player.velocity = Vector2.ZERO
	world.player.hurt_iframe = 5
	Input.action_press("toy_bash")
	await frames(1)
	check(world.motion.target == rock,"ToyMotion grabs a hovering rock")
	# Player flies away from the golem; the rock flies the opposite way into it.
	var away: Vector2 = Vector2(-1,0) if rock.global_position.x < golem.position.x else Vector2(1,0)
	await bash_release(away)
	check(rock.flying,"bashed rock flies")
	for i: int in 60:
		if not is_instance_valid(rock): break
		await frames(1)
	check(not is_instance_valid(rock),"flying rock is consumed")
	check(golem.hp <= hp-float(world.tuning.rock_damage_to_golem)+0.01,"rock hit damages golem")
	check(golem.stagger >= stagger+float(world.tuning.rock_stagger)-0.01 or golem.state == "kneel","rock hit staggers golem")
	check(world.log_data.rock_hits == 1 and world.log_data.bash_by_source.rock == 1,"rock bash and hit logged")

func _sweep_arm() -> void:
	await _reset(Vector2(golem.position.x-300,world.floor_y-14))
	golem.facing = -1
	golem.begin_attack("sweep")
	var open_time: float = 0
	var first: float = -1
	while golem.state == "attack" and golem.clock < 5:
		await frames(1)
		if golem.hand.open:
			open_time += 1.0/60
			if first < 0: first = golem.clock
	check(golem.hand.kind == "arm" and first >= float(world.tuning.telegraph_time)-0.02,"arm opens only after telegraph")
	var expected: float = maxf(float(world.tuning.arm_bash_window),0.12)+golem.MOVES.sweep.impact-golem.MOVES.sweep.windup
	check(absf(open_time-expected) < 0.05,"arm open for swing + arm_bash_window (%.2f vs %.2f)" % [open_time,expected])
	check(not golem.hand.open and golem.state == "idle","arm closes after sweep")
	# Sweep hurts a player standing in front.
	await _reset(Vector2(golem.position.x-70,world.floor_y-14))
	golem.facing = -1
	var hp: float = world.player.hp
	golem.begin_attack("sweep")
	while golem.clock < golem._impact_time()+0.2: await frames(1)
	check(world.player.hp < hp,"sweep damages player in front")

func _pogo_and_kneel() -> void:
	await _reset(Vector2(golem.position.x-300,world.floor_y-14))
	golem.facing = -1
	await frames(1)
	var weak: Vector2 = golem.weak_center()
	world.last_bash_time = world.game_time
	world.player.position = weak+Vector2(0,-40)
	world.player.velocity = Vector2(0,100)
	await frames(1)
	held = {&"aim_down":1.0}
	press(&"attack")
	await frames(2)
	held = {}
	check(world.log_data.weak_hits == 1,"down attack hits open weakpoint")
	check(world.player.velocity.y < -float(world.tuning.pogo_velocity)*0.8,"pogo bounces player up")
	check(world.player.dash_uses == 0,"pogo refills air dashes")
	check(golem.weak_open(),"pogo keeps weakpoint open")
	for i: int in 40:
		await frames(1)
		if world.player.velocity.y > 0: break
	while world.frozen(): await frames(1)
	world.player.position = golem.weak_center()+Vector2(0,-40)
	world.player.velocity = Vector2(0,100)
	await frames(1)
	world.swing_cooldown = 0
	held = {&"aim_down":1.0}
	press(&"attack")
	await frames(2)
	held = {}
	check(world.log_data.weak_hits == 2,"second pogo hit chains")
	while world.frozen(): await frames(1)
	world.player.position = golem.weak_center()+Vector2(0,-40)
	world.player.velocity = Vector2(0,100)
	await frames(1)
	world.swing_cooldown = 0
	world.last_bash_time = world.game_time
	held = {&"aim_down":1.0}
	press(&"attack")
	await frames(2)
	held = {}
	check(golem.state == "kneel" and world.log_data.kneels == 1,"weak_hits_to_stagger hits make golem kneel")
	await frames(30)
	world.player.position = Vector2(golem.weak_center().x+golem.facing*-30,world.floor_y-14)
	world.player.velocity = Vector2.ZERO
	await frames(2)
	var weak_height: float = world.floor_y-golem.weak_center().y
	var reach: float = world.player.body_size.y+float(world.tuning.attack_reach)+float(world.tuning.weak_radius)
	check(weak_height < reach,"kneel lowers weakpoint into ground up-attack reach (%.0f < %.0f)" % [weak_height,reach])
	world.player.position.x = golem.weak_center().x
	world.last_bash_time = -INF
	world.swing_cooldown = 0
	var hp: float = golem.hp
	held = {&"aim_up":1.0}
	press(&"attack")
	await frames(2)
	held = {}
	check(golem.hp <= hp-float(world.tuning.weak_hit_damage)+0.01,"ground up-attack hits weakpoint during kneel without a bash")
	var wait: int = int((float(world.tuning.kneel_duration)+0.6)*60)
	await frames(wait)
	check(golem.state == "idle" and golem.kneel_amount == 0 and golem.weak_hits == 0,"golem recovers from kneel")

func _platform_and_shake() -> void:
	await _reset(Vector2(golem.position.x-300,world.floor_y-14))
	golem.facing = -1
	await frames(2)
	world.player.position = Vector2(golem.platform.global_position.x,golem.top_y()-30)
	world.player.velocity = Vector2.ZERO
	world.player.hurt_iframe = 0
	var hp: float = world.player.hp
	await frames(20)
	check(world.player.is_on_floor() and golem.on_platform(),"player can stand on golem's shoulders")
	check(world.player.hp == hp,"standing on top is not contact damage")
	await frames(int(float(world.tuning.shake_off_time)*60)+10)
	check(not golem.on_platform() or world.player.velocity.y < 0,"golem shakes the rider off after shake_off_time")

func _tuning_and_log() -> void:
	world.tuning.golem_walk_speed = 120.0
	await _reset(Vector2(80,world.floor_y-14))
	golem.cooldown = INF
	var x: float = golem.position.x
	await frames(int(float(world.tuning.golem_step_time)*2*60)+2)
	check(absf(golem.position.x-x-golem.facing*120.0*float(world.tuning.golem_step_time)*2) < 4,"tuning change applies immediately (two strides)")
	check(world.save_tuning(),"tuning saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOLEM_BASH_TEST_TUNING")))
	check(saved.golem_walk_speed == 120 and not saved.has("bash_launch_speed"),"only golem numbers saved to golem file")
	var log_path: String = OS.get_environment("GOLEM_BASH_TEST_LOG")
	var before: int = _lines(log_path)
	golem.take_damage(INF)
	check(world.round_over and world.result_panel.visible,"golem death shows result with retry")
	check(_lines(log_path) == before,"round line waits for retry timing")
	await frames(3)
	world.start_round()
	check(_lines(log_path) == before+1,"retry writes one line")
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(log_path).strip_edges().split("\n")[-1])
	check(entry.result == "win" and entry.retry_within_sec != null and float(entry.retry_within_sec) >= 0,"line has result and retry_within_sec")
	for key: String in ["started_at","duration_sec","deaths_before","bash_count","bash_by_source","weak_hits","kneels"]: check(entry.has(key),"log field "+key)
	world.player.hurt_iframe = 0
	world.hurt_player(1000,0)
	check(world.round_over and world.deaths_total == 1,"player death ends round")
	world.write_quit_log()
	entry = JSON.parse_string(FileAccess.get_file_as_string(log_path).strip_edges().split("\n")[-1])
	check(_lines(log_path) == before+2 and entry.result == "death" and entry.retry_within_sec == null,"quit after death writes once without retry")
	world.write_quit_log()
	check(_lines(log_path) == before+2,"no duplicate lines")

func _lines(path: String) -> int:
	if not FileAccess.file_exists(path): return 0
	var text: String = FileAccess.get_file_as_string(path).strip_edges()
	return 0 if text.is_empty() else text.split("\n").size()
