extends Node2D
## Menu principale: il cortile del castello del necromante, sotto assedio.
##
## Gli edifici sono i pulsanti (nodi figli di Mondo/Cortile, script menu_building.gd):
##   AlloggioNecromante -> AVVIA RUN    Ricerca -> RICERCA    Portale -> EVOCAZIONE
## In basso a sinistra BACK chiude il gioco; in alto a sinistra "Bug e consigli".
##
## Livelli di disegno (dal fondo): Cielo, CieloAnim (stelle, nuvole, pipistrelli),
## Orda (assedianti fuori dalle mura), Mura, Difese (difensori, torce, frecce),
## Cortile (edifici e scheletri, ordinati in profondità), Nebbia (nebbia e BACK).
## Tutto dentro Mondo, scalato di scala_pixel: le coordinate sono in pixel dell'arte.
##
## Comandi: mouse; frecce sinistra/destra + Invio; Esc non fa nulla (per uscire c'è BACK).

const PixelFont := preload("res://scripts/pixel_font.gd")
const Portafoglio := preload("res://scripts/portafoglio.gd")
const ATLAS := preload("res://assets/sprites.png")
const FeedbackPanel := preload("res://scripts/feedback_panel.gd")
const GAME_SCENE := "res://scenes/main.tscn"
const PREP_SCENE := "res://scenes/preparazione.tscn"  # AVVIA RUN: prima si sceglie la squadra
const RESEARCH_SCENE := "res://scenes/research.tscn"
const EVOCATION_SCENE := "res://scenes/evocazione.tscn"
const SHOP_SCENE := "res://scenes/negozio.tscn"

## Pixel dello schermo per ogni pixel dell'arte (320x180 -> 1280x720 con 4).
@export_range(2, 6) var scala_pixel := 4

@export_group("Animazioni")
## Assedianti fuori dalle mura.
@export_range(0, 120) var nemici_orda := 54
## Scheletri che girano nel cortile.
@export_range(0, 20) var scheletri_cortile := 7

@export_group("Bug e consigli")
## La tua email: è il destinatario quando il gioco apre l'app email del giocatore.
@export var email_feedback := "tua.email@esempio.com"
## Invio diretto dal gioco, senza app email: incolla qui l'indirizzo del tuo
## modulo Formspree (es. https://formspree.io/f/abcd1234). Vuoto = usa l'app email.
@export var url_invio_feedback := ""
## Versione scritta nei report, per sapere su quale build è successo il problema.
@export var versione_gioco := "0.1"
## Tema del pannello (facoltativo). Vuoto = stile in scala di grigi del gioco.
@export var tema_feedback: Theme

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")

# Geometria delle mura: uguale a make_menu_art.py (wall_inner_y / face_h / rw_*)
const BACK_END := 262
# muro destro in prospettiva: punto di fuga, distanza dal centro del bordo interno/esterno
const VP := Vector2(160.0, -34.7)
const RW_IN := 102.0
const RW_OUT := 110.0
const RW_Z0 := 380.0
const RW_TOP := 127.5
const RW_GROUND := 147.5
# torre quadrata sul muro destro (X da / a, profondità da / a)
const RT := Rect2(84.0, 74.0, 30.0, 22.0)
const ART := Vector2(320, 180)

@onready var mondo: Node2D = $Mondo
@onready var cielo_anim: Node2D = $Mondo/CieloAnim
@onready var orda: Node2D = $Mondo/Orda
@onready var difese: Node2D = $Mondo/Difese
@onready var cortile: Node2D = $Mondo/Cortile
@onready var nebbia: Node2D = $Mondo/Nebbia
@onready var interfaccia: Node2D = $Interfaccia

var t := 0.0
var buildings: Array = []
var hovered = null  # edificio sotto il mouse, oppure "back" / "feedback"
var key_index := -1  # selezione da tastiera
var fade := 1.0
var leaving := false
var next_scene := ""
var quitting := false
var feedback_panel: Node = null
var feedback_rect := Rect2()
var back_rect := Rect2()  # in pixel dell'arte

var stars: Array = []
var clouds: Array = []
var bats: Array = []
var horde: Array = []
var ladders: Array = []
var defenders: Array = []
var arrows: Array = []
var rocks: Array = []
var particles: Array = []
var walkers: Array = []
var catapult_t := 0.0
var torches := [34, 104, 216, 306]
var rnd := RandomNumberGenerator.new()


func _ready() -> void:
	if "--autotest" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
		return
	Engine.time_scale = 1.0
	rnd.randomize()
	Portafoglio.install_dev_tool(get_tree())
	mondo.scale = Vector2.ONE * scala_pixel
	for c in cortile.get_children():
		if c.has_method("hit"):
			buildings.append(c)
	buildings.sort_custom(func(a, b): return a.position.x < b.position.x)
	cielo_anim.draw.connect(_draw_sky_anim)
	orda.draw.connect(_draw_horde)
	difese.draw.connect(_draw_defenses)
	nebbia.draw.connect(_draw_fog)
	interfaccia.draw.connect(_draw_ui)
	_setup_sky()
	_setup_siege()
	_setup_walkers()


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


# --- Geometria delle mura -------------------------------------------------------

static func wall_inner_y(x: float) -> float:
	if x <= BACK_END:
		return 90.0 + 5.0 * pow((x - 150.0) / 150.0, 2.0)
	return VP.y + RW_TOP * (x - VP.x) / RW_IN


static func wall_outer_y(x: float) -> float:
	if x <= BACK_END:
		return wall_inner_y(x) - 4.0
	return VP.y + RW_TOP * (x - VP.x) / RW_OUT


static func face_h(x: float) -> float:
	return 20.0 if x <= BACK_END else 20.0 * (x - VP.x) / RW_IN


## Punto del cortile (a terra) -> coordinate del mondo del muro destro:
## x = distanza dal centro, y = profondità dal muro di fondo.
static func ground_to_world(p: Vector2) -> Vector2:
	var k := (p.y - VP.y) / RW_GROUND
	return Vector2((p.x - VP.x) / k, RW_Z0 * (1.0 - 1.0 / k))


# --- Preparazione -------------------------------------------------------------

func _setup_sky() -> void:
	for i in 70:
		var p := Vector2(rnd.randi_range(0, 319), rnd.randi_range(0, 27))
		if p.distance_to(Vector2(252, 24)) < 18:
			continue
		stars.append({"p": p, "ph": rnd.randf() * TAU, "sp": rnd.randf_range(1.0, 3.0)})
	for i in 4:
		clouds.append({"x": rnd.randf_range(-60, 320), "y": rnd.randf_range(8, 24), "w": rnd.randi_range(30, 60), "sp": rnd.randf_range(1.5, 4.0)})
	for i in 3:
		bats.append({"x": rnd.randf_range(0, 320), "y": rnd.randf_range(12, 34), "sp": rnd.randf_range(10, 18), "ph": rnd.randf() * TAU})


func _setup_siege() -> void:
	for i in nemici_orda:
		horde.append(_new_attacker(true))
	for lx in [72.0, 206.0, 240.0]:
		ladders.append({"x": lx, "state": "wait", "timer": rnd.randf_range(0.5, 4.0), "y": 0.0})
	# difensori: arcieri sparsi, spadaccini accanto alle scale
	for dx in [24.0, 50.0, 96.0, 118.0, 196.0, 224.0, 254.0]:
		defenders.append({"x": dx, "kind": "archer", "timer": rnd.randf_range(0.5, 3.0), "anim": 0.0, "face": -1.0})
	for l in ladders:
		defenders.append({"x": l["x"] + 7.0, "kind": "sword", "timer": 0.0, "anim": 0.0, "face": -1.0, "ladder": l})


func _new_attacker(anywhere: bool) -> Dictionary:
	var x := rnd.randf_range(-6, 300)
	var y := rnd.randf_range(57, wall_outer_y(x) + 2) if anywhere else rnd.randf_range(54, 60)
	var r := rnd.randf()
	var kind := "spear"
	if r < 0.18:
		kind = "torch"
	elif r < 0.32:
		kind = "shield"
	elif r < 0.44:
		kind = "archer"
	return {"x": x, "y": y, "sp": rnd.randf_range(2.0, 5.0), "kind": kind, "ph": rnd.randf() * TAU,
		"fall": 0.0, "shoot": rnd.randf_range(2.0, 8.0), "drift": rnd.randf_range(-1.0, 1.0)}


func _setup_walkers() -> void:
	var kinds := [0, 0, 2, 2, 4, 6, 0, 2, 4, 0, 6, 2, 0, 4, 0, 2, 0, 2, 4, 0]
	for i in scheletri_cortile:
		var s := Sprite2D.new()
		s.texture = ATLAS
		s.region_enabled = true
		s.centered = false
		s.offset = Vector2(-8, -16)
		var w := {"node": s, "kind": kinds[i], "frame": 0, "ft": 0.0, "target": Vector2.ZERO, "wait": rnd.randf_range(0.0, 2.0)}
		w["pos"] = _random_free_point()
		w["target"] = w["pos"]
		s.position = w["pos"]
		cortile.add_child(s)
		walkers.append(w)
		_update_walker_frame(w)


func _free_at(p: Vector2) -> bool:
	if p.x < 18 or p.x > 306 or p.y < 116 or p.y > 174:
		return false
	var w := ground_to_world(p)
	if w.x > RW_IN - 5.0:
		return false  # contro o oltre il muro destro
	if w.x > RT.position.x - 5.0 and w.y < RT.end.y + 3.0:
		return false  # torre quadrata (e l'angolo nascosto dietro di lei)
	for b in buildings:
		if b.footprint().grow(4).has_point(p):
			return false
	return true


func _random_free_point() -> Vector2:
	for i in 60:
		var p := Vector2(rnd.randf_range(20, 300), rnd.randf_range(118, 172))
		if _free_at(p):
			return p
	return Vector2(160, 160)


func _segment_free(a: Vector2, b: Vector2) -> bool:
	for i in range(1, 9):
		if not _free_at(a.lerp(b, i / 8.0)):
			return false
	return true


# --- Ciclo --------------------------------------------------------------------

func _process(delta: float) -> void:
	t += delta
	if leaving:
		fade = minf(1.0, fade + delta * 2.5)
		if fade >= 1.0:
			if quitting:
				get_tree().quit()
			else:
				get_tree().change_scene_to_file(next_scene)
			return
	else:
		fade = maxf(0.0, fade - delta * 1.6)
	_update_hover()
	_update_sky(delta)
	_update_siege(delta)
	_update_walkers(delta)
	_update_particles(delta)
	for n in [cielo_anim, orda, difese, nebbia, interfaccia]:
		n.queue_redraw()


func _update_hover() -> void:
	var new_hover = null
	if feedback_panel == null and not leaving:
		var mouse := get_global_mouse_position()
		var art_mouse := mondo.get_local_mouse_position()
		if feedback_rect.grow(4).has_point(mouse):
			new_hover = "feedback"
		elif back_rect.grow(2).has_point(art_mouse):
			new_hover = "back"
		else:
			# dal più vicino allo spettatore (y maggiore) al più lontano
			var ordered := buildings.duplicate()
			ordered.sort_custom(func(a, b): return a.position.y > b.position.y)
			for b in ordered:
				if b.hit(mouse):
					new_hover = b
					break
		if new_hover == null and key_index >= 0:
			new_hover = _key_target(key_index)
	if not is_same(new_hover, hovered):
		hovered = new_hover
		for b in buildings:
			b.set_highlight(is_same(b, hovered))
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered != null else Input.CURSOR_ARROW)


func _key_target(i: int):
	var items: Array = buildings.duplicate()
	items.append("back")
	return items[posmod(i, items.size())]


func _unhandled_input(event: InputEvent) -> void:
	if leaving or feedback_panel != null:
		return
	if event is InputEventMouseMotion:
		key_index = -1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hovered != null:
			_activate(hovered)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT, KEY_D:
				key_index = 0 if key_index < 0 else key_index + 1
			KEY_LEFT, KEY_A:
				key_index = 0 if key_index < 0 else key_index - 1
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if hovered != null:
					_activate(hovered)


func _activate(target) -> void:
	if target is String:
		if target == "feedback":
			_open_feedback()
		elif target == "back":
			quitting = true
			leaving = true
		return
	match target.azione:
		0:
			next_scene = PREP_SCENE
		1:
			next_scene = RESEARCH_SCENE
		2:
			next_scene = EVOCATION_SCENE
		3:
			next_scene = SHOP_SCENE
	leaving = true
	# piccolo lampo sull'edificio scelto
	for i in 14:
		var a := rnd.randf() * TAU
		particles.append({"p": target.position + Vector2(0, -20), "v": Vector2(cos(a), sin(a)) * rnd.randf_range(10, 30),
			"life": 0.6, "max": 0.6, "col": C6, "g": 0.0, "layer": "fog"})


func _open_feedback() -> void:
	feedback_panel = FeedbackPanel.new()
	feedback_panel.email_to = email_feedback.strip_edges()
	feedback_panel.send_url = url_invio_feedback.strip_edges()
	feedback_panel.game_version = versione_gioco
	feedback_panel.theme_override = tema_feedback
	feedback_panel.closed.connect(func(): feedback_panel = null)
	add_child(feedback_panel)


# --- Cielo ----------------------------------------------------------------------

func _update_sky(delta: float) -> void:
	for c in clouds:
		c["x"] += c["sp"] * delta
		if c["x"] > 330:
			c["x"] = -c["w"] - 10.0
			c["y"] = rnd.randf_range(8, 24)
	for b in bats:
		b["x"] += b["sp"] * delta
		if b["x"] > 330:
			b["x"] = -10.0
			b["y"] = rnd.randf_range(12, 34)


func _draw_sky_anim() -> void:
	var n := cielo_anim
	for s in stars:
		var v: float = 0.5 + 0.5 * sin(t * s["sp"] + s["ph"])
		if v > 0.3:
			n.draw_rect(Rect2(s["p"], Vector2.ONE), Color(C5, v) if v > 0.85 else Color(C3, v))
	for c in clouds:
		var x0: float = floorf(c["x"])
		var y0: float = c["y"]
		var w: int = c["w"]
		for i in w:
			var hgt := int(3 + 3 * sin(i / float(w) * PI))
			for j in hgt:
				if (i + j * 2) % 3 != 0:
					n.draw_rect(Rect2(x0 + i, y0 - j, 1, 1), Color(C2, 0.55))
		n.draw_rect(Rect2(x0 + 4, y0 + 1, w - 8, 1), Color(C3, 0.4))
	for b in bats:
		var up := int(t * 8.0 + b["ph"]) % 2 == 0
		var p := Vector2(floorf(b["x"]), floorf(b["y"] + 3.0 * sin(t * 2.0 + b["ph"])))
		n.draw_rect(Rect2(p, Vector2.ONE), C0)
		var wy := -1.0 if up else 0.0
		n.draw_rect(Rect2(p + Vector2(-2, wy), Vector2(2, 1)), C0)
		n.draw_rect(Rect2(p + Vector2(1, wy), Vector2(2, 1)), C0)


# --- Assedio --------------------------------------------------------------------

func _update_siege(delta: float) -> void:
	for a in horde:
		if a["fall"] > 0.0:
			a["fall"] += delta
			if a["fall"] > 0.9:
				a.merge(_new_attacker(false), true)
			continue
		a["y"] += a["sp"] * delta
		a["x"] += a["drift"] * delta
		# gli arcieri nemici si fermano a tirare verso le mura
		if a["kind"] == "archer":
			a["shoot"] -= delta
			if a["shoot"] <= 0.0 and a["y"] > 62:
				a["shoot"] = rnd.randf_range(3.0, 7.0)
				var tx: float = a["x"] + rnd.randf_range(-20, 20)
				_launch_arrow(Vector2(a["x"], a["y"] - 6), Vector2(tx, wall_outer_y(tx) - 3), false)
		if a["y"] > wall_outer_y(a["x"]) + 5:  # sparito dietro le mura: ne arriva un altro
			a.merge(_new_attacker(false), true)
	# scale d'assedio: uno sale, combatte, viene buttato giù
	for l in ladders:
		l["timer"] -= delta
		match l["state"]:
			"wait":
				if l["timer"] <= 0.0:
					l["state"] = "climb"
					l["y"] = 0.0
			"climb":
				l["y"] = minf(1.0, l["y"] + delta * 0.8)
				if l["y"] >= 1.0:
					l["state"] = "fight"
					l["timer"] = rnd.randf_range(0.8, 1.6)
			"fight":
				if l["timer"] <= 0.0:
					l["state"] = "fall"
					l["timer"] = 0.6
					_burst(Vector2(l["x"] + 2, wall_outer_y(l["x"]) - 10), 6, C6)
			"fall":
				l["y"] -= delta * 2.2
				if l["timer"] <= 0.0:
					l["state"] = "wait"
					l["timer"] = rnd.randf_range(2.0, 5.0)
	# difensori
	for d in defenders:
		d["anim"] = maxf(0.0, d["anim"] - delta)
		if d["kind"] == "archer":
			d["timer"] -= delta
			if d["timer"] <= 0.0:
				d["timer"] = rnd.randf_range(1.5, 4.0)
				var target = _nearest_attacker(d["x"])
				if target != null:
					d["anim"] = 0.3
					d["face"] = signf(target["x"] - d["x"]) if target["x"] != d["x"] else -1.0
					var arrow := _launch_arrow(Vector2(d["x"], wall_outer_y(d["x"]) - 9), Vector2(target["x"], target["y"] - 3), true)
					arrow["victim"] = target
		else:
			var l: Dictionary = d["ladder"]
			if l["state"] == "fight" and d["anim"] <= 0.0:
				d["anim"] = 0.35
				_burst(Vector2(l["x"] + 2, wall_outer_y(l["x"]) - 9), 3, C6)
	# frecce
	for ar in arrows:
		ar["t"] += delta / ar["dur"]
		if ar["t"] >= 1.0:
			if ar.has("victim") and ar["victim"]["fall"] <= 0.0:
				ar["victim"]["fall"] = 0.01
			_burst(ar["b"], 2, C5)
	arrows = arrows.filter(func(ar): return ar["t"] < 1.0)
	# catapulta lontana
	catapult_t += delta
	if catapult_t > 5.5:
		catapult_t = 0.0
		var tx := rnd.randf_range(30, 250)
		if absf(tx - 160) < 30:
			tx += 60
		rocks.append({"a": Vector2(286, 55), "b": Vector2(tx, wall_outer_y(tx) - 2), "t": 0.0, "dur": 2.2})
	for r in rocks:
		r["t"] += delta / r["dur"]
		if r["t"] >= 1.0:
			_burst(r["b"], 12, C4)
			for i in 6:
				particles.append({"p": r["b"], "v": Vector2(rnd.randf_range(-12, 12), rnd.randf_range(-20, -6)),
					"life": 0.8, "max": 0.8, "col": C3, "g": 40.0, "layer": "def"})
	rocks = rocks.filter(func(r): return r["t"] < 1.0)


func _nearest_attacker(x: float):
	var best = null
	var best_d := 1e9
	for a in horde:
		if a["fall"] > 0.0 or a["y"] < 60:
			continue
		var d := absf(a["x"] - x) + rnd.randf_range(0, 40)
		if d < best_d:
			best_d = d
			best = a
	return best


func _launch_arrow(a: Vector2, b: Vector2, defender: bool) -> Dictionary:
	var ar := {"a": a, "b": b, "t": 0.0, "dur": 0.7 + a.distance_to(b) / 90.0, "def": defender}
	arrows.append(ar)
	return ar


func _arrow_pos(ar: Dictionary, k: float) -> Vector2:
	var p: Vector2 = (ar["a"] as Vector2).lerp(ar["b"], k)
	return p - Vector2(0, sin(k * PI) * (10.0 + (ar["a"] as Vector2).distance_to(ar["b"]) * 0.25))


func _burst(p: Vector2, n: int, col: Color) -> void:
	for i in n:
		var a := rnd.randf() * TAU
		particles.append({"p": p, "v": Vector2(cos(a), sin(a)) * rnd.randf_range(6, 18), "life": 0.35, "max": 0.35,
			"col": col, "g": 20.0, "layer": "def"})


func _update_particles(delta: float) -> void:
	for p in particles:
		p["life"] -= delta
		p["v"] += Vector2(0, p["g"] * delta)
		p["p"] += p["v"] * delta
	particles = particles.filter(func(p): return p["life"] > 0.0)


## Figurina lontana a pixel (6-8 di altezza): umani scuri, scheletri chiari.
func _draw_mini(n: CanvasItem, x: float, y: float, skeleton: bool, kind: String, ph: float, face: float, anim: float = 0.0) -> void:
	var p := Vector2(roundf(x), roundf(y))
	var step := int(t * 6.0 + ph) % 2
	var far := y < 64.0  # in lontananza più piccoli
	var body := Color("cfcfcf") if skeleton else Color("3e3e40")
	var head := Color("ececec") if skeleton else Color("6a6a6c")
	if far:
		n.draw_rect(Rect2(p + Vector2(-1, -5), Vector2(2, 2)), head)
		n.draw_rect(Rect2(p + Vector2(-1, -3), Vector2(2, 2)), body)
		n.draw_rect(Rect2(p + Vector2(-1 + step, -1), Vector2(1, 1)), body)
	else:
		n.draw_rect(Rect2(p + Vector2(-1, -8), Vector2(3, 3)), head)
		if skeleton:
			n.draw_rect(Rect2(p + Vector2(0 if face > 0 else -1, -7), Vector2(1, 1)), C0)
		else:
			n.draw_rect(Rect2(p + Vector2(-1, -8), Vector2(3, 1)), Color("8a8a8c"))  # elmo
		n.draw_rect(Rect2(p + Vector2(-1, -5), Vector2(3, 3)), body)
		n.draw_rect(Rect2(p + Vector2(-1 + step, -2), Vector2(1, 2)), body)
		n.draw_rect(Rect2(p + Vector2(1 - step, -2), Vector2(1, 2)), body)
	var hand := p + Vector2(2 * face, -5)
	match kind:
		"spear":
			n.draw_rect(Rect2(hand + Vector2(0, -6), Vector2(1, 8)), Color("6a6a6c"))
			n.draw_rect(Rect2(hand + Vector2(0, -7), Vector2(1, 1)), Color("acacac"))
		"torch":
			n.draw_rect(Rect2(hand + Vector2(0, -3), Vector2(1, 4)), Color("4a4a4a"))
			var fl := 1.0 + absf(sin(t * 11.0 + ph)) * 1.5
			n.draw_rect(Rect2(hand + Vector2(0, -3 - fl), Vector2(1, fl)), C6)
			n.draw_rect(Rect2(hand + Vector2(-2, -6), Vector2(5, 4)), Color(1, 1, 1, 0.07))
		"shield":
			n.draw_rect(Rect2(p + Vector2(face * 2 - 1, -6), Vector2(2, 4)), Color("8a8a8c"))
		"archer":
			n.draw_rect(Rect2(hand + Vector2(0, -2), Vector2(1, 4)), Color("6a6a6c"))
		"bow":
			n.draw_rect(Rect2(hand + Vector2(0, -2 - (1 if anim > 0.0 else 0)), Vector2(1, 4)), Color("acacac"))
		"sword":
			var up := anim > 0.15
			if up:
				n.draw_rect(Rect2(hand + Vector2(0, -4), Vector2(1, 4)), C6)
			else:
				n.draw_rect(Rect2(hand + Vector2(0, -1), Vector2(3 * face, 1)).abs(), C6)


func _draw_horde() -> void:
	var n := orda
	# nebbia bassa sul campo di battaglia
	for i in 3:
		var y := 62.0 + i * 7.0
		var off := fmod(t * (3.0 + i), 90.0)
		var x := -90.0 + off
		while x < ART.x:
			n.draw_rect(Rect2(floorf(x), y, 60, 2), Color(C4, 0.05))
			x += 90.0
	# fuochi del campo nemico
	for fx_ in [30.0, 63.0, 228.0, 300.0]:
		var hgt := 2.0 + roundf(absf(sin(t * 7.0 + fx_)) * 2.0)
		n.draw_rect(Rect2(fx_, 62 - hgt, 2, hgt), C6)
		n.draw_rect(Rect2(fx_ - 3, 58, 8, 5), Color(1, 1, 1, 0.06))
	# catapulta lontana (a destra)
	var cp := Vector2(286, 60)
	n.draw_rect(Rect2(cp + Vector2(-5, -2), Vector2(10, 2)), Color("4a4a4a"))
	n.draw_rect(Rect2(cp + Vector2(-4, 0), Vector2(2, 2)), C2)
	n.draw_rect(Rect2(cp + Vector2(2, 0), Vector2(2, 2)), C2)
	var arm := clampf(catapult_t / 0.3, 0.0, 1.0) if catapult_t < 0.3 else clampf(1.0 - (catapult_t - 0.3) / 4.5, 0.0, 1.0)
	var tip := cp + Vector2(-2, -2) + Vector2(cos(lerpf(PI * 0.95, PI * 0.35, arm)), -sin(lerpf(PI * 0.95, PI * 0.35, arm))) * 8.0
	_line(n, cp + Vector2(-2, -2), tip, Color("707070"))
	# scale appoggiate alle mura (la parte bassa la coprono le mura)
	for l in ladders:
		var lx: float = l["x"]
		var top := wall_outer_y(lx) - 12.0
		for y in range(int(top), int(wall_outer_y(lx) + 12)):
			n.draw_rect(Rect2(lx, y, 1, 1), Color("6a6a6c"))
			n.draw_rect(Rect2(lx + 4, y, 1, 1), Color("6a6a6c"))
			if (y - int(top)) % 3 == 0:
				n.draw_rect(Rect2(lx + 1, y, 3, 1), Color("4a4a4a"))
		if l["state"] != "wait":
			var k: float = clampf(l["y"], 0.0, 1.0)
			var cy := lerpf(wall_outer_y(lx) + 10.0, top + 6.0, k)
			_draw_mini(n, lx + 2.5, cy, false, "sword" if l["state"] == "fight" else "shield", lx, 1.0)
	# assedianti, dal più lontano al più vicino
	var sorted := horde.duplicate()
	sorted.sort_custom(func(a, b): return a["y"] < b["y"])
	for a in sorted:
		var y: float = a["y"]
		if a["fall"] > 0.0:
			if int(a["fall"] * 12.0) % 2 == 0:
				n.draw_rect(Rect2(roundf(a["x"]) - 1, roundf(y) - 2, 4, 2), Color("3e3e40"))
			continue
		_draw_mini(n, a["x"], y, false, a["kind"], a["ph"], 1.0)


func _draw_defenses() -> void:
	var n := difese
	# torce sulle mura
	for tx in torches:
		var yi := wall_inner_y(tx)
		var hgt := 2.0 + roundf(absf(sin(t * 9.0 + tx)) * 2.0)
		n.draw_rect(Rect2(tx, yi + 5 - hgt, 1, hgt), C6)
		n.draw_rect(Rect2(tx - 1, yi + 4, 3, 1), Color(1, 1, 1, 0.6))
		var k := 0.05 + 0.04 * absf(sin(t * 5.0 + tx))
		n.draw_rect(Rect2(tx - 5, yi, 11, 10), Color(1, 1, 1, k))
	# alone del cerchio rituale al centro del cortile
	var pulse := 0.04 + 0.04 * absf(sin(t * 1.3))
	for i in 3:
		var rx := 58.0 - i * 10.0
		var ry := 15.0 - i * 2.6
		for a in 64:
			var ang := a / 64.0 * TAU + t * (0.3 if i % 2 == 0 else -0.3)
			var p := Vector2(160 + cos(ang) * rx, 146 + sin(ang) * ry).round()
			if a % 2 == 0:
				n.draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, pulse * 3.0))
	# difensori sul camminamento
	for d in defenders:
		var x: float = d["x"]
		var y := wall_outer_y(x) + 1.0
		var kind := "bow" if d["kind"] == "archer" else "sword"
		_draw_mini(n, x, y, true, kind, x, d["face"], d["anim"])
	# frecce in volo
	for ar in arrows:
		var k: float = ar["t"]
		var p := _arrow_pos(ar, k)
		var q := _arrow_pos(ar, maxf(0.0, k - 0.04))
		_line(n, q.round(), p.round(), C5 if ar["def"] else Color("8a8a8c"))
	# massi della catapulta
	for r in rocks:
		var k: float = r["t"]
		var p: Vector2 = (r["a"] as Vector2).lerp(r["b"], k) - Vector2(0, sin(k * PI) * 46.0)
		n.draw_rect(Rect2(p.round() - Vector2.ONE, Vector2(3, 3)), Color("707070"))
		n.draw_rect(Rect2(p.round() - Vector2.ONE, Vector2(1, 1)), C5)
	for p in particles:
		if p["layer"] == "def":
			n.draw_rect(Rect2((p["p"] as Vector2).round(), Vector2.ONE), Color(p["col"], clampf(p["life"] / p["max"], 0.0, 1.0)))


func _line(n: CanvasItem, a: Vector2, b: Vector2, col: Color) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in steps + 1:
		var p := a.lerp(b, i / maxf(1.0, steps)).round()
		n.draw_rect(Rect2(p, Vector2.ONE), col)


# --- Scheletri nel cortile ----------------------------------------------------------

func _update_walker_frame(w: Dictionary) -> void:
	var s: Sprite2D = w["node"]
	s.region_rect = Rect2((w["kind"] + w["frame"]) * 16, 0, 16, 16)


func _update_walkers(delta: float) -> void:
	for w in walkers:
		var s: Sprite2D = w["node"]
		if w["wait"] > 0.0:
			w["wait"] -= delta
			if w["frame"] != 0:
				w["frame"] = 0
				_update_walker_frame(w)
			if w["wait"] <= 0.0:
				# nuova meta raggiungibile in linea retta senza attraversare edifici
				for i in 20:
					var p := _random_free_point()
					if p.distance_to(w["pos"]) > 20 and _segment_free(w["pos"], p):
						w["target"] = p
						break
			continue
		var speed := 9.0 if w["kind"] != 6 else 6.0
		var before: Vector2 = w["pos"]
		w["pos"] = before.move_toward(w["target"], speed * delta)
		if absf(w["pos"].x - before.x) > 0.001:
			s.flip_h = w["pos"].x < before.x
		w["ft"] += delta
		if w["ft"] > 0.2:
			w["ft"] = 0.0
			w["frame"] = 1 - w["frame"]
			_update_walker_frame(w)
		if w["pos"].distance_to(w["target"]) < 0.5:
			w["wait"] = rnd.randf_range(1.0, 4.0)
		s.position = (w["pos"] as Vector2).round()  # pixel interi: restano nitidi


# --- Nebbia, BACK, interfaccia ----------------------------------------------------------

func _draw_fog() -> void:
	var n := nebbia
	for i in 3:
		var y := 150.0 + i * 9.0
		var off := fmod(t * (4.0 + i * 1.5), 100.0)
		var x := -100.0 + off
		while x < ART.x:
			var w := 70.0 + 12.0 * sin(x * 0.07 + i)
			n.draw_rect(Rect2(floorf(x), y, floorf(w), 3), Color(C5, 0.05))
			n.draw_rect(Rect2(floorf(x) + 8, y + 1, floorf(w) - 16, 1), Color(C6, 0.04))
			x += 100.0
	for p in particles:
		if p["layer"] == "fog":
			n.draw_rect(Rect2((p["p"] as Vector2).round(), Vector2.ONE), Color(p["col"], clampf(p["life"] / p["max"], 0.0, 1.0)))
	_draw_back_sign(n)


## Cartello di pietra "BACK" in basso a sinistra, con faccia superiore e lato in ombra.
func _draw_back_sign(n: CanvasItem) -> void:
	var anchor := Vector2(8, 170)
	var m := mondo.get_node_or_null("Back") as Node2D
	if m:
		anchor = m.position.round()
	var label := "< BACK"
	var tw := PixelFont.text_width(label, 1.0)
	var size := Vector2(tw + 10, 13)
	var r := Rect2(anchor - Vector2(0, size.y), size)
	back_rect = r
	var hot: bool = hovered is String and hovered == "back"
	if hot:  # contorno bianco come gli edifici
		n.draw_rect(r.grow(2), C6)
	n.draw_rect(r.grow(1), C0)
	n.draw_rect(Rect2(r.position + Vector2(2, -3), Vector2(size.x, 3)), Color("8a8a8c"))  # faccia superiore
	n.draw_rect(Rect2(r.position + Vector2(size.x, -1), Vector2(2, size.y)), C2)  # lato
	n.draw_rect(r, Color("5e5e60") if not hot else Color("707070"))
	n.draw_rect(Rect2(r.position, Vector2(size.x, 1)), C4)
	n.draw_rect(Rect2(r.position + Vector2(0, size.y - 1), Vector2(size.x, 1)), C1)
	var tp := r.position + Vector2(5, 3)
	PixelFont.draw_text(n, label, tp + Vector2(1, 1), 1.0, C0)
	PixelFont.draw_text(n, label, tp, 1.0, C6 if hot else C5)


func _draw_ui() -> void:
	var n := interfaccia
	_draw_feedback_button(n)
	if fade > 0.0:
		n.draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(C0, fade))


## Piccolo pulsante "Bug e consigli" in alto a sinistra (pixel dello schermo).
func _draw_feedback_button(n: CanvasItem) -> void:
	var pos := Vector2(20, 20)
	var m := get_node_or_null("Feedback") as Node2D
	if m:
		pos = m.position.round()
	var p := 2.0
	var label := "BUG E CONSIGLI"
	var tw := PixelFont.text_width(label, p)
	var size := Vector2(10 + 14 + 8 + tw + 10, 14 + PixelFont.text_height(p))
	feedback_rect = Rect2(pos, size)
	var hot: bool = hovered is String and hovered == "feedback"
	n.draw_rect(feedback_rect, Color(C1, 0.85) if not hot else C2)
	var border := C6 if hot else C4
	n.draw_rect(Rect2(feedback_rect.position, Vector2(size.x, 2)), border)
	n.draw_rect(Rect2(feedback_rect.position + Vector2(0, size.y - 2), Vector2(size.x, 2)), border)
	n.draw_rect(Rect2(feedback_rect.position, Vector2(2, size.y)), border)
	n.draw_rect(Rect2(feedback_rect.position + Vector2(size.x - 2, 0), Vector2(2, size.y)), border)
	var bug := [".#...#.", "..#.#..", "#.###.#", ".#####.", "#.###.#", ".#####.", "#..#..#"]
	var o := feedback_rect.position + Vector2(10, 7)
	for y in bug.size():
		for x in bug[y].length():
			if bug[y][x] == "#":
				n.draw_rect(Rect2(o + Vector2(x, y) * 2.0, Vector2(2, 2)), C6 if hot else C5)
	PixelFont.draw_text(n, label, feedback_rect.position + Vector2(10 + 14 + 8, 7), p, C6 if hot else C5)
