extends RefCounted
var boss: Variant
var data: Dictionary
var elapsed: float = 0.0
var origin: Vector2
var destination: Vector2
var nodes: Array[Node] = []
func setup(owner_boss: Node2D, values: Dictionary) -> void:
	boss = owner_boss
	data = values
	origin = boss.global_position
func begin() -> void:
	pass
func tick(delta: float) -> bool:
	elapsed += delta
	return elapsed >= float(data.get("duration",0))
func finish() -> void:
	for node: Variant in nodes:
		if is_instance_valid(node): node.queue_free()
func vec(value: Array) -> Vector2:
	return Vector2(value[0],value[1])
