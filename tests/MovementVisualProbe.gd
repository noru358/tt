extends Node
func _ready() -> void:
	var world: Node2D = preload("res://toys/movement/movement_toy.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(0.3).timeout
	print("MOVEMENT_RESTART tile_size=%s" % world.tuning.tile_size)
	var directory: String = OS.get_environment("MOVEMENT_CAPTURE_DIR")
	if not directory.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory+"/room.png")
		world._command("튜닝 F1")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory+"/tuning.png")
	get_tree().quit()
