extends Control
## SCELTA DEL LIVELLO: compare dopo "AVVIA RUN", prima della preparazione della squadra.
## I livelli stanno in livelli/elenco_livelli.tres (doppio clic per modificarli):
## ognuno si sblocca finendo quello prima. Il dev tool (Ctrl+Shift+D, scheda LIVELLI)
## li sblocca tutti.
## Tasti: frecce = scegli, Invio = gioca, Esc = torna al menu.

const Pietra := preload("res://scripts/ui_pietra.gd")
const Suoni := preload("res://scripts/suoni.gd")
const Lingua := preload("res://scripts/lingua.gd")
const Dialoghi := preload("res://scripts/dialoghi.gd")
const Livelli := preload("res://scripts/livelli.gd")
const Portafoglio := preload("res://scripts/portafoglio.gd")
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
	hover = -1
	for i in rects.size():
		if rects[i].has_point(m):
			hover = i
	hover_back = back_rect.has_point(m)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover >= 0 or hover_back else Control.CURSOR_ARROW
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if leaving != "" or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if hover_back:
		_back()
	elif hover >= 0:
		sel = hover
		_gioca(hover)


func _unhandled_input(event: InputEvent) -> void:
	if leaving != "" or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			sel = posmod(sel - 1, maxi(1, lista.size()))
			Suoni.play("click", 0.9)
		KEY_RIGHT, KEY_D:
			sel = posmod(sel + 1, maxi(1, lista.size()))
			Suoni.play("click", 0.9)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_gioca(sel)
		KEY_ESCAPE, KEY_BACKSPACE:
			_back()


func _back() -> void:
	Suoni.play("click")
	leaving = MENU_SCENE


func _gioca(i: int) -> void:
	if i < 0 or i >= lista.size():
		return
	if not Livelli.sbloccato(lista, i):
		Suoni.play("errore")
		msg = tr("Finisci \"%s\" per sbloccare questo livello.") % tr(lista[i - 1].nome)
		msg_t = 2.5
		return
	Suoni.play("conferma")
	Livelli.scegli(lista[i])
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
	for i in n:
		var r := Rect2(x0 + i * (cw + gap), 112, cw, 500)
		rects.append(r)
		_draw_card(i, r)

	Pietra.stone(self, back_rect, C3, hover_back)
	Pietra.text_c(self, font, back_rect.get_center().x, back_rect.position.y + 15, tr("< BACK"), 16, C6)
	Pietra.text_c(self, font, vp.x / 2.0, 668, tr("frecce per scegliere · Invio per giocare"), 16, C4, false)
	if msg_t > 0.0:
		var w := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 32
		var mr := Rect2(vp.x / 2.0 - w / 2.0, 620, w, 36)
		draw_rect(mr, Color(C0, 0.9))
		draw_rect(mr.grow(-3), C2)
		Pietra.text_c(self, font, vp.x / 2.0, 630, msg, 16, C6)
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
		var st := Rect2(rr.get_center().x - 80, sy - 4, 160, 30)
		draw_rect(st, C6)
		draw_rect(Rect2(st.position.x, st.end.y, st.size.x, 3), C0)
		Pietra.text_c(self, font, st.get_center().x, st.position.y + 7, tr("COMPLETATO"), 16, C0, false)
		Pietra.text_c(self, font, rr.get_center().x, sy + 34, tr("Record: ondata %d") % Livelli.record(info.id), 16, C2, false)
	else:
		var rec := Livelli.record(info.id)
		var line := tr("Record: ondata %d") % rec if rec > 0 else tr("Mai giocato")
		Pietra.text_c(self, font, rr.get_center().x, sy + 10, line, 16, C1, false)
