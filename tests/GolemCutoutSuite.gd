extends "res://tests/PlayerSuite.gd"
var boss: Node2D
var impacts: Array = []

func _run() -> void:
	check(DataRegistry.is_valid,"cutout registry validates")
	arena = load("res://scenes/arena/BattleArena.tscn").instantiate()
	add_child(arena)
	player = arena.player
	boss = arena.boss
	await frames(55)
	boss.set_physics_process(false)
	boss.interrupt()
	player.position = Vector2(250,912)
	player.set_physics_process(false)
	var visual: Node2D = boss.cutout
	check(is_instance_valid(visual),"production golem instantiates cutout adapter")
	check(visual.animator.has_animation("slam") and visual.animator.has_animation("sweep") and visual.animator.has_animation("stomp"),"three production animations exist")
	check(visual.rig.get_node("Torso") is Node2D and not visual.rig.get_node("Torso") is Sprite2D,"Torso joint remains texture-free")
	check(visual.rig.get_node("Torso/ArmFront_Upper/ArmFront_Lower").show_behind_parent,"forearm draw order preserved")
	check(visual.rig.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,"painted rig uses linear filtering")
	check(boss.data["patterns"].size() == 3,"unsupported legacy attacks absent from production")
	check(not visual.settings["weakpoint_enabled"] and not visual.weakpoint_bounds().has_area(),"weak point defaults off")
	visual.impact.connect(func(id: String, pos: Vector2) -> void: impacts.append([id,pos]))
	boss.global_position = Vector2(1000,810)
	for facing: int in [-1,1]:
		boss.facing = facing
		visual.begin("slam")
		visual.advance(0.7)
		var fist: Node2D = visual.rig.get_node("Torso/ArmFront_Upper/ArmFront_Lower/FistFront")
		var edge_a: Vector2 = fist.to_global(Vector2(19.6,67.2))
		var edge_b: Vector2 = fist.to_global(Vector2(134.4,64.96))
		print("LANDING facing=",facing," edge_a=",edge_a," edge_b=",edge_b," rect=",visual.attack_rect())
		check(absf(edge_a.y-960) < 2 and absf(edge_b.y-960) < 2,"slam fist edge meets ground facing "+str(facing))
		var rect: Rect2 = visual.attack_rect()
		check(rect.grow(2).has_point(edge_a) and rect.grow(2).has_point(edge_b),"ground hitbox covers fist edge facing "+str(facing))
		check(signf(rect.get_center().x-boss.position.x) == facing,"hitbox mirrors with visual facing "+str(facing))
		check(is_instance_valid(visual.box),"slam active at .7 facing "+str(facing))
		Feedback.boxes_visible = true
		boss.reset_physics_interpolation()
		await snapshot("golem_slam_"+("left" if facing < 0 else "right"))
		visual.cancel()
		await frames(2)
	for move_id: String in ["slam","sweep","stomp"]:
		impacts.clear()
		visual.begin(move_id)
		var samples: int = 0
		var outside: bool = false
		for i: int in 105:
			visual.advance(1.0/60)
			var active: bool = is_instance_valid(visual.box)
			if active:
				samples += 1
				if visual.elapsed < float(visual.attack_settings["active_start"])-0.000001 or visual.elapsed >= float(visual.attack_settings["active_end"])+0.000001: outside = true
			await frames(1)
		print("WINDOW ",move_id," active_ticks=",samples)
		check(samples > 0 and not outside,move_id+" hitbox only active inside data interval")
		check(impacts.size() == 1,move_id+" emits exactly one impact")
		visual.cancel()
		check(not is_instance_valid(visual.box),move_id+" interrupt clears active hitbox")
	boss.facing = -1
	for move_id: String in ["slam","sweep","stomp"]:
		visual.begin(move_id)
		visual.advance(float(visual.attack_settings["windup"]))
		boss.reset_physics_interpolation()
		await snapshot("golem_"+move_id+"_windup")
		visual.cancel()
	# Exercise the real player hurtbox, not just the visual rectangle.
	for facing: int in [-1,1]:
		boss.facing = facing
		visual.begin("slam")
		player.position = visual.attack_rect().get_center()
		player.hp = player.p("max_hp")
		player.hurt_iframe = 0
		player.since_dash = INF
		player.parry_age = INF
		Feedback.invincible = false
		visual.advance(0.69)
		await frames(1)
		check(player.hp == player.p("max_hp"),"no damage before slam window facing "+str(facing))
		visual.advance(0.01)
		await frames(2)
		check(player.hp == player.p("max_hp")-25,"live slam hits player once facing "+str(facing))
		visual.advance(0.1)
		player.hurt_iframe = 0
		await frames(2)
		check(player.hp == player.p("max_hp")-25,"no late damage after window facing "+str(facing))
		visual.cancel()
		Feedback.clear_transients()
	player.position = Vector2(250,912)
	var old_start: float = Tuning.golem["moves"]["slam"]["active_start"]
	Tuning.set_value("golem/slam","active_start",2.0)
	check(Tuning.golem["moves"]["slam"]["active_start"] == old_start,"invalid timing edit is rejected instead of saved")
	Tuning.set_value("golem/slam","windup",0.9)
	visual.begin("slam")
	check(is_equal_approx(visual.attack_settings["active_start"],1.0),"windup slider shifts active window with motion")
	check(is_equal_approx(visual.animator.get_animation("runtime/attack").length,1.7),"windup slider shifts animation length")
	visual.advance(0.7)
	check(not is_instance_valid(visual.box),"longer windup does not retain old impact time")
	visual.advance(0.3)
	check(is_instance_valid(visual.box),"retimed impact aligns at 1.0")
	visual.cancel()
	Tuning.set_value("golem/slam","windup",0.6)
	boss.phase_index = 1
	visual.begin("slam")
	check(is_equal_approx(visual.attack_settings["windup"],0.45) and is_equal_approx(visual.attack_settings["active_start"],0.55),"phase two slam uses .45 windup and .55 impact")
	visual.cancel()
	visual.begin("stomp")
	var before: int = boss.hazards.size()
	visual.advance(0.62)
	check(boss.hazards.size() >= before+3,"phase two stomp emits two shockwaves at impact")
	boss.interrupt()
	boss.phase_index = 0
	boss.last_pattern = "slam"
	boss.pattern_streak = 2
	check(boss.choose_pattern() == "sweep","same pattern cannot occur three times in a row")
	boss.foot_time = 1.5
	check(boss.choose_pattern() == "stomp","foot dwell selects stomp")
	var origin: Vector2 = boss.position
	boss.enabled = true
	boss.set_physics_process(true)
	var captured_live: bool = false
	for i: int in 250:
		await frames(1)
		if not captured_live and visual.active and visual.elapsed >= float(visual.attack_settings["windup"])*0.8 and visual.elapsed < float(visual.attack_settings["windup"]):
			captured_live = true
			await snapshot("golem_live_telegraph")
	check(captured_live,"real AI runner advances cutout telegraph")
	check(boss.position.distance_to(origin) < 0.01,"new golem stays stationary without fake walk animation")
	boss.set_physics_process(false)
	boss.interrupt()
	Tuning.set_value("golem","weakpoint_enabled",true)
	visual.begin("slam")
	visual.advance(0.7)
	check(visual.weakpoint_bounds().has_area() and boss.weakbox.box_size.x > 0,"optional weak point activates in punish window")
	var old_hp: float = boss.hp
	var strike: CombatHitbox = CombatHitbox.new()
	strike.source = player
	strike.team = "player"
	strike.box_size = Vector2(1000,1000)
	strike.damage = 10
	strike.duration = 0.03
	arena.add_child(strike)
	strike.global_position = boss.hurtbox.global_position
	await frames(2)
	check(is_equal_approx(boss.hp,old_hp-15),"body plus weakpoint overlap deals one amplified hit")
	Feedback.clear_transients()
	visual.advance(0.5)
	check(not visual.weakpoint_bounds().has_area() and boss.weakbox.box_size == Vector2.ZERO,"weak point closes after punish window")
	boss.interrupt()
	Tuning.set_value("golem","weakpoint_enabled",false)
	check(Tuning.save_values(),"golem tuning persists to isolated override")
	Tuning.set_value("golem","scale",0.6)
	check(Tuning.load_override() and is_equal_approx(Tuning.golem["scale"],0.7),"golem override restores saved scale")
	arena.debug_panel.tabs.current_tab = 8
	arena.debug_panel.toggle()
	boss.reset_physics_interpolation()
	await snapshot("golem_tuning_panel")
	arena.debug_panel.toggle()
	arena.queue_free()
	await frames(3)
	print("GOLEM_CUTOUT_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
