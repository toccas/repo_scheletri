@tool
extends Node2D
## Menu principale: titolo, Start, Research, Quit.
## Sfondo animato in pixel art e scala di grigi: cimitero di notte con la
## torre del necromante, luna, stelle, pipistrelli, nebbia e una fila di
## scheletri che marcia.
##
## Comandi: mouse, oppure frecce su/giù (o W/S) e Invio/Spazio.
##
## POSIZIONI: nella scena ci sono dei nodi figli (Marker2D) da spostare
## nell'editor, trascinandoli nella vista 2D o dal loro Transform nell'Inspector.
## Lo script gira anche nell'editor, quindi vedi subito il risultato.
##   Titolo   -> centro in alto del titolo
##   Voci     -> centro in alto della prima voce (START)
##   Torre    -> centro della base della torre
##   Luna     -> centro della luna
##   Albero   -> base dell'albero secco
##   Terreno  -> conta solo la Y: linea dell'orizzonte
## Se un nodo manca, quell'elemento torna alla posizione di partenza.

const PixelFont := preload("res://scripts/pixel_font.gd")
const ATLAS := preload("res://assets/sprites.png")
const GAME_SCENE := "res://scenes/main.tscn"
const RESEARCH_SCENE := "res://scenes/research.tscn"

## Titolo del gioco mostrato in alto.
@export var titolo := "GIOCO SCHELETRI"
## Pixel dello schermo per ogni pixel dello sfondo.
@export_range(2, 6) var scala_pixel := 4

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")

const ITEMS := ["START", "RESEARCH", "QUIT"]
const ITEM_PIXEL := 4.0  # grandezza dei pixel del testo delle voci
const ITEM_PIXEL_SELECTED := 6.0  # la voce selezionata è più grande, come nello schizzo

var px := 4
var art := Vector2(320, 180)
var t := 0.0
var selected := 0
var item_rects: Array = []
var fade := 1.0  # 1 = nero
var leaving := false
var next_scene := GAME_SCENE

# Posizioni (lette dai nodi segnaposto, vedi _update_layout)
var ground_y := 150.0  # linea del terreno, in pixel dello sfondo
var title_pos := Vector2(640, 70)  # pixel dello schermo
var items_pos := Vector2(640, 330)  # pixel dello schermo
var tower_base := Vector2(38, 137)  # pixel dello sfondo
var moon_pos := Vector2(284, 42)  # pixel dello sfondo
var tree_base := Vector2(290, 150)  # pixel dello sfondo

var stars: Array = []  # {pos, phase}
var tombs: Array = []  # {x, kind}
var walkers: Array = []  # {x, kind, team, speed, frame_t, frame}
var walker_timer := 0.0
var bats: Array = []  # {x, y, speed, phase}


func _ready() -> void:
	if Engine.is_editor_hint():
		fade = 0.0
	else:
		if "--autotest" in OS.get_cmdline_user_args():
			get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
			return
		Engine.time_scale = 1.0
	_update_layout()
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 1234
	for i in 70:
		stars.append({"pos": Vector2(rnd.randi_range(0, int(art.x) - 1), rnd.randi_range(0, 95)), "phase": rnd.randf() * TAU})
	var x := 70
	while x < art.x - 60:
		tombs.append({"x": x, "kind": rnd.randi_range(0, 2)})
		x += rnd.randi_range(14, 26)
	for i in 3:
		bats.append({"x": rnd.randf_range(0, art.x), "y": rnd.randf_range(20, 70), "speed": rnd.randf_range(14, 24), "phase": rnd.randf() * TAU})
	for i in 4:  # qualche scheletro già in marcia all'avvio
		_spawn_walker(rnd.randf_range(0, art.x))


## Dimensione dello schermo di gioco (nell'editor quella delle impostazioni del progetto).
func _screen_size() -> Vector2:
	if Engine.is_editor_hint():
		return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	return get_viewport_rect().size


func _marker(node_name: String, fallback: Vector2) -> Vector2:
	var m := get_node_or_null(node_name) as Node2D
	return m.position if m else fallback


## Legge le posizioni dai nodi segnaposto (in pixel dello schermo).
func _update_layout() -> void:
	px = scala_pixel
	art = (_screen_size() / px).floor()
	ground_y = floorf(_marker("Terreno", Vector2(0, 150 * px)).y / px)
	title_pos = _marker("Titolo", Vector2(640, 70)).round()
	items_pos = _marker("Voci", Vector2(640, 330)).round()
	tower_base = (_marker("Torre", Vector2(38, 137) * px) / px).floor()
	moon_pos = (_marker("Luna", Vector2(art.x - 36, 42) * px) / px).floor()
	tree_base = (_marker("Albero", Vector2(art.x - 30, 150) * px) / px).floor()


func _spawn_walker(start_x: float = -16.0) -> void:
	var kinds := [0, 2, 4, 6]  # colonne dell'atlante: soldato, arciere, mago, gigante
	var w := {
		"x": start_x, "kind": kinds.pick_random(), "team": 0,
		"speed": randf_range(9.0, 13.0), "frame_t": randf(), "frame": 0,
	}
	# ogni tanto un umano scappa davanti agli scheletri
	if randf() < 0.15:
		w["team"] = 1
		w["kind"] = [0, 2, 4].pick_random()
		w["speed"] = 22.0
	walkers.append(w)


func _process(delta: float) -> void:
	t += delta
	if Engine.is_editor_hint():
		_update_layout()  # anteprima: segue i segnaposto mentre li sposti
		fade = 0.0
	elif leaving:
		fade = minf(1.0, fade + delta * 2.5)
		if fade >= 1.0:
			get_tree().change_scene_to_file(next_scene)
			return
	else:
		fade = maxf(0.0, fade - delta * 1.8)
	walker_timer -= delta
	if walker_timer <= 0.0:
		walker_timer = randf_range(1.5, 3.5)
		_spawn_walker()
	for w in walkers:
		w["x"] += w["speed"] * delta
		w["frame_t"] += delta
		if w["frame_t"] >= 0.2:
			w["frame_t"] = 0.0
			w["frame"] = 1 - w["frame"]
	walkers = walkers.filter(func(w): return w["x"] < art.x + 20)
	for b in bats:
		b["x"] += b["speed"] * delta
		if b["x"] > art.x + 10:
			b["x"] = -10.0
			b["y"] = randf_range(20, 70)
	queue_redraw()


# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if leaving or Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion:
		var i := _item_at(event.position)
		if i >= 0:
			selected = i
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _item_at(event.position)
		if i >= 0:
			selected = i
			_activate()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				selected = (selected + ITEMS.size() - 1) % ITEMS.size()
			KEY_DOWN, KEY_S:
				selected = (selected + 1) % ITEMS.size()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate()


func _item_at(p: Vector2) -> int:
	for i in item_rects.size():
		var r: Rect2 = item_rects[i]
		if r.grow(10).has_point(p):
			return i
	return -1


func _activate() -> void:
	match ITEMS[selected]:
		"START":
			next_scene = GAME_SCENE
			leaving = true
		"RESEARCH":
			next_scene = RESEARCH_SCENE
			leaving = true
		"QUIT":
			get_tree().quit()


# --- Disegno ---------------------------------------------------------------

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	_draw_sky()
	_draw_far()
	_draw_tower()
	_draw_graveyard()
	_draw_walkers()
	_draw_fog()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_texts()
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, _screen_size()), Color(C0, fade))


func _draw_sky() -> void:
	var bands := [C0, C0, C1, C1, C2]
	var bh := ceilf(ground_y / float(bands.size()))
	for i in bands.size():
		draw_rect(Rect2(0, i * bh, art.x, bh), bands[i])
	# stelle che brillano
	for s in stars:
		var v := 0.5 + 0.5 * sin(t * 1.7 + s["phase"])
		if v > 0.25:
			draw_rect(Rect2(s["pos"], Vector2.ONE), C5 if v > 0.8 else C3)
	# luna con alone a scacchiera
	var m := moon_pos
	for y in range(-18, 19):
		for x in range(-18, 19):
			var d := x * x + y * y
			if d <= 144:
				draw_rect(Rect2(m.x + x, m.y + y, 1, 1), C6 if d < 120 else C5)
			elif d <= 324 and (x + y) % 2 == 0:
				draw_rect(Rect2(m.x + x, m.y + y, 1, 1), Color(C3, 0.6))
	for c in [Vector3(-4, -3, 2), Vector3(3, 2, 3), Vector3(-2, 5, 1), Vector3(5, -5, 1)]:
		for y in range(-int(c.z), int(c.z) + 1):
			for x in range(-int(c.z), int(c.z) + 1):
				if x * x + y * y <= c.z * c.z:
					draw_rect(Rect2(m.x + c.x + x, m.y + c.y + y, 1, 1), C5)
	# pipistrelli
	for b in bats:
		var up := int(t * 8.0 + b["phase"]) % 2 == 0
		var p := Vector2(floorf(b["x"]), floorf(b["y"] + 3.0 * sin(t * 2.0 + b["phase"])))
		draw_rect(Rect2(p, Vector2(1, 1)), C0)
		var wy := -1.0 if up else 1.0
		draw_rect(Rect2(p + Vector2(-2, wy), Vector2(2, 1)), C0)
		draw_rect(Rect2(p + Vector2(1, wy), Vector2(2, 1)), C0)


func _draw_far() -> void:
	# montagne lontane e colline più vicine
	for x in int(art.x):
		var h1 := 22.0 + 14.0 * absf(sin(x * 0.021)) + 6.0 * absf(sin(x * 0.07 + 2.0))
		draw_rect(Rect2(x, ground_y - floorf(h1), 1, floorf(h1)), C2)
	for x in int(art.x):
		var h2 := 8.0 + 5.0 * absf(sin(x * 0.045 + 1.0))
		draw_rect(Rect2(x, ground_y - floorf(h2), 1, floorf(h2)), C3)
	# collina sotto la torre, se la torre sta sopra il terreno
	var lift := ground_y - tower_base.y
	if lift > 0.0:
		for x in range(int(tower_base.x) - 56, int(tower_base.x) + 57):
			var k := (x - tower_base.x) / 56.0
			var h3 := (lift + 1.0) * (1.0 - k * k)
			if h3 > 0.0:
				draw_rect(Rect2(x, ground_y - floorf(h3), 1, floorf(h3) + 1.0), C2)
	# terreno
	var tx := 0.0
	while tx < art.x:
		var ty := ground_y
		while ty < art.y:
			draw_texture_rect_region(ATLAS, Rect2(tx, ty, 16, 16), Rect2(32, 32, 16, 16), Color(0.75, 0.75, 0.75))
			ty += 16.0
		tx += 16.0
	draw_rect(Rect2(0, ground_y, art.x, 1), C3)


func _draw_tower() -> void:
	var base := Vector2(tower_base.x - 24, tower_base.y)  # angolo in basso a sinistra
	draw_texture_rect_region(ATLAS, Rect2(base - Vector2(0, 96), Vector2(48, 96)), Rect2(0, 48, 48, 96), Color(0.8, 0.8, 0.8))
	# finestre che tremolano
	var glow := Color(C6, 0.5 + 0.5 * absf(sin(t * 3.0)))
	for wy in [24, 48]:
		draw_rect(Rect2(base.x + 22, base.y - 96 + wy, 4, 7), glow)
	draw_texture_rect_region(ATLAS, Rect2(base + Vector2(16, -108), Vector2(16, 16)), Rect2(64, 32, 16, 16))
	# bagliore dal bastone del necromante
	if int(t * 2.0) % 3 != 0:
		draw_rect(Rect2(base.x + 30, base.y - 107, 1, 1), C6)


func _draw_graveyard() -> void:
	for tb in tombs:
		var x: int = tb["x"]
		var y := ground_y + 1
		match tb["kind"]:
			0:  # lapide arrotondata
				draw_rect(Rect2(x, y - 8, 6, 8), C4)
				draw_rect(Rect2(x + 1, y - 9, 4, 1), C4)
				draw_rect(Rect2(x + 4, y - 8, 2, 8), C3)
				draw_rect(Rect2(x + 2, y - 6, 2, 1), C2)
			1:  # croce
				draw_rect(Rect2(x + 2, y - 10, 2, 10), C4)
				draw_rect(Rect2(x, y - 8, 6, 2), C4)
				draw_rect(Rect2(x + 3, y - 10, 1, 10), C3)
			2:  # lapide squadrata inclinata
				draw_rect(Rect2(x, y - 6, 7, 6), C3)
				draw_rect(Rect2(x + 1, y - 7, 6, 1), C3)
				draw_rect(Rect2(x, y - 6, 2, 6), C4)
	# albero secco a destra
	var tx := tree_base.x
	draw_rect(Rect2(tx, tree_base.y - 40, 3, 41), C0)
	for br in [[-1, 30, -8, -6], [2, 26, 7, -8], [-1, 18, -6, -4], [2, 12, 9, -5], [0, 36, -4, -5]]:
		var sx: float = tx + br[0]
		var sy: float = tree_base.y - br[1]
		var steps := maxi(absi(br[2]), absi(br[3]))
		for i in steps + 1:
			draw_rect(Rect2(roundf(sx + br[2] * i / float(steps)), roundf(sy + br[3] * i / float(steps)), 1, 1), C0)


func _draw_walkers() -> void:
	for w in walkers:
		var col: int = w["kind"] + w["frame"]
		var region := Rect2(col * 16, w["team"] * 16, 16, 16)
		var pos := Vector2(floorf(w["x"]) - 8, ground_y + 12 - 16)
		draw_rect(Rect2(pos + Vector2(4, 15), Vector2(8, 1)), Color(0, 0, 0, 0.4))
		draw_texture_rect_region(ATLAS, Rect2(pos, Vector2(16, 16)), region)


func _draw_fog() -> void:
	for i in 3:
		var y := ground_y - 6 + i * 9
		var off := fmod(t * (4.0 + i * 2.0), 80.0)
		var x := -80.0 + off
		while x < art.x:
			var w := 50.0 + 10.0 * sin(x * 0.1 + i)
			draw_rect(Rect2(floorf(x), y, floorf(w), 3), Color(C5, 0.06))
			draw_rect(Rect2(floorf(x) + 6, y + 1, floorf(w) - 12, 1), Color(C6, 0.05))
			x += 80.0


func _draw_texts() -> void:
	var vp := _screen_size()
	# titolo: grandezza dei pixel scelta per stare nello schermo
	var tp := floorf(minf(9.0, (vp.x - 480.0) / maxf(1.0, PixelFont.text_width(titolo, 1.0))))
	tp = maxf(tp, 3.0)
	var bob := roundf(sin(t * 1.5) * 2.0) * 2.0
	var ty := title_pos.y + bob
	PixelFont.draw_centered(self, titolo, title_pos.x, ty + tp, tp, C0)  # ombra profonda
	PixelFont.draw_centered(self, titolo, title_pos.x, ty, tp, C6, C3)

	# voci del menu: la selezionata è più grande e bianca
	item_rects.clear()
	var y := items_pos.y
	for i in ITEMS.size():
		var sel := i == selected
		var p := ITEM_PIXEL_SELECTED if sel else ITEM_PIXEL
		var h := PixelFont.text_height(p)
		var r := PixelFont.draw_centered(self, ITEMS[i], items_pos.x, y, p, C6 if sel else C4, C0)
		item_rects.append(r)
		if sel:
			var arrow_w := PixelFont.text_width(">", p)
			PixelFont.draw_text(self, ">", Vector2(r.position.x - arrow_w - 3 * p, y), p, C5)
			PixelFont.draw_text(self, "<", Vector2(r.end.x + 3 * p, y), p, C5)
		y += h + 22.0

