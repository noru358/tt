# Screenshots along the journey route for review (needs a display, e.g. xvfb-run).
# JOURNEY_CAPTURE_DIR=/path godot --path . res://tests/JourneyVisualProbe.tscn
extends Node
func _ready() -> void:
	var world: Node2D = preload("res://toys/journey/journey_toy.tscn").instantiate()
	add_child(world)
	var directory: String = OS.get_environment("JOURNEY_CAPTURE_DIR")
	for spot: Vector2i in [Vector2i(3,15),Vector2i(68,12),Vector2i(118,15),Vector2i(126,15),Vector2i(150,9),Vector2i(178,8),Vector2i(210,11),Vector2i(255,15),Vector2i(326,9),Vector2i(338,9),Vector2i(372,13)]:
		world.player.position = (Vector2(spot)+Vector2(0.5,0.5))*32
		world.player.velocity = Vector2.ZERO
		world.camera.position = world.player.position
		world.camera.reset_smoothing()
		for i: int in 40: await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		if not directory.is_empty(): get_viewport().get_texture().get_image().save_png("%s/journey_%03d.png" % [directory,spot.x])
	print("JOURNEY_CAPTURE done")
	get_tree().quit()
