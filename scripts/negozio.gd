@tool
extends Control
## Scena NEGOZIO: la bancarella del mercante. Qui si spendono le monete d'osso.
##
## GLI OGGETTI IN VENDITA SI MODIFICANO DALL'INSPECTOR:
##   seleziona il nodo "Negozio" > lista "Oggetti" > "Aggiungi elemento" >
##   "Nuovo OggettoNegozio", poi compila nome, descrizione, icona, prezzo e
##   cosa si ottiene. L'anteprima nell'editor si aggiorna subito.
##   Il pulsante "Ripristina oggetti di base" rimette i 4 pacchetti iniziali.
##
## Le monete d'osso si guadagnano giocando (2 per ondata superata).
## Dev tool: Ctrl+Shift+M = fondi infiniti (solo nelle build di prova).
## Tasti: frecce sinistra/destra = pagina, Esc / Backspace = torna al menu.

const Pietra := preload("res://scripts/ui_pietra.gd")
const Portafoglio := preload("res://scripts/portafoglio.gd")
const Collezione := preload("res://scripts/collezione.gd")
const TEX_STALL := preload("res://assets/menu/negozio.png")
const TEX_COIN = preload("res://assets/negozio/moneta.png")
const TEX_SCROLL = preload("res://assets/negozio/pergamena.png")
const MENU_SCENE := "res://scenes/menu.tscn"

## Gli oggetti in vendita, nell'ordine in cui compaiono.
@export var oggetti: Array[OggettoNegozio] = []
## Rimette i 4 oggetti di base (pergamena, fascio, scrigno, VIP). Poi salva la scena.
@export_tool_button("Ripristina oggetti di base", "Reload") var ripristina: Callable = _ripristina

@export_group("Disposizione")
## Schede per riga.
@export_range(1, 6) var colonne := 3
## Righe di schede per pagina (se gli oggetti sono di più compaiono le pagine).
@export_range(1, 4) var righe := 2
## Dimensione di ogni scheda, in pixel dello schermo.
@export var dimensione_scheda := Vector2(276, 248)
## Spazio tra le schede.
@export var spazio := 16.0
## Angolo in alto a sinistra della prima scheda.
@export var inizio_schede := Vector2(376, 104)
## Quanto è ingrandita l'icona (16x16 x 4 = 64 pixel).
@export_range(1, 8) var scala_icone := 4
## Angolo in alto a sinistra della bancarella del mercante.
@export var posizione_bancarella := Vector2(48, 268)
## Ingrandimento della bancarella.
@export_range(1, 10) var scala_bancarella := 5

@export_group("Testi")
@export var titolo := "NEGOZIO"
## Cosa dice il mercante quando entri.
@export_multiline var frase_benvenuto := "Benvenuto, necromante.\nOssa in cambio di pergamene!"

@export_group("")
## Il tuo tema (per il font). Vuoto = font predefinito.
@export var tema: Theme

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")

var font: Font
var t := 0.0
var fade := 1.0
var leaving := false
var wallet: Dictionary = {"monete": 0, "vip": false, "acquistati": [], "dev_infiniti": false}
var scrolls := 0
var page := 0
var hover := ""          # "card:N", "buy", "cancel", "back", "prev", "next"
var confirm_item: OggettoNegozio = null
var say := ""            # frase del mercante
var say_t := 0.0
var coins: Array = []    # luccichii attorno alla bancarella
var pop_t := 0.0         # piccolo sobbalzo del saldo dopo un acquisto
var back_rect := Rect2(24, 652, 120, 50)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tema:
		theme = tema
	font = get_theme_default_font()
	if Engine.is_editor_hint():
		fade = 0.0
		return
	Portafoglio.install_dev_tool(get_tree())
	_refresh()
	say = frase_benvenuto


func _refresh() -> void:
	wallet = Portafoglio.load_state()
	scrolls = int(Collezione.load_state()["scrolls"])


## Chiamata dal dev tool quando premi Ctrl+Shift+M.
func on_dev_tool_changed() -> void:
	_refresh()
	_merchant("Mmh... le tue tasche non hanno più fondo." if Portafoglio.infinite(wallet) else "Le tue tasche tornano normali.")


func _merchant(s: String) -> void:
	say = s
	say_t = 4.0


func per_page() -> int:
	return colonne * righe


func page_count() -> int:
	return maxi(1, ceili(oggetti.size() / float(per_page())))


func card_rect(i: int) -> Rect2:
	var k := i % per_page()
	var c := k % colonne
	var r := k / colonne
	return Rect2(inizio_schede + Vector2(c, r) * (dimensione_scheda + Vector2.ONE * spazio), dimensione_scheda)


func buy_rect(card: Rect2) -> Rect2:
	return Rect2(card.position.x + 18, card.end.y - 54, card.size.x - 36, 40)


func _arrow_rects() -> Array[Rect2]:
	var cx := inizio_schede.x + (colonne * (dimensione_scheda.x + spazio) - spazio) / 2.0
	var y := inizio_schede.y + righe * (dimensione_scheda.y + spazio) + 2.0
	return [Rect2(cx - 150, y, 56, 40), Rect2(cx + 94, y, 56, 40)]


func _confirm_rects() -> Array[Rect2]:
	var c := size / 2.0
	return [Rect2(c.x - 190, c.y + 62, 170, 50), Rect2(c.x + 20, c.y + 62, 170, 50)]


func _process(delta: float) -> void:
	t += delta
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if leaving:
		fade = minf(1.0, fade + delta * 3.0)
		if fade >= 1.0:
			get_tree().change_scene_to_file(MENU_SCENE)
			return
	else:
		fade = maxf(0.0, fade - delta * 3.0)
	say_t = maxf(0.0, say_t - delta)
	if say_t <= 0.0 and say != frase_benvenuto and confirm_item == null:
		say = frase_benvenuto
	pop_t = maxf(0.0, pop_t - delta)
	var st := TEX_STALL.get_size() * scala_bancarella
	if randf() < delta * 3.0:
		coins.append({"p": posizione_bancarella + Vector2(randf_range(0, st.x), randf_range(0, st.y * 0.6)), "life": 0.8})
	for c in coins:
		c["life"] -= delta
	coins = coins.filter(func(c: Dictionary) -> bool: return c["life"] > 0.0)
	page = clampi(page, 0, page_count() - 1)
	hover = _hit(get_local_mouse_position())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover != "" else Control.CURSOR_ARROW
	queue_redraw()


func _hit(p: Vector2) -> String:
	if confirm_item != null:
		var cr := _confirm_rects()
		if cr[0].has_point(p):
			return "buy"
		if cr[1].has_point(p):
			return "cancel"
		return ""
	if back_rect.has_point(p):
		return "back"
	if page_count() > 1:
		var ar := _arrow_rects()
		if ar[0].has_point(p) and page > 0:
			return "prev"
		if ar[1].has_point(p) and page < page_count() - 1:
			return "next"
	for i in range(page * per_page(), mini(oggetti.size(), (page + 1) * per_page())):
		if oggetti[i] != null and card_rect(i).has_point(p):
			return "card:%d" % i
	return ""


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_press(_hit(get_local_mouse_position()))


func _press(what: String) -> void:
	if what == "back":
		leaving = true
	elif what == "prev":
		page -= 1
	elif what == "next":
		page += 1
	elif what == "cancel":
		confirm_item = null
		_merchant("Come vuoi. La merce non scappa.")
	elif what == "buy" and confirm_item != null:
		var item := confirm_item
		confirm_item = null
		var msg := Portafoglio.buy(wallet, item)
		_refresh()
		pop_t = 0.4
		_merchant(msg)
		print("[negozio] %s -> %s" % [item.id, msg])
	elif what.begins_with("card:"):
		var item := oggetti[int(what.substr(5))]
		var why := Portafoglio.why_not(wallet, item)
		if why != "":
			_merchant(why)
		else:
			confirm_item = item


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if confirm_item != null:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_press("buy")
		elif event.keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
			_press("cancel")
		return
	match event.keycode:
		KEY_ESCAPE, KEY_BACKSPACE:
			leaving = true
		KEY_LEFT:
			page = maxi(0, page - 1)
		KEY_RIGHT:
			page = mini(page_count() - 1, page + 1)


# --- Disegno ---------------------------------------------------------------------

func _draw() -> void:
	if font == null:
		font = get_theme_default_font()
	var vp := size
	draw_rect(Rect2(Vector2.ZERO, vp), C0)
	_draw_floor(vp)
	_draw_stall()
	_draw_speech()
	Pietra.banner(self, Rect2(vp.x / 2.0 - 150, 18, 300, 64))
	Pietra.text_c(self, font, vp.x / 2.0, 32, titolo, 24, C0, false)
	_draw_wallet(vp)

	if oggetti.is_empty():
		Pietra.text_c(self, font, inizio_schede.x + 420, inizio_schede.y + 200, "Nessun oggetto in vendita: aggiungili nell'Inspector (lista Oggetti).", 16, C4)
	for i in range(page * per_page(), mini(oggetti.size(), (page + 1) * per_page())):
		_draw_card(i)
	if page_count() > 1:
		var ar := _arrow_rects()
		Pietra.stone(self, ar[0], C3 if page > 0 else C1, hover == "prev")
		Pietra.text_c(self, font, ar[0].get_center().x, ar[0].position.y + 10, "<", 20, C6 if page > 0 else C3)
		Pietra.stone(self, ar[1], C3 if page < page_count() - 1 else C1, hover == "next")
		Pietra.text_c(self, font, ar[1].get_center().x, ar[1].position.y + 10, ">", 20, C6 if page < page_count() - 1 else C3)
		Pietra.text_c(self, font, (ar[0].end.x + ar[1].position.x) / 2.0, ar[0].position.y + 12, "PAGINA %d / %d" % [page + 1, page_count()], 16, C5)

	Pietra.stone(self, back_rect, C3, hover == "back")
	Pietra.text_c(self, font, back_rect.get_center().x, back_rect.position.y + 15, "< BACK", 16, C6)
	if confirm_item != null:
		_draw_confirm(vp)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(C0, fade))


func _draw_floor(vp: Vector2) -> void:
	var y0 := posizione_bancarella.y + TEX_STALL.get_size().y * scala_bancarella - 12.0
	draw_rect(Rect2(0, y0, vp.x, vp.y - y0), Color("1b1b1b"))
	for i in 9:
		draw_rect(Rect2(0, y0 + i * i * 4.0, vp.x, 2), C1)


func _draw_stall() -> void:
	var s := float(scala_bancarella)
	var sz := TEX_STALL.get_size() * s
	var pos := posizione_bancarella.round()
	draw_rect(Rect2(pos + Vector2(3, 0) * s + Vector2(0, sz.y - 3 * s), Vector2(sz.x, 3 * s)), Color(0, 0, 0, 0.5))
	draw_texture_rect(TEX_STALL, Rect2(pos, sz), false)
	# luce della lanterna e occhi del mercante (stessi punti dell'immagine)
	var lk := 0.25 + 0.3 * absf(sin(t * 7.0) * sin(t * 2.3))
	draw_rect(Rect2(pos + Vector2(7, 20) * s, Vector2(1, 4) * s), Color(1, 1, 1, 0.35 + lk))
	draw_rect(Rect2(pos + Vector2(5, 18) * s, Vector2(5, 8) * s), Color(1, 1, 1, lk * 0.08))
	if fmod(t + 1.3, 4.0) < 0.25:
		draw_rect(Rect2(pos + Vector2(24, 22) * s, Vector2.ONE * s), C6)
		draw_rect(Rect2(pos + Vector2(26, 22) * s, Vector2.ONE * s), C6)
	for c in coins:
		var a: float = clampf(c["life"] / 0.8, 0.0, 1.0)
		var p: Vector2 = (c["p"] as Vector2).round()
		draw_rect(Rect2(p, Vector2(3, 3)), Color(1, 1, 1, a))
		draw_rect(Rect2(p - Vector2(3, -1), Vector2(9, 1)), Color(1, 1, 1, a * 0.4))
		draw_rect(Rect2(p - Vector2(-1, 3), Vector2(1, 9)), Color(1, 1, 1, a * 0.4))


func _draw_speech() -> void:
	var sz := TEX_STALL.get_size() * scala_bancarella
	var r := Rect2(posizione_bancarella.x - 24, posizione_bancarella.y - 136, maxf(sz.x + 48, 300), 100)
	Pietra.stone(self, r, C2)
	# punta del fumetto verso il mercante
	var tip := Vector2(posizione_bancarella.x + sz.x * 0.47, r.end.y)
	for k in 4:
		draw_rect(Rect2(tip + Vector2(-12 + k * 3, k * 3), Vector2(24 - k * 6, 3)), C2)
	var txt := frase_benvenuto if Engine.is_editor_hint() else say
	var th := font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 28, 16).y
	Pietra.text_block(self, font, Vector2(r.position.x + 14, roundf(r.get_center().y - th / 2.0)), r.size.x - 28, txt, 16, C6)


func _draw_wallet(vp: Vector2) -> void:
	var r := Rect2(vp.x - 330, 24, 306, 56)
	Pietra.stone(self, r, C2)
	var bump := -4.0 * sin(pop_t / 0.4 * PI) if pop_t > 0.0 else 0.0
	draw_texture_rect(TEX_COIN, Rect2(r.position + Vector2(12, 12 + bump), Vector2(32, 32)), false)
	var money := "INFINITE" if Portafoglio.infinite(wallet) else str(wallet["monete"])
	Pietra.text(self, font, r.position + Vector2(52, 17 + bump), money, 20, C6)
	draw_texture_rect(TEX_SCROLL, Rect2(r.position + Vector2(176, 12), Vector2(32, 32)), false)
	Pietra.text(self, font, r.position + Vector2(214, 17), str(scrolls), 20, C6)
	if wallet["vip"]:
		var v := Rect2(r.position.x + r.size.x - 58, r.position.y + 16, 46, 24)
		draw_rect(v, C6)
		Pietra.text_c(self, font, v.get_center().x, v.position.y + 4, "VIP", 14, C0, false)


func _draw_card(i: int) -> void:
	var item := oggetti[i]
	var r := card_rect(i)
	if item == null:
		Pietra.stone(self, r, C1)
		Pietra.text_c(self, font, r.get_center().x, r.get_center().y - 8, "(vuoto)", 16, C3)
		return
	var hot := hover == "card:%d" % i
	var is_owned := Portafoglio.owned(wallet, item)
	var why := "" if Engine.is_editor_hint() else Portafoglio.why_not(wallet, item)
	Pietra.stone(self, r, C2 if is_owned else C3, hot and not is_owned)
	# icona su un piedistallo, che fluttua appena
	var isz := Vector2.ONE * 16.0 * scala_icone
	var bob := roundf(sin(t * 2.0 + i) * 2.0) if hot else 0.0
	var ip := Vector2(roundf(r.get_center().x - isz.x / 2.0), r.position.y + 18 + bob)
	draw_rect(Rect2(ip.x - 8, r.position.y + 22 + isz.y, isz.x + 16, 6), C1)
	if item.icona:
		draw_texture_rect(item.icona, Rect2(ip, isz), false, Color(1, 1, 1, 0.5) if is_owned else Color.WHITE)
	else:
		Pietra.text_c(self, font, ip.x + isz.x / 2.0, ip.y + isz.y / 2.0 - 12, "?", 24, C4)
	if item.etichetta != "":
		var tw := font.get_string_size(item.etichetta, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var e := Rect2(r.end.x - tw - 22, r.position.y + 10, tw + 14, 22)
		draw_rect(e, C6)
		draw_rect(Rect2(e.position.x, e.end.y, e.size.x, 3), C0)
		Pietra.text(self, font, e.position + Vector2(7, 4), item.etichetta, 13, C0, false)
	var ny := r.position.y + 30 + isz.y
	var title := item.nome.to_upper()
	var fs := 18  # rimpicciolisce i nomi lunghi per farli stare nella scheda
	while fs > 11 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 24:
		fs -= 1
	Pietra.text_c(self, font, r.get_center().x, ny + (18 - fs) / 2.0, title, fs, C6)
	Pietra.text_block(self, font, Vector2(r.position.x + 14, ny + 28), r.size.x - 28, item.descrizione, 13, C5)
	# pulsante del prezzo
	var b := buy_rect(r)
	if is_owned:
		Pietra.stone(self, b, C1)
		Pietra.text_c(self, font, b.get_center().x, b.position.y + 12, "ACQUISTATO", 16, C4, false)
		return
	var can := why == ""
	Pietra.stone(self, b, C4 if (can and hot) else C1, false)
	var euro := item.valuta == OggettoNegozio.Valuta.EURO
	if euro and not OS.is_debug_build():
		Pietra.text_c(self, font, b.get_center().x, b.position.y + 12, "IN ARRIVO", 16, C4, false)
		return
	var label := item.prezzo_testo()
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var icon_w := 0.0 if euro else 30.0
	var x0 := roundf(b.get_center().x - (lw + icon_w) / 2.0)
	if not euro:
		draw_texture_rect(TEX_COIN, Rect2(x0, b.position.y + 8, 24, 24), false, Color.WHITE if can else Color(1, 1, 1, 0.5))
	Pietra.text(self, font, Vector2(x0 + icon_w, b.position.y + 11), label, 18, C6 if can else C4)


func _draw_confirm(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.6))
	var item := confirm_item
	var c := vp / 2.0
	var r := Rect2(c.x - 240, c.y - 150, 480, 280)
	Pietra.stone(self, r, C3)
	if item.icona:
		draw_texture_rect(item.icona, Rect2(c.x - 32, r.position.y + 20, 64, 64), false)
	Pietra.text_c(self, font, c.x, r.position.y + 96, "COMPRARE %s?" % item.nome.to_upper(), 20, C6)
	var price := item.prezzo_testo()
	var line := ""
	if item.valuta == OggettoNegozio.Valuta.EURO:
		line = "Prezzo: %s  (acquisto simulato: build di prova)" % price
	elif Portafoglio.infinite(wallet):
		line = "Prezzo: %s monete d'osso  (DEV: gratis)" % price
	else:
		line = "Prezzo: %s monete d'osso  ·  ne hai %d" % [price, wallet["monete"]]
	Pietra.text_c(self, font, c.x, r.position.y + 130, line, 14, C5, false)
	var cr := _confirm_rects()
	Pietra.stone(self, cr[0], C4, hover == "buy")
	Pietra.text_c(self, font, cr[0].get_center().x, cr[0].position.y + 15, "COMPRA", 18, C6)
	Pietra.stone(self, cr[1], C2, hover == "cancel")
	Pietra.text_c(self, font, cr[1].get_center().x, cr[1].position.y + 15, "ANNULLA", 18, C5)


# --- Oggetti di base -----------------------------------------------------------

func _ripristina() -> void:
	oggetti = oggetti_di_base()
	notify_property_list_changed()
	queue_redraw()


static func oggetti_di_base() -> Array[OggettoNegozio]:
	var out: Array[OggettoNegozio] = []
	out.append(_item("pergamena", "Pergamena", "Una pergamena da aprire nel portale per evocare un'unità.",
		"pergamena", 50, 1, "", false, false))
	out.append(_item("fascio", "Fascio di pergamene", "5 pergamene legate con il nastro del mercante.",
		"fascio", 220, 5, "-12%", false, false))
	out.append(_item("scrigno", "Scrigno del necromante", "10 pergamene: con la garanzia ogni 10 esce almeno un epico.",
		"scrigno", 400, 10, "MIGLIORE", false, false))
	var vip := _item("vip", "Pacchetto VIP", "Sblocca per sempre la velocità di gioco x3 e regala 5 pergamene.",
		"vip", 4.99, 5, "VIP", true, true)
	vip.valuta = OggettoNegozio.Valuta.EURO
	vip.id_store = "vip_pack"
	out.append(vip)
	return out


static func _item(id: String, nome: String, desc: String, icon: String, price: float, scrolls_n: int,
		tag: String, vip: bool, once: bool) -> OggettoNegozio:
	var it := OggettoNegozio.new()
	it.id = id
	it.nome = nome
	it.descrizione = desc
	it.icona = load("res://assets/negozio/%s.png" % icon)
	it.prezzo = price
	it.pergamene = scrolls_n
	it.etichetta = tag
	it.sblocca_vip = vip
	it.una_sola_volta = once
	return it
