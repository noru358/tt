extends "res://scripts/boss/steps/Step.gd"
func begin() -> void:
	destination = boss.target_position(data["target"])
func tick(delta: float) -> bool:
	elapsed += delta
	var t: float = minf(1,elapsed/float(data["duration"]))
	boss.global_position = origin.lerp(destination,t)-Vector2(0,4*float(data["height"])*t*(1-t))
	return t >= 1
