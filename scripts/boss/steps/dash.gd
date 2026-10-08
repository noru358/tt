extends "res://scripts/boss/steps/Step.gd"
var direction: Vector2
var distance: float = 0
func begin() -> void:
	direction = Vector2(boss.facing,0)
	var target: Node2D = boss.target_player()
	if data["direction"] == "to_target" and target != null:
		direction = (target.global_position-origin).normalized()
	if data.has("hitbox"):
		var box: CombatHitbox = boss.make_hitbox(data["hitbox"],float(data["distance"])/float(data["speed"])/boss.speed_mult,true)
		nodes.append(box)
func tick(delta: float) -> bool:
	var travel: float = minf(float(data["speed"])*delta,float(data["distance"])-distance)
	var before: Vector2 = boss.global_position
	boss.global_position = boss.clamp_position(before+direction*travel)
	distance += travel
	return distance >= float(data["distance"]) or boss.global_position.is_equal_approx(before)
