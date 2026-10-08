extends "res://tests/PlayerSuite.gd"
var boss: Node2D
var selected: Dictionary = {}

func retry_and_wait(use_pad: bool) -> void:
	while not arena.result_screen.input_ready: await frames(1)
	var old_id: int = arena.get_instance_id()
	var wall_start: int = Time.get_ticks_msec()
	if use_pad: pad(JOY_BUTTON_A,true)
	else: key(KEY_R,true)
	await frames(2)
	if use_pad: pad(JOY_BUTTON_A,false)
	else: key(KEY_R,false)
	arena = get_tree().current_scene
	check(arena.get_instance_id() != old_id,"one-button scene restart: "+("pad A" if use_pad else "R"))
	player = arena.player
	boss = arena.boss
	var ticks: int = 2
	while not boss.enabled and ticks < 70:
		await frames(1)
		ticks += 1
	check(boss.enabled and ticks/60.0 < 1.0,"retry begins combat under one simulated second")
	print("RETRY_WALL_MS ",Time.get_ticks_msec()-wall_start)
	check(player.hp == player.p("max_hp") and boss.hp == boss.data["max_hp"],"retry resets both HP pools")

func _run() -> void:
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_golem.json"))
	DataRegistry.documents["bosses/golem.json"] = legacy
	DataRegistry._indexes["bosses"]["golem"] = legacy
	print("LEGACY_PRIMITIVE_FIXTURE: old shape boss; cutout gameplay is tested by GolemCutoutSuite")
	Feedback.invincible = true
	arena = load("res://scenes/arena/BattleArena.tscn").instantiate()
	get_tree().root.add_child.call_deferred(arena)
	await frames(2)
	get_tree().current_scene = arena
	player = arena.player
	boss = arena.boss
	await frames(55)
	boss.rng.seed = 20261007
	player.controls._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	# Exercise natural selection across both phases, including entry pattern.
	boss.pattern_started.connect(func(id: String) -> void: selected[id] = true)
	player.set_physics_process(false)
	for phase: int in 2:
		if phase == 1: boss.hp = 400
		for tick: int in (0 if "--retry-only" in OS.get_cmdline_user_args() else 3600):
			player.position = Vector2(clampf(boss.position.x-boss.facing*240,160,1760),912)
			await frames(1)
	if "--retry-only" not in OS.get_cmdline_user_args(): check(selected.has_all(["slam","charge","rock_drop","punch","roar","double_slam"]),"natural weighted selector reaches all six golem patterns")
	print("NATURAL_PATTERNS ",selected.keys())
	boss.set_physics_process(false)
	boss.interrupt()
	boss.hp = 900
	boss.phase_index = 0
	boss.speed_mult = 1
	boss.stagger = 0
	boss.stagger_time = 0
	await frames(2)
	# Actual hitbox collision into player, then actual parry back to boss.
	player.set_physics_process(true)
	await reset_player(900,912)
	player.controls._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	Feedback.invincible = false
	boss.position = Vector2(1150,810)
	boss.facing = -1
	var punch: Dictionary = boss.data["patterns"]["punch"]["steps"][2]
	boss.make_hitbox(punch,0.14,true)
	await frames(2)
	check(player.hp == player.p("max_hp")-18,"real boss hitbox damages player once")
	await frames(8)
	check(player.hp == player.p("max_hp")-18,"same swing cannot hit twice")
	Feedback.clear_transients()
	await reset_player(900,912)
	player.controls._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	key(KEY_K,true)
	await frames(1)
	key(KEY_K,false)
	boss.make_hitbox(punch,0.14,true)
	await frames(1)
	check(player.hp == player.p("max_hp") and boss.stagger == 25,"real parry collision prevents damage and adds boss stagger")
	Feedback.clear_transients()
	await frames(20)
	boss.interrupt()
	await frames(2)
	# Slow-motion timing: telegraph must retain full scaled duration.
	Feedback.invincible = true
	Feedback.set_speed(0.25)
	boss.start_pattern("punch")
	var elapsed_ticks: int = 0
	while elapsed_ticks < 80:
		boss.runner.tick(0.25/60)
		await frames(1)
		elapsed_ticks += 1
	check(boss.runner.current != null and boss.runner.current.data["type"] == "telegraph","0.25 speed keeps 0.35-second warning active for over 1.3 real seconds")
	for tick: int in 7:
		boss.runner.tick(0.25/60)
		await frames(1)
	check(boss.runner.current != null and boss.runner.current.data["type"] == "hitbox","slow-motion warning transitions into matching active hitbox")
	await snapshot("step2_slow_hitbox")
	Feedback.set_speed(1)
	boss.interrupt()
	# Pause panel blocks actions and provides abandon/resume without F keys.
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await get_tree().process_frame
	check(get_tree().paused and arena.debug_panel.is_open and player.controls.blocked,"Esc opens paused tuning and blocks input")
	arena.debug_panel.toggle()
	await frames(2)
	check(not get_tree().paused and not player.controls.blocked,"resume restores play")
	# Real death signals result; input retry includes the intro in its time budget.
	player.hp = 1
	player.hurt_iframe = 0
	player.since_dash = INF
	Feedback.invincible = false
	var fatal: CombatHitbox = CombatHitbox.new()
	fatal.damage = 10
	player.receive_hit(fatal)
	fatal.free()
	await frames(2)
	check(arena.ended and arena.result_screen.visible and player.state == GatePlayer.State.DEAD,"death opens result screen")
	await snapshot("step2_death")
	await retry_and_wait(false)
	arena.finish(false)
	await frames(2)
	await retry_and_wait(true)
	# Victory is triggered by boss damage, not UI-only direct finish.
	boss.hp = 1
	boss.vulnerable = true
	var victory: CombatHitbox = CombatHitbox.new()
	victory.damage = 10
	boss.receive_hit(victory)
	victory.free()
	await frames(2)
	check(arena.ended and boss.hp == 0 and arena.result_screen.heading.text == "골렘 격파","boss death opens victory result")
	await snapshot("step2_actual_victory")
	arena.to_training()
	await frames(3)
	check(get_tree().current_scene.scene_file_path.ends_with("/Arena.tscn"),"abandon/result return to working training scene")
	print("BATTLE_FLOW_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
