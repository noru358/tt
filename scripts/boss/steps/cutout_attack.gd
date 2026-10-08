extends "res://scripts/boss/steps/Step.gd"
func begin() -> void:
	boss.cutout.begin(data["move"])
func tick(delta: float) -> bool:
	return boss.cutout.advance(delta)
func finish() -> void:
	boss.cutout.cancel()
	boss.retry = boss.rng.randf_range(Tuning.golem["idle_min"],Tuning.golem["idle_max"])
