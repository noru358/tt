extends Node2D
var world: Node2D
var kind: String = "o"
var home: Vector2
var velocity: Vector2 = Vector2.ZERO
var offset: Vector2 = Vector2.ZERO
var age: float = 0
var highlight: bool = false
var reflected: bool = false

func _ready() -> void:
	home = position
	add_to_group("toy_bashable")

func bash(direction: Vector2) -> void:
	if kind == "bullet":
		velocity = direction*float(world.tuning.projectile_speed)
		reflected = true
	else: offset += direction*float(world.tuning.orb_push_distance)

func _physics_process(delta: float) -> void:
	if world.panel.visible: return
	age += delta
	if kind == "bullet":
		var next: Vector2 = position+velocity*delta
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(position,next,1)
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		var wall_fraction: float = position.distance_to(hit.position)/maxf(position.distance_to(next),0.00001) if not hit.is_empty() else INF
		if reflected:
			var nearest: CombatHurtbox
			var nearest_fraction: float = wall_fraction
			for node: Node in get_tree().get_nodes_in_group("hurtboxes"):
				var hurt: CombatHurtbox = node as CombatHurtbox
				if hurt.team == "player" or not is_instance_valid(hurt.combatant): continue
				var fraction: float = hurt.sweep_fraction(position,next,float(world.tuning.projectile_radius))
				if fraction >= 0 and fraction < nearest_fraction:
					nearest = hurt
					nearest_fraction = fraction
			if nearest:
				var box: CombatProjectile = CombatProjectile.new()
				box.source = world.player
				box.team = "player"
				box.reflected = true
				box.damage = float(world.tuning.projectile_damage)
				nearest.combatant.receive_hit(box)
				box.free()
				queue_free()
				return
		if not hit.is_empty():
			queue_free()
			return
		position = next
		if not reflected and Geometry2D.get_closest_point_to_segment(world.player.position,position-velocity*delta,position).distance_to(world.player.position) < float(world.tuning.projectile_radius)+world.player.body_size.y/2:
			if not Feedback.invincible:
				world.player.hp -= float(world.tuning.projectile_damage)
				if world.player.hp <= 0: world.respawn()
			queue_free()
		if age > float(world.tuning.projectile_lifetime): queue_free()
	else:
		offset = offset.move_toward(Vector2.ZERO,float(world.tuning.orb_push_distance)/float(world.tuning.orb_return_time)*delta)
		position = home+offset
		if kind == "m": position.x += sin(age*TAU/float(world.tuning.moving_orb_period))*float(world.tuning.moving_orb_range)*float(world.tuning.tile_size)
	queue_redraw()

func _draw() -> void:
	var radius: float = float(world.tuning.projectile_radius if kind == "bullet" else world.tuning.orb_radius)
	draw_circle(Vector2.ZERO,radius,Color.SALMON if kind == "bullet" and not reflected else Color.TURQUOISE)
	if highlight: draw_arc(Vector2.ZERO,radius+3,0,TAU,32,Color.WHITE,2)
