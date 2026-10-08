extends CharacterBody2D
signal died
signal pattern_started(id: String)
var data: Dictionary
var rules: Dictionary
var arena: Dictionary
var body_size: Vector2
var hp: float
var stagger: float = 0
var stagger_time: float = 0
var flash: float = 0
var phase_index: int = 0
var speed_mult: float = 1
var facing: int = -1
var vulnerable: bool = true
var enabled: bool = false
var runner: Node
var hurtbox: CombatHurtbox
var cutout: Node2D
var walking: bool = false
var contact_clock: float = 0.0
var contact_attack: CombatHitbox
var foot_time: float = 0
var pattern_streak: int = 0
var weakbox: CombatHurtbox
var hazards: Array[Node] = []
var cooldowns: Dictionary = {}
var last_pattern: String = ""
var pattern_id: String = ""
var retry: float = 0
var pending_enter: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
func _ready() -> void:
	rng.randomize()
	rules = DataRegistry.documents["battle.json"]
	arena = data["arena"]
	body_size = Vector2(data["body"]["size"][0],data["body"]["size"][1])
	hp = data["max_hp"]
	speed_mult = data["phases"][0]["speed_mult"]
	pending_enter = data["phases"][0].get("enter_pattern","")
	collision_layer = 0
	collision_mask = 0
	hurtbox = CombatHurtbox.new()
	hurtbox.combatant = self
	hurtbox.team = "enemy"
	hurtbox.box_size = body_size
	add_child(hurtbox)
	runner = load("res://scripts/boss/PatternRunner.gd").new()
	runner.boss = self
	add_child(runner)
	if data.has("cutout"):
		cutout = preload("res://scripts/boss/GolemVisual.gd").new()
		add_child(cutout)
		weakbox = CombatHurtbox.new()
		weakbox.team = "enemy"
		weakbox.combatant = self
		weakbox.box_size = Vector2.ZERO
		add_child(weakbox)
		contact_attack = CombatHitbox.new()
		contact_attack.source = self
		contact_attack.attack_id = "golem.contact"
func target_player() -> Node2D:
	var nearest: Node2D
	var distance: float = INF
	for player: Node2D in get_tree().get_nodes_in_group("players"):
		if player.hp <= 0: continue
		var candidate: float = global_position.distance_squared_to(player.global_position)
		if candidate < distance:
			distance = candidate
			nearest = player
	return nearest
func clamp_position(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x,float(arena["left"])+body_size.x/2,float(arena["right"])-body_size.x/2),minf(point.y,float(arena["floor_y"])-body_size.y/2))
func target_position(kind: String, offset_y: float = 0) -> Vector2:
	var target: Node2D = target_player()
	var point: Vector2 = Vector2(global_position.x,float(arena["floor_y"])-body_size.y/2+offset_y)
	match kind:
		"player_x", "above_player":
			if target != null: point.x = target.global_position.x
		"arena_left": point.x = arena["left"]
		"arena_right": point.x = arena["right"]
		"arena_center": point.x = (float(arena["left"])+float(arena["right"]))/2
		"opposite_side": point.x = float(arena["right"]) if global_position.x < (float(arena["left"])+float(arena["right"]))/2 else float(arena["left"])
	return clamp_position(point)
func _physics_process(delta: float) -> void:
	contact_clock = maxf(0,contact_clock-delta)
	walking = false
	flash = maxf(0,flash-delta)
	queue_redraw()
	if not enabled or hp <= 0: return
	for key: String in cooldowns: cooldowns[key] = maxf(0,float(cooldowns[key])-delta*speed_mult)
	_update_phase()
	if is_instance_valid(cutout):
		cutout.idle(delta)
		var target: Node2D = target_player()
		if target != null and absf(target.global_position.x-global_position.x) <= float(Tuning.golem["foot_zone"])*float(Tuning.golem["scale"]): foot_time += delta
		else: foot_time = 0
	if stagger_time > 0:
		stagger_time = maxf(0,stagger_time-delta*speed_mult)
		_apply_gravity(delta)
		return
	stagger = maxf(0,stagger-float(data["stagger"]["decay_per_sec"])*delta)
	if runner.running:
		runner.tick(delta)
	else:
		retry = maxf(0,retry-delta*speed_mult)
		if not pending_enter.is_empty():
			var enter: String = pending_enter
			pending_enter = ""
			start_pattern(enter)
		elif _walk_toward_player(delta):
			pass
		elif retry <= 0:
			var selected: String = choose_pattern()
			if selected.is_empty(): retry = rules["selection_retry"]
			else: start_pattern(selected)
	var scripted: bool = runner.current != null and runner.current.data["type"] in ["move_to","dash","jump"]
	if not scripted:
		_apply_gravity(delta)
	else: velocity = Vector2.ZERO
	_contact()
func _apply_gravity(delta: float) -> void:
	velocity.y += float(data["gravity"])*delta
	global_position = clamp_position(global_position+Vector2(0,velocity.y*delta))
	if global_position.y >= float(arena["floor_y"])-body_size.y/2: velocity.y = 0

func eligible_patterns() -> Array[String]:
	var result: Array[String] = []
	var target: Node2D = target_player()
	if target == null: return result
	var distance: float = global_position.distance_to(target.global_position)
	for entry: Dictionary in data["phases"][phase_index]["patterns"]:
		var pattern: Dictionary = data["patterns"][entry["id"]]
		if float(cooldowns.get(entry["id"],0)) <= 0 and distance >= float(pattern["min_distance"]) and distance <= float(pattern["max_distance"]): result.append(entry["id"])
	if result.size() >= 2: result.erase(last_pattern)
	return result
func choose_pattern() -> String:
	if is_instance_valid(cutout):
		if foot_time >= float(Tuning.golem["foot_dwell"]) and not (last_pattern == "stomp" and pattern_streak >= 2):
			foot_time = 0
			return "stomp"
		var options: Array[String] = ["slam","sweep"]
		if pattern_streak >= 2: options.erase(last_pattern)
		return options[rng.randi_range(0,options.size()-1)]
	var candidates: Array[String] = eligible_patterns()
	var total: float = 0
	for entry: Dictionary in data["phases"][phase_index]["patterns"]:
		if entry["id"] in candidates: total += float(entry["weight"])
	if total <= 0: return ""
	var roll: float = rng.randf()*total
	for entry: Dictionary in data["phases"][phase_index]["patterns"]:
		if entry["id"] not in candidates: continue
		roll -= float(entry["weight"])
		if roll <= 0: return entry["id"]
	return candidates.back()
func start_pattern(id: String) -> void:
	pattern_streak = pattern_streak+1 if last_pattern == id else 1
	pattern_id = id
	last_pattern = id
	vulnerable = true
	cooldowns[id] = data["patterns"][id]["cooldown"]
	runner.start(data["patterns"][id]["steps"])
	pattern_started.emit(id)
func _update_phase() -> void:
	var selected: int = data["phases"].size()-1
	for index: int in data["phases"].size():
		if hp/float(data["max_hp"]) > float(data["phases"][index]["hp_above"]):
			selected = index
			break
	if selected == phase_index: return
	phase_index = selected
	speed_mult = data["phases"][selected]["speed_mult"]
	interrupt()
	pending_enter = data["phases"][selected].get("enter_pattern","")
func interrupt() -> void:
	if is_instance_valid(cutout): cutout.cancel()
	runner.cancel()
	for node: Variant in hazards:
		if is_instance_valid(node):
			node.set_physics_process(false)
			node.queue_free()
	hazards.clear()
	vulnerable = true
	velocity = Vector2.ZERO
func add_stagger(amount: float) -> void:
	if hp <= 0 or stagger_time > 0: return
	stagger += amount
	if stagger >= float(data["stagger"]["threshold"]):
		interrupt()
		stagger = 0
		stagger_time = data["stagger"]["duration"]
func on_parried() -> void:
	add_stagger(float(data["stagger"]["parry_gain"]))
func receive_hit(box: CombatHitbox) -> String:
	if not enabled or hp <= 0 or not vulnerable: return "ignored"
	var weak_mult: float = 1.0
	if is_instance_valid(cutout):
		var weak: Rect2 = cutout.weakpoint_bounds()
		if weak.has_area() and weak.intersects(Rect2(box.global_position-box.box_size/2,box.box_size)): weak_mult = Tuning.golem["weakpoint_multiplier"]
	var amount: float = box.damage*weak_mult*(float(data["stagger"]["damage_mult"]) if stagger_time > 0 else 1.0)
	hp = maxf(0,hp-amount)
	flash = Tuning.feedback["boss_hit_flash"]
	Feedback.trigger("hit")
	if Tuning.feedback["damage_numbers"]:
		var number: Node2D = load("res://scripts/combat/FloatingText.gd").new()
		number.text = str(snappedf(amount,0.1))
		number.tint = Color.WHITE
		number.remaining = Tuning.training["feedback"]["number_duration"]
		number.rise = Tuning.training["feedback"]["number_rise_speed"]
		get_parent().add_child(number)
		number.global_position = global_position-Vector2(0,body_size.y/2)
	if hp <= 0:
		interrupt()
		enabled = false
		died.emit()
	else:
		_update_phase()
		if box is CombatProjectile and box.reflected: add_stagger(box.reflect_stagger)
		elif box.damage >= float(data["stagger"]["heavy_damage_threshold"]): add_stagger(float(data["stagger"]["heavy_hit_gain"]))
	return "hit"
func _contact() -> void:
	if is_instance_valid(cutout):
		_cutout_contact()
		return
	if stagger_time > 0 or float(data["contact_damage"]) <= 0: return
	for player: Node2D in get_tree().get_nodes_in_group("players"):
		if player.hp > 0 and Rect2(global_position-body_size/2,body_size).intersects(player.hurtbox.bounds()):
			var contact: CombatHitbox = CombatHitbox.new()
			contact.source = self
			contact.damage = data["contact_damage"]
			contact.position = global_position
			contact.attack_id = data["id"]+".contact"
			player.receive_hit(contact)
			contact.free()
func warning(config: Dictionary) -> Node2D:
	var mark: Node2D = load("res://scenes/combat/Telegraph.tscn").instantiate()
	mark.box_size = Vector2(config["size"][0],config["size"][1])
	mark.shape = config["shape"]
	var color: Array = config["color"]
	mark.tint = Color(color[0],color[1],color[2],color[3])
	get_parent().add_child(mark)
	mark.global_position = global_position
	if config.get("target","") == "player_x": mark.global_position.x = target_position("player_x").x
	if config.has("offset"): mark.position += Vector2(float(config["offset"][0])*facing,config["offset"][1])
	mark.reset_physics_interpolation()
	_track(mark)
	return mark
func _track(node: Node) -> void:
	for index: int in range(hazards.size()-1,-1,-1):
		if not is_instance_valid(hazards[index]): hazards.remove_at(index)
	hazards.append(node)
func make_hitbox(config: Dictionary, lifetime: float, attached: bool) -> CombatHitbox:
	var box: CombatHitbox = CombatHitbox.new()
	_configure_box(box,config,lifetime)
	var offset: Array = config.get("offset",[0,0])
	if attached:
		add_child(box)
		box.position = Vector2(float(offset[0])*facing,offset[1])
	else:
		get_parent().add_child(box)
		box.global_position = global_position+Vector2(float(offset[0])*facing,offset[1])
	box.reset_physics_interpolation()
	_track(box)
	return box
func _configure_box(box: CombatHitbox, config: Dictionary, lifetime: float) -> void:
	box.source = self
	box.team = "enemy"
	box.box_size = Vector2(config["size"][0],config["size"][1])
	box.damage = config["damage"]
	box.knockback = config.get("knockback",0)
	box.parriable = config.get("parriable",false)
	box.duration = lifetime
	box.attack_id = data["id"]+"."+pattern_id
	box.tint = Color(0.1,0.65,1,0.7) if box.parriable else Color(1,0.18,0.12,0.7)
func projectile(config: Dictionary, motion: Vector2) -> CombatProjectile:
	var box: CombatProjectile = CombatProjectile.new()
	_configure_box(box,config,float(rules["projectile_lifetime"])/speed_mult)
	box.motion = motion
	box.projectile_gravity = float(config.get("gravity",0))*speed_mult*speed_mult
	box.reflect_damage = config.get("reflect_damage",0)
	box.reflect_stagger = config.get("reflect_stagger",0)
	box.arena_bounds = Rect2(float(arena["left"]),minf(0,float(config.get("spawn_y",0))),float(arena["right"])-float(arena["left"]),float(arena["floor_y"])-minf(0,float(config.get("spawn_y",0))))
	get_parent().add_child(box)
	box.global_position = global_position
	box.reset_physics_interpolation()
	_track(box)
	return box
func _draw() -> void:
	if data.is_empty() or is_instance_valid(cutout): return
	var c: Array = data["body"]["color"]
	var color: Color = Color(c[0],c[1],c[2],c[3])
	if flash > 0: color = Color.WHITE
	elif hp <= 0: color = Color.DIM_GRAY
	elif stagger_time > 0: color = Color(0.45,0.65,0.75)
	match data["body"]["shape"]:
		"rect": draw_rect(Rect2(-body_size/2,body_size),color)
		"triangle": draw_colored_polygon(PackedVector2Array([Vector2(0,-body_size.y/2),body_size/2,Vector2(-body_size.x/2,body_size.y/2)]),color)
		"circle":
			draw_set_transform(Vector2.ZERO,0,body_size/2)
			draw_circle(Vector2.ZERO,1,color)
			draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-body_size/2,body_size),Color.GRAY if not vulnerable else Color(0.85,0.9,0.95),false,4)
	draw_line(Vector2(facing*body_size.x/4,-body_size.y/4),Vector2(facing*body_size.x/2,-body_size.y/4),Color.WHITE,8)


func _walk_toward_player(delta: float) -> bool:
	if not is_instance_valid(cutout) or not Tuning.golem["walk_enabled"]: return false
	var target: Node2D = target_player()
	if target == null: return false
	var gap: float = target.global_position.x-global_position.x
	var stop: float = Tuning.golem["walk_stop_distance"]
	if absf(gap) <= stop: return false
	facing = int(signf(gap))
	var previous: Vector2 = global_position
	global_position = clamp_position(global_position+Vector2(facing*minf(float(Tuning.golem["walk_speed"])*delta,absf(gap)-stop),0))
	walking = not is_equal_approx(previous.x,global_position.x)
	if walking: cutout.walk(delta,global_position.x-previous.x)
	return walking

func _cutout_contact() -> void:
	if stagger_time > 0 or contact_clock > 0 or float(Tuning.golem["contact_damage"]) <= 0: return
	for player: Node2D in get_tree().get_nodes_in_group("players"):
		if player.hp <= 0 or not cutout.body_overlaps(player.hurtbox.bounds()): continue
		# The authored attack wins over contact on its impact tick.
		if is_instance_valid(cutout.box) and cutout.attack_rect().intersects(player.hurtbox.bounds()): continue
		contact_attack.damage = Tuning.golem["contact_damage"]
		contact_attack.position = global_position
		var outcome: String = player.receive_hit(contact_attack)
		if outcome != "ignored": contact_clock = Tuning.golem["contact_interval"]

func _exit_tree() -> void:
	if is_instance_valid(contact_attack): contact_attack.free()
