extends "res://scripts/boss/steps/Step.gd"
func begin() -> void:
	var mark: Node2D = boss.warning(data)
	nodes.append(mark)
