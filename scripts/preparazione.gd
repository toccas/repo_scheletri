@tool
extends Control
## Preparazione della run: scegli le 4 unità che potrai evocare per tutta la partita.
##
##   - a destra i 4 altari della squadra: clicca un altare per selezionarlo (o tasti 1-4)
##   - a sinistra la collezione: clicca un'unità per metterla sull'altare selezionato
##     (se è già in squadra, le due unità si scambiano di posto)
##   - tasto destro su un altare: lo svuota
##   - INIZIA LA RUN (o Invio) avvia la partita, BACK (o Esc) torna al menu
##   - in basso il NECROMANTE della run: toccalo per vederne i poteri, toccalo ancora per passare al prossimo
##     tra quelli che hai; il riquadro a destra mostra i suoi poteri e le sue magie.
##     Strega e Lich si comprano nel negozio (necromanti/*.tres).
## Le unità nuove si trovano aprendo le pergamene nel portale (scena Evocazione).
##
## SPECIALIZZAZIONI: al rango 3 e al rango 5 ogni unità sceglie tra due rami.
## Clicca la stella in basso a destra sulla carta (o tasto destro sulla carta) per
## aprire la scelta. I rami si modificano in specializzazioni/<unità>.tres.
##
## STATISTICHE: nell'Inspector di questo nodo, sezione "Statistiche delle unità",
## c'è un gruppo per ogni scheletro (vita, attacco, velocità d'attacco, gittata,
## velocità di movimento, quantità per squadra, area). La partita (main.gd) le
## legge da questa scena, anche se avvii direttamente main.tscn. La freccia
## accanto a un valore lo riporta a quello di game_data.gd. Ricerche, rango e
## level-up si applicano sopra questi valori.

const Data := preload("res://scripts/game_data.gd")
const Lingua := preload("res://scripts/lingua.gd")
const Dialoghi := preload("res://scripts/dialoghi.gd")
const Suoni := preload("res://scripts/suoni.gd")
const Portafoglio := preload("res://scripts/portafoglio.gd")
const Collezione := preload("res://scripts/collezione.gd")
const Pietra := preload("res://scripts/ui_pietra.gd")
const Livelli := preload("res://scripts/livelli.gd")
const Spec := preload("res://scripts/specializzazioni.gd")
const Necromanti := preload("res://scripts/necromanti.gd")
const TEX_SKY := preload("res://assets/campo/cielo.png")
const TEX_GROUND := preload("res://assets/campo/terreno.png")
const LEVELS_SCENE := "res://scenes/selezione_livello.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"
const EVOCATION_SCENE := "res://scenes/evocazione.tscn"

## Dialogo del necromante che spiega questa scena (compare solo la prima volta).
## Doppio clic sul file .tres per cambiare le battute; vuoto = nessun dialogo.
@export var dialogo_tutorial: Dialogo = preload("res://dialoghi/preparazione.tres")

## Il tuo tema (per il font). Vuoto = font predefinito.
@export var tema: Theme
## Dialogo che spiega le specializzazioni (la prima volta che apri la scelta).
@export var dialogo_specializzazioni: Dialogo = preload("res://dialoghi/specializzazioni.tres")

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")
const RARITY_PIPS := {"base": 0, "comune": 1, "raro": 2, "epico": 3, "leggendario": 4}
const CARD := Vector2(108, 112)
const CARD_GAP := 6.0
const GRID_POS := Vector2(50, 156)

var st: Dictionary
## Lo sfondo è quello del livello scelto.
var sfondo_cielo: Texture2D = TEX_SKY
var sfondo_terreno: Texture2D = TEX_GROUND
var livello_nome := ""
var font: Font
var selected := 0  # altare selezionato
var hover := {}  # {"type": "card"/"altar"/"button", "id": ...}
var t := 0.0
var fade := 1.0
var leaving := ""
var message := ""
var message_t := 0.0
var card_rects := {}  # id unità -> Rect2
var altar_rects: Array = []
## Specializzazioni: unità di cui è aperta la scelta ("" = chiusa) e zone cliccabili.
var spec_kind := ""
var spec_rects: Array = []  # [{rect, rango, idx}]
var spec_close := Rect2()
var spec_hover := -1
var _icone_rami := {}
## [nome nell'Inspector, chiave, intervallo]: le statistiche modificabili di ogni unità.
const STAT_FIELDS := [
	["vita", "hp", "1,5000,1"],
	["attacco", "dmg", "0,500,0.5"],
	["velocita_attacco", "rate", "0.05,10,0.01"],
	["gittata", "range", "0,400,1"],
	["velocita", "speed", "0,200,1"],
	["quantita", "count", "1,12,1"],
	["area", "splash", "0,80,1"],
]
## Valori cambiati nell'Inspector: "lanciere_vita" -> 80.0 (gli altri restano quelli di game_data.gd).
var unit_stats := {}
var start_rect := Rect2(1000, 646, 256, 62)
var back_rect := Rect2(24, 652, 120, 50)
var portal_rect := Rect2(560, 652, 300, 50)
var necro_rect := Rect2(156, 646, 392, 62)
var mostra_necro := false  # il riquadro a destra mostra il necromante invece dell'unità


# --- Statistiche nell'Inspector ------------------------------------------------

func _stat_key(prop: StringName) -> Array:
	var s := String(prop)
	for f in STAT_FIELDS:
		var suffix: String = "_" + f[0]
		if s.ends_with(suffix):
			var kind := s.substr(0, s.length() - suffix.length())
			if Data.UNITS.has(kind) and kind in Data.ALLY_ORDER:
				# "velocita_attacco" finisce anche con "_attacco": controlla il nome completo
				if f[0] == "attacco" and s.ends_with("_velocita_attacco"):
					continue
				return [kind, f[1]]
	return []


func _stat_default(kind: String, key: String) -> Variant:
	var d: Dictionary = Data.UNITS[kind]
	match key:
		"rate":
			return snappedf(1.0 / maxf(0.01, d["cooldown"]), 0.01)
		"count":
			return int(d["count"])
	return float(d[key])


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = [{"name": "Statistiche delle unità", "type": TYPE_NIL, "usage": PROPERTY_USAGE_CATEGORY}]
	for k in Data.ALLY_ORDER:
		props.append({"name": Data.UNITS[k]["ally_name"], "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP, "hint_string": k + "_"})
		for f in STAT_FIELDS:
			props.append({"name": k + "_" + f[0], "type": TYPE_INT if f[1] == "count" else TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": f[2], "usage": PROPERTY_USAGE_DEFAULT})
	return props


func _get(prop: StringName) -> Variant:
	var k := _stat_key(prop)
	if k.is_empty():
		return null
	return unit_stats.get(String(prop), _stat_default(k[0], k[1]))


func _set(prop: StringName, value: Variant) -> bool:
	var k := _stat_key(prop)
	if k.is_empty():
		return false
	unit_stats[String(prop)] = value
	return true


func _property_can_revert(prop: StringName) -> bool:
	return not _stat_key(prop).is_empty()


func _property_get_revert(prop: StringName) -> Variant:
	var k := _stat_key(prop)
	return null if k.is_empty() else _stat_default(k[0], k[1])


## Statistiche base di un'unità (con le modifiche dell'Inspector), usate da main.gd:
## {hp, dmg, cooldown, range, speed, count, splash}.
func stats_for(kind: String) -> Dictionary:
	var out := {}
	for f in STAT_FIELDS:
		out[f[1]] = _get(StringName(kind + "_" + f[0]))
	if unit_stats.has(kind + "_velocita_attacco"):
		out["cooldown"] = 1.0 / maxf(0.01, float(out["rate"]))
	else:
		out["cooldown"] = float(Data.UNITS[kind]["cooldown"])  # nessun arrotondamento se non lo tocchi
	out.erase("rate")
	out["count"] = int(out["count"])
	return out


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Portafoglio.install_dev_tool(get_tree())
	Suoni.install()
	Lingua.setup()
	_sfondo_livello()
	Dialoghi.avvia(self, dialogo_tutorial)
	if tema:
		theme = tema
	font = get_theme_default_font()
	st = Collezione.load_state()
	while st["squad"].size() < Collezione.SQUAD_SIZE:
		st["squad"].append("")
	for i in Data.ALLY_ORDER.size():
		var c := i % 5
		var r := i / 5
		card_rects[Data.ALLY_ORDER[i]] = Rect2(GRID_POS + Vector2(c * (CARD.x + CARD_GAP), r * (CARD.y + CARD_GAP)), CARD)
	for i in Collezione.SQUAD_SIZE:
		altar_rects.append(Rect2(672 + i * 146, 150, 136, 230))
	_select_first_empty()
	for k in st["owned"]:
		if Spec.da_scegliere(k, st["owned"][k]) > 0:
			_say(tr("Nuove specializzazioni da scegliere: clicca la stella sulle carte!"))
			message_t = 4.0
			break


func _select_first_empty() -> void:
	for i in st["squad"].size():
		if st["squad"][i] == "":
			selected = i
			return


func _squad() -> Array:
	return st["squad"].filter(func(k): return k != "")


func _save() -> void:
	var copy := st.duplicate(true)
	copy["squad"] = _squad()
	Collezione.save_state(copy)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	t += delta
	message_t = maxf(0.0, message_t - delta)
	if leaving != "":
		fade = minf(1.0, fade + delta * 3.0)
		if fade >= 1.0:
			get_tree().change_scene_to_file(leaving)
			return
	else:
		fade = maxf(0.0, fade - delta * 3.0)
	if spec_kind != "":
		var m := get_local_mouse_position()
		spec_hover = -1
		for i in spec_rects.size():
			if (spec_rects[i]["rect"] as Rect2).has_point(m):
				spec_hover = i
		hover = {}
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if spec_hover >= 0 or spec_close.has_point(m) else Control.CURSOR_ARROW
		queue_redraw()
		return
	hover = _hit(get_local_mouse_position())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hover.is_empty() else Control.CURSOR_ARROW
	queue_redraw()


func _hit(p: Vector2) -> Dictionary:
	for k in card_rects:
		if _badge_rect(k).has_point(p) and st["owned"].has(k) and not Spec.opzioni(k, 3).is_empty():
			return {"type": "spec", "id": k}
	for k in card_rects:
		if card_rects[k].has_point(p):
			return {"type": "card", "id": k}
	for i in altar_rects.size():
		if altar_rects[i].has_point(p):
			return {"type": "altar", "id": i}
	if start_rect.has_point(p):
		return {"type": "button", "id": "start"}
	if back_rect.has_point(p):
		return {"type": "button", "id": "back"}
	if portal_rect.has_point(p):
		return {"type": "button", "id": "portal"}
	if necro_rect.has_point(p):
		return {"type": "button", "id": "necro"}
	return {}


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if leaving != "" or not (event is InputEventMouseButton and event.pressed):
		return
	if spec_kind != "":
		_spec_click(event)
		return
	var h := _hit(event.position)
	if h.is_empty():
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if h["type"] in ["card", "spec"] and st["owned"].has(h["id"]):
			_apri_rami(h["id"])
		elif h["type"] == "altar":
			Suoni.play("click", 0.8)
			st["squad"][h["id"]] = ""
			selected = h["id"]
			_save()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if h["type"] != "button":
		mostra_necro = false
	match h["type"]:
		"altar":
			Suoni.play("click")
			selected = h["id"]
		"card":
			_place(h["id"])
		"spec":
			_apri_rami(h["id"])
		"button":
			_press(h["id"])


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if leaving != "" or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if spec_kind != "":
		if event.keycode in [KEY_ESCAPE, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			Suoni.play("click", 0.9)
			spec_kind = ""
		return
	var num: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(event.keycode)
	if num >= 0:
		selected = num
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_press("start")
	elif event.keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
		_press("back")


## Mette l'unità sull'altare selezionato (se è già in squadra si scambiano).
func _place(kind: String) -> void:
	if not st["owned"].has(kind):
		Suoni.play("errore")
		_say(tr("Non hai ancora questa unità: aprila con una pergamena nel portale."))
		return
	Suoni.play("conferma")
	var squad: Array = st["squad"]
	var j := squad.find(kind)
	if j == selected:
		return
	if j >= 0:
		squad[j] = squad[selected]
	squad[selected] = kind
	_save()
	# passa al prossimo altare vuoto, così riempi la squadra di fila
	for i in squad.size():
		if squad[i] == "":
			selected = i
			break


func _press(id: String) -> void:
	match id:
		"start":
			if _squad().is_empty():
				Suoni.play("errore")
				_say(tr("Metti almeno un'unità sugli altari."))
				return
			Suoni.play("conferma")
			_save()
			leaving = Livelli.scena_scelta()
		"back":
			Suoni.play("click")
			_save()
			leaving = LEVELS_SCENE if ResourceLoader.exists(LEVELS_SCENE) else MENU_SCENE
		"portal":
			Suoni.play("click")
			_save()
			leaving = EVOCATION_SCENE
		"necro":
			Suoni.play("click")
			if mostra_necro:  # al primo tocco si vede chi è, dal secondo si cambia
				var prossimo := Necromanti.successivo(Necromanti.attivo_id(), 1)
				if prossimo == Necromanti.attivo_id():
					_say(tr("Altri necromanti si comprano nel negozio."))
				Necromanti.scegli(prossimo)
			mostra_necro = true


func _say(text: String) -> void:
	message = text
	message_t = 2.5


# --- Disegno -----------------------------------------------------------------

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), C1)
		draw_string(get_theme_default_font(), Vector2(40, 60), "PREPARAZIONE · le statistiche delle unità sono nell'Inspector", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, C5)
		return
	var vp := size
	# sfondo: lo stesso campo della partita, scurito
	draw_rect(Rect2(Vector2.ZERO, vp), C0)
	draw_texture_rect(sfondo_cielo, Rect2(Vector2(0, -60), sfondo_cielo.get_size() * 3.0), false)
	draw_texture_rect(sfondo_terreno, Rect2(Vector2(0, 270), sfondo_terreno.get_size() * 3.0), false)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.05, 0.05, 0.55))

	Pietra.banner(self, Rect2(vp.x / 2.0 - 220, 18, 440, 74))
	if livello_nome == "":
		Pietra.text_c(self, font, vp.x / 2.0, 34, tr("PREPARA LA LEGIONE"), 24, C0, false)
	else:  # sotto il titolo: livello scelto e modalità
		Pietra.text_c(self, font, vp.x / 2.0, 26, tr("PREPARA LA LEGIONE"), 24, C0, false)
		var inf := Livelli.modalita_infinita()
		var sub := tr(livello_nome).to_upper() + "  ·  " + (tr("INFINITA") if inf else tr("%d ONDATE") % Data.FINAL_WAVE)
		var fs := 16 if font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x < 380 else 12
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sx := vp.x / 2.0 - sw / 2.0 + (16.0 if inf else 0.0)
		if inf:
			Livelli.disegna_infinito(self, Vector2(sx - 34, 62), 3.0, C1, false)
		Pietra.text(self, font, Vector2(sx, 58 if fs == 16 else 60), sub, fs, C1, false)

	# collezione
	var panel := Rect2(24, 112, 616, 520)
	Pietra.stone(self, panel, C2)
	Pietra.text(self, font, panel.position + Vector2(26, 14), tr("COLLEZIONE  %d/%d") % [st["owned"].size(), Data.ALLY_ORDER.size()], 16, C6)
	for k in Data.ALLY_ORDER:
		_draw_card(k, card_rects[k])

	# altari della squadra
	var head := tr("SQUADRA DELLA RUN")
	Pietra.text(self, font, Vector2(672, 116), head, 16, C6)
	# il suggerimento va dopo il titolo e si rimpicciolisce se non c'è spazio
	var hx := maxf(900.0, 672.0 + font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24.0)
	var hint := tr("clicca un altare, poi un'unità")
	var hs := 16
	while hs > 10 and hx + font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x > size.x - 24.0:
		hs -= 1
	Pietra.text(self, font, Vector2(hx, 116 + (16 - hs) / 2.0), hint, hs, C4, false)
	for i in altar_rects.size():
		_draw_altar(i, altar_rects[i])

	# scheda dell'unità
	var info_kind := ""
	if hover.get("type", "") == "card":
		info_kind = hover["id"]
	elif hover.get("type", "") == "altar":
		info_kind = st["squad"][hover["id"]]
	else:
		info_kind = st["squad"][selected]
	if mostra_necro:
		_draw_necro_info(Rect2(664, 400, 592, 232))
	else:
		_draw_info(Rect2(664, 400, 592, 232), info_kind)

	# pulsanti in basso
	var hb: String = hover.get("id", "") if hover.get("type", "") == "button" else ""
	Pietra.stone(self, back_rect, C3, hb == "back")
	Pietra.text_c(self, font, back_rect.get_center().x, back_rect.position.y + 15, tr("< BACK"), 16, C6)
	Pietra.stone(self, portal_rect, C3, hb == "portal")
	var sc_label := tr("PERGAMENE: %d  · PORTALE") % st["scrolls"]
	Pietra.text_c(self, font, portal_rect.get_center().x, portal_rect.position.y + 15, sc_label, 16, C6 if st["scrolls"] > 0 else C5)
	_draw_necro_button(hb == "necro")
	var ready := not _squad().is_empty()
	Pietra.stone(self, start_rect, C4 if ready else C2, hb == "start" and ready)
	Pietra.text_c(self, font, start_rect.get_center().x, start_rect.position.y + 8, tr("INIZIA LA RUN"), 24, C6 if ready else C4)
	Pietra.text_c(self, font, start_rect.get_center().x, start_rect.position.y + 36, tr("Invio"), 16, C1, false)

	if spec_kind != "":
		_draw_rami(vp)
	if message_t > 0.0:
		var a := clampf(message_t, 0.0, 1.0)
		var w := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 32
		var r := Rect2(vp.x / 2.0 - w / 2.0, 596, w, 36)
		draw_rect(r, Color(C0, 0.9 * a))
		draw_rect(r.grow(-3), Color(C2, 0.9 * a))
		Pietra.text_c(self, font, vp.x / 2.0, 606, message, 16, Color(C6, a))
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(C0, fade))


## Quadratini della rarità (1 comune ... 4 leggendario), nel colore della rarità.
func _draw_rarity_pips(center_x: float, y: float, rarity: String, col: Color) -> void:
	var n: int = RARITY_PIPS.get(rarity, 0)
	var x0 := center_x - (n * 9 - 3) / 2.0
	for i in n:
		draw_rect(Rect2(x0 + i * 9, y, 6, 6), C0)
		draw_rect(Rect2(x0 + i * 9 + 1, y + 1, 4, 4), col)


## Gemma colorata della rarità (rombo 14x14 in pixel art da 2): `p` è la punta in alto.
func _draw_rarity_gem(p: Vector2, rarity: String, dim: bool) -> void:
	if rarity == "base":
		return
	var col := Data.colore_rarita(rarity)
	if dim:
		col = col.darkened(0.55)
	var rows := [1, 3, 5, 7, 5, 3, 1]
	for i in rows.size():  # contorno scuro
		var w: float = rows[i] * 2.0
		draw_rect(Rect2(p.x - w / 2.0 - 2.0, p.y + i * 2.0 - 2.0, w + 4.0, 6.0), C0)
	for i in rows.size():
		var w: float = rows[i] * 2.0
		draw_rect(Rect2(p.x - w / 2.0, p.y + i * 2.0, w, 2.0), col)
	if not dim:  # riflesso
		draw_rect(Rect2(p.x - 2.0, p.y + 4.0, 2.0, 2.0), col.lightened(0.6))


func _draw_card(k: String, r: Rect2) -> void:
	var owned: bool = st["owned"].has(k)
	var in_squad: int = st["squad"].find(k)
	var hot: bool = hover.get("type", "") == "card" and hover.get("id", "") == k
	var d: Dictionary = Data.UNITS[k]
	var rr := Rect2(r.position + Vector2(0, -3 if hot and owned else 0), r.size)
	var base := C4 if owned else C1
	if owned and in_squad >= 0:
		base = C3
	Pietra.tomb(self, rr, base, hot and owned)
	var icon := Rect2(Vector2(rr.get_center().x - 24, rr.position.y + 12), Vector2(48, 48))
	if owned:
		draw_texture_rect_region(Data.ally_texture(k), icon, Data.ally_region(k), Color(1, 1, 1, 0.55 if in_squad >= 0 else 1.0))
		var label := Data.nome_breve(k)
		var fs := 16 if font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= rr.size.x - 10 else 12
		Pietra.text_c(self, font, rr.get_center().x, rr.position.y + 64 + (16 - fs) / 2.0, label, fs, C6)
		_draw_rarity_pips(rr.get_center().x, rr.position.y + 88, d["rarity"], Data.colore_rarita(d["rarity"]))
		_draw_rarity_gem(rr.position + Vector2(16, rr.size.y - 24), d["rarity"], false)
		var rank: int = st["owned"][k]
		if rank > 1:
			Pietra.text(self, font, rr.position + Vector2(8, 6), "R%d" % rank, 12, C6)
		_draw_badge(k, rank, hot)
		if in_squad >= 0:  # numero dell'altare su cui sta
			var b := Rect2(rr.end.x - 26, rr.position.y + 6, 20, 20)
			draw_rect(b, C0)
			draw_rect(b.grow(-2), C6)
			Pietra.text_c(self, font, b.get_center().x, b.position.y + 2, "%d" % (in_squad + 1), 16, C0, false)
	else:
		# sagoma scura: unità ancora da trovare
		draw_texture_rect_region(Data.ally_texture(k), icon, Data.ally_region(k), Color(0, 0, 0, 0.85))
		Pietra.text_c(self, font, rr.get_center().x, rr.position.y + 64, "???", 16, C3, false)
		_draw_rarity_pips(rr.get_center().x, rr.position.y + 88, d["rarity"], Data.colore_rarita(d["rarity"]).darkened(0.55))
		_draw_rarity_gem(rr.position + Vector2(16, rr.size.y - 24), d["rarity"], true)


func _draw_altar(i: int, r: Rect2) -> void:
	var k: String = st["squad"][i]
	var sel := i == selected
	var hot: bool = hover.get("type", "") == "altar" and hover.get("id", -1) == i
	# alone dell'altare selezionato
	if sel:
		var a := 0.08 + 0.05 * absf(sin(t * 3.0))
		draw_rect(Rect2(r.position + Vector2(8, 8), r.size - Vector2(16, 70)), Color(1, 1, 1, a))
	# piedistallo in 3D: faccia sopra chiara, davanti in pietra
	var top := Rect2(r.position.x + 10, r.position.y + 128, r.size.x - 20, 16)
	var front := Rect2(r.position.x + 10, r.position.y + 144, r.size.x - 20, 50)
	Pietra.stone(self, front, C3, sel or hot)
	draw_rect(top.grow(3), C0)
	draw_rect(top, C5 if sel else C4)
	draw_rect(Rect2(top.position, Vector2(top.size.x, 3)), C6 if sel else C5)
	# runa con il numero
	Pietra.text_c(self, font, front.get_center().x, front.position.y + 15, "%d" % (i + 1), 24, C6 if sel else C5)
	if k != "":
		var bob := roundf(sin(t * 2.0 + i) * 2.0)
		var spr := Rect2(Vector2(r.get_center().x - 32, r.position.y + 68 + bob), Vector2(64, 64))
		draw_rect(Rect2(r.get_center().x - 18, r.position.y + 130, 36, 3), Color(0, 0, 0, 0.5))
		draw_texture_rect_region(Data.ally_texture(k), spr, Data.ally_region(k, int(t * 3.0 + i) % 2))
		var lbl := Data.nome_breve(k)
		var fs := 16 if font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= r.size.x else 12
		Pietra.text_c(self, font, r.get_center().x, r.position.y + 204, lbl, fs, C6)
	else:
		Pietra.text_c(self, font, r.get_center().x, r.position.y + 96, tr("vuoto"), 16, C4, false)
	if sel:  # frecce che indicano l'altare selezionato
		var k2 := roundf(absf(sin(t * 5.0)) * 3.0)
		Pietra.text_c(self, font, r.get_center().x, r.position.y + 10 + k2, "v", 16, C6)


## Pulsante in basso: il necromante della run (ritratto, nome, "tocca per cambiare").
func _draw_necro_button(hot: bool) -> void:
	var n := Necromanti.attivo()
	if n == null:
		return
	Pietra.stone(self, necro_rect, C3, hot)
	var ic := Rect2(necro_rect.position + Vector2(12, 7), Vector2(48, 48))
	draw_rect(ic.grow(2), C1)
	if n.ritratto != null:
		draw_texture_rect(n.ritratto, ic, false)
	var nome := tr(n.nome).to_upper()
	var fs := 16
	while fs > 10 and font.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > necro_rect.size.x - 84.0:
		fs -= 2
	Pietra.text(self, font, necro_rect.position + Vector2(72, 9), nome, fs, n.colore.lightened(0.3))
	var sotto := tr("tocca per cambiare") if Necromanti.posseduti().size() > 1 else tr("altri nel negozio")
	Pietra.text(self, font, necro_rect.position + Vector2(72, 34), sotto, 16, C5, false)


## Riquadro a destra con il necromante: potere, magie e quanti ne hai.
func _draw_necro_info(r: Rect2) -> void:
	var n := Necromanti.attivo()
	Pietra.stone(self, r, C2)
	if n == null:
		return
	var spr := Rect2(r.position + Vector2(20, 24), Vector2(96, 96))
	draw_rect(Rect2(spr.position + Vector2(-6, -6), spr.size + Vector2(12, 12)), C1)
	if n.ritratto != null:
		draw_texture_rect(n.ritratto, spr, false)
	var x := r.position.x + 140
	var y := r.position.y + 18
	Pietra.text(self, font, Vector2(x, y), tr(n.nome).to_upper(), 24, n.colore.lightened(0.3))
	Pietra.text(self, font, Vector2(x, y + 32), tr(n.titolo), 16, C5, false)
	var righe := _a_capo(tr(n.descrizione), r.end.x - x - 16.0)
	for i in righe.size():
		Pietra.text(self, font, Vector2(x, y + 60 + i * 20), righe[i], 16, C6, false)
	var ym := y + 66 + righe.size() * 20
	Pietra.text(self, font, Vector2(x, ym), tr("MAGIE:"), 16, C4, false)
	var nomi: Array = []
	for k: String in n.magie:
		nomi.append(Data.nome_abilita(k))
	var mr := _a_capo(", ".join(nomi), r.end.x - x - 90.0)
	for i in mr.size():
		Pietra.text(self, font, Vector2(x + 74, ym + i * 20), mr[i], 16, C5, false)
	var tot := Necromanti.elenco().size()
	Pietra.text(self, font, Vector2(r.position.x + 20, r.end.y - 30),
		tr("Necromanti: %d/%d  ·  il loro albero è nelle Ricerche") % [Necromanti.posseduti().size(), tot], 16, C4, false)


## Spezza il testo in righe larghe al massimo `w` pixel.
func _a_capo(text: String, w: float) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var prova := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(prova, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > w:
			out.append(line)
			line = word
		else:
			line = prova
	if line != "":
		out.append(line)
	return out


func _draw_info(r: Rect2, k: String) -> void:
	Pietra.stone(self, r, C2)
	if k == "":
		Pietra.text_c(self, font, r.get_center().x, r.get_center().y - 8, tr("Scegli un'unità dalla collezione"), 16, C4, false)
		return
	var d: Dictionary = Data.UNITS[k]
	var owned: bool = st["owned"].has(k)
	var spr := Rect2(r.position + Vector2(20, 24), Vector2(96, 96))
	draw_rect(Rect2(spr.position + Vector2(-6, -6), spr.size + Vector2(12, 12)), C1)
	draw_texture_rect_region(Data.ally_texture(k), spr, Data.ally_region(k), Color.WHITE if owned else Color(0, 0, 0, 0.85))
	var x := r.position.x + 140
	var y := r.position.y + 18
	if not owned:
		Pietra.text(self, font, Vector2(x, y), tr("UNITÀ SCONOSCIUTA"), 24, C5)
		Pietra.text(self, font, Vector2(x, y + 38), "%s · %s" % [Data.rarita(d["rarity"]), Data.ruolo(d["role"])], 16, C4)
		_draw_rarity_gem(Vector2(x - 10, y + 40), d["rarity"], true)
		Pietra.text(self, font, Vector2(x, y + 70), tr("Trovala aprendo le pergamene nel portale."), 16, C4, false)
		return
	var rank: int = st["owned"][k]
	Pietra.text(self, font, Vector2(x, y), Data.nome(k).to_upper(), 24, C6)
	var sub := "%s · %s" % [Data.rarita(d["rarity"]), Data.ruolo(d["role"])]
	if rank > 1:
		sub += tr(" · rango %d (+%d%%)") % [rank, int(round((Collezione.rank_mult(rank) - 1.0) * 100.0))]
	Pietra.text(self, font, Vector2(x, y + 34), sub, 16, C5)
	_draw_rarity_gem(Vector2(x - 10, y + 36), d["rarity"], false)
	if d["rarity"] != "base":  # il nome della rarità nel suo colore, sopra il testo grigio
		Pietra.text(self, font, Vector2(x, y + 34), Data.rarita(d["rarity"]), 16, Data.colore_rarita(d["rarity"]))
	var rm := Collezione.rank_mult(rank)
	var ss := stats_for(k)
	var e := Spec.effetti(k, rank)  # le specializzazioni cambiano le statistiche
	var line := tr("x%d per squadra · Vita %d") % [ss["count"] + int(e["unita_extra"]), int(ss["hp"] * rm * e["vita"])]
	if ss["dmg"] > 0.0:
		line += tr(" · Attacco %d") % int(ss["dmg"] * rm * e["danno"])
	if not d["melee"]:
		line += tr(" · Gittata %d") % int(ss["range"] * e["gittata"])
	Pietra.text(self, font, Vector2(x, y + 62), line, 16, C6)
	Pietra.text_block_left(self, font, Vector2(x, y + 96), r.end.x - x - 20, Data.descrizione(k), 16, C5)
	# specializzazioni scelte (o da scegliere)
	var rami := Spec.nomi_attivi(k, rank)
	var manca := Spec.da_scegliere(k, rank)
	var sy := r.end.y - 34
	if manca > 0:
		Pietra.text(self, font, Vector2(x, sy), tr("Rango %d: scegli la specializzazione (stella sulla carta)") % manca, 16, C6)
	elif rami != "":
		Pietra.text(self, font, Vector2(x, sy), tr("Specializzazioni: %s") % rami, 16, C6)
	elif not Spec.opzioni(k, 3).is_empty():
		Pietra.text(self, font, Vector2(x, sy), tr("Al rango 3 sceglierai una specializzazione"), 16, C4, false)


## Usa cielo e terreno del bioma del livello scelto nella schermata dei livelli.
func _sfondo_livello() -> void:
	var id := Livelli.scelto()
	for info in Livelli.elenco():
		if info.id == id:
			livello_nome = info.nome
		if info.id == id and info.bioma != null:
			if info.bioma.cielo:
				sfondo_cielo = info.bioma.cielo
			if info.bioma.terreno:
				sfondo_terreno = info.bioma.terreno


# --- Specializzazioni -----------------------------------------------------------

func _badge_rect(k: String) -> Rect2:
	var r: Rect2 = card_rects[k]
	return Rect2(r.end.x - 28, r.end.y - 28, 22, 22)


## Stella sulla carta: grigia (rango basso), lampeggiante (da scegliere), colorata (scelta fatta).
func _draw_badge(k: String, rank: int, hot: bool) -> void:
	if Spec.opzioni(k, 3).is_empty():
		return
	var b := _badge_rect(k)
	if hot:
		b.position.y -= 3
	var manca := Spec.da_scegliere(k, rank) > 0
	var col := C3
	if manca:
		col = C6 if int(t * 3.0) % 2 == 0 else C5
	elif rank >= 3:
		var e := Spec.effetti(k, rank)
		col = e["colore"] if (e["colore"] as Color).a > 0.0 else C5
	draw_rect(b, C0)
	draw_rect(b.grow(-2), C2 if not manca else C1)
	_draw_stella(b.get_center(), 2.0, col)
	if manca:
		Pietra.text(self, font, b.position + Vector2(7, -20), "!", 16, C6)


## Stellina a pixel 7x7 (il font non ha la stella).
const STELLA := ["...X...", "...X...", "XXXXXXX", ".XXXXX.", "..XXX..", ".XX.XX.", "X.....X"]


func _draw_stella(c: Vector2, px: float, col: Color) -> void:
	for y in STELLA.size():
		var row: String = STELLA[y]
		for x in row.length():
			if row[x] == "X":
				draw_rect(Rect2(c + (Vector2(x, y) - Vector2(3.5, 3.5)) * px, Vector2(px, px)), col)


func _apri_rami(k: String) -> void:
	if Spec.opzioni(k, 3).is_empty():
		return
	Suoni.play("click")
	spec_kind = k
	message_t = 0.0
	Dialoghi.avvia(self, dialogo_specializzazioni)


func _spec_click(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		spec_kind = ""
		return
	var p := event.position
	for o in spec_rects:
		if (o["rect"] as Rect2).has_point(p):
			var rank: int = st["owned"].get(spec_kind, 1)
			if rank < int(o["rango"]):
				Suoni.play("errore")
				_say(tr("Serve il rango %d: trova altri doppioni nelle pergamene.") % o["rango"])
				return
			Suoni.play("conferma")
			Spec.scegli(spec_kind, o["rango"], o["idx"])
			return
	if spec_close.has_point(p) or not Rect2(140, 70, 1000, 580).has_point(p):
		Suoni.play("click", 0.9)
		spec_kind = ""


## Icona dell'unità con il colore del ramo (stesso cambio colore della partita).
func _icona_ramo(k: String, col: Color) -> Texture2D:
	var key := k + col.to_html()
	if not _icone_rami.has(key):
		var img := Data.ally_texture(k).get_image().get_region(Rect2i(Data.ally_region(k)))
		img.convert(Image.FORMAT_RGBA8)
		var base := Data.accent(k)
		var luma := base.r * 0.299 + base.g * 0.587 + base.b * 0.114
		if col.a > 0.0:
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.0 and maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) > 0.12:
						var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
						var n := col * (l / maxf(luma, 0.05))
						img.set_pixel(x, y, Color(clampf(n.r, 0, 1), clampf(n.g, 0, 1), clampf(n.b, 0, 1), c.a))
		_icone_rami[key] = ImageTexture.create_from_image(img)
	return _icone_rami[key]


func _draw_rami(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.75))
	var k := spec_kind
	var rank: int = st["owned"].get(k, 1)
	var panel := Rect2(140, 70, 1000, 580)
	Pietra.stone(self, panel, C2)
	draw_texture_rect_region(Data.ally_texture(k), Rect2(panel.position + Vector2(28, 18), Vector2(64, 64)), Data.ally_region(k))
	Pietra.text(self, font, panel.position + Vector2(108, 22), tr("SPECIALIZZAZIONI") + "  ·  " + Data.nome(k).to_upper(), 24, C6)
	Pietra.text(self, font, panel.position + Vector2(108, 56), tr("rango attuale: %d / %d") % [rank, Data.MAX_RANK], 16, C5, false)
	spec_rects.clear()
	var y := panel.position.y + 100
	for rango in Spec.RANGHI:
		var ops := Spec.opzioni(k, rango)
		var aperto := rank >= rango
		var scelto := Spec.scelta(k, rango)
		Pietra.text(self, font, Vector2(panel.position.x + 28, y + 70), tr("RANGO %d") % rango, 24, C6 if aperto else C4)
		if not aperto:
			Pietra.text(self, font, Vector2(panel.position.x + 28, y + 104), tr("bloccato"), 16, C4, false)
		for i in ops.size():
			var r := Rect2(panel.position.x + 190 + i * 396, y, 384, 210)
			spec_rects.append({"rect": r, "rango": rango, "idx": i})
			_draw_ramo(r, k, ops[i], aperto, scelto == i, spec_hover == spec_rects.size() - 1)
		if not aperto:  # velo sui rami ancora bloccati
			draw_rect(Rect2(panel.position.x + 186, y - 4, 788, 218), Color(0, 0, 0, 0.45))
			var lt := tr("Serve il rango %d") % rango
			var lw := font.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 40
			var lr := Rect2(panel.position.x + 580 - lw / 2.0, y + 80, lw, 48)
			draw_rect(lr, C0)
			draw_rect(lr.grow(-3), C2)
			Pietra.text_c(self, font, lr.get_center().x, lr.position.y + 12, lt, 24, C6)
		y += 226
	spec_close = Rect2(panel.end.x - 148, panel.end.y - 60, 128, 44)
	Pietra.stone(self, spec_close, C3, spec_close.has_point(get_local_mouse_position()))
	Pietra.text_c(self, font, spec_close.get_center().x, spec_close.position.y + 12, tr("CHIUDI"), 16, C6)
	Pietra.text(self, font, Vector2(panel.position.x + 28, panel.end.y - 46),
		tr("Puoi cambiare scelta quando vuoi, fuori dalla battaglia."), 16, C4, false)


func _draw_ramo(r: Rect2, k: String, s: Specializzazione, aperto: bool, scelto: bool, hot: bool) -> void:
	if scelto:
		draw_rect(r.grow(4), C6)
	Pietra.tomb(self, r, C3 if scelto else C2, hot and aperto and not scelto)
	var col := s.colore if s.colore.a > 0.0 else Data.accent(k)
	# icona con il nuovo colore e nome
	var ic := Rect2(r.position + Vector2(14, 30), Vector2(64, 64))
	draw_rect(ic.grow(4), C1)
	draw_texture_rect(_icona_ramo(k, s.colore), ic, false)
	var nome := tr(s.nome).to_upper()
	var fs := 24
	while fs > 12 and font.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 126:
		fs -= 2
	draw_rect(Rect2(r.position + Vector2(92, 36), Vector2(10, 10)), col)
	Pietra.text(self, font, r.position + Vector2(110, 30 + (24 - fs) / 2.0), nome, fs, C6)
	var yy := r.position.y + 66
	for riga in Spec.testo_effetti(s):
		Pietra.text_block_left(self, font, Vector2(r.position.x + 92, yy), r.size.x - 104, "· " + riga, 16, C6 if aperto else C4)
		yy += 20 * maxi(1, ceili(font.get_string_size("· " + riga, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / (r.size.x - 104)))
	if s.descrizione != "":
		Pietra.text_block_left(self, font, Vector2(r.position.x + 14, maxf(yy + 4, r.position.y + 104)), r.size.x - 28, tr(s.descrizione), 16, C5)
	if scelto:
		var tag := Rect2(r.end.x - 98, r.end.y - 34, 86, 24)
		draw_rect(tag, C6)
		Pietra.text_c(self, font, tag.get_center().x, tag.position.y + 4, tr("SCELTA"), 16, C0, false)
	elif aperto:
		Pietra.text(self, font, Vector2(r.position.x + 14, r.end.y - 30), tr("clicca per scegliere"), 16, C4, false)
