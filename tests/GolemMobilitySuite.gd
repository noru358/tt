extends "res://tests/PlayerSuite.gd"
var boss: Node2D

func ready_player() -> void:
	player.hp = player.p("max_hp")
	player.hurt_iframe = 0
	player.since_dash = INF
	player.parry_age = INF
	player.state = GatePlayer.State.IDLE
	Feedback.invincible = false
	Feedback.clear_transients()

func _run() -> void:
	Tuning.feedback["hitstop_on_hit"] = 0
	Tuning.feedback["hitstop_on_player_hurt"] = 0
	arena = load("res://scenes/arena/BattleArena.tscn").instantiate()
	add_child(arena)
	player = arena.player
	boss = arena.boss
	await frames(55)
	boss.set_physics_process(false)
	player.set_physics_process(false)
	boss.interrupt()
	var visual: Node2D = boss.cutout
	boss.position = Vector2(1000,810)
	check(visual.body_parts.size() == 12,"all twelve visible body parts have outlines")
	check(boss.hurtbox.get_parent().name == "TorsoSkin","stable torso aim anchor")
	for facing: int in [-1,1]:
		boss.facing = facing
		visual.idle(0)
		for part: CombatHurtbox in visual.body_parts:
			check(part.outline.size() >= 3 and part.overlaps(Rect2(part.aim_point()-Vector2(3,3),Vector2(6,6))),"body hit at "+str(part.get_parent().name)+" facing "+str(facing))
		var fist_part: CombatHurtbox = visual.rig.get_node("Torso/ArmFront_Upper/ArmFront_Lower/FistFront/BodyHurtbox")
		var fist_center: Vector2 = fist_part.aim_point()
		check(fist_part.sweep_fraction(fist_center-Vector2(400,0),fist_center+Vector2(400,0),3) >= 0,"arrow sweeps mirrored limb facing "+str(facing))
		check(not visual.body_overlaps(Rect2(50,50,10,10)),"outside silhouette misses facing "+str(facing))
	var limb: CombatHurtbox = visual.rig.get_node("Torso/ArmFront_Upper/ArmFront_Lower/FistFront/BodyHurtbox")
	var center: Vector2 = limb.aim_point()
	check(limb.sweep_fraction(center-Vector2(400,0),center+Vector2(400,0),3) >= 0,"fast arrow sweeps actual moving limb")
	var old_hp: float = boss.hp
	var strike: CombatHitbox = CombatHitbox.new()
	strike.source = player
	strike.team = "player"
	strike.box_size = Vector2(900,900)
	strike.damage = 3
	strike.duration = 0.05
	arena.add_child(strike)
	strike.global_position = boss.position
	await frames(4)
	check(is_equal_approx(boss.hp,old_hp-3),"twelve overlapping parts still receive one hit")
	ready_player()
	player.position = limb.aim_point()
	boss.contact_clock = 0
	boss._contact()
	check(player.hp == player.p("max_hp")-8,"arm contact deals configured body damage")
	player.hurt_iframe = 0
	boss._contact()
	check(player.hp == player.p("max_hp")-8,"contact interval prevents immediate repeated damage")
	boss.contact_clock = 0
	boss._contact()
	check(player.hp == player.p("max_hp")-16,"body damage repeats only after interval and invulnerability")
	ready_player()
	boss.contact_clock = 0
	player.since_dash = 0.01
	player.perfect_boxes.clear()
	var perfect: int = player.total_perfect
	for i: int in 5: boss._contact()
	check(player.hp == player.p("max_hp") and player.total_perfect == perfect+1,"dash passes body safely with one perfect dodge reward")
	player.since_dash = INF
	boss.stagger_time = 1
	boss._contact()
	check(player.hp == player.p("max_hp"),"stagger allows safe close-range punishment")
	boss.stagger_time = 0
	ready_player()
	boss.contact_clock = 0
	visual.begin("slam")
	visual.advance(0.7)
	player.position = visual.attack_rect().get_center()
	boss._contact()
	check(player.hp == player.p("max_hp"),"impact tick prioritizes authored attack over body contact")
	await frames(2)
	check(player.hp == player.p("max_hp")-25,"slam retains full damage with contact enabled")
	boss.interrupt()
	player.position = Vector2(250,912)
	boss.position = Vector2(1200,810)
	boss.retry = 0
	boss.set_physics_process(true)
	var origin: float = boss.position.x
	await frames(100)
	check(boss.position.x < origin-100 and boss.walking,"golem walks toward distant player")
	check(not visual.active,"distant golem approaches instead of attacking empty space")
	Feedback.boxes_visible = false
	await snapshot("wetland_walk")
	boss.set_physics_process(false)
	for facing: int in [-1,1]:
		boss.facing = facing
		for i: int in 20:
			visual.walk(1.0/60,95.0/60)
			for side: String in ["Front","Back"]:
				var part: CombatHurtbox = visual.rig.get_node("Torso/Leg"+side+"_Upper/Leg"+side+"_Lower/BodyHurtbox")
				check(part.bounds().end.y <= 960.5,"walking sole stays above floor")
		boss.reset_physics_interpolation()
		await snapshot("walk_pose_"+str(facing))
	boss.position = Vector2(1000,810)
	player.position = Vector2(850,912)
	boss.interrupt()
	boss.retry = 0
	boss.set_physics_process(true)
	await frames(10)
	check(not boss.walking and boss.runner.running,"golem stops in range and starts attack")
	var locked_x: float = boss.position.x
	player.position.x = 250
	await frames(15)
	check(is_equal_approx(boss.position.x,locked_x),"attack windup does not slide after retreating target")
	boss.set_physics_process(false)
	boss.interrupt()
	check(not arena.debug_panel.live_readout.visible and arena.hud_backdrop.size.y == 218,"compact HUD exposes more combat space")
	arena.detail_button.button_pressed = true
	check(arena.debug_panel.live_readout.visible and arena.hud_backdrop.size.y == 415,"details remain accessible with screen button")
	arena.detail_button.button_pressed = false
	player.position = Vector2(600,912)
	ready_player()
	player.controls._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	player.set_physics_process(true)
	player.bow.cooldown = 0.1
	key(KEY_U,true)
	await frames(9)
	check(player.bow.charging,"near-ready held bow press starts when cooldown ends")
	check(player.bow.target == boss.hurtbox,"automatic aim selects stable torso instead of limbs")
	key(KEY_U,false)
	await frames(1)
	check(player.bow.shots_fired == 1,"buffered charge releases exactly one arrow")
	player.bow.cooldown = 0.1
	key(KEY_U,true)
	await frames(1)
	key(KEY_U,false)
	await frames(12)
	check(not player.bow.charging and player.bow.shots_fired == 1,"released early press is discarded, not fired later")
	player.bow.cooldown = 0.1
	key(KEY_U,true)
	await frames(1)
	player.clear_action_intent()
	key(KEY_U,false)
	await frames(12)
	check(not player.bow.charging and player.bow.queued_charge == 0,"cancel clears pending bow press")
	boss.facing = -1
	visual.begin("slam")
	visual.advance(0.6)
	boss.reset_physics_interpolation()
	await snapshot("wetland_slam_windup")
	visual.advance(0.1)
	boss.reset_physics_interpolation()
	Feedback.boxes_visible = true
	await snapshot("wetland_full_body_hitboxes")
	Tuning.save_values()
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Tuning.override_path()))
	legacy["golem"]["body_x"] = -75
	legacy["golem"]["body_y"] = -210
	legacy["golem"]["body_width"] = 170
	legacy["golem"]["body_height"] = 260
	legacy["golem"].erase("walk_enabled")
	var file: FileAccess = FileAccess.open(Tuning.override_path(),FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(Tuning.load_override() and Tuning.golem["walk_enabled"] and not Tuning.golem.has("body_x"),"old rectangular-body tuning migrates without blocking startup")
	arena.queue_free()
	await frames(3)
	print("GOLEM_MOBILITY_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
