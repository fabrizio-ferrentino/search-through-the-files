extends Control


func _draw():
	var center = get_viewport_rect().size / 2
	# Disegna il cerchietto centrale
	draw_circle(center, 2, Color(1, 1, 1))
