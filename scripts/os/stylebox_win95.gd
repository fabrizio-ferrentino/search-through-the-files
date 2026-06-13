class_name StyleBoxWin95
extends StyleBox

# StyleBox personalizzato che disegna riempimento + bordo 3D stile Win95.
@export var raised: bool = true
@export var bg: Color = Color("c0c0c0")
@export var double: bool = true
@export var fill: bool = true

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if fill:
		RenderingServer.canvas_item_add_rect(to_canvas_item, rect, bg)
	Win95.bevel_rid(to_canvas_item, rect, raised, double)
