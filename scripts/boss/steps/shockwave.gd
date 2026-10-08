extends "res://scripts/boss/steps/Step.gd"
func begin() -> void:
	var directions: Array = [-1,1] if data["direction"] == "both" else [-1 if data["direction"] == "left" else 1]
	for direction: int in directions:
		var config: Dictionary = data.duplicate(true)
		config["size"] = [boss.rules["shockwave_width"],data["height"]]
		var box: CombatProjectile = boss.projectile(config,Vector2(direction*float(data["speed"])*boss.speed_mult,0))
		box.global_position = Vector2(boss.global_position.x,float(boss.arena["floor_y"])-float(data["height"])/2)
		box.reset_physics_interpolation()
