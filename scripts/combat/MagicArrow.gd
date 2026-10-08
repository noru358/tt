class_name MagicArrow
extends CombatHitbox
var target: CombatHurtbox
var motion: Vector2 = Vector2.RIGHT
var speed: float
var turn_rate: float
var charge: float
var trail: PackedVector2Array = []
var impacted: bool = false
var impact_age: float = 0.0

static func targetable(box: CombatHurtbox) -> bool:
	if not is_instance_valid(box) or not is_instance_valid(box.combatant) or box.is_queued_for_deletion() or box.combatant.is_queued_for_deletion(): return false
	if box.box_size.x <= 0 or box.box_size.y <= 0: return false
	if box.team != "enemy" or not box.combatant.is_visible_in_tree(): return false
	var hp: Variant = box.combatant.get("hp")
	if hp != null and float(hp) <= 0: return false
	var vulnerable: Variant = box.combatant.get("vulnerable")
	if vulnerable != null and not vulnerable: return false
	# A disabled training dummy still receives attacks; a disabled boss does not.
	if box.combatant.has_signal("died") and box.combatant.get("enabled") == false: return false
	return true

# Swept collision prevents a fast charged arrow skipping a thin target.
static func sweep_fraction(start: Vector2, finish: Vector2, rect: Rect2) -> float:
	var direction: Vector2 = finish-start
	var low: float = 0.0
	var high: float = 1.0
	for axis: int in 2:
		if is_zero_approx(direction[axis]):
			if start[axis] < rect.position[axis] or start[axis] > rect.end[axis]: return -1.0
		else:
			var a: float = (rect.position[axis]-start[axis])/direction[axis]
			var b: float = (rect.end[axis]-start[axis])/direction[axis]
			low = maxf(low,minf(a,b))
			high = minf(high,maxf(a,b))
			if low > high: return -1.0
	return low

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or source.hp <= 0 or source.controls.blocked:
		queue_free()
		return
	if impacted:
		impact_age += delta
		if impact_age >= 0.22: queue_free()
		queue_redraw()
		return
	if targetable(target):
		var desired: Vector2 = target.aim_point()-global_position
		motion = motion.rotated(clampf(wrapf(desired.angle()-motion.angle(),-PI,PI),-turn_rate*delta,turn_rate*delta))
	var start: Vector2 = global_position
	var finish: Vector2 = start+motion*speed*minf(delta,maxf(0,duration-elapsed))
	var nearest: CombatHurtbox
	var earliest: float = INF
	for node: Node in get_tree().get_nodes_in_group("hurtboxes"):
		var box: CombatHurtbox = node as CombatHurtbox
		if not targetable(box): continue
		var fraction: float = box.sweep_fraction(start,finish,box_size.y/2)
		if fraction >= 0 and fraction < earliest:
			nearest = box
			earliest = fraction
	trail.append(start)
	if trail.size() > 12: trail.remove_at(0)
	global_position = finish
	if nearest != null:
		global_position = start.lerp(finish,earliest)
		var outcome: String = nearest.combatant.receive_hit(self)
		if outcome == "hit":
			impacted = true
			struck[nearest.get_instance_id()] = true
			if is_instance_valid(source): source.dealt_hit(nearest.combatant,self)
	elapsed += delta
	if not impacted and elapsed >= duration: queue_free()
	queue_redraw()

func _draw() -> void:
	var color: Color = Color(0.35,0.85,1).lerp(Color(1,0.85,0.35),charge)
	for i: int in range(1,trail.size()):
		draw_line(to_local(trail[i-1]),to_local(trail[i]),Color(color,float(i)/trail.size()*0.65),2+charge*5,true)
	if impacted:
		var fade: float = 1-impact_age/0.22
		for i: int in 8:
			var ray: Vector2 = Vector2.RIGHT.rotated(i*TAU/8)
			draw_line(ray*(12+impact_age*80),ray*(25+charge*25+impact_age*180),Color(color,fade),3,true)
		return
	var tip: Vector2 = motion*(20+charge*12)
	draw_line(-tip,tip,Color(color,0.25),12+charge*8,true)
	draw_line(-tip,tip,Color.WHITE,3+charge*2,true)
	draw_colored_polygon(PackedVector2Array([tip,tip-motion*15+motion.orthogonal()*8,tip-motion*15-motion.orthogonal()*8]),color)
