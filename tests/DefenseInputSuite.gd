extends "res://tests/PlayerSuite.gd"

func prepare(state: GatePlayer.State) -> void:
	await reset_player()
	player.clear_action_intent()
	player.parry_age = INF
	player.controls._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	player.state = state
	player.action_clock = 0
	if state == GatePlayer.State.ATTACK: player._begin_attack()
	if state == GatePlayer.State.DASH: player._begin_dash()
	player.dash_cooldown = 0
	player.parry_cooldown = 0

func _run() -> void:
	arena = load("res://scenes/arena/Arena.tscn").instantiate()
	add_child(arena)
	player = arena.player
	dummy = arena.dummy
	Tuning.set_value("dummy","enabled",false)
	await frames(10)
	for action_state: GatePlayer.State in [GatePlayer.State.IDLE,GatePlayer.State.RUN,GatePlayer.State.JUMP,GatePlayer.State.FALL,GatePlayer.State.ATTACK,GatePlayer.State.PARRY,GatePlayer.State.POTION,GatePlayer.State.HURT]:
		await prepare(action_state)
		key(KEY_SHIFT,true)
		await frames(1)
		check(player.state == GatePlayer.State.DASH,"dash next tick from "+GatePlayer.State.keys()[action_state])
		key(KEY_SHIFT,false)
	for action_state: GatePlayer.State in [GatePlayer.State.IDLE,GatePlayer.State.ATTACK,GatePlayer.State.DASH,GatePlayer.State.POTION,GatePlayer.State.HURT]:
		await prepare(action_state)
		key(KEY_J,true)
		key(KEY_K,true)
		await frames(1)
		check(player.parry_age <= player.p("parry_window") and not player.attack_running,"parry beats held attack from "+GatePlayer.State.keys()[action_state])
		if action_state == GatePlayer.State.DASH: check(player.state == GatePlayer.State.DASH,"parry does not cancel dash movement")
		key(KEY_K,false)
		key(KEY_J,false)
	await prepare(GatePlayer.State.ATTACK)
	key(KEY_SHIFT,true)
	key(KEY_K,true)
	await frames(1)
	check(player.state == GatePlayer.State.DASH and player.parry_age <= player.p("parry_window"),"same-tick keyboard dash and parry both activate")
	await snapshot("step3_dash_parry")
	await prepare(GatePlayer.State.IDLE)
	pad(JOY_BUTTON_X,true)
	pad(JOY_BUTTON_B,true)
	pad(JOY_BUTTON_LEFT_SHOULDER,true)
	await frames(1)
	check(player.state == GatePlayer.State.DASH and player.parry_age <= player.p("parry_window") and not player.attack_running,"pad X+B+LB honors both defenses")
	await prepare(GatePlayer.State.ATTACK)
	key(KEY_K,true)
	key(KEY_K,false)
	await frames(1)
	check(player.parry_age <= player.p("parry_window"),"between-tick parry tap is retained")
	await prepare(GatePlayer.State.ATTACK)
	key(KEY_SHIFT,true)
	key(KEY_SHIFT,false)
	await frames(1)
	check(player.state == GatePlayer.State.DASH,"between-tick dash tap is retained")
	await prepare(GatePlayer.State.IDLE)
	player.dash_cooldown = 0.06
	key(KEY_SHIFT,true)
	key(KEY_SHIFT,false)
	await frames(5)
	check(player.state == GatePlayer.State.DASH,"near-ready cooldown consumes short defensive tap")
	await prepare(GatePlayer.State.IDLE)
	player.dash_cooldown = 0.06
	key(KEY_SHIFT,true)
	key(KEY_SHIFT,false)
	await frames(1)
	OS.delay_msec(130)
	await frames(5)
	check(player.state == GatePlayer.State.DASH,"defensive tap survives wall time and expires in game time")
	await prepare(GatePlayer.State.IDLE)
	player.dash_cooldown = 0.05
	key(KEY_SHIFT,true)
	await frames(1)
	player.clear_action_intent()
	key(KEY_SHIFT,false)
	await frames(6)
	check(player.state != GatePlayer.State.DASH,"menu interruption clears defensive queue")
	await prepare(GatePlayer.State.IDLE)
	player.dash_cooldown = 0.3
	key(KEY_SHIFT,true)
	await frames(1)
	check(player.defense_note.begins_with("대시 대기") and player.defense_pending.is_empty(),"long cooldown is explained instead of silently swallowing or storing input")
	await prepare(GatePlayer.State.IDLE)
	Tuning.set_value("player","parry_enabled",false)
	key(KEY_K,true)
	await frames(1)
	check(player.parry_age == INF and player.defense_note.contains("꺼짐"),"disabled parry explains rejection")
	Tuning.set_value("player","parry_enabled",true)
	print("DEFENSE_SUITE_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
