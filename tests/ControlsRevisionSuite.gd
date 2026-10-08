extends "res://tests/PlayerSuite.gd"
## Behavioral regressions for the user's Step 1 controls feedback.

func click_button(button: Control) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	point = get_viewport().get_final_transform() * point
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame

func _run() -> void:
	check(DataRegistry.is_valid,"revised data valid")
	Tuning.training["dummy"]["enabled"] = false
	arena = load("res://scenes/arena/Arena.tscn").instantiate()
	add_child(arena)
	player = arena.player
	dummy = arena.dummy
	await frames(10)
	await reset_player()
	key(KEY_D,true)
	await frames(1)
	check(player.velocity.x == player.p("move_speed"),"current input reaches speed on the next tick")
	key(KEY_A,true)
	await frames(1)
	check(player.velocity.x == -player.p("move_speed"),"last direction wins even while old direction is held")
	key(KEY_A,false)
	key(KEY_D,false)
	var position_before: float = player.position.x
	await frames(1)
	check(player.velocity.x == 0 and player.position.x == position_before,"release stops without residual drift")
	await reset_player(800,500)
	key(KEY_SHIFT,true)
	await frames(1)
	key(KEY_SHIFT,false)
	await frames(10)
	position_before = player.position.x
	await frames(20)
	check(player.velocity.x == 0 and absf(player.position.x-position_before) < 0.01,"dash end cannot leak high speed into movement")
	var directions: Array[Vector2] = [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]
	for direction: Vector2 in directions:
		await reset_player(900,350)
		player.dash_uses = 0
		if direction.x < 0: key(KEY_A,true)
		if direction.x > 0: key(KEY_D,true)
		if direction.y < 0: key(KEY_W,true)
		if direction.y > 0: key(KEY_S,true)
		key(KEY_SHIFT,true)
		await frames(1)
		key(KEY_SHIFT,false)
		check(player.state == GatePlayer.State.DASH and player.dash_direction.is_equal_approx(direction),"dash direction " + str(direction))
		check(is_equal_approx(player.velocity.length(),player.dash_speed),"diagonal has no extra speed " + str(direction))
	await reset_player(250,912)
	position_before = player.position.x
	key(KEY_J,true)
	await frames(1)
	key(KEY_J,false)
	await frames(30)
	check(absf(player.position.x-position_before-30) < 1,"standing attack advances configured30px")
	await reset_player()
	key(KEY_J,true)
	await frames(1)
	key(KEY_J,false)
	key(KEY_D,true)
	await frames(7)
	check(player.state == GatePlayer.State.ATTACK and is_equal_approx(player.velocity.x,player.p("move_speed")*player.p("attack_move_mult")),"attack movement follows configured multiplier")
	key(KEY_D,false)
	await frames(1)
	check(player.velocity.x == 0,"release stops movement during attack")
	key(KEY_SPACE,true)
	await frames(1)
	key(KEY_SPACE,false)
	check(player.state != GatePlayer.State.ATTACK and player.velocity.y < 0,"jump interrupts attack immediately")
	await reset_player()
	key(KEY_J,true)
	await frames(1)
	key(KEY_J,false)
	key(KEY_W,true)
	key(KEY_SHIFT,true)
	await frames(1)
	key(KEY_SHIFT,false)
	key(KEY_W,false)
	check(player.state == GatePlayer.State.DASH and player.dash_direction == Vector2.UP,"vertical dash cancels sword startup")
	Tuning.set_value("player","attack_buffer",0.0)
	Tuning.set_value("player","attack_release_clears_buffer",true)
	await reset_player(1320,912)
	var hits: int = dummy.hits_received
	key(KEY_J,true)
	await frames(1)
	key(KEY_J,false)
	await frames(2)
	key(KEY_J,true)
	await frames(1)
	key(KEY_J,false)
	await frames(50)
	check(dummy.hits_received == hits+1 and player.combo_index == 0,"buffer disabled: early released press cannot resurrect as a delayed combo")
	Tuning.set_value("player","attack_buffer",0.08)
	Tuning.set_value("player","attack_release_clears_buffer",false)
	await reset_player(1320,912)
	key(KEY_J,true)
	await frames(1)
	key(KEY_J,false)
	await frames(2)
	key(KEY_J,true)
	await frames(1)
	key(KEY_J,false)
	OS.delay_msec(100)
	await frames(50)
	check(player.combo_index == 1,"optional queued attack survives current attack and chains once")
	Tuning.set_value("player","attack_buffer",0.0)
	Tuning.set_value("player","attack_release_clears_buffer",true)
	await reset_player()
	key(KEY_SPACE,true)
	key(KEY_SPACE,false)
	await frames(1)
	check(player.velocity.y < 0,"press+release between physics ticks is not lost")
	await reset_player()
	key(KEY_SPACE,true)
	key(KEY_SPACE,false)
	OS.delay_msec(150)
	await frames(1)
	check(player.velocity.y < 0,"short input survives wall-clock stall before physics")
	await reset_player()
	arena.debug_panel.practice_buttons["조작감 패널 (Tab)"].pressed.emit()
	key(KEY_J,true)
	key(KEY_J,false)
	arena.debug_panel.practice_buttons["닫고 연습"].pressed.emit()
	await frames(1)
	check(player.state != GatePlayer.State.ATTACK,"panel editing cannot leak stale gameplay actions")
	var menu: CanvasLayer = arena.debug_panel
	check(menu.tabs.get_tab_count() == 9,"nine tuning tabs including magic bow and golem")
	for section: String in ["player","feedback"]:
		var all_present: bool = true
		for key: String in Tuning.section_values(section):
			all_present = all_present and menu.controls.has(section+"/"+key)
		check(all_present,"all " + section + " fields have controls")
	for weapon: Dictionary in Tuning.weapons:
		var all_present: bool = menu.controls.has("weapons/"+weapon["id"]+"/combo_window")
		for i: int in weapon["combo"].size():
			for key: String in weapon["combo"][i]: all_present = all_present and menu.controls.has("weapons/%s/combo/%d/%s" % [weapon["id"],i,key])
		for kind: String in ["air_attack","up_attack","down_attack"]:
			for key: String in weapon[kind]: all_present = all_present and menu.controls.has("weapons/%s/%s/%s" % [weapon["id"],kind,key])
		check(all_present,"all attacks editable: " + weapon["id"])
	menu.controls["weapons/sword_basic/combo/0/recovery"]["label"].value = 0.04
	check(player.weapon["combo"][0]["recovery"] == 0.04,"numeric entry updates active weapon immediately")
	menu.controls["weapons/sword_basic/combo/0/lunge"]["control"].value = 25
	check(player.weapon["combo"][0]["lunge"] == 25,"lunge remains adjustable")
	menu.controls["weapons/sword_basic/combo/0/lunge"]["control"].value = 0
	menu.controls["dummy/attack_interval"]["label"].value = 4.5
	check(dummy.data["attack_interval"] == 4.5,"dummy interval updates from panel")
	menu.controls["dummy/hitbox_size/0"]["label"].value = 310
	check(dummy.data["hitbox_size"][0] == 310,"dummy hitbox geometry updates from panel")
	menu.weapon_select.item_selected.emit(1)
	check(player.weapon["id"] == "greatsword_slab","weapon selector changes practice weapon")
	for i: int in range(1,7):
		check(not InputMap.has_action("debug_f%d" % i),"no F%d dependency" % i)
	Tuning.storage_override = OS.get_environment("GATE1_TEST_TUNING")
	check(Tuning.save_values(),"full panel settings save")
	Tuning.reset_defaults()
	check(Tuning.load_override() and player.weapon["id"] == "greatsword_slab" and Tuning.get_weapon("sword_basic")["combo"][0]["recovery"] == 0.04 and dummy.data["attack_interval"] == 4.5,"weapon + dummy + player settings restore together")
	# Actual GUI mouse routing, not button signal calls.
	await frames(2)
	await click_button(menu.practice_buttons["조작감 패널 (Tab)"])
	check(menu.is_open,"mouse opens panel through GUI hit testing")
	await click_button(menu.practice_buttons["닫고 연습"])
	check(not menu.is_open,"mouse closes panel through GUI hit testing")
	Tuning.reset_defaults()
	Tuning.training["dummy"]["enabled"] = false
	Tuning.set_value("dummy","enabled",false)
	await snapshot("controls_arena")
	menu.toggle()
	await snapshot("controls_movement")
	menu.tabs.current_tab = 4
	await get_tree().process_frame
	await snapshot("controls_weapons")
	menu.tabs.current_tab = 2
	await get_tree().process_frame
	await snapshot("controls_attack")
	menu.tabs.current_tab = 7
	await get_tree().process_frame
	await snapshot("controls_dummy")
	menu.toggle()
	await get_tree().create_timer(0.25,true,false,true).timeout
	print("CONTROLS_SUITE_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
