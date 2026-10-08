extends "res://scripts/boss/steps/Step.gd"
func begin() -> void:
	var target: Node2D = boss.target_player()
	if target != null and target.global_position.x != boss.global_position.x:
		boss.facing = int(signf(target.global_position.x-boss.global_position.x))
