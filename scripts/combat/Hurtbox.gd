class_name CombatHurtbox
extends Area2D
var combatant: Node2D
var team: String = ""
var box_size: Vector2
# Optional sprite-local convex outline; inherited transforms follow each joint.
var outline: PackedVector2Array = []
var aim_priority: int = 0

func _ready() -> void:
	add_to_group("hurtboxes")
	collision_layer = 0
	collision_mask = 0

func world_outline() -> PackedVector2Array:
	return global_transform*outline

func bounds() -> Rect2:
	if outline.is_empty(): return Rect2(global_position-box_size/2,box_size)
	var points: PackedVector2Array = world_outline()
	var rect: Rect2 = Rect2(points[0],Vector2.ZERO)
	for point: Vector2 in points: rect = rect.expand(point)
	return rect

func aim_point() -> Vector2:
	return bounds().get_center()

func overlaps(rect: Rect2) -> bool:
	if not bounds().intersects(rect): return false
	if outline.is_empty(): return true
	return not Geometry2D.intersect_polygons(world_outline(),PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])).is_empty()

func sweep_fraction(start: Vector2, finish: Vector2, radius: float) -> float:
	var broad: float = MagicArrow.sweep_fraction(start,finish,bounds().grow(radius))
	if broad < 0 or outline.is_empty(): return broad
	var polygons: Array[PackedVector2Array] = Geometry2D.offset_polygon(world_outline(),radius)
	var result: float = INF
	for polygon: PackedVector2Array in polygons:
		if Geometry2D.is_point_in_polygon(start,polygon): return 0
		for i: int in polygon.size():
			var point: Variant = Geometry2D.segment_intersects_segment(start,finish,polygon[i],polygon[(i+1)%polygon.size()])
			if point != null: result = minf(result,start.distance_to(point)/maxf(start.distance_to(finish),0.0001))
	return -1.0 if result == INF else result

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Feedback.boxes_visible: return
	if outline.is_empty(): draw_rect(Rect2(-box_size/2,box_size),Color.GREEN,false,2)
	else:
		var closed: PackedVector2Array = outline.duplicate()
		closed.append(outline[0])
		draw_polyline(closed,Color.GREEN,2)
