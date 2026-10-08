extends Node
signal tick_finished

func _physics_process(_delta: float) -> void:
	tick_finished.emit.call_deferred()

var checks: int = 0
var failures: int = 0
var arena: Node2D
var player: GatePlayer
var dummy: Node2D

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
	else: print("PASS: " + description)

func frames(count: int) -> void:
	for i: int in count:
		await tick_finished

func snapshot(name: String) -> void:
	var folder: String = OS.get_environment("GATE1_TEST_CAPTURES")
	if folder.is_empty(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join(name+".png"))

func key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func pad(button: JoyButton, pressed: bool, device: int = 0) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func reset_player(x: float = 250.0, y: float = 912.0) -> void:
	for code: Key in [KEY_A,KEY_D,KEY_W,KEY_S,KEY_SPACE,KEY_SHIFT,KEY_J,KEY_U,KEY_K,KEY_L]: key(code,false)
	for button: JoyButton in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_DPAD_RIGHT]: pad(button,false)
	player.clear_action_intent()
	player.bow.cooldown = 0
	player.coyote = 0
	player.controls.device_id = -1
	player.position = Vector2(x,y)
	player.velocity = Vector2.ZERO
	player.state = GatePlayer.State.IDLE
	player.hp = player.p("max_hp")
	player.dash_uses = 0
	player.dash_cooldown = 0
	player.parry_cooldown = 0
	player.hurt_iframe = 0
	player.since_dash = INF
	player.combo_remaining = 0
	player.facing = 1
	player._cancel_attack()
	for box: Node in get_tree().get_nodes_in_group("hitboxes"): box.queue_free()
	Feedback.clear_transients()
	await frames(5)

func jump_peak(hold: int) -> float:
	await reset_player()
	key(KEY_SPACE,true)
	var peak: float = player.position.y
	for i: int in 65:
		if i == hold: key(KEY_SPACE,false)
		await frames(1)
		peak = minf(peak,player.position.y)
	return peak

func attack_test(up: bool, down: bool) -> void:
	await reset_player(1490, 540 if down else 990)
	if up: key(KEY_W,true)
	if down: key(KEY_S,true)
	key(KEY_J,true)
	await frames(1)
	key(KEY_J,false)
	check(player.attack_kind == ("down_attack" if down else "up_attack"), "directional attack selection")
	await frames(20)
	key(KEY_W,false)
	key(KEY_S,false)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("GATE1_TEST_SAVE").is_empty() or OS.get_environment("GATE1_TEST_TUNING").is_empty():
		printerr("Tests require isolated GATE1_TEST_SAVE and GATE1_TEST_TUNING paths")
		get_tree().quit(1)
		return
	Tuning.storage_override = OS.get_environment("GATE1_TEST_TUNING")
	Tuning.set_value("practice","weapon_id","sword_basic")
	_run.call_deferred()

func _run() -> void:
	check(DataRegistry.is_valid,"data valid")
	arena = load("res://scenes/arena/Arena.tscn").instantiate()
	add_child(arena)
	player = arena.player
	dummy = arena.dummy
	Tuning.set_value("dummy","enabled",false)
	print("CONNECTED_JOYPADS ", Input.get_connected_joypads())
	await frames(15)
	check(player.is_on_floor(),"player lands on floor")
	key(KEY_D,true)
	await frames(30)
	key(KEY_D,false)
	check(player.position.x > 500 and player.facing == 1,"keyboard movement + acceleration")
	var short_peak: float = await jump_peak(2)
	var long_peak: float = await jump_peak(30)
	check(long_peak < short_peak-80,"variable jump height (held vs released)")
	await reset_player(550,912)
	key(KEY_SPACE,true)
	await frames(55)
	key(KEY_SPACE,false)
	check(player.is_on_floor() and player.position.y < 700,"jump through and land on one-way platform")
	await reset_player(250,500)
	player.dash_uses = 0
	key(KEY_SHIFT,true)
	await frames(1)
	key(KEY_SHIFT,false)
	var start: float = player.position.x
	check(player.state == GatePlayer.State.DASH,"air dash starts")
	await frames(ceili(player.p("dash_duration")*60)-1)
	check(absf(player.position.x-start-(player.p("dash_distance")-player.p("dash_distance")/player.p("dash_duration")/60.0)) < 5,"dash distance follows tuning")
	player.dash_cooldown = 0
	key(KEY_SHIFT,true)
	await frames(1)
	key(KEY_SHIFT,false)
	check(player.state != GatePlayer.State.DASH,"second airborne dash blocked")
	await reset_player(1320,912)
	var before: float = dummy.damage_received
	key(KEY_J,true)
	await frames(2)
	key(KEY_J,false)
	await frames(18)
	check(dummy.damage_received == before+10,"sword hits once per active hitbox")
	key(KEY_J,true)
	await frames(2)
	key(KEY_J,false)
	await frames(20)
	check(player.combo_index == 1,"combo second stage")
	key(KEY_J,true)
	await frames(2)
	key(KEY_J,false)
	await frames(36)
	check(player.combo_index == 2,"combo third stage from array")
	await reset_player(1490,620)
	key(KEY_S,true)
	key(KEY_J,true)
	await frames(1)
	key(KEY_J,false)
	var bounced: bool = false
	for i: int in 20:
		await frames(1)
		if player.velocity.y < -500: bounced = true
	key(KEY_S,false)
	check(bounced,"downward hit produces pogo bounce")
	await snapshot("step1_pogo")
	await reset_player(1430,912)
	key(KEY_W,true)
	key(KEY_J,true)
	await frames(8)
	check(player.attack_kind == "up_attack" and is_instance_valid(player.active_box) and player.active_box.position.y < 0,"upper attack geometry")
	key(KEY_J,false)
	key(KEY_W,false)
	await reset_player(1280,912)
	key(KEY_K,true)
	await frames(1)
	key(KEY_K,false)
	var parries: int = player.total_parries
	dummy.attack_count = 0
	dummy.attack()
	await frames(2)
	check(player.hp == 100 and player.total_parries == parries+1 and dummy.stagger > 0,"melee parry negates damage and adds stagger")
	await snapshot("step1_parry")
	await frames(20)
	await reset_player(1280,912)
	key(KEY_K,true)
	await frames(1)
	key(KEY_K,false)
	await frames(10)
	key(KEY_J,true)
	await frames(1)
	key(KEY_J,false)
	check(player.state == GatePlayer.State.PARRY,"failed parry locks attack during whiff recovery")
	await frames(25)
	check(player.state != GatePlayer.State.PARRY,"whiff recovery ends")
	Tuning.set_value("player","parry_enabled",false)
	key(KEY_K,true)
	await frames(1)
	key(KEY_K,false)
	check(player.state != GatePlayer.State.PARRY and not arena.parry_help.visible,"parry disabled: input + HUD hidden")
	check(not arena.debug_panel.controls["player/parry_window"]["row"].visible,"parry sliders hidden while disabled")
	check(not arena.debug_panel.controls["feedback/hitstop_on_parry"]["row"].visible,"parry feedback controls hidden while disabled")
	await snapshot("step1_parry_off")
	Tuning.set_value("player","parry_enabled",true)
	await reset_player(1280,912)
	var projectile: CombatProjectile = CombatProjectile.new()
	projectile.box_size = Vector2(32,32)
	projectile.position = player.position+Vector2(30,0)
	projectile.motion = Vector2(-540,0)
	projectile.source = dummy
	projectile.damage = 12
	projectile.parriable = true
	projectile.duration = 4
	key(KEY_K,true)
	await frames(1)
	key(KEY_K,false)
	before = dummy.damage_received
	arena.add_child(projectile)
	await frames(2)
	check(projectile.reflected and projectile.motion.x > 0 and projectile.team == "player","projectile parry reverses direction/team")
	await frames(45)
	check(dummy.damage_received == before+12,"reflected projectile damages dummy")
	await reset_player(1280,912)
	var perfect: int = player.total_perfect
	key(KEY_SHIFT,true)
	await frames(1)
	key(KEY_SHIFT,false)
	dummy.attack_count = 0
	dummy.attack()
	await frames(2)
	check(player.hp == 100 and player.total_perfect == perfect+1,"dash iframe + single perfect dodge event")
	await reset_player(1280,912)
	dummy.attack_count = 0
	dummy.attack()
	await frames(2)
	check(player.hp == 88 and player.state == GatePlayer.State.HURT,"hit damage and hurt state")
	dummy.attack_count = 0
	dummy.attack()
	await frames(2)
	check(player.hp == 88,"hurt invulnerability prevents duplicate damage")
	await frames(65)
	player.hp = 40
	player.potions = 3
	key(KEY_L,true)
	await frames(1)
	key(KEY_L,false)
	await frames(55)
	check(player.hp == 75 and player.potions == 2,"potion completes channel and consumes one")
	await reset_player(1280,912)
	Feedback.invincible = true
	dummy.attack_count = 0
	dummy.attack()
	await frames(2)
	check(player.hp == 100,"F5 invulnerability behavior")
	Feedback.invincible = false
	# Real UI slider signal, not a direct dictionary write.
	arena.debug_panel.controls["player/move_speed"]["control"].value = 780
	check(player.p("move_speed") == 780,"F1 slider changes live player value")
	Tuning.storage_override = OS.get_environment("GATE1_TEST_TUNING")
	check(not Tuning.storage_override.is_empty(),"isolated persistence path supplied")
	check(Tuning.save_values(),"save runtime override")
	Tuning.set_value("player","move_speed",120)
	check(Tuning.load_override() and player.p("move_speed") == 780,"reload saved override")
	Tuning.reset_defaults()
	check(player.p("move_speed") == 520,"restore factory defaults")
	# Slow motion must survive overlapping hitstops.
	Feedback.set_speed(0.5)
	Feedback.hitstop(0.05)
	Feedback.hitstop(0.12)
	check(Engine.time_scale == Tuning.feedback["hitstop_time_scale"],"hitstop uses configured scale")
	await get_tree().create_timer(0.2,true,false,true).timeout
	check(Engine.time_scale == 0.5,"longest hitstop restores selected slow motion")
	Feedback.set_speed(1.0)
	await reset_player()
	pad(JOY_BUTTON_DPAD_RIGHT,true)
	await frames(15)
	pad(JOY_BUTTON_DPAD_RIGHT,false)
	check(player.controls.device_id == 0 and player.position.x > 300,"gamepad event routes device + movement")
	pad(JOY_BUTTON_A,true)
	await frames(2)
	pad(JOY_BUTTON_A,false)
	check(player.velocity.y < 0,"gamepad jump")
	pad(JOY_BUTTON_B,true)
	await frames(2)
	pad(JOY_BUTTON_B,false)
	check(player.state == GatePlayer.State.DASH,"gamepad dash")
	await frames(40)
	pad(JOY_BUTTON_X,true)
	await frames(2)
	pad(JOY_BUTTON_X,false)
	check(player.state == GatePlayer.State.ATTACK,"gamepad attack")
	await frames(30)
	pad(JOY_BUTTON_LEFT_SHOULDER,true)
	await frames(2)
	pad(JOY_BUTTON_LEFT_SHOULDER,false)
	check(player.state == GatePlayer.State.PARRY,"gamepad parry")
	await frames(35)
	player.hp = 40
	player.potions = 3
	pad(JOY_BUTTON_Y,true)
	await frames(2)
	pad(JOY_BUTTON_Y,false)
	check(player.state == GatePlayer.State.POTION,"gamepad potion")
	await frames(55)
	check(player.hp == 75,"gamepad potion completes")
	await reset_player(1490,620)
	pad(JOY_BUTTON_DPAD_DOWN,true)
	pad(JOY_BUTTON_X,true)
	await frames(2)
	pad(JOY_BUTTON_X,false)
	check(player.attack_kind == "down_attack","gamepad down attack")
	pad(JOY_BUTTON_DPAD_DOWN,false)
	await reset_player(1430,912)
	pad(JOY_BUTTON_DPAD_UP,true)
	pad(JOY_BUTTON_X,true)
	await frames(2)
	pad(JOY_BUTTON_X,false)
	check(player.attack_kind == "up_attack","gamepad upper attack")
	pad(JOY_BUTTON_DPAD_UP,false)
	await reset_player(250,912)
	player.controls.auto_device = false
	player.controls.device_id = 0
	pad(JOY_BUTTON_DPAD_RIGHT,true,1)
	await frames(10)
	check(player.position.x == 250,"other device cannot control assigned player")
	pad(JOY_BUTTON_DPAD_RIGHT,false,1)
	player.controls.auto_device = true
	await reset_player(250,500)
	var reached_buffer_height: bool = false
	for i: int in 50:
		await frames(1)
		if player.position.y > 875:
			reached_buffer_height = true
			break
	key(KEY_SPACE,true)
	await frames(5)
	key(KEY_SPACE,false)
	check(reached_buffer_height and player.velocity.y < 0,"jump buffer fires on landing")
	await reset_player(650,672)
	key(KEY_D,true)
	for i: int in 30:
		await frames(1)
		if not player.is_on_floor(): break
	key(KEY_SPACE,true)
	await frames(1)
	key(KEY_SPACE,false)
	key(KEY_D,false)
	check(player.velocity.y < -500,"coyote jump after leaving platform")
	await reset_player(1280,912)
	player.hp = 40
	player.potions = 3
	key(KEY_L,true)
	await frames(1)
	key(KEY_L,false)
	dummy.attack_count = 0
	dummy.attack()
	await frames(60)
	check(player.hp == 28 and player.potions == 3,"hit interrupts potion without consuming it")
	await reset_player(250,912)
	player.weapon = DataRegistry.get_weapon("daggers_twin")
	key(KEY_J,true)
	await frames(1)
	key(KEY_J,false)
	await frames(6)
	key(KEY_SHIFT,true)
	await frames(1)
	key(KEY_SHIFT,false)
	check(player.state == GatePlayer.State.DASH,"dagger recovery dash cancel flag")
	player.weapon = DataRegistry.get_weapon("sword_basic")
	arena.debug_panel.practice_buttons["판정 보기"].button_pressed = true
	check(Feedback.boxes_visible,"mouse-accessible hit/hurt/parry overlays")
	arena.debug_panel.practice_buttons["무적"].button_pressed = true
	check(Feedback.invincible and Feedback.debug_used,"mouse-accessible invulnerability and debug marker")
	Feedback.invincible = false
	arena.debug_panel.practice_buttons["0.25×"].pressed.emit()
	check(Feedback.base_speed == 0.25,"quarter speed button")
	arena.debug_panel.practice_buttons["0.5×"].pressed.emit()
	check(Feedback.base_speed == 0.5,"half speed button")
	arena.debug_panel.practice_buttons["1×"].pressed.emit()
	check(Feedback.base_speed == 1.0,"normal speed button")
	key(KEY_TAB,true)
	key(KEY_TAB,false)
	check(get_tree().paused and arena.debug_panel.panel.visible,"Tab opens panel and pauses training")
	key(KEY_TAB,true)
	key(KEY_TAB,false)
	check(not get_tree().paused and not arena.debug_panel.panel.visible,"Tab closes panel and resumes")
	await reset_player(250,912)
	Tuning.set_value("player","dash_duration",0)
	key(KEY_SHIFT,true)
	await frames(1)
	key(KEY_SHIFT,false)
	check(is_finite(player.velocity.x) and player.position.x > 500,"zero duration slider safely uses one physics tick")
	Tuning.reset_defaults()
	await reset_player(1280,912)
	player.hp = 1
	dummy.attack_count = 0
	dummy.attack()
	await frames(2)
	check(player.state == GatePlayer.State.DEAD and arena.retry_button.visible,"death stops player and shows retry")
	await get_tree().create_timer(0.25,true,false,true).timeout
	print("PLAYER_SUITE_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
