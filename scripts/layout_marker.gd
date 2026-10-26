@tool
extends Marker2D
## Segnaposto per posizionare gli elementi della partita dall'editor.
## Spostalo nella vista 2D (o dal Transform nell'Inspector): il gioco legge
## la sua posizione all'avvio. Nell'editor disegna un'anteprima di cosa
## rappresenta; durante la partita non disegna niente.
##
##   Griglia -> angolo in alto a sinistra della griglia di schieramento
##   Torre   -> centro della base della torre. Se nel Main è attiva
##              "Torre attaccata alla griglia" si sposta da solo sul bordo
##              sinistro della griglia (e non serve trascinarlo).

const ATLAS := preload("res://assets/sprites.png")
const TEX_TOWER := preload("res://assets/campo/torre.png")
const TEX_TOWER_MERLI := preload("res://assets/campo/torre_merli.png")
const TEX_TILES := preload("res://assets/campo/lastre.png")
const TEX_PILLAR := preload("res://assets/campo/pilastro.png")

# devono coincidere con main.gd
const TOWER_W := 48
const TOWER_H := 96
const TOWER_IMG_OFFSET := Vector2(-3, -30)
const NECRO_FEET := Vector2(24, 9)
const WALL_X := -4.0
const FACE_H := 7

enum Tipo { GRIGLIA, TORRE }

## Cosa rappresenta questo segnaposto.
@export var tipo: Tipo = Tipo.GRIGLIA:
	set(v):
		tipo = v
		queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if tipo == Tipo.TORRE:
		_follow_grid()
	queue_redraw()  # aggiorna l'anteprima se cambi colonne, file o scala del Main


func _get_int(node: Node, prop: String, fallback: int) -> int:
	var v = node.get(prop)
	return int(v) if v != null else fallback


func _get_bool(node: Node, prop: String, fallback: bool) -> bool:
	var v = node.get(prop)
	return bool(v) if v != null else fallback


## Con la torre attaccata alla griglia, il segnaposto segue la griglia.
func _follow_grid() -> void:
	var main := get_parent()
	if main == null or not _get_bool(main, "torre_attaccata_alla_griglia", true):
		return
	var grid := main.get_node_or_null("Griglia") as Node2D
	if grid == null:
		return
	var px := _get_int(main, "scala_pixel", 3)
	var rows := _get_int(main, "file", 4)
	var cell := 16 * _get_int(main, "tile_per_casella", 2)
	var fila := _get_int(main, "torre_fila", -1)
	var r := rows - 1 if fila < 0 else clampi(fila, 0, rows - 1)
	var origin := (grid.position / px).round()
	var base := origin + Vector2(WALL_X - TOWER_W / 2.0, (r + 0.5) * cell)
	var target := base * px
	if not position.is_equal_approx(target):
		position = target


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


func _draw_grid(main: Node, px: int) -> void:
	var cols := _get_int(main, "colonne", 9)
	var rows := _get_int(main, "file", 4)
	var cell := 16 * _get_int(main, "tile_per_casella", 2) * px
	var size := Vector2(cols * cell, rows * cell)
	# lastre in rilievo come nel gioco
	for r in rows:
		for c in cols:
			var rect := Rect2(Vector2(c, r) * cell, Vector2(cell, cell))
			var tint := Color(0.75, 0.75, 0.75, 0.85) if (c + r) % 2 == 0 else Color(0.63, 0.63, 0.63, 0.85)
			draw_texture_rect_region(TEX_TILES, rect, Rect2(0, 0, 16, 16), tint)
			draw_rect(Rect2(rect.position, Vector2(cell, px)), Color(1, 1, 1, 0.2))
			draw_rect(Rect2(rect.position + Vector2(0, cell - px), Vector2(cell, px)), Color(0, 0, 0, 0.45))
			draw_rect(Rect2(rect.position + Vector2(cell - px, 0), Vector2(px, cell)), Color(0, 0, 0, 0.4))
	# bordo davanti del campo
	draw_rect(Rect2(Vector2(0, size.y), Vector2(size.x + 16 * px, FACE_H * px)), Color(0.2, 0.2, 0.2, 0.85))
	# striscia di spawn, sempre attaccata al bordo destro della griglia
	draw_rect(Rect2(Vector2(size.x, 0), Vector2(16 * px, size.y)), Color(0.1, 0.1, 0.1, 0.6))
	draw_texture_rect(TEX_PILLAR, Rect2(Vector2(size.x, 2 * px - TEX_PILLAR.get_height() * px),
		TEX_PILLAR.get_size() * px), false, Color(1, 1, 1, 0.8))
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 2.0)


func _draw_tower(px: int) -> void:
	var pos := Vector2(-TOWER_W / 2.0, -TOWER_H)  # angolo in alto a sinistra, in pixel dell'arte
	var img := pos + TOWER_IMG_OFFSET
	draw_texture_rect(TEX_TOWER, Rect2(img * px, TEX_TOWER.get_size() * px), false, Color(1, 1, 1, 0.9))
	var necro := pos + NECRO_FEET - Vector2(8, 15)
	draw_texture_rect_region(ATLAS, Rect2(necro * px, Vector2(16, 16) * px), Rect2(64, 32, 16, 16), Color(1, 1, 1, 0.9))
	draw_texture_rect(TEX_TOWER_MERLI, Rect2(img * px, TEX_TOWER_MERLI.get_size() * px), false, Color(1, 1, 1, 0.9))
	# rettangolo colpito dai nemici e punto della base
	draw_rect(Rect2(pos * px, Vector2(TOWER_W, TOWER_H) * px), Color(1, 1, 1, 0.5), false, 2.0)
	draw_circle(Vector2.ZERO, 3.0 * px, Color.WHITE)
