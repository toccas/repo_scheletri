@tool
extends Node2D
## Schermata dell'albero delle ricerche, in pixel art e scala di grigi.
## I nodi e le regole stanno in research_data.gd.
##
## Comandi: clic su un nodo per vederne i dettagli, clic su SBLOCCA/POTENZIA
## (o Invio) per comprarlo. Frecce per muoversi tra i nodi. Esc torna al menu.
##
## POSIZIONI: nella scena ci sono dei nodi figli (Marker2D) da spostare
## nell'editor, trascinandoli nella vista 2D o dal loro Transform nell'Inspector.
## Lo script gira anche nell'editor, quindi vedi subito il risultato.
##   Titolo     -> centro in alto della scritta RICERCHE
##   Indietro   -> angolo in alto a sinistra di "< MENU"
##   Punti      -> angolo in alto a DESTRA dei punti (sotto c'è "Azzera ricerche")
##   Albero     -> angolo in alto a sinistra del primo nodo (i nomi dei rami stanno sopra)
##   Dettagli   -> angolo in alto a sinistra del riquadro dei dettagli
## Se un nodo manca, quell'elemento torna alla posizione di partenza.

const PixelFont := preload("res://scripts/pixel_font.gd")
const Suoni := preload("res://scripts/suoni.gd")
const Research := preload("res://scripts/research_data.gd")
const ATLAS := preload("res://assets/sprites.png")
const MENU_SCENE := "res://scenes/menu.tscn"

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")

const NODE := 72.0  # lato di un nodo, in pixel dello schermo
const COL_STEP := 136.0
const ROW_STEP := 108.0
const GRID_TOP := 160.0
const PANEL_TOP := 486.0
const PANEL_H := 210.0
const PANEL_PAD := 24.0  # quanto il riquadro dei dettagli sporge ai lati dell'albero
const ICON_SCALE := 3.0

var st: Dictionary
var t := 0.0
var selected := "mura"
var hovered := ""
var grid_left := 0.0
var grid_top := GRID_TOP
var grid_width := 0.0
var default_grid_left := 0.0
var title_pos := Vector2(640, 30)
var back_pos := Vector2(36, 42)
var points_pos := Vector2(1244, 34)
var panel_pos := Vector2(104, PANEL_TOP)
var buy_rect := Rect2()
var back_rect := Rect2()
var reset_rect := Rect2()
var reset_armed := 0.0  # secondi rimasti per confermare l'azzeramento
var flash := {}  # id -> secondi di lampeggio dopo l'acquisto
var message := ""
var message_t := 0.0
var fade := 1.0
var leaving := false
var stars: Array = []


func _ready() -> void:
	st = Research.load_state()
	Suoni.install()
	if Engine.is_editor_hint():
		fade = 0.0
	var vp := _screen_size()
	var cols := 0
	for id in Research.NODES:
		cols = maxi(cols, Research.NODES[id]["pos"].x + 1)
	grid_width = (cols - 1) * COL_STEP + NODE
	default_grid_left = roundf((vp.x - grid_width) / 2.0)
	_update_layout()
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 99
	for i in 60:
		stars.append({"pos": Vector2(rnd.randi_range(0, int(vp.x / 4.0)), rnd.randi_range(0, int(vp.y / 4.0))), "phase": rnd.randf() * TAU})


## Dimensione dello schermo di gioco (nell'editor quella delle impostazioni del progetto).
func _screen_size() -> Vector2:
	if Engine.is_editor_hint():
		return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	return get_viewport_rect().size


func _marker(node_name: String, fallback: Vector2) -> Vector2:
	var m := get_node_or_null(node_name) as Node2D
	return (m.position if m else fallback).round()


## Legge le posizioni dai nodi segnaposto (in pixel dello schermo).
func _update_layout() -> void:
	var vp := _screen_size()
	title_pos = _marker("Titolo", Vector2(vp.x / 2.0, 30))
	back_pos = _marker("Indietro", Vector2(36, 42))
	points_pos = _marker("Punti", Vector2(vp.x - 36, 34))
	var g := _marker("Albero", Vector2(default_grid_left, GRID_TOP))
	grid_left = g.x
	grid_top = g.y
	panel_pos = _marker("Dettagli", Vector2(default_grid_left - PANEL_PAD, PANEL_TOP))


func node_rect(id: String) -> Rect2:
	var p: Vector2i = Research.NODES[id]["pos"]
	return Rect2(grid_left + p.x * COL_STEP, grid_top + p.y * ROW_STEP, NODE, NODE)


func _process(delta: float) -> void:
	t += delta
	if Engine.is_editor_hint():
		_update_layout()  # anteprima: segue i segnaposto mentre li sposti
		fade = 0.0
	elif leaving:
		fade = minf(1.0, fade + delta * 3.0)
		if fade >= 1.0:
			get_tree().change_scene_to_file(MENU_SCENE)
			return
	else:
		fade = maxf(0.0, fade - delta * 3.0)
	reset_armed = maxf(0.0, reset_armed - delta)
	message_t = maxf(0.0, message_t - delta)
	for id in flash.keys():
		flash[id] -= delta
		if flash[id] <= 0.0:
			flash.erase(id)
	queue_redraw()


# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if leaving or Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion:
		hovered = _node_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		var id := _node_at(p)
		if id != "":
			Suoni.play("click")
			selected = id
		elif buy_rect.grow(6).has_point(p):
			_buy()
		elif back_rect.grow(8).has_point(p):
			Suoni.play("click")
			leaving = true
		elif reset_rect.grow(6).has_point(p):
			_reset()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_BACKSPACE:
				leaving = true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_buy()
			KEY_LEFT, KEY_A:
				_move(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D:
				_move(Vector2i(1, 0))
			KEY_UP, KEY_W:
				_move(Vector2i(0, -1))
			KEY_DOWN, KEY_S:
				_move(Vector2i(0, 1))


func _node_at(p: Vector2) -> String:
	for id in Research.NODES:
		if node_rect(id).grow(4).has_point(p):
			return id
	return ""


## Sposta la selezione verso il nodo più vicino nella direzione indicata.
func _move(dir: Vector2i) -> void:
	var from: Vector2i = Research.NODES[selected]["pos"]
	var best := ""
	var best_d := INF
	for id in Research.NODES:
		var p: Vector2i = Research.NODES[id]["pos"]
		var d := p - from
		var along := d.x * dir.x + d.y * dir.y
		if along <= 0:
			continue
		var side := absi(d.x * dir.y) + absi(d.y * dir.x)
		var score := along + side * 2.5
		if score < best_d:
			best_d = score
			best = id
	if best != "":
		selected = best


func _buy() -> void:
	var lv_before := Research.level(st, selected)
	if Research.buy(st, selected):
		Suoni.play("livello", 1.2, -3.0)
		flash[selected] = 0.6
		message = "%s %s!" % [Research.NODES[selected]["name"], "SBLOCCATO" if lv_before == 0 else "POTENZIATO"]
		message_t = 2.0
	elif Research.next_cost(st, selected) >= 0:
		Suoni.play("errore")
		if not Research.requirements_met(st, selected):
			message = "PRIMA SBLOCCA LA RICERCA RICHIESTA"
		else:
			message = "PUNTI INSUFFICIENTI"
		message_t = 2.0


func _reset() -> void:
	if reset_armed > 0.0:
		Research.refund_all(st)
		reset_armed = 0.0
		message = "RICERCHE AZZERATE: PUNTI RESTITUITI"
		message_t = 2.5
	else:
		reset_armed = 3.0


# --- Disegno ---------------------------------------------------------------

func _draw() -> void:
	var vp := _screen_size()
	_draw_background(vp)

	# intestazione
	PixelFont.draw_centered(self, "RICERCHE", title_pos.x, title_pos.y, 7.0, C6, C0)
	back_rect = Rect2(back_pos, Vector2(PixelFont.text_width("< MENU", 4.0), PixelFont.text_height(4.0)))
	PixelFont.draw_text(self, "< MENU", back_rect.position, 4.0, C6 if back_rect.grow(8).has_point(get_local_mouse_position()) else C5)
	var pts := "PUNTI: %d" % st["points"]
	var pw := PixelFont.text_width(pts, 4.0)
	PixelFont.draw_text(self, pts, Vector2(points_pos.x - pw, points_pos.y), 4.0, C6)
	var rtxt := "CONFERMI? CLICCA ANCORA" if reset_armed > 0.0 else "AZZERA RICERCHE"
	var rw := PixelFont.text_width(rtxt, 2.0)
	reset_rect = Rect2(Vector2(points_pos.x - rw, points_pos.y + 38), Vector2(rw, PixelFont.text_height(2.0)))
	PixelFont.draw_text(self, rtxt, reset_rect.position, 2.0, C6 if reset_armed > 0.0 else C4)

	# titoli dei rami
	for b in Research.BRANCHES:
		var cols: Array = b["cols"]
		var cx: float = grid_left + (cols[0] + cols[cols.size() - 1]) * COL_STEP / 2.0 + NODE / 2.0
		PixelFont.draw_centered(self, b["name"], cx, grid_top - 44, 4.0, C5, C0)
		var w: float = (cols[cols.size() - 1] - cols[0]) * COL_STEP + NODE + 24.0
		draw_rect(Rect2(cx - w / 2.0, grid_top - 16, w, 2), C3)

	# collegamenti tra ricerche
	for id in Research.NODES:
		var req: Array = Research.NODES[id]["requires"]
		if req.is_empty():
			continue
		var a := node_rect(req[0])
		var b := node_rect(id)
		var ok: bool = Research.level(st, req[0]) >= req[1]
		var col := C5 if ok else C2
		var x := roundf(a.get_center().x) - 2.0
		draw_rect(Rect2(x, a.end.y + 18, 4, b.position.y - a.end.y - 22), col)

	# nodi
	for id in Research.NODES:
		_draw_node(id)

	_draw_panel(vp)

	if message_t > 0.0:
		var a := minf(1.0, message_t * 2.0)
		PixelFont.draw_centered(self, message, panel_pos.x + (grid_width + 2 * PANEL_PAD) / 2.0, panel_pos.y - 30, 3.0, Color(C6, a), Color(C0, a))

	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(C0, fade))


func _draw_background(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), C0)
	for i in 4:
		draw_rect(Rect2(0, vp.y - (i + 1) * 40, vp.x, 40), Color(C1, 0.25 * (i + 1)))
	for s in stars:
		var v := 0.5 + 0.5 * sin(t * 1.5 + s["phase"])
		if v > 0.3:
			draw_rect(Rect2(s["pos"] * 4.0, Vector2(4, 4)), C3 if v < 0.85 else C4)


func _border(r: Rect2, w: float, col: Color) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, w)), col)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - w), Vector2(r.size.x, w)), col)
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	draw_rect(Rect2(r.position + Vector2(r.size.x - w, 0), Vector2(w, r.size.y)), col)


func _draw_node(id: String) -> void:
	var n: Dictionary = Research.NODES[id]
	var r := node_rect(id)
	var lv := Research.level(st, id)
	var maxed := lv >= Research.max_level(id)
	var unlocked := Research.requirements_met(st, id)
	var affordable := Research.can_buy(st, id)

	var bg := C1
	var border := C2
	var icon_mod := Color(1, 1, 1, 0.25)
	if maxed:
		bg = C3
		border = C6
		icon_mod = Color.WHITE
	elif lv > 0:
		bg = C2
		border = C5
		icon_mod = Color.WHITE
	elif unlocked:
		bg = C2
		border = C4 if affordable else C3
		icon_mod = Color(1, 1, 1, 0.85)
	if flash.has(id) and int(flash[id] * 20.0) % 2 == 0:
		bg = C5

	draw_rect(r, bg)
	_border(r, 4.0, border)
	if affordable and not maxed and int(t * 2.0) % 2 == 0:
		_border(r.grow(-6), 2.0, C4)  # si può comprare: bordo interno che pulsa
	var icon_pos := r.position + Vector2((NODE - 16 * ICON_SCALE) / 2.0, (NODE - 16 * ICON_SCALE) / 2.0)
	draw_texture_rect_region(ATLAS, Rect2(icon_pos, Vector2(16, 16) * ICON_SCALE), Rect2(n["icon"], Vector2(16, 16)), icon_mod)
	if not unlocked:  # lucchetto
		var lp := r.end - Vector2(22, 24)
		draw_rect(Rect2(lp + Vector2(2, -6), Vector2(10, 4)), C4)
		draw_rect(Rect2(lp + Vector2(2, -6), Vector2(2, 8)), C4)
		draw_rect(Rect2(lp + Vector2(10, -6), Vector2(2, 8)), C4)
		draw_rect(Rect2(lp, Vector2(14, 12)), C4)
		draw_rect(Rect2(lp + Vector2(6, 4), Vector2(2, 4)), C0)

	# livelli: un quadratino per livello sotto il nodo
	var m := Research.max_level(id)
	var pip := 8.0
	var gap := 4.0
	var total := m * pip + (m - 1) * gap
	var x0 := roundf(r.get_center().x - total / 2.0)
	for i in m:
		var pr := Rect2(x0 + i * (pip + gap), r.end.y + 6, pip, pip)
		draw_rect(pr, C6 if i < lv else C2)

	# selezione e passaggio del mouse
	if id == selected:
		var s := r.grow(8.0 + (2.0 if int(t * 3.0) % 2 == 0 else 0.0))
		for c in [s.position, Vector2(s.end.x - 10, s.position.y), Vector2(s.position.x, s.end.y - 10), s.end - Vector2(10, 10)]:
			draw_rect(Rect2(c, Vector2(10, 10)), C6)
	elif id == hovered:
		_border(r.grow(4), 2.0, C5)


## Riquadro in basso con i dettagli della ricerca selezionata.
func _draw_panel(vp: Vector2) -> void:
	var n: Dictionary = Research.NODES[selected]
	var box := Rect2(panel_pos, Vector2(grid_width + 2 * PANEL_PAD, PANEL_H))
	draw_rect(box, C1)
	_border(box, 4.0, C4)
	var lv := Research.level(st, selected)
	var m := Research.max_level(selected)
	var x := box.position.x + 28
	var y := box.position.y + 24

	# icona grande
	draw_rect(Rect2(x, y, 96, 96), C2)
	draw_texture_rect_region(ATLAS, Rect2(x + 8, y + 8, 80, 80), Rect2(n["icon"], Vector2(16, 16)))
	x += 124

	PixelFont.draw_text(self, n["name"], Vector2(x, y), 5.0, C6)
	var branch_name: String = Research.BRANCHES[n["branch"]]["name"]
	PixelFont.draw_text(self, "%s  -  LIVELLO %d/%d" % [branch_name, lv, m], Vector2(x, y + 48), 3.0, C4)
	var lines := _wrap(n["desc"], 33)
	for i in lines.size():
		PixelFont.draw_text(self, lines[i], Vector2(x, y + 84 + i * 30), 3.0, C5)


	# pulsante di acquisto
	var cost := Research.next_cost(st, selected)
	var bw := 260.0
	var bx := box.end.x - 28 - bw
	if cost < 0:
		buy_rect = Rect2()
		PixelFont.draw_centered(self, "MASSIMO", bx + bw / 2.0, y + 40, 5.0, C6)
		PixelFont.draw_centered(self, "RAGGIUNTO", bx + bw / 2.0, y + 86, 5.0, C6)
		return
	PixelFont.draw_centered(self, "COSTO: %d PUNTI" % cost, bx + bw / 2.0, y + 6, 3.0, C5)
	buy_rect = Rect2(bx, y + 44, bw, 64)
	var can := Research.can_buy(st, selected)
	var hover := buy_rect.has_point(get_local_mouse_position())
	draw_rect(buy_rect, C3 if can and hover else (C2 if can else C1))
	_border(buy_rect, 4.0, C6 if can else C3)
	var label := "SBLOCCA" if lv == 0 else "POTENZIA"
	PixelFont.draw_centered(self, label, buy_rect.get_center().x, buy_rect.position.y + 18, 4.0, C6 if can else C3)
	var req: Array = n["requires"]
	if not Research.requirements_met(st, selected):
		var rn: String = Research.NODES[req[0]]["name"]
		PixelFont.draw_centered(self, "RICHIEDE: %s" % rn, buy_rect.get_center().x, buy_rect.end.y + 14, 2.0, C6)
		PixelFont.draw_centered(self, "LIVELLO %d" % req[1], buy_rect.get_center().x, buy_rect.end.y + 34, 2.0, C6)
	elif not can:
		PixelFont.draw_centered(self, "PUNTI INSUFFICIENTI", buy_rect.get_center().x, buy_rect.end.y + 14, 2.0, C4)


## Spezza il testo in righe di al massimo `width` caratteri.
func _wrap(text: String, width: int) -> Array:
	var lines := []
	var line := ""
	for word in text.split(" "):
		if line.length() + word.length() + 1 > width and line != "":
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		lines.append(line)
	return lines
