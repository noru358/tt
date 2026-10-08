extends "res://tests/ControlsRevisionSuite.gd"
const Calc = preload("res://scripts/stats/StatCalc.gd")
var hub: Control

func _run() -> void:
	check(not OS.get_environment("GATE1_TEST_SAVE").is_empty(),"isolated save path supplied")
	if OS.get_environment("GATE1_TEST_SAVE").is_empty():
		get_tree().quit(1)
		return
	check(GameState.reset_progress(),"fresh progress saved")
	hub = load("res://scenes/hub/Hub.tscn").instantiate()
	add_child(hub)
	await frames(3)
	check(hub.boss_buttons["wing"].disabled and "wing" not in GameState.state["unlocked"],"wing begins locked")
	check(hub.craft_buttons["rock_mail"].disabled,"insufficient materials disables craft")
	check(GameState.loadout()["weapon_id"] == "sword_basic","starting loadout uses basic sword")
	await snapshot("step3_hub_fresh")
	hub.queue_free()
	await frames(2)
	GameState.rng.seed = 3
	for index: int in 4:
		GameState.progression_run = true
		arena = load("res://scenes/arena/BattleArena.tscn").instantiate()
		add_child(arena)
		player = arena.player
		await frames(50)
		arena.boss.set_physics_process(false)
		arena.elapsed = 10+index
		var hit: CombatHitbox = CombatHitbox.new()
		hit.damage = 10000
		arena.boss.vulnerable = true
		arena.boss.receive_hit(hit)
		hit.free()
		await frames(2)
		check(arena.ended and arena.result_screen.visible,"boss death -> result -> reward "+str(index))
		var saved: Dictionary = GameState.state.duplicate(true)
		arena.finish(true)
		GameState.award_win(arena.boss.data,999,arena.run_token)
		check(GameState.state == saved,"duplicate victory cannot duplicate drops "+str(index))
		if index == 0: await snapshot("step3_reward")
		arena.queue_free()
		await frames(2)
	check(int(GameState.state["materials"]["golem_shard"]) >= 12 and int(GameState.state["materials"]["golem_shard"]) <= 20,"four real wins grant 3-5 shards each")
	check(GameState.state["materials"]["golem_core"] == 4,"guaranteed core reward")
	check(GameState.state["records"]["golem"]["kills"] == 4 and "wing" in GameState.state["unlocked"],"kill count and wing unlock persist")
	check(is_equal_approx(float(GameState.state["records"]["golem"]["best_time"]),10),"best time keeps the shortest completed run")
	hub = load("res://scenes/hub/Hub.tscn").instantiate()
	add_child(hub)
	await frames(3)
	check(not hub.boss_buttons["wing"].disabled,"hub allows every data-unlocked boss without id-specific gate")
	var before: int = GameState.state["materials"]["golem_shard"]
	await click_button(hub.craft_buttons["slab_greatsword"])
	await frames(2)
	check("slab_greatsword" in GameState.state["owned"] and GameState.state["materials"]["golem_shard"] == before-3,"actual UI crafting deducts exact recipe")
	var inventory: Dictionary = GameState.state.duplicate(true)
	check(not GameState.craft("slab_greatsword") and GameState.state == inventory,"owned equipment cannot charge recipe twice")
	check(GameState.craft("rock_mail") and GameState.craft("core_ward"),"craft armor and parry charm")
	check(GameState.equip("weapon","slab_greatsword") and GameState.equip("armor","rock_mail") and GameState.equip("charm","core_ward"),"equip all three slots")
	check(not GameState.equip("armor","core_ward"),"wrong slot rejected")
	var final: Dictionary = GameState.loadout()
	check(is_equal_approx(float(final["stats"]["move_speed"]),520*0.87) and final["stats"]["max_hp"] == 130,"single stat boundary sums equipment multipliers")
	check(is_equal_approx(final["stats"]["parry_window"],0.17),"parry window bonus applied")
	await frames(3)
	await snapshot("step3_hub_equipped")
	Tuning.set_value("player","parry_enabled",false)
	await frames(3)
	check(not hub.craft_buttons.has("core_ward") and hub.craft_buttons.has("heart_ring"),"parry-only recipe filtering is effect-type based")
	Tuning.set_value("player","parry_enabled",true)
	await frames(3)
	check(GameState.load_save() and GameState.state["equipped"]["armor"] == "rock_mail","save round-trip retains loadout")
	hub.queue_free()
	await frames(2)
	GameState.progression_run = true
	arena = load("res://scenes/arena/BattleArena.tscn").instantiate()
	add_child(arena)
	player = arena.player
	await frames(50)
	arena.boss.set_physics_process(false)
	arena.boss.interrupt()
	check(player.hp == 130 and player.weapon["id"] == "greatsword_slab" and player.p("move_speed") == final["stats"]["move_speed"],"new battle uses crafted equipment stats and weapon")
	player.controls._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	player.hp = 100
	key(KEY_J,true)
	await frames(2)
	key(KEY_K,true)
	await frames(1)
	key(KEY_K,false)
	key(KEY_J,false)
	var parry_hit: CombatHitbox = CombatHitbox.new()
	parry_hit.parriable = true
	parry_hit.damage = 20
	check(player.receive_hit(parry_hit) == "parried" and player.hp == 105,"parry during attack triggers equipped heal")
	parry_hit.free()
	Feedback.clear_transients()
	var bonus: Dictionary = {"modifiers":{},"effects":[{"type":"potion_bonus","count":2}]}
	check(Calc.calculate(Tuning.player,[bonus])["stats"]["potion_count"] == 5,"potion_bonus effect supported")
	# Test temporary damage effect with the same Player event and hitbox path.
	player.effects = [{"type":"on_perfect_dodge_damage_buff","mult":1.5,"duration":2.0}]
	player.since_dash = 0
	player.parry_age = INF
	var dodge_hit: CombatHitbox = CombatHitbox.new()
	dodge_hit.damage = 10
	player.receive_hit(dodge_hit)
	check(player.damage_buff == 1.5 and player.damage_buff_time == 2,"perfect dodge triggers timed damage buff")
	player._begin_attack()
	player._spawn_attack()
	check(player.active_box.damage == float(player.attack_data["damage"])*1.5,"buff multiplies actual attack damage")
	dodge_hit.free()
	await frames(125)
	check(player.damage_buff == 1,"damage buff expires")
	inventory = GameState.state.duplicate(true)
	player.hp = 0
	await frames(2)
	check(arena.ended and GameState.state == inventory,"death preserves materials equipment and records")
	arena.queue_free()
	await frames(2)
	# Transaction rollback on write failure; canonical test save remains intact.
	var path: String = GameState.storage_path
	GameState.storage_path = path+"/missing/save.json"
	check(not GameState.equip("armor","") and GameState.state == inventory,"failed persistence rolls back equip")
	GameState.storage_path = path
	check(GameState.load_save(),"previous valid save survives write failure")
	GameState.state = GameState.fresh()
	GameState.storage_path = path+"/missing/save.json"
	var no_reward: Dictionary = GameState.award_win(DataRegistry.get_boss("golem"),20,"failed-reward-test")
	check(no_reward.is_empty() and not GameState.pending_reward.is_empty() and GameState.state["materials"]["golem_core"] == 0,"failed reward write keeps a pending transaction")
	var promised: Dictionary = GameState.pending_reward["drops"].duplicate()
	GameState.storage_path = path+".reward-retry"
	check(GameState.retry_reward() == promised and GameState.pending_reward.is_empty(),"reward retry persists identical roll without rerolling")
	check(GameState.award_win(DataRegistry.get_boss("golem"),20,"failed-reward-test").is_empty() and GameState.state["records"]["golem"]["kills"] == 1,"retried reward cannot be claimed twice")
	GameState.storage_path = path
	check(GameState.load_save(),"restore main isolated save after reward failure test")
	var corrupt_path: String = path+".corrupt-test"
	var file: FileAccess = FileAccess.open(corrupt_path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	GameState.storage_path = corrupt_path
	check(not GameState.load_save() and GameState.save_blocked,"invalid save blocks progression")
	check(not GameState.save() and FileAccess.get_file_as_string(corrupt_path) == "{broken","invalid original is not overwritten")
	GameState.storage_path = path
	check(GameState.load_save(),"restore valid test save")
	var invalid: Dictionary = GameState.state.duplicate(true)
	invalid["equipped"]["weapon"] = "rock_mail"
	check(not GameState.validate(invalid),"saved loadout slot validation")
	invalid = GameState.state.duplicate(true)
	invalid["materials"]["golem_core"] = -1
	check(not GameState.validate(invalid),"negative saved resources rejected")
	hub = load("res://scenes/hub/Hub.tscn").instantiate()
	add_child(hub)
	await frames(3)
	var shards_before: int = GameState.state["materials"]["golem_shard"]
	hub.craft_buttons["twin_daggers"].grab_focus()
	pad(JOY_BUTTON_A,true)
	await frames(1)
	pad(JOY_BUTTON_A,false)
	await frames(3)
	check("twin_daggers" in GameState.state["owned"] and GameState.state["materials"]["golem_shard"] == shards_before-4,"pad A activates focused crafting control")
	hub.reparent(get_tree().root)
	get_tree().current_scene = hub
	await click_button(hub.boss_buttons["golem"])
	await frames(4)
	arena = get_tree().current_scene
	check(arena.scene_file_path.ends_with("BattleArena.tscn") and arena.player.use_loadout and arena.player.weapon["id"] == "greatsword_slab","actual hub fight button enters equipped progression battle")
	arena.finish(false)
	await frames(2)
	while not arena.result_screen.input_ready: await frames(1)
	await click_button(arena.result_screen.return_button)
	await frames(4)
	check(get_tree().current_scene.scene_file_path.ends_with("Hub.tscn"),"result hub button returns to crafting screen")
	print("GROWTH_SUITE_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
