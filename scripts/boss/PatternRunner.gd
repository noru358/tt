extends Node
signal step_started(kind: String)
var boss: Variant
var pending: Array = []
var current: RefCounted
var running: bool = false
var history: Array[String] = []
func start(steps: Array) -> void:
	cancel()
	pending = steps.duplicate(true)
	running = true
func cancel() -> void:
	if current != null: current.finish()
	current = null
	pending.clear()
	running = false
func tick(delta: float) -> void:
	if not running: return
	# Instant steps share a tick; timed steps consume at most this tick's budget.
	while current == null:
		if pending.is_empty():
			running = false
			return
		var data: Dictionary = pending.pop_front()
		var kind: String = data["type"]
		history.append(kind)
		if history.size() > 512: history.pop_front()
		step_started.emit(kind)
		if kind == "repeat":
			pending = load("res://scripts/boss/steps/repeat.gd").expand(data) + pending
			continue
		current = load("res://scripts/boss/steps/"+kind+".gd").new()
		current.setup(boss,data)
		current.begin()
		if kind in ["face_target","set_vulnerable","projectile","shockwave"]:
			current.finish()
			current = null
	if current.tick(delta*boss.speed_mult):
		current.finish()
		current = null
