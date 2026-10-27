extends Control
## Scena EVOCAZIONE (il portale del menu): qui si aprono le pergamene.
##
##   - ogni pergamena evoca un'unità: finché la collezione non è completa è sempre
##     un'unità nuova; dopo, i doppioni ne alzano il rango (+10% vita e danno)
##   - ogni 10 pergamene è garantita un'unità epica o leggendaria
##   - le pergamene si guadagnano superando le ondate 10, 20, 30... (vedi main.gd)
##   - con almeno 10 pergamene puoi aprirne 10 insieme (pulsante APRI 10)
## Tasti: Spazio/Invio = apri una o continua, 0 = apri 10, Esc = torna al menu.

const Data := preload("res://scripts/game_data.gd")
const Portafoglio := preload("res://scripts/portafoglio.gd")
const Collezione := preload("res://scripts/collezione.gd")
const Pietra := preload("res://scripts/ui_pietra.gd")
const MENU_SCENE := "res://scenes/menu.tscn"
const PREP_SCENE := "res://scenes/preparazione.tscn"

## Il tuo tema (per il font). Vuoto = font predefinito.
@export var tema: Theme
## Durata della carica del portale prima che appaia l'unità (secondi).
@export_range(0.3, 4.0, 0.1) var durata_evocazione := 1.6
## Quante pergamene apre il pulsante "APRI 10" (serve averne almeno tante).
@export_range(2, 10) var apertura_multipla := 10
## Secondi tra una carta e l'altra quando apri più pergamene insieme.
@export_range(0.02, 1.0, 0.01) var cadenza_carte := 0.18

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")
const PORTAL := Vector2(640, 250)
const BLOCK := 6.0

enum Fase { ATTESA, CARICA, RIVELA, RIVELA_MULTI }
const TEX_SCROLL := preload("res://assets/negozio/pergamena.png")
const FLIP := 0.18  # durata del giro di una carta
const CARD := Vector2(150, 190)
const CARD_GAP := 14.0

var st: Dictionary
var font: Font
var fase := Fase.ATTESA
var fase_t := 0.0
var result := {}
var results: Array = []  # apertura multipla: un risultato per carta
var t := 0.0
var spin := 2.0
var fade := 1.0
var leaving := ""
var sparks: Array = []
var hover := ""
var open_rect := Rect2(340, 452, 280, 62)
var multi_rect := Rect2(660, 452, 280, 62)
var back_rect := Rect2(24, 652, 120, 50)
var prep_rect := Rect2(980, 652, 276, 50)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if tema:
		theme = tema
	font = get_theme_default_font()
	st = Collezione.load_state()
	Portafoglio.install_dev_tool(get_tree())


func _process(delta: float) -> void:
	t += delta
	fase_t += delta
	if leaving != "":
		fade = minf(1.0, fade + delta * 3.0)
		if fade >= 1.0:
			get_tree().change_scene_to_file(leaving)
			return
	else:
		fade = maxf(0.0, fade - delta * 3.0)
	var target_spin := 2.0
	if fase == Fase.CARICA:
		target_spin = 2.0 + 14.0 * clampf(fase_t / durata_evocazione, 0.0, 1.0)
		if randf() < delta * 60.0:  # scintille risucchiate dal portale
			var a := randf() * TAU
			sparks.append({"p": PORTAL + Vector2(cos(a), sin(a) * 0.8) * randf_range(180, 260), "life": 1.0})
		if fase_t >= durata_evocazione:
			fase = Fase.RIVELA_MULTI if results.size() > 1 else Fase.RIVELA
			fase_t = 0.0
	spin = lerpf(spin, target_spin, minf(1.0, delta * 4.0))
	for s in sparks:
		s["p"] = (s["p"] as Vector2).move_toward(PORTAL, delta * 260.0)
		s["life"] -= delta
	sparks = sparks.filter(func(s): return s["life"] > 0.0 and (s["p"] as Vector2).distance_to(PORTAL) > 8.0)
	var m := get_local_mouse_position()
	hover = ""
	if fase == Fase.ATTESA and open_rect.has_point(m):
		hover = "open"
	elif fase == Fase.ATTESA and multi_rect.has_point(m):
		hover = "multi"
	elif back_rect.has_point(m):
		hover = "back"
	elif prep_rect.has_point(m):
		hover = "prep"
	var revealing := fase == Fase.RIVELA or fase == Fase.RIVELA_MULTI
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover != "" or revealing else Control.CURSOR_ARROW
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if leaving != "" or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if fase == Fase.RIVELA or fase == Fase.RIVELA_MULTI:
		_continue()
	elif hover != "":
		_press(hover)


func _unhandled_input(event: InputEvent) -> void:
	if leaving != "" or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		if fase == Fase.RIVELA or fase == Fase.RIVELA_MULTI:
			_continue()
		elif fase == Fase.ATTESA:
			_press("open")
	elif event.keycode in [KEY_0, KEY_KP_0]:
		if fase == Fase.RIVELA_MULTI:
			_continue()
		elif fase == Fase.ATTESA:
			_press("multi")
	elif event.keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
		_press("back")


func _press(id: String) -> void:
	match id:
		"open":
			if fase != Fase.ATTESA or st["scrolls"] <= 0:
				return
			result = Collezione.open_scroll(st)
			if result.is_empty():
				return
			results = []
			fase = Fase.CARICA
			fase_t = 0.0
		"multi":
			if fase != Fase.ATTESA or st["scrolls"] < apertura_multipla:
				return
			results = []
			for i in apertura_multipla:
				var r := Collezione.open_scroll(st)
				if not r.is_empty():
					results.append(r)
			if results.is_empty():
				return
			print("[evocazione] aperte %d pergamene: %s" % [results.size(), results.map(func(x: Dictionary) -> String: return "%s(%s)" % [x["kind"], x["rarity"]])])
			fase = Fase.CARICA
			fase_t = -0.3  # carica un po' più lunga
		"back":
			leaving = MENU_SCENE
		"prep":
			leaving = PREP_SCENE


func _continue() -> void:
	if fase == Fase.RIVELA_MULTI:
		var all_done := _card_time(results.size() - 1) + FLIP
		if fase_t < all_done:
			fase_t = all_done  # primo clic: gira subito tutte le carte
			return
		if fase_t < all_done + 0.3:
			return
	elif fase_t < 0.5:
		return  # evita di saltare la rivelazione per sbaglio
	fase = Fase.ATTESA
	fase_t = 0.0
	results = []


## Quando inizia a girarsi la carta i.
func _card_time(i: int) -> float:
	return 0.35 + i * cadenza_carte


# --- Disegno -----------------------------------------------------------------

func _draw() -> void:
	var vp := size
	draw_rect(Rect2(Vector2.ZERO, vp), C0)
	_draw_vortex()
	for s in sparks:
		draw_rect(Rect2((s["p"] as Vector2).round(), Vector2(3, 3)), Color(1, 1, 1, clampf(s["life"], 0.0, 1.0)))

	Pietra.banner(self, Rect2(vp.x / 2.0 - 170, 18, 340, 64))
	Pietra.text_c(self, font, vp.x / 2.0, 32, "EVOCAZIONE", 24, C0, false)

	if fase == Fase.RIVELA:
		_draw_reveal()
	elif fase == Fase.RIVELA_MULTI:
		_draw_multi()
	else:
		var n: int = st["scrolls"]
		Pietra.text_c(self, font, vp.x / 2.0, 408, "PERGAMENE: %d" % n, 24, C6)
		var can := n > 0 and fase == Fase.ATTESA
		Pietra.stone(self, open_rect, C4 if can else C2, hover == "open" and can)
		Pietra.text_c(self, font, open_rect.get_center().x, open_rect.position.y + 10, "APRI 1", 24, C6 if can else C4)
		Pietra.text_c(self, font, open_rect.get_center().x, open_rect.position.y + 38, "Spazio", 16, C1, false)
		var can_multi := n >= apertura_multipla and fase == Fase.ATTESA
		Pietra.stone(self, multi_rect, C4 if can_multi else C2, hover == "multi" and can_multi)
		Pietra.text_c(self, font, multi_rect.get_center().x, multi_rect.position.y + 10, "APRI %d" % apertura_multipla, 24, C6 if can_multi else C4)
		var sub := "tasto 0" if n >= apertura_multipla else "ne servono %d" % apertura_multipla
		Pietra.text_c(self, font, multi_rect.get_center().x, multi_rect.position.y + 38, sub, 16, C1 if can_multi else C3, false)
		var left: int = Data.PITY_EVERY - st["pity"]
		var note := "Epica o leggendaria garantita entro %d pergamene" % left
		if n == 0:
			note = "Supera le ondate 10, 20, 30... per ottenere pergamene"
		Pietra.text_c(self, font, vp.x / 2.0, 526, note, 16, C4, false)

	_draw_collection_strip()
	Pietra.stone(self, back_rect, C3, hover == "back")
	Pietra.text_c(self, font, back_rect.get_center().x, back_rect.position.y + 15, "< BACK", 16, C6)
	Pietra.stone(self, prep_rect, C3, hover == "prep")
	Pietra.text_c(self, font, prep_rect.get_center().x, prep_rect.position.y + 15, "PREPARA LA SQUADRA >", 16, C6)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(C0, fade))


## Vortice a blocchi di pixel, più veloce e luminoso durante l'evocazione.
func _draw_vortex() -> void:
	var r_max := 150.0
	var charge := 0.0
	if fase == Fase.CARICA:
		charge = clampf(fase_t / durata_evocazione, 0.0, 1.0)
	elif fase == Fase.RIVELA:
		charge = maxf(0.0, 1.0 - fase_t * 2.0)
	var steps := int(r_max / BLOCK)
	for by in range(-steps, steps + 1):
		for bx in range(-steps, steps + 1):
			var x := bx * BLOCK
			var y := by * BLOCK
			var r := Vector2(x, y * 1.25).length()
			if r > r_max:
				continue
			var a := atan2(y, x)
			var v := sin(a * 3.0 + r * 0.05 - t * spin) * 0.5 + 0.5
			v *= 1.0 - r / r_max
			v += charge * 0.35 * (1.0 - r / r_max)
			var col: Color
			if v > 0.75:
				col = C6
			elif v > 0.55:
				col = C5
			elif v > 0.35:
				col = C3
			elif v > 0.18:
				col = C2
			else:
				continue
			draw_rect(Rect2(PORTAL + Vector2(x, y) - Vector2.ONE * BLOCK / 2.0, Vector2(BLOCK, BLOCK)), col)


func _draw_reveal() -> void:
	var vp := size
	var k: String = result["kind"]
	var d: Dictionary = Data.UNITS[k]
	# lampo bianco all'arrivo
	if fase_t < 0.4:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 1, 1, 1.0 - fase_t / 0.4))
	# raggi che girano dietro l'unità
	var rays: int = {"comune": 6, "raro": 8, "epico": 10, "leggendario": 14}.get(result["rarity"], 6)
	for i in rays:
		var a: float = t * 0.6 + TAU * i / rays
		draw_line(PORTAL, PORTAL + Vector2(cos(a), sin(a)) * 210.0, Color(1, 1, 1, 0.12), 12.0)
	var pop := clampf(fase_t / 0.25, 0.0, 1.0)
	var sz := roundf(160.0 * pop / 16.0) * 16.0
	if sz > 0.0:
		var spr := Rect2(PORTAL - Vector2(sz, sz) / 2.0 + Vector2(0, roundf(sin(t * 2.0) * 4.0)), Vector2(sz, sz))
		draw_texture_rect_region(Data.ally_texture(k), spr, Data.ally_region(k, int(t * 3.0) % 2))
	# rarità, nome e risultato
	var rr := Rect2(vp.x / 2.0 - 140, 352, 280, 44)
	Pietra.stone(self, rr, C4 if result["rarity"] in ["epico", "leggendario"] else C3, result["rarity"] == "leggendario")
	Pietra.text_c(self, font, vp.x / 2.0, 362, Data.RARITY_NAMES[result["rarity"]].to_upper(), 24, C6)
	Pietra.text_c(self, font, vp.x / 2.0, 410, String(d["ally_name"]).to_upper(), 32, C6)
	var res := "NUOVA UNITÀ!" if result["new"] else "RANGO %d  (+%d%% vita e danno)" % [result["rank"], int(round((Collezione.rank_mult(result["rank"]) - 1.0) * 100.0))]
	Pietra.text_c(self, font, vp.x / 2.0, 452, res, 24, C5)
	Pietra.text_block(self, font, Vector2(vp.x / 2.0 - 300, 488), 600, d["desc"], 16, C5)
	if fase_t > 0.5:
		Pietra.text_c(self, font, vp.x / 2.0, 532, "clicca o premi Spazio per continuare", 16, C4, false)


## Tutte le unità in fila: quelle trovate chiare, quelle mancanti come sagome.
func _draw_collection_strip() -> void:
	var n := Data.ALLY_ORDER.size()
	var step := 44.0
	var x0 := roundf((size.x - n * step) / 2.0)
	var y := 578.0
	var hidden := _not_yet_revealed()
	Pietra.text_c(self, font, size.x / 2.0, y - 22, "COLLEZIONE  %d/%d" % [st["owned"].size() - hidden.size(), n], 16, C5)
	for i in n:
		var k: String = Data.ALLY_ORDER[i]
		var r := Rect2(x0 + i * step, y, 40, 40)
		var owned: bool = st["owned"].has(k) and not k in hidden
		var just: bool = (fase == Fase.RIVELA and result.get("kind", "") == k) or _revealed_kind(k)
		draw_rect(r, C6 if just else C1)
		draw_rect(r.grow(-3), C2)
		draw_texture_rect_region(Data.ally_texture(k), Rect2(r.position + Vector2(4, 4), Vector2(32, 32)), Data.ally_region(k),
			Color.WHITE if owned else Color(0, 0, 0, 0.85))


## Nell'apertura multipla: questa unità è già uscita su una carta girata?
func _revealed_kind(k: String) -> bool:
	if fase != Fase.RIVELA_MULTI:
		return false
	for i in results.size():
		if results[i]["kind"] == k and fase_t >= _card_time(i) + FLIP * 0.5:
			return true
	return false


func _card_rect(i: int) -> Rect2:
	var per_row := mini(5, results.size())
	var rows := ceili(results.size() / float(per_row))
	var w := per_row * CARD.x + (per_row - 1) * CARD_GAP
	var h := rows * CARD.y + (rows - 1) * CARD_GAP
	var o := Vector2(roundf((size.x - w) / 2.0), roundf(316.0 - h / 2.0))
	return Rect2(o + Vector2(i % per_row, i / per_row) * (CARD + Vector2.ONE * CARD_GAP), CARD)


## Apertura multipla: le carte si girano una dopo l'altra.
func _draw_multi() -> void:
	var vp := size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(C0, 0.6))  # il portale resta dietro, più scuro
	if fase_t < 0.4:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 1, 1, 1.0 - fase_t / 0.4))
	var news := 0
	var shown := 0
	for i in results.size():
		var r := _card_rect(i)
		var f := clampf((fase_t - _card_time(i)) / FLIP, 0.0, 1.0)
		var front := f >= 0.5
		var sx := absf(cos(f * PI))  # la carta si stringe e si riapre girandosi
		draw_set_transform(r.get_center(), 0.0, Vector2(maxf(sx, 0.02), 1.0))
		var lr := Rect2(-CARD / 2.0, CARD)
		if front:
			shown += 1
			if results[i]["new"]:
				news += 1
			_draw_card_front(lr, results[i], i)
		else:
			Pietra.stone(self, lr, C2)
			draw_rect(lr.grow(-10), C1)
			draw_texture_rect(TEX_SCROLL, Rect2(Vector2(-32, -48), Vector2(64, 64)), false, Color(1, 1, 1, 0.6))
			Pietra.text_c(self, font, 0.0, 30.0, "?", 32, C4)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var all_done := _card_time(results.size() - 1) + FLIP
	var line := "Unità nuove: %d   ·   Doppioni: %d" % [news, shown - news]
	Pietra.text_c(self, font, vp.x / 2.0, 522, line, 16, C5, false)
	var hint := "clicca o premi Spazio per continuare" if fase_t >= all_done else "clicca per girarle tutte"
	Pietra.text_c(self, font, vp.x / 2.0, 98, hint, 16, C4, false)


func _draw_card_front(r: Rect2, res: Dictionary, i: int) -> void:
	var k: String = res["kind"]
	var rar: String = res["rarity"]
	var base: Color = {"comune": C3, "raro": C4, "epico": Color("5e5e5e"), "leggendario": Color("8a8a8a")}.get(rar, C3)
	var top := rar == "epico" or rar == "leggendario"
	if rar == "leggendario":  # bagliore che pulsa attorno alle leggendarie
		var g := 0.25 + 0.2 * sin(t * 5.0 + i)
		draw_rect(r.grow(8), Color(1, 1, 1, g * 0.4))
		draw_rect(r.grow(4), Color(1, 1, 1, g))
	Pietra.stone(self, r, base, top)
	var tag := Rect2(r.position.x + 10, r.position.y + 10, r.size.x - 20, 22)
	draw_rect(tag, C6 if top else C1)
	Pietra.text_c(self, font, 0.0, tag.position.y + 4, Data.RARITY_NAMES[rar].to_upper(), 13, C0 if top else C5, false)
	# l'unità, che ondeggia appena
	var bob := roundf(sin(t * 2.5 + i) * 2.0)
	var spr := Rect2(Vector2(-40, r.position.y + 40 + bob), Vector2(80, 80))
	draw_rect(Rect2(-36, r.position.y + 124, 72, 4), Color(0, 0, 0, 0.35))
	draw_texture_rect_region(Data.ally_texture(k), spr, Data.ally_region(k, int(t * 3.0 + i) % 2))
	var title := String(Data.UNITS[k]["ally_name"]).to_upper()
	var fs := 15
	while fs > 9 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 14:
		fs -= 1
	Pietra.text_c(self, font, 0.0, r.position.y + 132 + (15 - fs) / 2.0, title, fs, C6)
	if res["new"]:
		Pietra.text_c(self, font, 0.0, r.position.y + 158, "NUOVA!", 16, C6)
	else:
		Pietra.text_c(self, font, 0.0, r.position.y + 158, "RANGO %d" % res["rank"], 16, C5)


## Unità nuove appena evocate ma non ancora mostrate (restano sagome nella collezione).
func _not_yet_revealed() -> Array:
	var out: Array = []
	if fase == Fase.CARICA:
		for r in (results if not results.is_empty() else [result]):
			if r.get("new", false):
				out.append(r["kind"])
	elif fase == Fase.RIVELA_MULTI:
		for i in results.size():
			if results[i]["new"] and fase_t < _card_time(i) + FLIP * 0.5:
				out.append(results[i]["kind"])
	return out
