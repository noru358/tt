# Golem bash boss toy. Reuses the movement toy's player setup and ToyMotion unchanged;
# golem-only numbers live in golem_bash_tuning.json.
extends Node2D
signal round_finished(result: String)
const MOVEMENT_TUNING_PATH: String = "res://toys/movement/movement_tuning.json"
const TUNING_PATH: String = "res://toys/golem_bash/golem_bash_tuning.json"
const ARENA_PATH: String = "res://toys/golem_bash/arena.txt"
const AIM_SIDE_BIAS: float = 2.0
var movement_path: String = MOVEMENT_TUNING_PATH
var tuning_path: String = TUNING_PATH
var arena_path: String = ARENA_PATH
var log_path: String = "user://toy_golem_bash_log.jsonl"
var schema: Dictionary
var golem_keys: Array = []
var tuning: Dictionary
var player: GatePlayer
var motion: Node
var golem: Node2D
var geometry: Node2D
var camera: Camera2D
var panel: PanelContainer
var result_panel: PanelContainer
var result_label: Label
var status: Label
var aim_help: Label
var spawn: Vector2
var golem_spawn: Vector2
var arena_size: Vector2
var floor_y: float
var respawning: bool = false
var game_time: float = 0
var last_bash_time: float = -INF
var golem_attacks: Dictionary = {}
var log_data: Dictionary = {}
var round_started: int = 0
var round_over: bool = false
var ended_at: int = 0
var pending_log: Dictionary = {}
var deaths_total: int = 0
var swing_time: float = -1
var swing_kind: String = ""
var swing_hit: bool = false
var swing_cooldown: float = 0
var swing_rect: Rect2
var prompt: Label
var hurt_overlay: ColorRect
var freeze_left: int = 0
var grabbed: Node2D
var fx: Array = []
var dodge_text_at: float = -INF
var attack_queued: bool = false
var base_launch_speed: float = 0
var part_launch: bool = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	DisplayServer.window_set_title("골렘 튕기기 장난감")
	if not OS.get_environment("GOLEM_BASH_TEST_TUNING").is_empty(): tuning_path = OS.get_environment("GOLEM_BASH_TEST_TUNING")
	if not OS.get_environment("GOLEM_BASH_TEST_ARENA").is_empty(): arena_path = OS.get_environment("GOLEM_BASH_TEST_ARENA")
	if not OS.get_environment("GOLEM_BASH_TEST_LOG").is_empty(): log_path = OS.get_environment("GOLEM_BASH_TEST_LOG")
	if not OS.get_environment("MOVEMENT_TEST_TUNING").is_empty(): movement_path = OS.get_environment("MOVEMENT_TEST_TUNING")
	var movement: Variant = JSON.parse_string(FileAccess.get_file_as_string(movement_path))
	schema = JSON.parse_string(FileAccess.get_file_as_string("res://toys/golem_bash/golem_bash_schema.json"))
	var own: Variant = JSON.parse_string(FileAccess.get_file_as_string(tuning_path))
	if not movement is Dictionary or not own is Dictionary:
		push_error("Golem bash tuning files must be JSON objects")
		get_tree().quit(1)
		return
	tuning = movement
	for key: String in schema:
		if not own.has(key) or not (own[key] is float or own[key] is int) or float(own[key]) < float(schema[key].min) or float(own[key]) > float(schema[key].max):
			push_error("Invalid golem bash tuning field: "+key)
			get_tree().quit(1)
			return
		tuning[key] = own[key]
		golem_keys.append(key)
	base_launch_speed = float(tuning.bash_launch_speed)
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
	player.collision_mask |= 4
	player.controls.toy_dash_aim = true
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
	Feedback.camera = camera
	_build_ui()
	load_arena()
	golem = preload("res://toys/golem_bash/Golem.gd").new()
	golem.world = self
	golem.position = golem_spawn
	add_child(golem)
	start_round()

func load_arena() -> void:
	if is_instance_valid(geometry):
		remove_child(geometry)
		geometry.queue_free()
	geometry = Node2D.new()
	add_child(geometry)
	var lines: PackedStringArray = FileAccess.get_file_as_string(arena_path).strip_edges(false,true).split("\n")
	var width: int = 0
	for line: String in lines: width = maxi(width,line.trim_suffix("\r").length())
	var tile: float = tuning.tile_size
	arena_size = Vector2(width,lines.size())*tile
	spawn = Vector2.ONE*tile
	golem_spawn = Vector2(arena_size.x/2,(lines.size()-1)*tile)
	for row: int in lines.size():
		var line: String = lines[row].trim_suffix("\r")
		for col: int in line.length():
			var c: String = line[col]
			var center: Vector2 = (Vector2(col,row)+Vector2.ONE/2)*tile
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
				"B": golem_spawn = Vector2(center.x,(row+1)*tile)
				".", " ": pass
				_: push_warning("Unknown arena character row=%d col=%d char=%s" % [row+1,col+1,c])
	floor_y = golem_spawn.y

func golem_margin() -> float:
	return float(tuning.tile_size)*3

func paused() -> bool:
	return panel.visible or round_over

# Hitstop: golem and player hold still for a few physics frames; camera shake keeps going.
func frozen() -> bool:
	return freeze_left > 0

func freeze(frames: int) -> void:
	if frames <= 0: return
	freeze_left = maxi(freeze_left,frames)
	player.set_physics_process(false)

func fx_spark(at: Vector2, color: Color, count: int, speed: float) -> void:
	for i: int in count:
		var direction: Vector2 = Vector2.from_angle(randf()*TAU)
		fx.append({"kind":"spark","pos":at,"vel":direction*speed*randf_range(0.5,1.0),"age":0.0,"life":randf_range(0.2,0.35),"color":color})

func fx_dust(at: Vector2, count: int) -> void:
	for i: int in count:
		fx.append({"kind":"dust","pos":at+Vector2(randf_range(-14,14),-4),"vel":Vector2(randf_range(-70,70),randf_range(-60,-15)),"age":0.0,"life":randf_range(0.4,0.7),"color":Color(0.72,0.66,0.56)})

func fx_text(at: Vector2, text: String, color: Color, size: int) -> void:
	fx.append({"kind":"text","pos":at,"vel":Vector2(0,-45),"age":0.0,"life":0.8,"color":color,"text":text,"size":size})

func start_round() -> void:
	if not pending_log.is_empty():
		pending_log.retry_within_sec = (Time.get_ticks_msec()-ended_at)/1000.0
		_write(pending_log)
		pending_log = {}
	round_over = false
	result_panel.hide()
	player.controls.set_blocked(false)
	motion.cancel()
	player.position = spawn
	player.velocity = Vector2.ZERO
	player.hp = player.p("max_hp")
	player.state = GatePlayer.State.IDLE
	player.dash_uses = 0
	player.dash_cooldown = 0
	player.hurt_iframe = 0
	motion.reset_motion()
	freeze_left = 0
	attack_queued = false
	player.set_physics_process(true)
	player.modulate = Color.WHITE
	grabbed = null
	fx.clear()
	golem.position = golem_spawn
	golem.reset()
	golem_attacks.clear()
	last_bash_time = -INF
	swing_time = -1
	swing_cooldown = 0
	round_started = Time.get_ticks_msec()
	log_data = {"started_at":Time.get_datetime_string_from_system(true),"duration_sec":0,"result":"","deaths_before":deaths_total,"bash_count":0,"bash_by_source":{"fist":0,"rock":0,"arm":0},"weak_hits":0,"kneels":0,"retry_within_sec":null,"rock_hits":0,"wall_jump_count":0}
	camera.position = player.position
	camera.reset_smoothing()

func round_end(result: String) -> void:
	if round_over: return
	round_over = true
	if result == "death": deaths_total += 1
	motion.cancel()
	player.controls.set_blocked(true)
	log_data.result = result
	log_data.duration_sec = (Time.get_ticks_msec()-round_started)/1000.0
	pending_log = log_data.duplicate(true)
	ended_at = Time.get_ticks_msec()
	result_label.text = ("승리!" if result == "win" else "쓰러졌다") + "   %.1f초 · 튕기기 %d · 약점 %d · 무릎 %d" % [log_data.duration_sec,log_data.bash_count,log_data.weak_hits,log_data.kneels]
	result_panel.show()
	if result == "win": Sfx.play("win")
	round_finished.emit(result)

func _write(entry: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(log_path,FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if not file:
		push_error("Cannot write golem bash log")
		return
	file.seek_end()
	file.store_line(JSON.stringify(entry))
	file.flush()

func write_quit_log() -> void:
	if not pending_log.is_empty():
		_write(pending_log)
		pending_log = {}
	elif not round_over and not log_data.is_empty():
		log_data.result = "quit"
		log_data.duration_sec = (Time.get_ticks_msec()-round_started)/1000.0
		_write(log_data)
	log_data = {}

func player_rect() -> Rect2:
	return Rect2(player.position-player.body_size/2,player.body_size)

func hurt_player(amount: float, from_x: float) -> void:
	if round_over or Feedback.invincible or player.hurt_iframe > 0 or amount <= 0: return
	# Dash frames dodge everything (the cyan outline on the player shows the window).
	if player.since_dash <= float(tuning.dash_iframe):
		if game_time-dodge_text_at > 0.5:
			dodge_text_at = game_time
			fx_text(player.position+Vector2(-16,-30),"회피!",Color(0.5,1,1),14)
			Sfx.play("dodge")
		return
	player.hp -= amount
	Sfx.play("hurt")
	freeze(int(tuning.hitstop_frames)+2)
	Feedback.shake_strength = maxf(Feedback.shake_strength,8)
	hurt_overlay.color.a = 0.35
	fx_spark(player.position,Color(1,0.35,0.3),8,180)
	fx_text(player.position+Vector2(-12,-34),"-%d" % int(amount),Color(1,0.4,0.35),16)
	player.hurt_iframe = float(tuning.player_hurt_iframe)
	motion.cancel()
	motion.launch_age = -1
	player.velocity = Vector2(signf(player.position.x-from_x+0.01)*float(tuning.player_knockback),-220)
	if player.hp <= 0: round_end("death")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	if freeze_left > 0:
		# A swing pressed during hitstop fires as soon as it ends.
		if player.controls.just_pressed(&"attack"): attack_queued = true
		freeze_left -= 1
		if freeze_left == 0: player.set_physics_process(true)
		return
	if paused(): return
	game_time += delta
	_auto_aim()
	_part_boost()
	swing_cooldown = maxf(0,swing_cooldown-delta)
	var attack_pressed: bool = player.controls.just_pressed(&"attack") or attack_queued
	attack_queued = false
	if attack_pressed and swing_cooldown <= 0 and not is_instance_valid(motion.target):
		var vertical: float = player.controls.vertical()
		swing_kind = "up" if vertical < 0 else ("down" if vertical > 0 and (not player.is_on_floor() or golem.on_platform()) else "side")
		swing_time = 0
		swing_hit = false
		swing_cooldown = float(tuning.attack_cooldown)
		Sfx.play("swing")
	if swing_time >= 0:
		swing_time += delta
		swing_rect = _swing_rect()
		if not swing_hit:
			var result: String = golem.receive_player_hit(swing_rect)
			if result != "":
				swing_hit = true
				_hit_feedback(result)
				if swing_kind == "down":
					# Pogo: bounce up, refill air dashes, keep the weakpoint open.
					motion.launch_age = -1
					motion.coast_remaining = 0
					player.velocity.y = -float(tuning.pogo_velocity)
					player.dash_uses = 0
					player.dash_cooldown = 0
					if result == "weak": last_bash_time = game_time
		if swing_time >= float(tuning.attack_active): swing_time = -1
	if player.position.y > arena_size.y: round_end("death")

func _hit_feedback(result: String) -> void:
	Sfx.play("weak_hit" if result == "weak" else "body_hit")
	if result == "weak":
		var at: Vector2 = golem.weak_center()
		freeze(int(tuning.hitstop_frames)+2)
		Feedback.shake_strength = maxf(Feedback.shake_strength,6)
		fx_spark(at,Color(1,0.9,0.4),14,260)
		fx_text(at+Vector2(-26,-40),"약점! %d" % int(tuning.weak_hit_damage),Color(1,0.9,0.35),20)
	else:
		var at: Vector2 = swing_rect.get_center()
		freeze(2)
		Feedback.shake_strength = maxf(Feedback.shake_strength,2)
		fx_spark(at,Color(0.7,0.7,0.7),5,140)
		fx_text(at+Vector2(-10,-20),"%d" % ceili(float(tuning.weak_hit_damage)*float(tuning.body_damage_mult)),Color(0.75,0.75,0.75),13)

# Golem parts fling harder than rocks (part_launch_mult) so a fist or arm bash can clear the shoulders.
# Only this toy's in-memory copy changes; movement_tuning.json stays as approved.
func _part_boost() -> void:
	var holding_part: bool = is_instance_valid(motion.target) and motion.target.kind != "rock"
	if holding_part: part_launch = true
	elif not is_instance_valid(motion.target) and motion.launch_age < 0: part_launch = false
	tuning.bash_launch_speed = base_launch_speed*(float(tuning.part_launch_mult) if part_launch else 1.0)

# Right after grabbing, point the launch somewhere useful; any aim input still overrides it.
func _auto_aim() -> void:
	var target: Node2D = motion.target if is_instance_valid(motion.target) else null
	if target == grabbed: return
	grabbed = target
	if target == null or float(tuning.auto_aim) <= 0: return
	if target.kind == "rock":
		# The rock flies opposite to the player's launch: send it into the golem's chest.
		motion.aim = -(golem.torso.to_global(Vector2(20,-120))-target.global_position).normalized()
	else:
		# Air control bleeds sideways speed after a launch, so lean the aim further sideways than the straight line.
		var gap: Vector2 = golem.weak_center()+Vector2(0,-50)-target.global_position
		motion.aim = Vector2(gap.x*AIM_SIDE_BIAS,gap.y).normalized()

func context_hint() -> String:
	if is_instance_valid(motion.target):
		if motion.target.kind == "rock": return "돌을 잡았다! K를 놓으면 돌이 골렘에게 날아간다 (방향은 WASD로 바꿀 수 있음)"
		return "잡았다! K를 놓으면 등 위 약점 쪽으로 날아간다 (방향은 WASD로 바꿀 수 있음)"
	if golem.state == "kneel": return "쓰러졌다! 금색 약점을 마구 때려라 (W+J 위로, 위에서는 S+J)"
	if golem.weak_open(): return "약점 열림! 어깨 위 금색 결정을 J로 (공중에서 S+J로 튕기며 연타)"
	if golem.hand.open: return "주먹이 박혔다! 가까이 가서 K를 눌러 잡기" if golem.hand.kind == "fist" else "팔이 지나간다! 가까이서 K로 잡기"
	for rock: Node2D in golem.rocks: if is_instance_valid(rock) and rock.open: return "떨어지는 돌에 K → 놓으면 골렘에게 던진다"
	if golem.state == "attack" and golem.clock < golem.segments[0][0]:
		match golem.attack_id:
			"slam": return "내려찍기 준비! 피한 뒤 박힌 주먹을 K로 잡아라 (대시 중엔 무적)"
			"stomp": return "발구르기 준비! 충격파는 점프로, 튀어 오른 돌은 K로"
			"sweep": return "휘두르기 준비! 위로 피하거나 대시로 통과 (대시 중엔 무적)"
	return "공격을 피하고 주먹·팔·돌을 K로 튕겨서 약점을 열어라"

func _swing_rect() -> Rect2:
	var size: Vector2 = Vector2(float(tuning.attack_reach),float(tuning.attack_height))
	var half: Vector2 = player.body_size/2
	match swing_kind:
		"up": return Rect2(player.position+Vector2(-size.y/2,-half.y-size.x),Vector2(size.y,size.x))
		"down": return Rect2(player.position+Vector2(-size.y/2,half.y),Vector2(size.y,size.x))
	var x: float = half.x if player.facing > 0 else -half.x-size.x
	return Rect2(player.position+Vector2(x,-size.y/2),size)

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	motion.flash_remaining = maxf(0,motion.flash_remaining-delta)
	for item: Dictionary in fx.duplicate():
		item.age += delta
		if item.age >= item.life:
			fx.erase(item)
			continue
		item.pos += item.vel*delta
		if item.kind == "spark": item.vel *= 0.9
		elif item.kind == "dust": item.vel.y += 60*delta
	hurt_overlay.color.a = move_toward(hurt_overlay.color.a,0,delta*1.2)
	# Blink while the post-hit invincibility lasts.
	player.modulate = Color(1,0.6,0.6,0.35 if fmod(player.hurt_iframe,0.16) < 0.08 else 1.0) if player.hurt_iframe > 0 and not round_over else Color.WHITE
	var viewport: Vector2 = get_viewport_rect().size
	var zoom_value: float = maxf(viewport.x/float(tuning.camera_view_width),viewport.y/float(tuning.camera_view_height))
	camera.zoom = Vector2.ONE*zoom_value
	camera.position_smoothing_speed = tuning.camera_smoothing
	var half: Vector2 = viewport/zoom_value/2
	var padding: Vector2 = (half-arena_size/2).max(Vector2.ZERO)
	camera.limit_left = int(-padding.x)
	camera.limit_top = int(-padding.y)
	camera.limit_right = int(arena_size.x+padding.x)
	camera.limit_bottom = int(arena_size.y+padding.y)
	camera.position = Vector2(
		arena_size.x/2 if arena_size.x < half.x*2 else clampf(player.position.x,half.x,arena_size.x-half.x),
		arena_size.y/2 if arena_size.y < half.y*2 else clampf(player.position.y,half.y,arena_size.y-half.y))
	status.text = "HP %d   골렘 %d/%d   튕기기 %d   약점 %d   무릎 %d   %s" % [maxf(0,player.hp),golem.hp,int(tuning.golem_max_hp),log_data.get("bash_count",0),log_data.get("weak_hits",0),log_data.get("kneels",0),"무적 ON" if Feedback.invincible else ""]
	aim_help.text = "K 유지 → WASD 조준 → K 놓으면 튕기기 · J 공격 (S+J 공중 내려찍기) · Shift 대시(무적)"
	prompt.text = context_hint()
	prompt.size.x = get_viewport_rect().size.x
	prompt.position.y = get_viewport_rect().size.y*0.18
	queue_redraw()

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(20,16)
	layer.add_child(column)
	status = Label.new()
	column.add_child(status)
	aim_help = Label.new()
	column.add_child(aim_help)
	hurt_overlay = ColorRect.new()
	hurt_overlay.color = Color(1,0.1,0.1,0)
	hurt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hurt_overlay)
	layer.move_child(hurt_overlay,0)
	prompt = Label.new()
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size",24)
	prompt.add_theme_color_override("font_outline_color",Color.BLACK)
	prompt.add_theme_constant_override("outline_size",6)
	layer.add_child(prompt)
	var movement_help: Label = Label.new()
	movement_help.text = "이동 WASD · 점프 Space · 대시 Shift · 주먹(내려찍기 후)·돌(발구르기 후 낙하 중)·팔(휘두르는 중)을 튕길 수 있음"
	column.add_child(movement_help)
	var buttons: HBoxContainer = HBoxContainer.new()
	column.add_child(buttons)
	for title: String in ["조준 전환 R","튜닝 F1","판정 F2","무적 F5","속도 F6","다시 읽기 F7","골렘 리셋 F9","종료"]:
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
	save.text = "수치 저장 (golem_bash_tuning.json)"
	save.pressed.connect(func() -> void:
		if save_tuning(): save.text = "저장 완료"
		else: save.text = "저장 실패: 프로젝트 쓰기 권한 확인")
	values.add_child(save)
	for key: String in schema:
		var label: Label = Label.new()
		label.text = "%s: %s" % [key,tuning.get(key,"")]
		values.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.min_value = schema[key].min
		slider.max_value = schema[key].max
		slider.step = schema[key].step
		slider.value = float(tuning.get(key,schema[key].min))
		slider.value_changed.connect(func(value: float) -> void:
			tuning[key] = value
			label.text = "%s: %.3f" % [key,value])
		values.add_child(slider)
	panel.hide()
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(260,220)
	layer.add_child(result_panel)
	var result_box: VBoxContainer = VBoxContainer.new()
	result_panel.add_child(result_box)
	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size",26)
	result_box.add_child(result_label)
	var again: Button = Button.new()
	again.text = "다시 (Enter / 패드 A)"
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(start_round)
	result_box.add_child(again)
	result_panel.hide()

func save_tuning() -> bool:
	var own: Dictionary = {}
	for key: String in golem_keys: own[key] = tuning[key]
	var file: FileAccess = FileAccess.open(tuning_path,FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(own,"  ")+"\n")
	return true

func _command(title: String) -> void:
	match title:
		"조준 전환 R": motion.direct_aim = not motion.direct_aim
		"튜닝 F1":
			panel.visible = not panel.visible
			motion.cancel()
			player.controls.set_blocked(panel.visible or round_over)
		"판정 F2": Feedback.boxes_visible = not Feedback.boxes_visible
		"무적 F5": Feedback.invincible = not Feedback.invincible
		"속도 F6": Feedback.set_speed({1.0:0.5,0.5:0.25}.get(Feedback.base_speed,1.0))
		"다시 읽기 F7":
			load_arena()
			start_round()
		"골렘 리셋 F9": start_round()
		"종료":
			write_quit_log()
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if round_over and (event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)):
		start_round()
		return
	if not event is InputEventKey or not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_R: _command("조준 전환 R")
		KEY_F1, KEY_TAB: _command("튜닝 F1")
		KEY_F2: _command("판정 F2")
		KEY_F5: _command("무적 F5")
		KEY_F6: _command("속도 F6")
		KEY_F7: _command("다시 읽기 F7")
		KEY_F9: _command("골렘 리셋 F9")

func _draw() -> void:
	if not is_instance_valid(player): return
	if Feedback.boxes_visible:
		draw_arc(player.position,float(tuning.bash_radius),0,TAU,64,Color.CYAN,1)
		draw_rect(player_rect(),Color.YELLOW,false)
	if swing_time >= 0:
		draw_rect(swing_rect,Color(1,1,1,0.35))
		draw_rect(swing_rect,Color(0.7,1,1,0.9),false,2)
	if motion.flash_remaining > 0:
		var strength: float = motion.flash_remaining/float(tuning.bash_flash_time)
		var glow: Color = Color(0.4,1,1,strength)
		draw_line(player.position-motion.launch_direction*float(tuning.bash_trail_length)*strength,player.position,glow,6*strength)
		draw_arc(motion.launch_origin,float(tuning.bash_burst_radius)*(1-strength),0,TAU,32,glow,3)
	_draw_golem_bar()
	for item: Dictionary in fx:
		var fade: float = 1-item.age/item.life
		var color: Color = item.color
		color.a = fade
		match item.kind:
			"spark": draw_line(item.pos,item.pos-item.vel*0.04,color,3)
			"dust": draw_circle(item.pos,4+8*(1-fade),Color(color,0.6*fade))
			"text": draw_string(ThemeDB.fallback_font,item.pos,item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,item.size,color)
	if is_instance_valid(motion.target):
		var start: Vector2 = motion.target.global_position
		draw_arc(start,22,0,TAU,32,Color.GOLD,3)
		draw_line(player.position,start,Color.GOLD,2)
		var end: Vector2 = start+motion.aim*float(tuning.bash_radius)
		draw_line(start,end,Color.WHITE,3)
		draw_line(end,end-motion.aim.rotated(0.5)*12,Color.WHITE,3)
		draw_line(end,end-motion.aim.rotated(-0.5)*12,Color.WHITE,3)

# Golem HP bar floating above its head.
func _draw_golem_bar() -> void:
	if golem.state == "dead": return
	var top: Vector2 = Vector2(golem.position.x,minf(golem.top_y(),golem.weak_center().y)-float(tuning.weak_radius)-50)
	var width: float = 120
	var ratio: float = golem.hp/maxf(float(tuning.golem_max_hp),1)
	draw_rect(Rect2(top-Vector2(width/2,0),Vector2(width,7)),Color(0,0,0,0.6))
	draw_rect(Rect2(top-Vector2(width/2,0),Vector2(width*ratio,7)),Color(0.95,0.55,0.25))
	var stagger_ratio: float = clampf(golem.stagger/maxf(float(tuning.stagger_threshold),1),0,1)
	draw_rect(Rect2(top+Vector2(-width/2,9),Vector2(width*stagger_ratio,3)),Color(0.9,0.9,1))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		write_quit_log()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(motion): motion.cancel()

func _exit_tree() -> void:
	write_quit_log()
	Engine.time_scale = 1
