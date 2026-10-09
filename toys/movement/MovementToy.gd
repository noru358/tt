extends Node2D
const TUNING_PATH: String = "res://toys/movement/movement_tuning.json"
var tuning_path: String = TUNING_PATH
var room_directory: String = "res://toys/movement/rooms"
var schema: Dictionary
var respawn_generation: int = 0
var tuning: Dictionary
var player: GatePlayer
var motion: Node
var geometry: Node2D
var camera: Camera2D
var panel: PanelContainer
var aim_help: Label
var status: Label
var fade: ColorRect
var rooms: PackedStringArray = []
var room_index: int = 0
var checkpoint: Vector2
var room_size: Vector2
var triggers: Array[Dictionary] = []
var turrets: Array[Dictionary] = []
var respawning: bool = false
var logged: bool = false
var started: int
var log_data: Dictionary

func _ready() -> void:
	get_tree().auto_accept_quit = false
	if not OS.get_environment("MOVEMENT_TEST_TUNING").is_empty(): tuning_path = OS.get_environment("MOVEMENT_TEST_TUNING")
	if not OS.get_environment("MOVEMENT_TEST_ROOMS").is_empty(): room_directory = OS.get_environment("MOVEMENT_TEST_ROOMS")
	schema = JSON.parse_string(FileAccess.get_file_as_string("res://toys/movement/movement_schema.json"))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(tuning_path))
	if not parsed is Dictionary:
		push_error("Movement tuning must be a JSON object")
		get_tree().quit(1)
		return
	for key: String in schema:
		if not parsed.has(key) or not (parsed[key] is float or parsed[key] is int) or float(parsed[key]) < float(schema[key].min) or float(parsed[key]) > float(schema[key].max):
			push_error("Invalid movement tuning field: "+key)
			get_tree().quit(1)
			return
	tuning = parsed
	started = Time.get_ticks_msec()
	log_data = {"started_at":Time.get_datetime_string_from_system(true),"duration_sec":0,"rooms_entered":[],"deaths":0,"bash_count":0,"wall_jump_count":0,"f7_reloads":0}
	for filename: String in DirAccess.get_files_at(room_directory):
		if filename.ends_with(".txt"): rooms.append(filename)
	rooms.sort()
	if not InputMap.has_action("toy_bash"):
		InputMap.add_action("toy_bash")
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_K
		InputMap.action_add_event("toy_bash",key)
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_Y
		InputMap.action_add_event("toy_bash",button)
	player = preload("res://scenes/player/Player.tscn").instantiate()
	player.toy_movement_enabled = true
	add_child(player)
	player.body_size = Vector2(tuning.player_width,tuning.player_height)
	for child: Node in player.get_children():
		if child is CollisionShape2D: child.shape.size = player.body_size
	player.hurtbox.box_size = player.body_size
	motion = preload("res://toys/movement/ToyMotion.gd").new()
	motion.player = player
	motion.world = self
	player.toy_motion = motion
	player.add_child(motion)
	camera = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled = true
	add_child(camera)
	_build_ui()
	load_room(0)

func load_room(index: int, reload_room: bool = false) -> void:
	motion.cancel()
	respawn_generation += 1
	respawning = false
	fade.color.a = 0
	if is_instance_valid(geometry):
		remove_child(geometry)
		geometry.queue_free()
	geometry = Node2D.new()
	add_child(geometry)
	triggers.clear()
	turrets.clear()
	room_index = posmod(index,rooms.size())
	var lines: PackedStringArray = FileAccess.get_file_as_string(room_directory+"/"+rooms[room_index]).strip_edges(false,true).split("\n")
	var width: int = 0
	for line: String in lines: width = maxi(width,line.trim_suffix("\r").length())
	var tile: float = tuning.tile_size
	room_size = Vector2(width,lines.size())*tile
	var spawn: Vector2 = Vector2.ONE*tile
	for row: int in lines.size():
		var line: String = lines[row].trim_suffix("\r")
		for col: int in line.length():
			var c: String = line[col]
			var center: Vector2 = (Vector2(col,row)+Vector2.ONE/2)*tile
			if col > 0 and line[col-1] == "T" and c in "<>AV": continue
			match c:
				"#", "=":
					var body: StaticBody2D = StaticBody2D.new()
					body.position = center
					var collision: CollisionShape2D = CollisionShape2D.new()
					var shape: RectangleShape2D = RectangleShape2D.new()
					shape.size = Vector2(tile,tile if c == "#" else float(tuning.platform_thickness))
					collision.shape = shape
					collision.one_way_collision = c == "="
					body.add_child(collision)
					var visual: Polygon2D = Polygon2D.new()
					var half: Vector2 = shape.size/2
					visual.polygon = PackedVector2Array([-half,Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)])
					visual.color = Color("42536c") if c == "#" else Color("a9c1d8")
					body.add_child(visual)
					geometry.add_child(body)
				"P": spawn = center
				"o", "m": _orb(center,c)
				"C", "^", "G": triggers.append({"kind":c,"position":center})
				"T":
					var direction: String = line[col+1] if col+1 < line.length() else ""
					if not direction in ["<",">","A","V"]: push_warning("Invalid turret direction at %d:%d" % [row+1,col+1])
					else: turrets.append({"position":center,"direction":{"<":Vector2.LEFT,">":Vector2.RIGHT,"A":Vector2.UP,"V":Vector2.DOWN}[direction],"clock":0.0})
				".", " ": pass
				_: push_warning("Unknown room character row=%d col=%d char=%s" % [row+1,col+1,c])
	if not reload_room: checkpoint = spawn
	player.position = checkpoint
	player.hp = player.p("max_hp")
	player.velocity = Vector2.ZERO
	player.state = GatePlayer.State.IDLE
	player.dash_uses = 0
	player.dash_cooldown = 0
	motion.lock_time = 0
	motion.jump_pending = 0
	motion.wall_grace = 0
	motion.launch_age = -1
	motion.coast_remaining = 0
	motion.cooldowns.clear()
	camera.position = player.position
	camera.reset_smoothing()
	log_data.rooms_entered.append(rooms[room_index])
	queue_redraw()

func _orb(at: Vector2, kind: String) -> Node2D:
	var orb: Node2D = preload("res://toys/movement/Bashable.gd").new()
	orb.world = self
	orb.kind = kind
	orb.position = at
	geometry.add_child(orb)
	return orb

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or panel.visible: return
	for turret: Dictionary in turrets:
		turret.clock += delta
		if turret.clock >= float(tuning.turret_interval):
			turret.clock = 0
			var bullet: Node2D = _orb(turret.position,"bullet")
			bullet.velocity = turret.direction*float(tuning.projectile_speed)
	if respawning or panel.visible: return
	for trigger: Dictionary in triggers:
		var rect: Rect2 = Rect2(trigger.position-Vector2.ONE*float(tuning.tile_size)/2,Vector2.ONE*float(tuning.tile_size))
		if rect.intersects(Rect2(player.position-player.body_size/2,player.body_size)):
			match trigger.kind:
				"C": checkpoint = trigger.position
				"^":
					if not Feedback.invincible: respawn()
				"G":
					load_room(room_index+1)
					return
	if player.position.y > room_size.y: respawn()

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	motion.flash_remaining = maxf(0,motion.flash_remaining-delta)
	var viewport: Vector2 = get_viewport_rect().size
	var zoom_value: float = maxf(viewport.x/float(tuning.camera_view_width),viewport.y/float(tuning.camera_view_height))
	camera.zoom = Vector2.ONE*zoom_value
	camera.position_smoothing_speed = tuning.camera_smoothing
	var half: Vector2 = viewport/zoom_value/2
	var padding: Vector2 = (half-room_size/2).max(Vector2.ZERO)
	camera.limit_left = int(-padding.x)
	camera.limit_top = int(-padding.y)
	camera.limit_right = int(room_size.x+padding.x)
	camera.limit_bottom = int(room_size.y+padding.y)
	camera.position = Vector2(
		room_size.x/2 if room_size.x < half.x*2 else clampf(player.position.x,half.x,room_size.x-half.x),
		room_size.y/2 if room_size.y < half.y*2 else clampf(player.position.y,half.y,room_size.y-half.y))
	status.text = "%s   %.1f분   HP %d   사망 %d   배시 %d   %s" % [rooms[room_index],(Time.get_ticks_msec()-started)/60000.0,player.hp,log_data.deaths,log_data.bash_count,"무적 ON" if Feedback.invincible else ""]
	aim_help.text = "K 유지 → %s → K 놓으면 발사 · R: 조준 방식 전환" % ("WASD 8방향 조준" if motion.direct_aim else "방향키 ↑↓←→ 8방향 조준")
	if is_instance_valid(motion.target): aim_help.text = "잡힘! WASD 조준 · K 놓으면 발사" if motion.direct_aim else "잡힘! 방향키 조준 · K 놓으면 발사"
	queue_redraw()

func respawn() -> void:
	if respawning: return
	respawning = true
	log_data.deaths += 1
	motion.cancel()
	respawn_generation += 1
	var generation: int = respawn_generation
	var tween: Tween = create_tween().set_ignore_time_scale(true)
	tween.tween_property(fade,"color:a",1.0,float(tuning.respawn_fade)/2)
	await tween.finished
	if generation != respawn_generation: return
	player.position = checkpoint
	player.velocity = Vector2.ZERO
	player.hp = player.p("max_hp")
	player.state = GatePlayer.State.IDLE
	player.dash_uses = 0
	player.dash_cooldown = 0
	motion.lock_time = 0
	motion.jump_pending = 0
	motion.wall_grace = 0
	motion.launch_age = -1
	motion.coast_remaining = 0
	tween = create_tween().set_ignore_time_scale(true)
	tween.tween_property(fade,"color:a",0.0,float(tuning.respawn_fade)/2)
	await tween.finished
	if generation == respawn_generation: respawning = false

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(20,16)
	layer.add_child(column)
	status = Label.new()
	column.add_child(status)
	aim_help = Label.new()
	aim_help.text = "K 유지 → WASD 8방향 조준 → K 놓으면 발사 · R: 조준 방식 전환"
	column.add_child(aim_help)
	var movement_help: Label = Label.new()
	movement_help.text = "이동 WASD · 점프 Space · 공중 대시 Shift 2회 · 패드 Y 튕기기 / 왼쪽 스틱 조준"
	column.add_child(movement_help)
	var buttons: HBoxContainer = HBoxContainer.new()
	column.add_child(buttons)
	for title: String in ["조준 전환 R","튜닝 F1","판정 F2","무적 F5","속도 F6","다시 읽기 F7","이전 Shift+F8","다음 F8","종료"]:
		var button: Button = Button.new()
		button.text = title
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_command.bind(title))
		buttons.add_child(button)
	panel = PanelContainer.new()
	panel.position = Vector2(20,150)
	panel.size = Vector2(700,650)
	layer.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	panel.add_child(scroll)
	var values: VBoxContainer = VBoxContainer.new()
	values.custom_minimum_size.x = 650
	scroll.add_child(values)
	var save: Button = Button.new()
	save.text = "수치 저장 (movement_tuning.json)"
	save.pressed.connect(func() -> void:
		var file: FileAccess = FileAccess.open(tuning_path,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(tuning,"  ")+"\n"); save.text = "저장 완료"
		else: save.text = "저장 실패: 프로젝트 쓰기 권한 확인")
	values.add_child(save)
	for key: String in tuning:
		var label: Label = Label.new()
		label.text = "%s: %s" % [key,tuning[key]]
		values.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.min_value = schema[key].min
		slider.max_value = schema[key].max
		slider.step = schema[key].step
		slider.value = tuning[key]
		slider.value_changed.connect(func(value: float) -> void:
			tuning[key] = value
			label.text = "%s: %.3f" % [key,value]
			if key in ["player_width","player_height"]:
				player.body_size = Vector2(tuning.player_width,tuning.player_height)
				for child: Node in player.get_children():
					if child is CollisionShape2D: child.shape.size = player.body_size
				player.hurtbox.box_size = player.body_size
			if key in ["tile_size","platform_thickness"]: load_room(room_index))
		values.add_child(slider)
	panel.hide()
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0,0,0,0)
	layer.add_child(fade)

func _command(title: String) -> void:
	match title:
		"조준 전환 R": motion.direct_aim = not motion.direct_aim
		"튜닝 F1":
			panel.visible = not panel.visible
			motion.cancel()
			player.controls.set_blocked(panel.visible)
		"판정 F2": Feedback.boxes_visible = not Feedback.boxes_visible
		"무적 F5": Feedback.invincible = not Feedback.invincible
		"속도 F6": Feedback.set_speed(float(tuning.slow_speed) if Feedback.base_speed == 1 else 1)
		"다시 읽기 F7":
			log_data.f7_reloads += 1
			load_room(room_index,true)
		"이전 Shift+F8": load_room(room_index-1)
		"다음 F8": load_room(room_index+1)
		"종료":
			write_log()
			get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_R: _command("조준 전환 R")
		KEY_F1, KEY_TAB: _command("튜닝 F1")
		KEY_F2: _command("판정 F2")
		KEY_F5: _command("무적 F5")
		KEY_F6: _command("속도 F6")
		KEY_F7: _command("다시 읽기 F7")
		KEY_F8: _command("이전 Shift+F8" if event.shift_pressed else "다음 F8")

func _draw() -> void:
	if not is_instance_valid(player): return
	for item: Dictionary in triggers:
		var color: Color = Color.ORANGE_RED if item.kind == "^" else (Color.GOLD if item.kind == "G" else Color.SEA_GREEN)
		var half: float = float(tuning.tile_size)/2
		if item.kind == "^": draw_colored_polygon(PackedVector2Array([item.position+Vector2(-half,half),item.position+Vector2(0,-half),item.position+Vector2(half,half)]),color)
		else:
			draw_circle(item.position,half/2,color)
			if item.kind == "C" and item.position == checkpoint: draw_arc(item.position,half/2+3,0,TAU,32,Color.WHITE,2)
	for turret: Dictionary in turrets:
		draw_rect(Rect2(turret.position-Vector2.ONE*10,Vector2.ONE*20),Color.SALMON)
		draw_line(turret.position,turret.position+turret.direction*20,Color.WHITE,3)
	if Feedback.boxes_visible:
		draw_arc(player.position,float(tuning.bash_radius),0,TAU,64,Color.CYAN,1)
		draw_rect(Rect2(player.position-player.body_size/2,player.body_size),Color.YELLOW,false)
	if motion.flash_remaining > 0:
		var strength: float = motion.flash_remaining/float(tuning.bash_flash_time)
		var glow: Color = Color(0.4,1,1,strength)
		draw_line(player.position-motion.launch_direction*float(tuning.bash_trail_length)*strength,player.position,glow,6*strength)
		draw_arc(motion.launch_origin,float(tuning.bash_burst_radius)*(1-strength),0,TAU,32,glow,3)
	if is_instance_valid(motion.target):
		var start: Vector2 = motion.target.position
		draw_arc(start,float(tuning.orb_radius)+6,0,TAU,32,Color.GOLD,3)
		draw_line(player.position,start,Color.GOLD,2)
		var end: Vector2 = start+motion.aim*float(tuning.bash_radius)
		draw_line(start,end,Color.WHITE,3)
		draw_line(end,end-motion.aim.rotated(0.5)*12,Color.WHITE,3)
		draw_line(end,end-motion.aim.rotated(-0.5)*12,Color.WHITE,3)

func write_log() -> void:
	if log_data.is_empty(): return
	if logged: return
	var path: String = OS.get_environment("MOVEMENT_TEST_LOG")
	if path.is_empty(): path = "user://toy_movement_log.jsonl"
	var file: FileAccess = FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if not file:
		push_error("Cannot write movement session log")
		return
	log_data.duration_sec = (Time.get_ticks_msec()-started)/1000.0
	file.seek_end()
	file.store_line(JSON.stringify(log_data))
	file.flush()
	logged = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		write_log()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(motion): motion.cancel()

func _exit_tree() -> void:
	write_log()
	Engine.time_scale = 1
