extends Node2D
var player: GatePlayer
var dummy: Node2D
var hud: Label
var parry_help: Label
var status: Label
var debug_panel: CanvasLayer
var retry_button: Button
var arena: Dictionary

func _ready() -> void:
	GameState.progression_run = false
	process_physics_priority = 100 # Read actor state after movement/defense this tick.
	arena = DataRegistry.documents["training.json"]["arena"]
	var camera: Camera2D = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position = Vector2(960,540)
	add_child(camera)
	Feedback.camera = camera
	_static_rect(Rect2(0,arena["floor_y"],1920,1080-float(arena["floor_y"])),false)
	_static_rect(Rect2(-100,0,100+float(arena["left"]),1080),false)
	_static_rect(Rect2(arena["right"],0,2020-float(arena["right"]),1080),false)
	for platform: Dictionary in arena["platforms"]:
		_static_rect(Rect2(platform["x"],platform["y"],platform["w"],arena["platform_thickness"]),true)
	player = load("res://scenes/player/Player.tscn").instantiate()
	var spawn: Array = DataRegistry.documents["training.json"]["player"]["spawn"]
	player.position = Vector2(spawn[0],spawn[1])
	player.player_index = 0
	add_child(player)
	dummy = load("res://scripts/arena/TrainingDummy.gd").new()
	var location: Array = DataRegistry.documents["training.json"]["dummy"]["position"]
	dummy.position = Vector2(location[0],location[1])
	add_child(dummy)
	_build_ui()
	debug_panel = load("res://scenes/ui/DebugPanel.tscn").instantiate()
	add_child(debug_panel)
	debug_panel.toggled.connect(func(open: bool) -> void:
		player.controls.set_blocked(open)
		if open:
			player.clear_action_intent()
			Feedback.clear_transients())
	Tuning.changed.connect(_update_parry_help)
	_update_parry_help()
	if "--open-panel" in OS.get_cmdline_user_args() and not get_tree().has_meta("initial_panel_shown"):
		get_tree().set_meta("initial_panel_shown",true)
		debug_panel.toggle()
	var battle_button: Button = Button.new()
	battle_button.text = DataRegistry.get_boss(DataRegistry.documents["battle.json"]["boss_id"])["name"]+" 연습 · 보상 없음"
	battle_button.focus_mode = Control.FOCUS_NONE
	debug_panel.toolbar.add_child(battle_button)
	battle_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file.call_deferred("res://scenes/arena/BattleArena.tscn"))
	_add_hub_buttons()
	_capture.call_deferred()

func _static_rect(rect: Rect2, one_way: bool) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.shape = shape
	collider.one_way_collision = one_way
	body.add_child(collider)
	add_child(body)

func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(44,28)
	column.add_theme_constant_override("separation",12)
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic"])
	var theme: Theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 24
	column.theme = theme
	canvas.add_child(column)
	var title: Label = Label.new()
	title.text = "GATE 1 / 연습 모드 · 보상 없음"
	title.add_theme_font_size_override("font_size",36)
	column.add_child(title)
	hud = Label.new()
	column.add_child(hud)
	var help: Label = Label.new()
	help.text = "이동 A/D · 점프 Space · 방향 W/A/S/D + Shift 대시 · 공격 J · 포션 L\n위 W + J / 공중 아래 S + J (포고) · 패드: 스틱 / A / B / X / Y"
	column.add_child(help)
	parry_help = Label.new()
	parry_help.text = "패리 K / LB · 금색 예고 후 근접 / 투사체 공격"
	column.add_child(parry_help)
	var debug_help: Label = Label.new()
	debug_help.text = "마법 활 U / RB: 누르고 충전 → 떼면 자동 발사 · 대시 중 사용 | Tab / Esc / Start 조작감 · R 초기화"
	column.add_child(debug_help)
	status = Label.new()
	column.add_child(status)
	retry_button = Button.new()
	retry_button.text = "연습 다시 시작 (R / 패드 A)"
	retry_button.position = Vector2(650,490)
	retry_button.size = Vector2(620,90)
	retry_button.add_theme_font_override("font",font)
	retry_button.add_theme_font_size_override("font_size",32)
	retry_button.visible = false
	retry_button.pressed.connect(restart)
	canvas.add_child(retry_button)
	player.died.connect(func() -> void:
		retry_button.visible = true
		retry_button.grab_focus())

func _update_parry_help() -> void:
	parry_help.visible = Tuning.player["parry_enabled"]

func restart() -> void:
	get_tree().paused = false
	Feedback.clear_transients()
	get_tree().reload_current_scene()

func refill() -> void:
	if player.state == GatePlayer.State.DEAD:
		restart()
		return
	player.hp = player.p("max_hp")
	player.potions = int(player.p("potion_count"))
	Feedback.debug_used = true

func _physics_process(_delta: float) -> void:
	hud.text = "HP %s / %s   |   포션 %d   |   대시 %.2fs   |   %s" % [player.hp,player.p("max_hp"),player.potions,player.dash_cooldown,GatePlayer.State.keys()[player.state].to_lower()]
	status.text = "허수아비 피해 %s / %d회  ·  완벽 회피 %d  ·  %s배속%s%s" % [dummy.damage_received,dummy.hits_received,player.total_perfect,Feedback.base_speed," · 무적 ON" if Feedback.invincible else ""," · 판정 ON" if Feedback.boxes_visible else ""]
	if Tuning.player["parry_enabled"]: status.text += "  ·  패리 %d / 스태거 %s" % [player.total_parries,dummy.stagger]
	if player.controls.just_pressed(&"retry"):
		# A is jump while alive; R is always retry on keyboard.
		if player.controls.device_id == -1 or player.state == GatePlayer.State.DEAD: restart()
	queue_redraw()

func _draw() -> void:
	if arena.is_empty(): return
	draw_rect(Rect2(0,arena["floor_y"],1920,1080-float(arena["floor_y"])),Color(0.14,0.18,0.23))
	draw_line(Vector2(0,arena["floor_y"]),Vector2(1920,arena["floor_y"]),Color(0.4,0.5,0.6),3)
	for platform: Dictionary in arena["platforms"]:
		draw_rect(Rect2(platform["x"],platform["y"],platform["w"],arena["platform_thickness"]),Color(0.29,0.34,0.42))

func _capture() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--arena-capture="):
			await get_tree().create_timer(0.5).timeout
			if "--show-debug" in OS.get_cmdline_user_args(): debug_panel.toggle()
			await RenderingServer.frame_post_draw
			var result: Error = get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--arena-capture="))
			get_tree().quit(0 if result == OK else 1)


func _add_hub_buttons() -> void:
	for parent: Node in [debug_panel.toolbar,debug_panel.practice_buttons["닫고 연습"].get_parent()]:
		var back: Button = Button.new()
		back.text = "허브로 돌아가기"
		back.focus_mode = Control.FOCUS_NONE
		parent.add_child(back)
		back.pressed.connect(to_hub)

func to_hub() -> void:
	get_tree().paused = false
	player.clear_action_intent()
	Feedback.clear_transients()
	Feedback.set_speed(1,false)
	GameState.progression_run = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/hub/Hub.tscn")
