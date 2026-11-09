extends Control
## SCELTA DEL LIVELLO: compare dopo "AVVIA RUN", prima della preparazione della squadra.
## I livelli stanno in livelli/elenco_livelli.tres (doppio clic per modificarli):
## ognuno si sblocca finendo quello prima. Il dev tool (Ctrl+Shift+D, scheda LIVELLI)
## li sblocca tutti.
## Finito un livello, si sblocca anche la sua MODALITÀ INFINITA (ondate senza fine)
## con la sua classifica delle 10 corse migliori.
## Tasti: frecce sinistra/destra = livello, su/giù = storia o infinita, Invio = gioca,
## C = classifica, Esc = torna al menu.

const Pietra := preload("res://scripts/ui_pietra.gd")
const Suoni := preload("res://scripts/suoni.gd")
const Lingua := preload("res://scripts/lingua.gd")
const Dialoghi := preload("res://scripts/dialoghi.gd")
const Livelli := preload("res://scripts/livelli.gd")
const Portafoglio := preload("res://scripts/portafoglio.gd")
const Data := preload("res://scripts/game_data.gd")
const ATLAS := preload("res://assets/sprites.png")
const PREP_SCENE := "res://scenes/preparazione.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"
const LOCK: Array[String] = ["..KKK..", ".K...K.", ".K...K.", "KKKKKKK", "KWWWWWK", "KWWKWWK", "KWWKWWK", "KKKKKKK"]

## L'elenco dei livelli (in ordine di sblocco).
@export var elenco: ElencoLivelli = preload("res://livelli/elenco_livelli.tres")
## Dialogo del necromante che spiega questa scena (solo la prima volta).
@export var dialogo_tutorial: Dialogo = preload("res://dialoghi/livelli.tres")
## Il tuo tema (per il font).
@export var tema: Theme

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")

var font: Font
var lista: Array[InfoLivello] = []
var sel := 0
var hover := -1
var hover_back := false
var t := 0.0
var fade := 1.0
var leaving := ""
var rects: Array[Rect2] = []
var back_rect := Rect2(24, 652, 120, 50)
var msg := ""
var msg_t := 0.0
## Pulsanti dentro le schede: [{rect, azione ("storia"/"infinita"/"classifica"), i}]
var bottoni: Array[Dictionary] = []
var hover_btn := -1
## Modalità scelta con la tastiera sulla scheda selezionata.
var modo_inf := false
## Classifica aperta (indice del livello) o -1.
var classifica_i := -1
var cl_prev := Rect2()
var cl_next := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tema:
		theme = tema
	font = get_theme_default_font()
	Portafoglio.install_dev_tool(get_tree())
	Suoni.install()
	Lingua.setup()
	Dialoghi.avvia(self, dialogo_tutorial)
	lista = elenco.livelli if elenco else ([] as Array[InfoLivello])
	# parte dal livello scelto l'ultima volta (o dall'ultimo sbloccato)
	var last := Livelli.scelto()
	for i in lista.size():
		if lista[i].id == last and Livelli.sbloccato(lista, i):
			sel = i
			modo_inf = Livelli.modalita_infinita() and Livelli.finito(last)


func _process(delta: float) -> void:
	t += delta
	msg_t = maxf(0.0, msg_t - delta)
	if leaving != "":
		fade = minf(1.0, fade + delta * 3.0)
		if fade >= 1.0:
			get_tree().change_scene_to_file(leaving)
			return
	else:
		fade = maxf(0.0, fade - delta * 3.0)
	var m := get_local_mouse_position()
	_aggiorna_hover(m)
	var mano := hover_btn >= 0 or hover_back or (hover >= 0 and Livelli.sbloccato(lista, hover))
	if classifica_i >= 0:
		mano = cl_prev.has_point(m) or cl_next.has_point(m)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if mano else Control.CURSOR_ARROW
	queue_redraw()


func _aggiorna_hover(m: Vector2) -> void:
	hover = -1
	hover_btn = -1
	hover_back = false
	if classifica_i < 0:
		for i in rects.size():
			if rects[i].has_point(m):
				hover = i
		for k in bottoni.size():
			if (bottoni[k]["rect"] as Rect2).has_point(m):
				hover_btn = k
		hover_back = back_rect.has_point(m)


func _gui_input(event: InputEvent) -> void:
	if leaving != "" or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_aggiorna_hover(event.position)  # sul telefono il tocco arriva senza movimento prima
	if classifica_i >= 0:
		var m: Vector2 = event.position
		if cl_prev.has_point(m):
			_cambia_classifica(-1)
		elif cl_next.has_point(m):
			_cambia_classifica(1)
		else:
			Suoni.play("click", 0.9)
			classifica_i = -1
		return
	if hover_btn >= 0:
		var bt: Dictionary = bottoni[hover_btn]
		sel = bt["i"]
		match bt["azione"]:
			"storia":
				modo_inf = false
				_gioca(sel)
			"infinita":
				modo_inf = true
				_gioca(sel, true)
			"classifica":
				Suoni.play("click")
				classifica_i = sel
	elif hover_back:
		_back()
	elif hover >= 0:
		if Livelli.finito(lista[hover].id) and hover != sel:
			sel = hover  # livello finito: prima si sceglie la modalità con i pulsanti
			Suoni.play("click", 0.9)
		else:
			sel = hover
			_gioca(hover, modo_inf and Livelli.finito(lista[hover].id))


func _unhandled_input(event: InputEvent) -> void:
	if leaving != "" or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if classifica_i >= 0:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_cambia_classifica(-1)
			KEY_RIGHT, KEY_D:
				_cambia_classifica(1)
			KEY_ESCAPE, KEY_BACKSPACE, KEY_C, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				Suoni.play("click", 0.9)
				classifica_i = -1
		return
	match event.keycode:
		KEY_UP, KEY_W, KEY_DOWN, KEY_S:
			if sel < lista.size() and Livelli.finito(lista[sel].id):
				modo_inf = not modo_inf
				Suoni.play("click", 0.9)
		KEY_C:
			if sel < lista.size():
				Suoni.play("click")
				classifica_i = sel
		KEY_LEFT, KEY_A:
			sel = posmod(sel - 1, maxi(1, lista.size()))
			Suoni.play("click", 0.9)
		KEY_RIGHT, KEY_D:
			sel = posmod(sel + 1, maxi(1, lista.size()))
			Suoni.play("click", 0.9)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if sel < lista.size():
				_gioca(sel, modo_inf and Livelli.finito(lista[sel].id))
		KEY_ESCAPE, KEY_BACKSPACE:
			_back()


func _back() -> void:
	Suoni.play("click")
	leaving = MENU_SCENE


func _cambia_classifica(d: int) -> void:
	Suoni.play("click", 0.9)
	classifica_i = posmod(classifica_i + d, maxi(1, lista.size()))


func _gioca(i: int, infinita: bool = false) -> void:
	if i < 0 or i >= lista.size():
		return
	if not Livelli.sbloccato(lista, i):
		Suoni.play("errore")
		msg = tr("Finisci \"%s\" per sbloccare questo livello.") % tr(lista[i - 1].nome)
		msg_t = 2.5
		return
	Suoni.play("conferma")
	Livelli.scegli(lista[i], infinita and Livelli.finito(lista[i].id))
	leaving = PREP_SCENE


# --- Disegno -----------------------------------------------------------------

func _draw() -> void:
	var vp := size
	draw_rect(Rect2(Vector2.ZERO, vp), C0)
	for i in 50:  # stelle
		var p := Vector2(fmod(i * 127.3, vp.x), fmod(i * 71.9, vp.y * 0.6))
		var a := 0.15 + 0.3 * absf(sin(t * (1.0 + i % 3) + i))
		draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(1, 1, 1, a))
	Pietra.banner(self, Rect2(vp.x / 2.0 - 260, 18, 520, 64))
	Pietra.text_c(self, font, vp.x / 2.0, 32, tr("SCEGLI IL CAMPO DI BATTAGLIA"), 24, C0, false)

	var n := lista.size()
	var gap := 20.0
	var cw := minf(280.0, (vp.x - 80.0 - gap * (n - 1)) / maxf(1, n))
	var x0 := (vp.x - (cw * n + gap * (n - 1))) / 2.0
	rects.clear()
	bottoni.clear()
	for i in n:
		var r := Rect2(x0 + i * (cw + gap), 112, cw, 500)
		rects.append(r)
		_draw_card(i, r)

	Pietra.stone(self, back_rect, C3, hover_back)
	Pietra.text_c(self, font, back_rect.get_center().x, back_rect.position.y + 15, tr("< BACK"), 16, C6)
	Pietra.text_c(self, font, vp.x / 2.0, 668, tr("frecce per scegliere · Invio per giocare · C classifica"), 16, C4, false)
	if msg_t > 0.0:
		var w := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 32
		var mr := Rect2(vp.x / 2.0 - w / 2.0, 620, w, 36)
		draw_rect(mr, Color(C0, 0.9))
		draw_rect(mr.grow(-3), C2)
		Pietra.text_c(self, font, vp.x / 2.0, 630, msg, 16, C6)
	if classifica_i >= 0:
		_draw_classifica(vp)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(C0, fade))


func _draw_card(i: int, r: Rect2) -> void:
	var info := lista[i]
	var open := Livelli.sbloccato(lista, i)
	var done := Livelli.finito(info.id)
	var on := i == sel or i == hover
	var lift := -8.0 if on and open else 0.0
	var rr := Rect2(r.position + Vector2(0, lift), r.size)
	Pietra.tomb(self, rr, C4 if open else C2, on and open)
	# anteprima: un pezzo di cielo e di terreno del bioma
	var pv := Rect2(rr.position + Vector2(14, 40), Vector2(rr.size.x - 28, 150))
	draw_rect(pv.grow(4), C0)
	var b := info.bioma
	if b and b.cielo and b.terreno:
		# pixel 1:1, centrato: il bordo basso del cielo combacia con l'orizzonte del terreno
		var sky_h := minf(105.0, b.cielo.get_height())
		var w := minf(pv.size.x, b.cielo.get_width())
		var sx := floorf((b.cielo.get_width() - w) * (0.2 + 0.2 * (i % 4)))
		draw_texture_rect_region(b.cielo, Rect2(pv.position, Vector2(w, sky_h)),
			Rect2(sx, b.cielo.get_height() - sky_h, w, sky_h))
		draw_texture_rect_region(b.terreno, Rect2(pv.position + Vector2(0, sky_h), Vector2(w, pv.size.y - sky_h)),
			Rect2(sx, 0, w, pv.size.y - sky_h))
		if b.ostacoli:  # un ostacolo del bioma in primo piano
			draw_texture_rect_region(b.ostacoli, Rect2(pv.end - Vector2(76, 68), Vector2(64, 64)), Rect2((i % 4) * 32, 0, 32, 32))
		# gli eroi che si incontrano in questo campo (elfi, vichinghi...), girati verso sinistra
		var tn: Texture2D = b.sprite_nemici if b.sprite_nemici else ATLAS
		var ty := 0.0 if b.sprite_nemici else 16.0
		for k in 2:
			draw_set_transform(Vector2(pv.position.x + 60 + k * 44, pv.end.y - 52 - k * 4), 0.0, Vector2(-1, 1))
			draw_texture_rect_region(tn, Rect2(0, 0, 48, 48), Rect2(k * 32 + (int(t * 3.0) % 2) * 16, ty, 16, 16))
			draw_set_transform(Vector2.ZERO)
	else:
		draw_rect(pv, C1)
	if not open:
		draw_rect(pv, Color(0, 0, 0, 0.65))
		var lp := pv.get_center() - Vector2(14, 16)
		for y in LOCK.size():
			for x in LOCK[y].length():
				var ch: String = LOCK[y][x]
				if ch != ".":
					draw_rect(Rect2(lp + Vector2(x, y) * 4.0, Vector2(4, 4)), C0 if ch == "K" else C5)
	# numero del livello
	Pietra.text_c(self, font, rr.get_center().x, rr.position.y + 12, tr("LIVELLO %d") % (i + 1), 16, C1 if open else C4, false)
	# nome e descrizione
	var title := tr(info.nome).to_upper()
	var fs := 24
	while fs > 12 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > rr.size.x - 24:
		fs -= 2
	Pietra.text_c(self, font, rr.get_center().x, pv.end.y + 16, title, fs, C6 if open else C5)
	Pietra.text_block(self, font, Vector2(rr.position.x + 16, pv.end.y + 52), rr.size.x - 32,
		tr(info.descrizione), 16, C5 if open else C4)
	# stato
	var sy := rr.end.y - 64
	if not open and i > 0:
		Pietra.text_block(self, font, Vector2(rr.position.x + 12, sy), rr.size.x - 24,
			tr("Finisci \"%s\" per sbloccarlo") % tr(lista[i - 1].nome), 16, C4)
	elif done:
		var cx := rr.get_center().x
		var st := Rect2(cx - 70, rr.end.y - 156, 140, 24)
		draw_rect(st, C6)
		draw_rect(Rect2(st.position.x, st.end.y, st.size.x, 3), C0)
		Pietra.text_c(self, font, cx, st.position.y + 4, tr("COMPLETATO"), 16, C0, false)
		# record della modalità infinita
		var ri := Livelli.record_infinito(info.id)
		var line := tr("Record: ondata %d") % ri if ri > 0 else tr("Infinita: mai giocata")
		var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var lx := cx - (lw + 34) / 2.0
		Livelli.disegna_infinito(self, Vector2(lx, rr.end.y - 122), 3.0, C1, false)
		Pietra.text(self, font, Vector2(lx + 34, rr.end.y - 124), line, 16, C1, false)
		var m := 14.0
		_bottone(Rect2(rr.position.x + m, rr.end.y - 94, rr.size.x - m * 2, 34), tr("CLASSIFICA"), "classifica", i, false)
		var bw := (rr.size.x - m * 2 - 8) / 2.0
		_bottone(Rect2(rr.position.x + m, rr.end.y - 52, bw, 38), tr("STORIA"), "storia", i, i == sel and not modo_inf)
		_bottone(Rect2(rr.position.x + m + bw + 8, rr.end.y - 52, bw, 38), tr("INFINITA"), "infinita", i, i == sel and modo_inf)
	else:
		var rec := Livelli.record(info.id)
		var line := tr("Record: ondata %d") % rec if rec > 0 else tr("Mai giocato")
		Pietra.text_c(self, font, rr.get_center().x, sy + 10, line, 16, C1, false)


## Pulsante di pietra dentro una scheda (con il simbolo dell'infinito per "infinita").
func _bottone(r: Rect2, testo: String, azione: String, i: int, scelto: bool) -> void:
	var k := bottoni.size()
	bottoni.append({"rect": r, "azione": azione, "i": i})
	var hot := k == hover_btn
	if scelto:
		draw_rect(r.grow(3), C6)
	Pietra.stone(self, r, C2 if azione == "infinita" else C3, hot)
	var ty := r.position.y + (r.size.y - 16.0) / 2.0 - 2.0
	if azione == "infinita":
		var tw := font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var x0 := r.get_center().x - (tw + 32) / 2.0
		Livelli.disegna_infinito(self, Vector2(x0, r.get_center().y - 9), 3.0, C6)
		Pietra.text(self, font, Vector2(x0 + 32, ty), testo, 16, C6)
	else:
		Pietra.text_c(self, font, r.get_center().x, ty, testo, 16, C6)


## Classifica della modalità infinita del livello classifica_i.
func _draw_classifica(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.75))
	var info := lista[classifica_i]
	var r := Rect2(vp.x / 2.0 - 420, 92, 840, 556)
	Pietra.tomb(self, r, C3, false)
	var inner := r.grow(-18)
	inner.position.y += 34
	inner.size.y -= 34
	draw_rect(inner, C1)
	# titolo: simbolo + CLASSIFICA, sotto il livello con le frecce
	var t := tr("CLASSIFICA")
	var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var tx := r.get_center().x - (tw + 40) / 2.0
	Livelli.disegna_infinito(self, Vector2(tx, r.position.y + 18), 3.0, C0, false)
	Pietra.text(self, font, Vector2(tx + 40, r.position.y + 12), t, 24, C0, false)
	var ny := inner.position.y + 14
	Pietra.text_c(self, font, r.get_center().x, ny, tr(info.nome).to_upper(), 24, C6)
	cl_prev = Rect2(inner.position.x + 14, ny - 6, 44, 40)
	cl_next = Rect2(inner.end.x - 58, ny - 6, 44, 40)
	var m := get_local_mouse_position()
	Pietra.stone(self, cl_prev, C3, cl_prev.has_point(m))
	Pietra.stone(self, cl_next, C3, cl_next.has_point(m))
	Pietra.text_c(self, font, cl_prev.get_center().x, cl_prev.position.y + 9, "<", 16, C6)
	Pietra.text_c(self, font, cl_next.get_center().x, cl_next.position.y + 9, ">", 16, C6)
	# colonne
	var cols: Array[float] = [inner.position.x + 30, inner.position.x + 90, inner.position.x + 220, inner.position.x + 360, inner.position.x + 450, inner.position.x + 660]
	var hy := ny + 52
	var heads: Array[String] = ["#", tr("ONDATA"), tr("UCCISIONI"), tr("LIV."), tr("SQUADRA"), tr("DATA")]
	for k in heads.size():
		Pietra.text(self, font, Vector2(cols[k], hy), heads[k], 16, C4, false)
	draw_rect(Rect2(inner.position.x + 20, hy + 24, inner.size.x - 40, 2), C3)
	var c := Livelli.classifica(info.id)
	if c.is_empty():
		var vuoto := tr("Nessuna corsa: gioca in modalità infinita!") if Livelli.finito(info.id) else tr("Finisci il livello per sbloccare la modalità infinita.")
		Pietra.text_c(self, font, r.get_center().x, hy + 140, vuoto, 16, C5)
	for i in c.size():
		var v: Dictionary = c[i]
		var y := hy + 36 + i * 34.0
		if i % 2 == 0:
			draw_rect(Rect2(inner.position.x + 20, y - 4, inner.size.x - 40, 32), C2)
		var col := C6 if i == 0 else C5
		Pietra.text(self, font, Vector2(cols[0], y), "%d" % (i + 1), 16, col)
		Pietra.text(self, font, Vector2(cols[1], y), "%d" % int(v.get("ondata", 0)), 16, col)
		Pietra.text(self, font, Vector2(cols[2], y), "%d" % int(v.get("uccisioni", 0)), 16, col)
		Pietra.text(self, font, Vector2(cols[3], y), "%d" % int(v.get("livello", 0)), 16, col)
		var sq: Array = v.get("squadra", [])
		for k in mini(sq.size(), 6):
			var kind := String(sq[k])
			if Data.UNITS.has(kind):
				draw_texture_rect_region(Data.ally_texture(kind), Rect2(Vector2(cols[4] + k * 34, y - 10), Vector2(32, 32)), Data.ally_region(kind))
		Pietra.text(self, font, Vector2(cols[5], y), String(v.get("data", "")), 16, C4)
	Pietra.text_c(self, font, r.get_center().x, inner.end.y - 28, tr("frecce: cambia livello · Esc: chiudi"), 16, C4, false)
