@tool
extends Marker2D
## Segnaposto per posizionare gli elementi della partita dall'editor.
## Spostalo nella vista 2D (o dal Transform nell'Inspector): il gioco legge
## la sua posizione all'avvio. Nell'editor disegna un'anteprima di cosa
## rappresenta; durante la partita non disegna niente.
##
##   Griglia -> angolo in alto a sinistra della griglia di schieramento
##   Torre   -> centro della base della torre

const ATLAS := preload("res://assets/sprites.png")

enum Tipo { GRIGLIA, TORRE }

## Cosa rappresenta questo segnaposto.
@export var tipo: Tipo = Tipo.GRIGLIA:
	set(v):
		tipo = v
		queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()  # aggiorna l'anteprima se cambi colonne, file o scala del Main


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var main := get_parent()
	if main == null:
		return
	var px: int = _get_int(main, "scala_pixel", 3)
	match tipo:
		Tipo.GRIGLIA:
			_draw_grid(main, px)
		Tipo.TORRE:
			_draw_tower(px)


func _get_int(node: Node, prop: String, fallback: int) -> int:
	var v = node.get(prop)
	return int(v) if v != null else fallback


func _draw_grid(main: Node, px: int) -> void:
	var cols := _get_int(main, "colonne", 9)
	var rows := _get_int(main, "file", 4)
	var cell := 16 * _get_int(main, "tile_per_casella", 2) * px
	var size := Vector2(cols * cell, rows * cell)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.45, 0.45, 0.35))
	for c in cols + 1:
		draw_line(Vector2(c * cell, 0), Vector2(c * cell, size.y), Color(1, 1, 1, 0.35), 1.0)
	for r in rows + 1:
		draw_line(Vector2(0, r * cell), Vector2(size.x, r * cell), Color(1, 1, 1, 0.35), 1.0)
	# striscia di spawn, sempre attaccata al bordo destro della griglia
	draw_rect(Rect2(Vector2(size.x, 0), Vector2(16 * px, size.y)), Color(0.1, 0.1, 0.1, 0.6))
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 2.0)


func _draw_tower(px: int) -> void:
	var w := 48.0 * px
	var h := 96.0 * px
	var pos := Vector2(-w / 2.0, -h)
	draw_texture_rect_region(ATLAS, Rect2(pos, Vector2(w, h)), Rect2(0, 48, 48, 96), Color(1, 1, 1, 0.8))
	draw_texture_rect_region(ATLAS, Rect2(pos + Vector2(w / 2.0 - 8 * px, -12 * px), Vector2(16, 16) * px), Rect2(64, 32, 16, 16), Color(1, 1, 1, 0.8))
	draw_rect(Rect2(pos, Vector2(w, h)), Color.WHITE, false, 2.0)
