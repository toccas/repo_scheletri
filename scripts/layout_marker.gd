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
const SPAWN_W := 16
const UI_TOP := 72
const HINT_SPACE := 48
const UI_BOTTOM := 96

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


## Stesso calcolo di main.gd (_compute_layout + _fit_on_screen): dove finiranno
## davvero griglia e torre nel gioco. Restituisce {px, origin, wall_x, tower_base_y}
## in pixel dell'arte, oppure {} se manca il segnaposto della griglia.
static func game_layout(main: Node) -> Dictionary:
	var grid := main.get_node_or_null("Griglia") as Node2D
	if grid == null:
		return {}
	var vp := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1280),
		ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	var g := func(prop: String, fallback): return main.get(prop) if main.get(prop) != null else fallback
	var cols: int = g.call("colonne", 9)
	var rows: int = g.call("file", 4)
	var cell: int = 16 * int(g.call("tile_per_casella", 2))
	var lane := float(cols * cell)
	var depth := float(rows * cell)
	var px: int = g.call("scala_pixel", 3)
	var need_w := 6 + TOWER_W + 4 + int(lane) + SPAWN_W + 4
	while px > 1:
		var aw := floori(vp.x / px)
		var ah := floori(vp.y / px) - ceili(float(UI_TOP + HINT_SPACE + UI_BOTTOM) / px)
		if need_w <= aw and depth <= ah:
			break
		px -= 1
	var art := (vp / px).floor()
	var origin := (grid.position / px).round()
	var wall_x := WALL_X
	var tower_base_y: float
	var tower := main.get_node_or_null("Torre") as Node2D
	if bool(g.call("torre_attaccata_alla_griglia", true)) or tower == null:
		var fila: int = g.call("torre_fila", -1)
		var r := rows - 1 if fila < 0 else clampi(fila, 0, rows - 1)
		tower_base_y = (r + 0.5) * cell
	else:
		var base := (tower.position / px).round()
		wall_x = base.x + TOWER_W / 2.0 - origin.x
		tower_base_y = clampf(base.y - origin.y, cell * 0.5, depth)
	# _fit_on_screen
	var min_x := maxf(2.0, 2.0 - (wall_x - TOWER_W))
	var max_x := art.x - lane - SPAWN_W - 2.0
	origin.x = clampf(origin.x, min_x, maxf(min_x, max_x))
	var min_y := ceilf(float(UI_TOP) / px) + 2.0 - (tower_base_y - TOWER_H + TOWER_IMG_OFFSET.y)
	min_y = maxf(min_y, ceilf(float(UI_TOP) / px) + 14.0)
	var max_y := art.y - depth - FACE_H - 2.0
	origin.y = maxf(origin.y, min_y)
	origin.y = minf(origin.y, maxf(max_y, ceilf(float(UI_TOP) / px)))
	return {"px": px, "origin": origin.round(), "wall_x": wall_x, "tower_base_y": tower_base_y}


## Con la torre attaccata alla griglia, il segnaposto segue la griglia.
func _follow_grid() -> void:
	var main := get_parent()
	if main == null or not _get_bool(main, "torre_attaccata_alla_griglia", true):
		return
	var lay := game_layout(main)
	if lay.is_empty():
		return
	var base: Vector2 = lay["origin"] + Vector2(lay["wall_x"] - TOWER_W / 2.0, lay["tower_base_y"])
	var target: Vector2 = base * lay["px"]
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
	var lay := game_layout(main)
	if not lay.is_empty():
		px = lay["px"]
		var real: Vector2 = lay["origin"] * px - position
		if real.length() > 0.5:
			# il gioco sposterà la griglia per farla entrare nello schermo: mostro dove
			draw_rect(Rect2(Vector2.ZERO, Vector2(_get_int(main, "colonne", 9), _get_int(main, "file", 4)) * 16 * _get_int(main, "tile_per_casella", 2) * px), Color(1, 0.3, 0.3, 0.8), false, 2.0)
			draw_line(Vector2.ZERO, real, Color(1, 0.3, 0.3, 0.8), 2.0)
			draw_set_transform(real)
	var cols := _get_int(main, "colonne", 9)
	var rows := _get_int(main, "file", 4)
	var cell := 16 * _get_int(main, "tile_per_casella", 2) * px
	var size := Vector2(cols * cell, rows * cell)
	# lastre in rilievo come nel gioco (con le lastre del bioma del livello)
	var bioma = main.get("bioma")
	var tiles: Texture2D = TEX_TILES
	var obst_tex: Texture2D = null
	var barrier_col := Color("1a1c1e")
	if bioma is Resource:
		if bioma.get("lastre"):
			tiles = bioma.lastre
		obst_tex = bioma.get("ostacoli")
		barrier_col = bioma.get("colore_barriera")
	var blocked = main.get("file_bloccate")
	var obstacles = main.get("ostacoli")
	for r in rows:
		if blocked != null and r in blocked:
			# fila bloccata: acqua, fossa, crepaccio... (niente schieramento, i nemici non passano)
			var br := Rect2(Vector2(0, r * cell), Vector2(cols * cell, cell))
			draw_rect(br, Color(barrier_col, 0.95))
			for k in cols * 2:
				draw_line(br.position + Vector2(k * cell / 2.0, 0), br.position + Vector2(k * cell / 2.0 + cell / 2.0, cell), Color(1, 1, 1, 0.08), px)
			continue
		for c in cols:
			var rect := Rect2(Vector2(c, r) * cell, Vector2(cell, cell))
			var tint := Color(0.75, 0.75, 0.75, 0.85) if (c + r) % 2 == 0 else Color(0.63, 0.63, 0.63, 0.85)
			draw_texture_rect_region(tiles, rect, Rect2(0, 0, 16, 16), tint)
			draw_rect(Rect2(rect.position, Vector2(cell, px)), Color(1, 1, 1, 0.2))
			draw_rect(Rect2(rect.position + Vector2(0, cell - px), Vector2(cell, px)), Color(0, 0, 0, 0.45))
			draw_rect(Rect2(rect.position + Vector2(cell - px, 0), Vector2(px, cell)), Color(0, 0, 0, 0.4))
			if obstacles != null and Vector2i(c, r) in obstacles:
				# ostacolo: la casella non si usa (variante 0 dell'immagine del bioma)
				if obst_tex:
					var v := (c * 7 + r * 3) % maxi(1, floori(obst_tex.get_width() / 32.0))
					draw_texture_rect_region(obst_tex, Rect2(rect.position + Vector2(cell / 2.0 - 16 * px, cell - 30 * px), Vector2(32, 32) * px), Rect2(v * 32, 0, 32, 32))
				else:
					draw_rect(rect.grow(-px * 2), Color(0.1, 0.1, 0.1, 0.8))
				draw_line(rect.position, rect.end, Color(1, 0.3, 0.3, 0.7), 2.0)
				draw_line(rect.position + Vector2(cell, 0), rect.position + Vector2(0, cell), Color(1, 0.3, 0.3, 0.7), 2.0)
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
