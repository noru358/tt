extends Node2D
var data: Dictionary
var body_size: Vector2
var clock: float = 0.0
var attack_count: int = 0
var flash: float = 0.0
var damage_received: float = 0.0
var hits_received: int = 0
var stagger: float = 0.0
var warning: bool = false
var enabled: bool = true
var target: GatePlayer

func _ready() -> void:
	data = Tuning.training["dummy"]
	enabled = data["enabled"]
	Tuning.changed.connect(func() -> void:
		data = Tuning.training["dummy"]
		enabled = data["enabled"])
	body_size = Vector2(data["size"][0],data["size"][1])
	var hurtbox: CombatHurtbox = CombatHurtbox.new()
	hurtbox.combatant = self
	hurtbox.team = "enemy"
	hurtbox.box_size = body_size
	add_child(hurtbox)

func _physics_process(delta: float) -> void:
	flash = maxf(0,flash-delta)
	if enabled:
		clock += delta
		warning = clock >= float(data["attack_interval"])-float(data["warning_time"])
		if clock >= float(data["attack_interval"]):
			clock -= float(data["attack_interval"])
			attack()
			warning = false
	queue_redraw()

func nearest_player() -> GatePlayer:
	var chosen: GatePlayer
	var distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("players"):
		var candidate: GatePlayer = node as GatePlayer
		if candidate.state == GatePlayer.State.DEAD: continue
		var current: float = global_position.distance_squared_to(candidate.global_position)
		if current < distance:
			distance = current
			chosen = candidate
	return chosen

func attack() -> void:
	target = nearest_player()
	if target == null: return
	var kind: String = data["attack_cycle"][attack_count % data["attack_cycle"].size()]
	attack_count += 1
	var box: CombatHitbox
	var direction: Vector2 = global_position.direction_to(target.global_position)
	if kind == "projectile":
		var projectile: CombatProjectile = CombatProjectile.new()
		projectile.motion = direction * float(data["projectile_speed"])
		box = projectile
		box.box_size = Vector2(data["projectile_size"][0],data["projectile_size"][1])
		box.duration = data["projectile_lifetime"]
		box.position = global_position
	else:
		box = CombatHitbox.new()
		box.box_size = Vector2(data["hitbox_size"][0],data["hitbox_size"][1])
		box.duration = data["hitbox_duration"]
		box.position = global_position + Vector2((-1 if direction.x < 0 else 1)*(body_size.x+box.box_size.x)/2, data["hitbox_offset_y"])
	box.source = self
	box.damage = data["damage"]
	box.parriable = true
	box.attack_id = "training." + kind
	get_parent().add_child(box)

func receive_hit(box: CombatHitbox) -> String:
	damage_received += box.damage
	hits_received += 1
	flash = Tuning.feedback["boss_hit_flash"]
	Feedback.trigger("hit")
	if Tuning.feedback["damage_numbers"]:
		var node: Node2D = load("res://scripts/combat/FloatingText.gd").new()
		var visual: Dictionary = DataRegistry.documents["training.json"]["feedback"]
		node.text = "%s" % box.damage
		node.remaining = visual["number_duration"]
		node.rise = visual["number_rise_speed"]
		get_parent().add_child(node)
		node.global_position = global_position-Vector2(0,body_size.y/2)
	return "hit"

func on_parried() -> void:
	stagger += float(data["parry_stagger"])

func _draw() -> void:
	var color: Array = data["color"]
	draw_rect(Rect2(-body_size/2,body_size),Color.WHITE if flash > 0 else Color(color[0],color[1],color[2],color[3]))
	if warning:
		draw_rect(Rect2(-body_size/2-Vector2(10,10),body_size+Vector2(20,20)),Color.GOLD,false,5)
		draw_line(Vector2(-body_size.x, -body_size.y/2-24),Vector2(body_size.x,-body_size.y/2-24),Color.GOLD,6)
