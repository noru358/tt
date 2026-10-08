extends "res://scripts/boss/steps/Step.gd"
func begin() -> void:
	nodes.append(boss.make_hitbox(data,float(data["duration"])/boss.speed_mult,data["attach"] == "self"))
