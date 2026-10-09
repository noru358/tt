# Saves GPU captures of the golem bash toy states to GOLEM_BASH_CAPTURES (needs a display).
extends Node
var world: Node2D
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("GOLEM_BASH_CAPTURES")+"/"+name+".png")

func _ready() -> void:
	world = preload("res://toys/golem_bash/golem_bash_toy.tscn").instantiate()
	add_child(world)
	var golem: Node2D = world.golem
	await get_tree().create_timer(0.3).timeout
	world.player.position = Vector2(golem.position.x-180,world.floor_y-14)
	golem.cooldown = INF
	Feedback.invincible = true
	await get_tree().create_timer(0.3).timeout
	await shot("idle")
	# Walk: let it take a stride toward the player, capture mid-stride and at the footfall.
	world.player.position = Vector2(golem.position.x-400,world.floor_y-14)
	while golem.step_u < 0.35: await get_tree().physics_frame
	await shot("walk_mid")
	while not golem.step_landed: await get_tree().physics_frame
	await shot("walk_land")
	world.player.position = Vector2(golem.position.x-180,world.floor_y-14)
	await get_tree().create_timer(1.0).timeout
	for move: String in ["slam","stomp","sweep"]:
		golem.begin_attack(move)
		await get_tree().create_timer(float(world.tuning.telegraph_time)*0.7).timeout
		await shot(move+"_windup")
		while not golem.impacted: await get_tree().physics_frame
		await get_tree().create_timer(0.25 if move == "stomp" else 0.05).timeout
		await shot(move+"_open")
		while golem.state == "attack": await get_tree().physics_frame
		golem.cooldown = INF
	world.last_bash_time = world.game_time
	Feedback.boxes_visible = true
	await shot("hitboxes")
	Feedback.boxes_visible = false
	golem.weak_hits = 99
	golem._check_kneel()
	await get_tree().create_timer(0.2).timeout
	await shot("kneel_falling")
	await get_tree().create_timer(0.4).timeout
	world.fx_text(golem.weak_center()+Vector2(-26,-40),"약점! 40",Color(1,0.9,0.35),20)
	world.fx_spark(golem.weak_center(),Color(1,0.9,0.4),14,260)
	await get_tree().create_timer(0.08).timeout
	await shot("kneel")
	get_tree().quit()
