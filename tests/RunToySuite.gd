# One-run contract: listed rooms in order, the last goal opens the golem, a boss death
# retries at the golem, a win shows the run clear and writes one run log line.
extends Node
var failures: int = 0
var checks: int = 0
var run: Node

func check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+note)

func frames(count: int) -> void:
	for i: int in count: await get_tree().physics_frame

func _goal(world: Node) -> Vector2:
	for trigger: Dictionary in world.triggers: if trigger.kind == "G": return trigger.position
	return Vector2.INF

func _ready() -> void:
	for key: String in ["RUN_TEST_CONFIG","RUN_TEST_LOG","MOVEMENT_TEST_ROOMS","GOLEM_BASH_TEST_TUNING"]:
		if OS.get_environment(key).is_empty():
			push_error("Scratch paths required: "+key)
			get_tree().quit(1)
			return
	Feedback.invincible = true
	run = preload("res://toys/run/run_toy.tscn").instantiate()
	add_child(run)
	await frames(2)
	var expected: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("RUN_TEST_CONFIG"))).rooms
	check(run.phase == "rooms" and run.stage.rooms == PackedStringArray(expected),"run starts in the listed jump rooms")
	var seen: Array = []
	for i: int in expected.size():
		var world: Node = run.stage
		seen.append(world.rooms[world.room_index])
		var goal: Vector2 = _goal(world)
		check(goal != Vector2.INF,"room %s has a goal" % seen.back())
		world.player.position = goal
		world.player.velocity = Vector2.ZERO
		await frames(3)
	check(seen == expected,"rooms play in run.json order (%s)" % [seen])
	check(run.phase == "boss" and run.stage.has_method("start_round") and is_instance_valid(run.stage.golem),"last goal opens the golem fight")
	var boss: Node = run.stage
	check(float(boss.tuning.move_speed) == float(boss.tuning.boss_move_speed),"golem fight uses boss movement numbers")
	Feedback.invincible = false
	boss.player.hurt_iframe = 0
	boss.player.since_dash = INF
	boss.hurt_player(1000,0)
	check(boss.round_over and run.phase == "boss" and run.boss_attempts == 2,"boss death stays at the golem")
	boss.start_round()
	await frames(2)
	check(not boss.round_over and run.stage == boss,"retry restarts the golem, not the rooms")
	boss.golem.take_damage(INF)
	check(run.phase == "clear" and boss.result_label.text.begins_with("한 판 클리어"),"golem win shows the run clear")
	var lines: PackedStringArray = FileAccess.get_file_as_string(OS.get_environment("RUN_TEST_LOG")).strip_edges().split("\n")
	var entry: Dictionary = JSON.parse_string(lines[-1])
	check(lines.size() == 1 and entry.result == "clear" and entry.boss_attempts == 2,"one run line with result and boss attempts")
	run.queue_free()
	await frames(2)
	check(FileAccess.get_file_as_string(OS.get_environment("RUN_TEST_LOG")).strip_edges().split("\n").size() == 1,"no extra run line on exit after clear")
	print("RUN_TOY_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(failures)
