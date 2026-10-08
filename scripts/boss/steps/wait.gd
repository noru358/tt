extends "res://scripts/boss/steps/Step.gd"
func tick(delta: float) -> bool:
	elapsed += delta
	return elapsed >= float(data["duration"])
