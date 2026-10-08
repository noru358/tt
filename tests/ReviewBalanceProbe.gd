extends "res://tests/PlayerSuite.gd"

func damage_probe(weapon_id: String, rapid: bool) -> float:
	Tuning.set_value("practice","weapon_id",weapon_id)
	await reset_player(1320,912)
	var before: float = dummy.damage_received
	if not rapid: key(KEY_J,true)
	for tick: int in 180:
		# Standardized stationary target, same range. Exclude movement and hitstop from cadence comparison.
		player.position = Vector2(1320,912)
		if rapid:
			if tick % 3 == 0: key(KEY_J,true)
			elif tick % 3 == 1: key(KEY_J,false)
		await frames(1)
	key(KEY_J,false)
	return dummy.damage_received-before

func _run() -> void:
	arena = load("res://scenes/arena/Arena.tscn").instantiate()
	add_child(arena)
	player = arena.player
	dummy = arena.dummy
	Tuning.set_value("dummy","enabled",false)
	Tuning.feedback["hitstop_on_hit"] = 0
	await frames(10)
	await reset_player(800,912)
	key(KEY_S,true)
	var immune: int = 0
	var start: Vector2 = player.position
	for tick: int in 180:
		if tick % 2 == 0: key(KEY_SHIFT,true)
		else: key(KEY_SHIFT,false)
		await frames(1)
		if player.since_dash <= player.p("dash_iframe"): immune += 1
	key(KEY_S,false)
	key(KEY_SHIFT,false)
	var report: Dictionary = {"dash_immune_ratio":float(immune)/180,"dash_displacement":player.position.distance_to(start),"damage":{}}
	for weapon: Dictionary in Tuning.weapons:
		var held: float = await damage_probe(weapon["id"],false)
		var rapid: float = await damage_probe(weapon["id"],true)
		report["damage"][weapon["id"]] = {"held":held,"rapid":rapid,"relative_difference":absf(rapid-held)/maxf(held,1)}
	print("REVIEW_BALANCE "+JSON.stringify(report))
	check(report["dash_immune_ratio"] <= 0.5,"dash spam immune ratio <= 50 percent")
	for id: String in report["damage"]: check(report["damage"][id]["relative_difference"] <= 0.1,id+" hold/rapid damage difference <=10 percent")
	await reset_player()
	arena.queue_free()
	await frames(3)
	print("REVIEW_BALANCE_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
