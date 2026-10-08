extends "res://scripts/boss/steps/Step.gd"
func begin() -> void:
	var direction: Vector2 = Vector2(boss.facing,0)
	var target: Node2D = boss.target_player()
	if data["aim"] == "down": direction = Vector2.DOWN
	elif data["aim"] == "target" and target != null: direction = (target.global_position-origin).normalized()
	for index: int in int(data["count"]):
		var angle: float = 0 if int(data["count"]) == 1 else lerpf(-float(data["spread_deg"])/2,float(data["spread_deg"])/2,float(index)/(int(data["count"])-1))
		var config: Dictionary = data.duplicate(true)
		if data.has("parriable_indices"):
			config["parriable"] = false
			for allowed: Variant in data["parriable_indices"]:
				if int(allowed) == index: config["parriable"] = true
		boss.projectile(config,direction.rotated(deg_to_rad(angle))*float(data["speed"])*boss.speed_mult)
