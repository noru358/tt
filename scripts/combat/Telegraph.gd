extends Node2D
var box_size: Vector2
var tint: Color
var shape: String = "rect"
func _ready() -> void:
	add_to_group("telegraphs")
func _draw() -> void:
	if shape == "circle":
		draw_set_transform(Vector2.ZERO,0,box_size/2)
		draw_circle(Vector2.ZERO,1,tint)
		draw_arc(Vector2.ZERO,1,0,TAU,48,Color.GOLD,0.02)
	elif shape == "triangle":
		var points: PackedVector2Array = PackedVector2Array([Vector2(0,-box_size.y/2),box_size/2,Vector2(-box_size.x/2,box_size.y/2),Vector2(0,-box_size.y/2)])
		draw_colored_polygon(points,tint)
		draw_polyline(points,Color.GOLD,3)
	else:
		draw_rect(Rect2(-box_size/2,box_size),tint)
		draw_rect(Rect2(-box_size/2,box_size),Color.GOLD,false,3)
