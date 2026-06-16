extends Control

# Freccia di navigazione della stanza: un rettangolo "outline" (solo il bordo, dentro
# vuoto) semi-trasparente, con una freccia (chevron) centrata. Disegnata in codice.
# Il rettangolo del controllo e' anche la zona attiva (vedi player.gd).

@export var dir: String = "right"   # "left" | "right" | "down"

signal clicked   # emesso al click (usato solo in modalita' click: vedi player.gd)

const BORDER_TH := 5.0
const ARROW_TH := 12.0
const A_IDLE := 0.45    # opacita' a riposo
const A_HOVER := 0.85   # opacita' col cursore sopra

# Hover: lo pilota player.gd; rende il pulsante piu' opaco.
var hovered := false:
	set(v):
		if v != hovered:
			hovered = v
			queue_redraw()

# In modalita' click (mouse_filter = STOP, impostato da player.gd) intercetta il click.
# In modalita' hover (mouse_filter = IGNORE) questo non viene mai chiamato.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit()
		accept_event()

func _draw() -> void:
	var col := Color(1, 1, 1, A_HOVER if hovered else A_IDLE)
	# solo il bordo (outline), interno trasparente
	draw_rect(Rect2(Vector2.ZERO, size), col, false, BORDER_TH)
	_arrow(col)

# Una freccia (chevron) centrata nel rettangolo.
func _arrow(col: Color) -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var cy := h * 0.5
	var a: float = minf(w, h) * 0.22
	var pts: PackedVector2Array
	match dir:
		"left":
			pts = PackedVector2Array([Vector2(cx + a * 0.6, cy - a), Vector2(cx - a * 0.6, cy), Vector2(cx + a * 0.6, cy + a)])
		"right":
			pts = PackedVector2Array([Vector2(cx - a * 0.6, cy - a), Vector2(cx + a * 0.6, cy), Vector2(cx - a * 0.6, cy + a)])
		"down":
			pts = PackedVector2Array([Vector2(cx - a, cy - a * 0.6), Vector2(cx, cy + a * 0.6), Vector2(cx + a, cy - a * 0.6)])
	draw_polyline(pts, col, ARROW_TH, true)
