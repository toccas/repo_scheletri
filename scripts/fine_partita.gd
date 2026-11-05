extends Control
## SCHERMATA DI FINE PARTITA "finale cinematico": bande nere, titolo grande,
## cronaca delle 100 ondate con le corone dei campioni, bottino e quattro pulsanti
## grandi (pensati per il dito sul telefono). Si usa sia quando la torre cade sia
## quando superi l'ultima ondata. La crea main.gd in _end_run() con mostra().
##
## Da tastiera: Invio/Spazio = pulsante principale, Esc = menu, e le lettere
## scritte sotto ogni pulsante (tasto_*).

const Data := preload("res://scripts/game_data.gd")
const Pietra := preload("res://scripts/ui_pietra.gd")
const Livelli := preload("res://scripts/livelli.gd")
const Suoni := preload("res://scripts/suoni.gd")
const ATLAS := preload("res://assets/sprites.png")
const R_NECRO := Rect2(64, 32, 16, 16)
const R_CORONA := Rect2(80, 32, 16, 16)
const TEX_MONETA := preload("res://assets/negozio/moneta.png")
const TEX_PERGAMENA := preload("res://assets/negozio/pergamena.png")

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")
const ORO := Color("f0ce52")
const ORO_CHIARO := Color("fff3b8")
const ORO_SCURO := Color("a8862a")

## Icone dei pulsanti a pixel (8x8).
const ICONE := {
	"riprova": ["..XXXX..", ".X....X.", "X....XXX", "X.....XX", "X.......", "X......X", ".X....X.", "..XXXX.."],
	"squadra": ["..XXXX..", ".XXXXXX.", ".X.XX.X.", ".XXXXXX.", "..XXXX..", "..X..X..", "..XXXX..", "........"],
	"campo": [".XXXXXX.", ".XXXXX..", ".XXXXXX.", ".X......", ".X......", ".X......", ".X......", "XXX....."],
	"menu": ["........", "XXXXXXXX", "........", "XXXXXXXX", "........", "XXXXXXXX", "........", "........"],
}

var font: Font
var dati: Dictionary = {}
## Pulsanti: [{testo, sotto, azione: Callable, stile ("chiaro", "oro", "grigio", "scuro"), icona, larghezza, tasto}]
var pulsanti: Array = []
var rects: Array[Rect2] = []
var hover := -1
var premuto := -1
var t := 0.0
var scelto := false
var briciole: Array = []


## `d`: vinto, infinita, ondata, uccisioni, record, posto, punti, punti_totali, monete, pergamene,
## nuovo_livello, campioni ([{ondata, campione, sconfitto}]), squadra (tipi), ultimo (Campione).
func mostra(d: Dictionary, bottoni: Array, f: Font) -> void:
	dati = d
	pulsanti = bottoni
	font = f
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		briciole.append(Vector2(randf_range(-40, 40), randf_range(0.0, 1.0)))


func _ready() -> void:
	grab_focus.call_deferred()


func _process(delta: float) -> void:
	t += delta
	var m := get_local_mouse_position()
	hover = -1
	for i in rects.size():
		if rects[i].has_point(m):
			hover = i
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover >= 0 else Control.CURSOR_ARROW
	queue_redraw()


func _pronto() -> bool:
	return t >= 1.6


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if not _pronto():  # un tocco salta l'animazione
		if event.pressed:
			t = 1.6
		return
	var i := -1
	for k in rects.size():
		if rects[k].has_point(event.position):
			i = k
	if event.pressed:
		premuto = i
	elif premuto >= 0 and premuto == i:
		_scegli(i)
	elif not event.pressed:
		premuto = -1


func _unhandled_key_input(event: InputEvent) -> void:
	if scelto or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not _pronto():
		t = 1.6
		get_viewport().set_input_as_handled()
		return
	for i in pulsanti.size():
		var tasti: Array = pulsanti[i].get("tasti", [])
		if event.keycode in tasti:
			get_viewport().set_input_as_handled()
			_scegli(i)
			return


func _scegli(i: int) -> void:
	if scelto or i < 0 or i >= pulsanti.size():
		return
	scelto = true
	Suoni.play("conferma")
	var cb: Callable = pulsanti[i]["azione"]
	cb.call()


# --- Disegno ---------------------------------------------------------------------

func _k(da: float, durata: float) -> float:
	return clampf((t - da) / durata, 0.0, 1.0)


func _draw() -> void:
	var vp := size
	var vinto: bool = dati.get("vinto", false)
	# il campo si scurisce, poi entrano le bande nere
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.03, 0.03, 0.86 * _k(0.0, 0.6)))
	var kb := _k(0.0, 0.45)
	draw_rect(Rect2(0, 0, vp.x, 48.0 * kb), Color.BLACK)
	draw_rect(Rect2(0, vp.y - 148.0 * kb, vp.x, 148.0 * kb), Color.BLACK)
	var cx := vp.x / 2.0
	if vinto:
		_draw_vittoria(cx)
	else:
		_draw_sconfitta(cx)
	_draw_cronaca(Rect2(cx - 400, 312 if vinto else 300, 800, 40))
	_draw_bottino(cx, 424)
	_draw_pulsanti(cx, vp.y - 120)
	if vinto and not dati.get("infinita", false):
		var a := _k(2.0, 0.4)
		Pietra.text_c(self, font, cx, vp.y - 22, tr("Continua: la partita prosegue senza fine ed entra in classifica"), 12, Color(C4, a), false)


func _titolo(cx: float, y: float, testo: String, a: float) -> void:
	# lettere distanziate, come nei titoli dei film
	var fs := 56
	var spazio := 8.0
	var w := 0.0
	for ch in testo:
		w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + spazio
	while w - spazio > size.x - 80 and fs > 24:
		fs -= 4
		w = 0.0
		for ch in testo:
			w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + spazio
	var x := cx - (w - spazio) / 2.0
	var dy := (1.0 - a) * 12.0
	for ch in testo:
		draw_string(font, Vector2(x, y + fs + dy + 6), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, a))
		draw_string(font, Vector2(x, y + fs + dy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(C6, a))
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + spazio


func _draw_sconfitta(cx: float) -> void:
	var a := _k(0.2, 0.5)
	# il necromante senza torre, che si sbriciola
	var nr := Rect2(cx - 48, 64, 96, 96)
	draw_texture_rect_region(ATLAS, nr, R_NECRO, Color(0.7, 0.7, 0.7, a))
	for b in briciole:
		var v: Vector2 = b
		var y := fmod(t * 18.0 + v.y * 40.0, 40.0)
		draw_rect(Rect2(cx + v.x, nr.end.y + y, 6, 6), Color(C4, a * (1.0 - y / 40.0)))
	_titolo(cx, 176, tr("LA TORRE È CADUTA"), _k(0.3, 0.5))
	var riga: String
	if dati.get("infinita", false):
		riga = tr("%d ONDATE  ·  %d EROI ABBATTUTI") % [dati["ondata"], dati["uccisioni"]] + "  ·  " + _testo_posto()
	else:
		riga = tr("%d ONDATE  ·  %d EROI ABBATTUTI  ·  RECORD %d") % [dati["ondata"], dati["uccisioni"], dati["record"]]
	Pietra.text_c(self, font, cx, 254, riga, 16, Color(C5, _k(0.6, 0.4)), false)


func _testo_posto() -> String:
	var p: int = dati.get("posto", -1)
	if p == 0:
		return tr("NUOVO RECORD!")
	if p > 0:
		return tr("POSTO %d IN CLASSIFICA") % (p + 1)
	return tr("FUORI CLASSIFICA")


func _draw_vittoria(cx: float) -> void:
	var a := _k(0.2, 0.5)
	var sottotitolo := tr("%d ONDATE · %d CAMPIONI · %d EROI") % [dati["ondata"], dati.get("campioni_battuti", 0), dati["uccisioni"]]
	Pietra.text_c(self, font, cx, 64, sottotitolo, 16, Color(ORO, a), false)
	_titolo(cx, 82, tr("LA NOTTE È TUA"), _k(0.3, 0.5))
	# il necromante incoronato in mezzo al suo esercito, il campione finale a terra
	var base_y := 150.0
	var ka := _k(0.5, 0.6)
	draw_rect(Rect2(cx - 440, base_y + 132, 880, 3), Color(C2, ka))
	var squadra: Array = dati.get("squadra", [])
	if not squadra.is_empty():
		var xs := [-408, -352, -296, -240, -184, -120, 72, 128, 184, 240]
		for i in xs.size():
			var k: String = squadra[i % squadra.size()]
			var bob := roundf(sin(t * 3.0 + i) * 2.0)
			draw_texture_rect_region(Data.ally_texture(k), Rect2(cx + xs[i], base_y + (84 if i % 2 else 80) + bob, 48, 48),
				Data.ally_region(k, int(t * 3.0 + i) % 2), Color(1, 1, 1, ka))
	draw_texture_rect_region(ATLAS, Rect2(cx - 24, base_y, 48, 48), R_CORONA, Color(1, 1, 1, ka))
	draw_texture_rect_region(ATLAS, Rect2(cx - 48, base_y + 36, 96, 96), R_NECRO, Color(1, 1, 1, ka))
	var ultimo: Campione = dati.get("ultimo")
	if ultimo != null and ultimo.sprite != null:
		var fs := float(ultimo.sprite.get_height())
		var s := fs * (2.0 if fs <= 40.0 else 1.5)
		draw_set_transform(Vector2(cx + 400, base_y + 132 - s * 0.3), PI / 2.0, Vector2.ONE)
		draw_texture_rect_region(ultimo.sprite, Rect2(-s / 2.0, -s / 2.0, s, s), Rect2(0, 0, fs, fs), Color(0.45, 0.45, 0.45, ka))
		draw_set_transform(Vector2.ZERO)


## Le 100 ondate in 10 tratti, con la corona (o il ritratto) di ogni campione.
func _draw_cronaca(r: Rect2) -> void:
	var segs: Array = dati.get("campioni", [])
	if segs.is_empty():
		return
	var a := _k(0.7, 0.4)
	var n := segs.size()
	var gap := 6.0
	var w := (r.size.x - gap * (n - 1)) / n
	var totale: float = dati.get("ondate_totali", 100)
	var reached: float = float(dati["ondata"])
	if not dati.get("vinto", false) and not dati.get("infinita", false):
		reached -= 1.0  # l'ondata in cui è caduta la torre non è superata
	var kf := _k(0.9, 1.0)  # la linea si riempie piano
	var pieno := minf(reached, totale) * kf
	var oro: bool = dati.get("vinto", false) or dati.get("infinita", false)
	var prossimo_mostrato := false
	for i in n:
		var s: Dictionary = segs[i]
		var x := r.position.x + i * (w + gap)
		var inizio := totale * i / n
		var fine := totale * (i + 1) / n
		var bar := Rect2(x, r.position.y + 38, w, 8)
		draw_rect(bar, Color(C2, a))
		var k := clampf((pieno - inizio) / (fine - inizio), 0.0, 1.0)
		if k > 0.0:
			draw_rect(Rect2(bar.position, Vector2(roundf(w * k), 8)), Color(ORO if oro else (C5 if k >= 1.0 else C6), a))
		# icona: ritratto del prossimo campione e dell'ultimo, corona per gli altri
		var c: Campione = s.get("campione")
		var battuto: bool = s.get("sconfitto", false)
		var ritratto := c != null and c.sprite != null and ((not battuto and not prossimo_mostrato) or i == n - 1)
		if not battuto and not prossimo_mostrato:
			prossimo_mostrato = true
		var lit := battuto or (ritratto and i != n - 1) or oro
		var col := Color(1, 1, 1, a) if lit else Color(0.35, 0.35, 0.35, a * 0.5)
		if ritratto:
			var fs := float(c.sprite.get_height())
			var sz := minf(fs, 48.0)
			draw_set_transform(Vector2(bar.end.x + 4, bar.position.y + 2), 0.0, Vector2(-1, 1))
			draw_texture_rect_region(c.sprite, Rect2(0, -sz, sz, sz), Rect2(0, 0, fs, fs), col if (lit or i == n - 1) else col)
			draw_set_transform(Vector2.ZERO)
		elif c != null:
			draw_texture_rect_region(ATLAS, Rect2(bar.end.x - 16, bar.position.y - 18, 16, 16), R_CORONA, col)
	# segno dove è caduta la torre
	if not oro and kf >= 1.0:
		var w_x := r.position.x
		var seg_i := clampi(int((reached) / (totale / n)), 0, n - 1)
		var dentro := (reached - totale * seg_i / n) / (totale / n)
		w_x += seg_i * (w + gap) + w * dentro
		var am := _k(1.9, 0.3)
		draw_rect(Rect2(w_x - 2, r.position.y + 50, 4, 10), Color(C6, am))
		Pietra.text_c(self, font, w_x, r.position.y + 62, "%d" % dati["ondata"], 12, Color(C6, am), false)


## Monete, pergamene, punti (contano fino al totale) e livello sbloccato.
func _draw_bottino(cx: float, y: float) -> void:
	var a := _k(1.4, 0.4)
	if a <= 0.0:
		return
	var kc := _k(1.5, 0.8)
	var parti: Array = []  # [icona (Rect2 nel negozio o null), testo, piccolo, colore]
	parti.append(["moneta", "+%d" % int(round(float(dati.get("monete", 0)) * kc)), "", C6])
	parti.append(["pergamena", "+%d" % int(round(float(dati.get("pergamene", 0)) * kc)), "", C6])
	parti.append(["", "+%d" % int(round(float(dati.get("punti", 0)) * kc)), tr("PUNTI"), C6])
	if str(dati.get("nuovo_livello", "")) != "":
		parti.append(["", tr("NUOVO: %s") % tr(dati["nuovo_livello"]).to_upper(), "", ORO])
	var larg: Array[float] = []
	var tot := 0.0
	for p in parti:
		var fs := 24 if p[2] == "" and p[3] != ORO else 16
		var w: float = font.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if p[0] != "":
			w += 40
		if p[2] != "":
			w += 8 + font.get_string_size(p[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		larg.append(w)
		tot += w
	tot += 36.0 * (parti.size() - 1) + 56
	var x := cx - tot / 2.0
	draw_rect(Rect2(x, y, tot, 3), Color(C2, a))
	draw_rect(Rect2(x, y + 56, tot, 3), Color(C2, a))
	x += 28
	for i in parti.size():
		var p: Array = parti[i]
		var fs := 24 if p[2] == "" and p[3] != ORO else 16
		var px := x
		if p[0] != "":
			var tex: Texture2D = TEX_MONETA if p[0] == "moneta" else TEX_PERGAMENA
			draw_texture_rect(tex, Rect2(px, y + 14, 32, 32), false, Color(1, 1, 1, a))
			px += 40
		Pietra.text(self, font, Vector2(px, y + 30 - fs / 2.0 - 2), p[1], fs, Color(p[3], a))
		if p[2] != "":
			Pietra.text(self, font, Vector2(px + font.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8, y + 24), p[2], 12, Color(C4, a), false)
		x += larg[i] + 36


func _draw_pulsanti(cx: float, y: float) -> void:
	rects.clear()
	var a := _k(1.6, 0.4)
	var tot := 0.0
	for p in pulsanti:
		tot += float(p.get("larghezza", 230))
	tot += 16.0 * (pulsanti.size() - 1)
	var x := cx - tot / 2.0
	for i in pulsanti.size():
		var p: Dictionary = pulsanti[i]
		var r := Rect2(x, y + (1.0 - a) * 16.0, float(p.get("larghezza", 230)), 92)
		rects.append(r if a >= 1.0 else Rect2())
		_draw_pulsante(r, p, a, i == hover, i == premuto and i == hover)
		x += r.size.x + 16


func _draw_pulsante(r: Rect2, p: Dictionary, a: float, hot: bool, giu: bool) -> void:
	var stile: String = p.get("stile", "grigio")
	var base := C3
	var chiaro := C4
	var scuro := C2
	var testo := C6
	match stile:
		"chiaro":
			base = C6
			chiaro = Color.WHITE
			scuro = C5
			testo = C0
		"oro":
			base = ORO
			chiaro = ORO_CHIARO
			scuro = ORO_SCURO
			testo = C0
		"argento":
			base = C5
			chiaro = C6
			scuro = C4
			testo = C0
		"scuro":
			base = C2
			chiaro = C3
			scuro = C1
			testo = C5
	if hot:
		base = base.lightened(0.08)
	var rr := r
	if giu:
		rr.position.y += 3
	draw_rect(rr, Color(C0, a))
	var dentro := rr.grow(-4)
	draw_rect(dentro, Color(base, a))
	draw_rect(Rect2(dentro.position, Vector2(dentro.size.x, 5)), Color(chiaro, a))
	draw_rect(Rect2(dentro.position, Vector2(5, dentro.size.y)), Color(chiaro, a))
	draw_rect(Rect2(dentro.position + Vector2(0, dentro.size.y - 5), Vector2(dentro.size.x, 5)), Color(scuro, a))
	draw_rect(Rect2(dentro.position + Vector2(dentro.size.x - 5, 0), Vector2(5, dentro.size.y)), Color(scuro, a))
	var t1: String = p.get("testo", "")
	var t2: String = p.get("sotto", "")
	var icona: String = p.get("icona", "")
	var fs := 28 if stile in ["chiaro", "oro"] else 20
	while fs > 12 and font.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - (70 if icona != "" else 24):
		fs -= 2
	var tw := font.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if t1 != "" else 0.0
	var iw := 0.0
	if icona == "infinito":
		iw = 36.0
	elif icona != "":
		iw = 32.0 if t1 == "" else 24.0
	var gap := 14.0 if icona != "" and t1 != "" else 0.0
	var x := rr.get_center().x - (iw + gap + tw) / 2.0
	var cy := rr.get_center().y - (8.0 if t2 != "" else 0.0)
	var col := Color(testo, a)
	if icona == "infinito":
		Livelli.disegna_infinito(self, Vector2(x, cy - 10), 4.0, col, false)
	elif icona != "":
		var px := iw / 8.0
		var rows: Array = ICONE.get(icona, [])
		for yy in rows.size():
			var row: String = rows[yy]
			for xx in row.length():
				if row[xx] == "X":
					draw_rect(Rect2(x + xx * px, cy - iw / 2.0 + yy * px, px, px), col)
	if t1 != "":
		Pietra.text(self, font, Vector2(x + iw + gap, cy - fs / 2.0 - 2), t1, fs, col, false)
	if t2 != "":
		Pietra.text_c(self, font, rr.get_center().x, cy + fs / 2.0 + 2, t2, 12, Color(C2 if testo == C0 else C5, a), false)
