# One run: a few jump-map rooms, then the golem. Each part keeps its own toy and
# movement numbers (jump map: movement_tuning.json, golem: its boss_* overrides).
extends Node
const RUN_PATH: String = "res://toys/run/run.json"
var run_path: String = RUN_PATH
var log_path: String = "user://toy_run_log.jsonl"
var stage: Node
var phase: String = ""
var started: int = 0
var boss_started: int = 0
var boss_attempts: int = 0
var logged: bool = false
var rooms: PackedStringArray = []

func _ready() -> void:
	if not OS.get_environment("RUN_TEST_CONFIG").is_empty(): run_path = OS.get_environment("RUN_TEST_CONFIG")
	if not OS.get_environment("RUN_TEST_LOG").is_empty(): log_path = OS.get_environment("RUN_TEST_LOG")
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(run_path))
	if not config is Dictionary or not config.get("rooms") is Array or config.rooms.is_empty():
		push_error("run.json needs a non-empty rooms list")
		get_tree().quit(1)
		return
	for room: Variant in config.rooms: rooms.append(str(room))
	started = Time.get_ticks_msec()
	_start_rooms()

func _start_rooms() -> void:
	phase = "rooms"
	stage = preload("res://toys/movement/movement_toy.tscn").instantiate()
	stage.room_filter = rooms
	stage.rooms_finished.connect(func() -> void: _to_boss.call_deferred())
	add_child(stage)
	DisplayServer.window_set_title("한 판 — 점프 구간")

func _to_boss() -> void:
	if phase != "rooms": return
	phase = "boss"
	remove_child(stage)
	stage.queue_free()
	boss_started = Time.get_ticks_msec()
	stage = preload("res://toys/golem_bash/golem_bash_toy.tscn").instantiate()
	stage.round_finished.connect(_on_boss_round)
	add_child(stage)
	boss_attempts = 1
	DisplayServer.window_set_title("한 판 — 골렘")
	stage.fx_text(stage.player.position+Vector2(-40,-60),"골렘 방",Color(1,0.9,0.6),22)

func _on_boss_round(result: String) -> void:
	if result == "win":
		phase = "clear"
		var total: float = (Time.get_ticks_msec()-started)/1000.0
		var boss: float = (Time.get_ticks_msec()-boss_started)/1000.0
		stage.result_label.text = "한 판 클리어!   총 %.1f초 (점프 %.1f초 · 골렘 %.1f초, %d번째 도전)" % [total,total-boss,boss,boss_attempts]
		write_log("clear")
	else:
		# Boss retries restart at the golem, not the first room.
		boss_attempts += 1

func write_log(result: String) -> void:
	if logged or phase == "": return
	logged = true
	var file: FileAccess = FileAccess.open(log_path,FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if not file:
		push_error("Cannot write run log")
		return
	file.seek_end()
	var now: int = Time.get_ticks_msec()
	file.store_line(JSON.stringify({"result":result,"reached":phase,"rooms":rooms,"total_sec":(now-started)/1000.0,"boss_sec":(now-boss_started)/1000.0 if boss_started > 0 else null,"boss_attempts":boss_attempts}))

func _exit_tree() -> void:
	write_log("quit")
