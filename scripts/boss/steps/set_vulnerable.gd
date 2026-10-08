extends "res://scripts/boss/steps/Step.gd"
func begin() -> void:
	boss.vulnerable = data["value"]
