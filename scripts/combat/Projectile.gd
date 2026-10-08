class_name CombatProjectile
extends CombatHitbox
var motion: Vector2
var projectile_gravity: float = 0
var reflect_damage: float = 0
var reflect_stagger: float = 0
var arena_bounds: Rect2 = Rect2()

func _physics_process(delta: float) -> void:
	motion.y += projectile_gravity*delta
	position += motion * delta
	if arena_bounds.has_area() and not arena_bounds.grow(maxf(box_size.x,box_size.y)).has_point(global_position):
		queue_free()
		return
	super._physics_process(delta)

func reflect(new_source: Node2D) -> bool:
	source = new_source
	team = "player"
	motion = -motion
	projectile_gravity = 0
	if reflect_damage > 0: damage = reflect_damage
	reflected = true
	struck.clear()
	tint = Color(0.35,0.95,1,1)
	return true

