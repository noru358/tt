extends Node
func _ready() -> void:
	var hz: int = int(OS.get_environment("MOVEMENT_AUDIT_HZ"))
	Engine.physics_ticks_per_second = hz
	var world: Node2D = preload("res://toys/movement/movement_toy.tscn").instantiate()
	add_child(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.controls.set_physics_process(false)
	await get_tree().physics_frame
	world.player.position = Vector2(600,100)
	world.player.controls._current = {&"move_right":1.0}
	world.player.controls._previous = world.player.controls._current.duplicate()
	world.player.controls._pressed_edges = {&"dash":true}
	world.motion.tick(1.0/hz)
	world.player.controls._pressed_edges.clear()
	while world.player.state == GatePlayer.State.DASH:
		await get_tree().physics_frame
		world.motion.tick(1.0/hz)
	var distance: float = world.player.position.x-600
	var passed: bool = absf(distance-float(world.tuning.dash_distance)) < 0.1
	print("DASH_RATE_RESULT hz=%d distance=%.5f passed=%s" % [hz,distance,passed])
	get_tree().quit(0 if passed else 1)
