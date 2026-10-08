extends "res://scripts/boss/steps/Step.gd"
func begin() -> void:
	destination = boss.target_position(data["target"],float(data.get("offset_y",0)))
	var gap: float = float(data.get("stop_distance",0))
	if gap > 0:
		destination.x -= signf(destination.x-origin.x)*minf(gap,absf(destination.x-origin.x))
func tick(delta: float) -> bool:
	elapsed += delta
	boss.global_position = boss.global_position.move_toward(destination,float(data["speed"])*delta)
	return boss.global_position.is_equal_approx(destination) or (data.has("max_duration") and elapsed >= float(data["max_duration"]))
