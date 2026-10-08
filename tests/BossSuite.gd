extends "res://tests/PlayerSuite.gd"
var boss: Node2D
var started: Array[String] = []
var captured: Dictionary = {}

func run_pattern(id: String) -> void:
	boss.interrupt()
	await frames(2)
	boss.position = Vector2(1200,810)
	boss.velocity = Vector2.ZERO
	player.position = Vector2(850,912)
	boss.start_pattern(id)
	var ticks: int = 0
	while boss.runner.running and ticks < 1800:
		boss.runner.tick(1.0/60)
		ticks += 1
		await frames(1)
		var kind: String = boss.runner.current.data["type"] if boss.runner.current != null else ""
		if kind in ["telegraph","hitbox","dash","falling","jump"] and not captured.has(id+kind):
			captured[id+kind] = true
			await snapshot("step2_"+id+"_"+kind)
	check(not boss.runner.running,"pattern finishes: "+id)

func _run() -> void:
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_golem.json"))
	DataRegistry.documents["bosses/golem.json"] = legacy
	DataRegistry._indexes["bosses"]["golem"] = legacy
	print("LEGACY_PRIMITIVE_FIXTURE: old shape boss; cutout gameplay is tested by GolemCutoutSuite")
	check(DataRegistry.is_valid,"Step 2 complete data is valid")
	Feedback.invincible = true
	arena = load("res://scenes/arena/BattleArena.tscn").instantiate()
	add_child(arena)
	player = arena.player
	boss = arena.boss
	check(not boss.enabled and player.controls.blocked,"intro blocks boss and player")
	await frames(50)
	check(boss.enabled and not player.controls.blocked,"0.8 second intro ends")
	boss.set_physics_process(false)
	boss.interrupt()
	await reset_player()
	# Synthetic input tests explicitly inject focus, just as they inject key events.
	player.controls._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	Feedback.invincible = true
	# Reproduce front -> up while J stays held, including an early direction change.
	key(KEY_J,true)
	await frames(2)
	key(KEY_W,true)
	await frames(9)
	check(player.state == GatePlayer.State.ATTACK and player.attack_kind == "up_attack","held front -> up chains at active end, without recovery gap")
	key(KEY_W,false)
	await frames(13)
	check(player.state == GatePlayer.State.ATTACK and player.attack_kind == "combo","held up -> front also chains")
	key(KEY_J,false)
	await frames(40)
	check(player.state != GatePlayer.State.ATTACK,"release does not leave automatic follow-up")
	await reset_player()
	key(KEY_J,true)
	await frames(2)
	key(KEY_W,true)
	key(KEY_J,false)
	await frames(30)
	check(not player.attack_running and player.combo_index == 0,"startup may re-aim once, but release cannot enqueue another attack")
	await reset_player()
	key(KEY_J,true)
	await frames(12)
	key(KEY_J,false)
	await frames(1)
	key(KEY_W,true)
	key(KEY_J,true)
	await frames(1)
	check(player.attack_kind == "combo","new direction respects minimum chain_at recovery")
	await frames(4)
	check(player.attack_kind == "up_attack" and player.action_clock < 0.1,"new direction chains after chain_at")
	await reset_player(850,350)
	var gravity: float = player.p("gravity")
	Tuning.player["gravity"] = 0
	player.velocity = Vector2.ZERO
	key(KEY_J,true)
	await frames(2)
	key(KEY_W,true)
	await frames(11)
	check(player.attack_kind == "up_attack","air front -> up chains")
	key(KEY_S,true)
	await frames(13)
	check(player.attack_kind == "down_attack","latest vertical direction wins and chains up -> down in air")
	Tuning.player["gravity"] = gravity
	await reset_player()
	pad(JOY_BUTTON_X,true)
	await frames(2)
	pad(JOY_BUTTON_DPAD_UP,true)
	await frames(10)
	check(player.attack_kind == "up_attack","pad X + D-pad up uses the same directional chain contract")
	pad(JOY_BUTTON_DPAD_UP,false)
	pad(JOY_BUTTON_X,false)
	await reset_player()
	Tuning.set_value("player","attack_direction_chain",false)
	key(KEY_J,true)
	await frames(2)
	key(KEY_W,true)
	await frames(12)
	check(player.attack_kind == "combo","direction chaining can be disabled from tuning")
	check(arena.debug_panel.controls.has("player/attack_direction_chain"),"new attack policy is exposed in the panel")
	Tuning.set_value("player","attack_direction_chain",true)
	await reset_player(850,912)
	player.controls.set_blocked(true)
	player.set_physics_process(false)
	Feedback.invincible = true
	Feedback.boxes_visible = true
	for id: String in boss.data["patterns"]: await run_pattern(id)
	check(boss.runner.history.count("jump") == 1,"repeat inserts opposite-side jump exactly once between two slams")
	# Telegraph and attack share world bounds and never overlap in lifetime.
	boss.interrupt()
	await frames(2)
	boss.position = Vector2(1200,810)
	boss.facing = -1
	boss.start_pattern("punch")
	boss.runner.tick(1.0/60)
	var mark: Node2D = boss.runner.current.nodes[0]
	var warning_bounds: Rect2 = Rect2(mark.global_position-mark.box_size/2,mark.box_size)
	check(get_tree().get_nodes_in_group("hitboxes").is_empty(),"telegraph does not deal damage")
	for index: int in 21:
		boss.runner.tick(1.0/60)
		await frames(1)
	if boss.runner.current == null: boss.runner.tick(1.0/60)
	var box: CombatHitbox = boss.runner.current.nodes[0]
	check(warning_bounds == Rect2(box.global_position-box.box_size/2,box.box_size),"punch warning and hitbox align exactly")
	check(get_tree().get_nodes_in_group("telegraphs").is_empty(),"warning is removed when attack activates")
	boss.interrupt()
	await frames(2)
	# Selection respects distance/cooldown, excludes only when alternatives exist.
	boss.phase_index = 0
	boss.cooldowns.clear()
	boss.position = Vector2(1400,810)
	player.position = Vector2(300,912)
	boss.last_pattern = "slam"
	var eligible: Array[String] = boss.eligible_patterns()
	check("punch" not in eligible and "slam" not in eligible,"range filter and previous-pattern exclusion")
	boss.cooldowns = {"charge":99,"rock_drop":99,"punch":99}
	check(boss.choose_pattern() == "slam","single candidate may repeat")
	boss.cooldowns["slam"] = 99
	check(boss.choose_pattern().is_empty(),"no eligible pattern yields wait")
	boss.retry = 0
	boss._physics_process(1.0/60)
	check(is_equal_approx(boss.retry,float(boss.rules["selection_retry"])),"empty selection retries after data-driven 0.3 seconds")
	# Phase change aborts hazards and queues roar once.
	boss.cooldowns.clear()
	boss.start_pattern("rock_drop")
	boss.runner.tick(1.0/60)
	boss.hp = 450
	boss._update_phase()
	await frames(2)
	check(boss.phase_index == 1 and boss.speed_mult == 1.2 and boss.pending_enter == "roar","half HP transitions to phase 2 with roar")
	check(get_tree().get_nodes_in_group("telegraphs").is_empty(),"phase transition clears old warning")
	boss._physics_process(1.0/60)
	check(boss.pattern_id == "roar" and boss.pending_enter.is_empty(),"phase entry runs once")
	boss.runner.tick(1.0/60)
	check(not boss.vulnerable,"roar invulnerability applies")
	var strike: CombatHitbox = CombatHitbox.new()
	strike.damage = 25
	var before: float = boss.hp
	check(boss.receive_hit(strike) == "ignored" and boss.hp == before,"invulnerable boss ignores damage")
	boss.interrupt()
	for index: int in 4: boss.on_parried()
	check(boss.stagger_time == 2 and not boss.runner.running and boss.vulnerable,"four parries interrupt pattern into stagger")
	boss.receive_hit(strike)
	check(is_equal_approx(before-boss.hp,31.25),"stagger amplifies damage by 1.25")
	boss.stagger_time = 0
	boss.stagger = 0
	boss.receive_hit(strike)
	check(boss.stagger == 18,"heavy hit builds stagger")
	strike.free()
	# All remaining primitives through the same runner, using existing wing data.
	boss.interrupt()
	boss.speed_mult = 1
	var wing: Dictionary = DataRegistry.get_boss("wing")
	var fan: Dictionary = wing["patterns"]["fan_shot"]["steps"][3]
	boss.runner.start([fan,{"type":"wait","duration":0.1}])
	boss.runner.tick(1.0/60)
	var shots: Array[Node] = get_tree().get_nodes_in_group("hitboxes")
	check(shots.size() == 5,"generic projectile emits fan count")
	var parryable: int = 0
	for node: Node in shots:
		if node.parriable: parryable += 1
	check(parryable == 1,"only declared projectile indices can be parried")
	var reflected: CombatProjectile = shots[2]
	reflected.reflect_damage = 80
	reflected.reflect_stagger = 80
	reflected.reflect(player)
	boss.vulnerable = true
	boss.stagger_time = 0
	boss.stagger = 0
	before = boss.hp
	boss.receive_hit(reflected)
	check(before-boss.hp == 80 and boss.stagger == 80,"reflected projectile applies configured damage and stagger")
	boss.interrupt()
	await frames(2)
	# Reorder a JSON file in scratch; runner receives parsed data, never changed code.
	var modified: Dictionary = DataRegistry.get_boss("golem")
	var original: Array = modified["patterns"]["punch"]["steps"]
	var last: Variant = original.pop_back()
	original.push_front(last)
	var path: String = OS.get_environment("GATE1_TEST_REORDER")
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(modified))
	file.close()
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	boss.runner.history.clear()
	boss.runner.start(parsed["patterns"]["punch"]["steps"])
	boss.runner.tick(1.0/60)
	check(boss.runner.history[0] == "wait" and boss.runner.current.data["type"] == "wait","JSON reordered punch begins with wait without code changes")
	print("JSON_ORDER_PROOF ",path," first=",boss.runner.history[0])
	# Visual captures are real viewport pixels in GPU runs.
	boss.interrupt()
	boss.hp = 900
	boss.phase_index = 0
	boss.speed_mult = 1
	boss.position = Vector2(1200,810)
	player.position = Vector2(850,912)
	Feedback.set_speed(0.25)
	boss.start_pattern("punch")
	boss.runner.tick(1.0/60)
	await frames(2)
	await snapshot("step2_slow_warning")
	Feedback.set_speed(1)
	boss.interrupt()
	boss.hp = 1
	boss.vulnerable = true
	var final_hit: CombatHitbox = CombatHitbox.new()
	final_hit.damage = 10
	boss.receive_hit(final_hit)
	final_hit.free()
	await frames(2)
	check(arena.ended and arena.result_screen.visible and not boss.enabled,"victory opens result and stops combat")
	await snapshot("step2_victory")
	Feedback.clear_transients()
	await get_tree().create_timer(0.2,true,false,true).timeout
	print("BOSS_SUITE_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
