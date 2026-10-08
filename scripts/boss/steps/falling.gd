extends "res://scripts/boss/steps/Step.gd"
var positions: Array[float] = []
func begin() -> void:
	var target: Node2D = boss.target_player()
	var center: float = target.global_position.x if target != null else origin.x
	for index: int in int(data["count"]):
		var x: float = boss.rng.randf_range(float(boss.arena["left"]),float(boss.arena["right"]))
		if data["x_mode"] == "around_player":
			x = center + (0.0 if int(data["count"]) == 1 else lerpf(-float(data["spread"])/2,float(data["spread"])/2,float(index)/(int(data["count"])-1)))
		x = clampf(x,float(boss.arena["left"])+float(data["size"][0])/2,float(boss.arena["right"])-float(data["size"][0])/2)
		positions.append(x)
		var mark: Node2D = boss.warning({"shape":"rect","size":[data["size"][0],boss.rules["fall_warning_height"]],"color":[1,0.6,0.12,0.2],"target":"self"})
		mark.global_position = Vector2(x,float(boss.arena["floor_y"])-float(boss.rules["fall_warning_height"])/2)
		mark.reset_physics_interpolation()
		nodes.append(mark)
func tick(delta: float) -> bool:
	elapsed += delta
	if elapsed < float(data["warn_time"]): return false
	for x: float in positions:
		var box: CombatProjectile = boss.projectile(data,Vector2(0,float(data["fall_speed"])*boss.speed_mult))
		box.global_position = Vector2(x,data["spawn_y"])
		box.reset_physics_interpolation()
	return true
