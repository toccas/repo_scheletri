@tool
extends Control
## Preparazione della run: scegli le 4 unità che potrai evocare per tutta la partita.
##
##   - a destra i 4 altari della squadra: clicca un altare per selezionarlo (o tasti 1-4)
##   - a sinistra la collezione: clicca un'unità per metterla sull'altare selezionato
##     (se è già in squadra, le due unità si scambiano di posto)
##   - tasto destro su un altare: lo svuota
##   - INIZIA LA RUN (o Invio) avvia la partita, BACK (o Esc) torna al menu
## Le unità nuove si trovano aprendo le pergamene nel portale (scena Evocazione).
##
## STATISTICHE: nell'Inspector di questo nodo, sezione "Statistiche delle unità",
## c'è un gruppo per ogni scheletro (vita, attacco, velocità d'attacco, gittata,
## velocità di movimento, quantità per squadra, area). La partita (main.gd) le
## legge da questa scena, anche se avvii direttamente main.tscn. La freccia
## accanto a un valore lo riporta a quello di game_data.gd. Ricerche, rango e
## level-up si applicano sopra questi valori.

const Data := preload("res://scripts/game_data.gd")
const Collezione := preload("res://scripts/collezione.gd")
const Pietra := preload("res://scripts/ui_pietra.gd")
const TEX_SKY := preload("res://assets/campo/cielo.png")
const TEX_GROUND := preload("res://assets/campo/terreno.png")
const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"
const EVOCATION_SCENE := "res://scenes/evocazione.tscn"

## Il tuo tema (per il font). Vuoto = font predefinito.
@export var tema: Theme

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
	hover = _hit(get_local_mouse_position())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hover.is_empty() else Control.CURSOR_ARROW
	queue_redraw()


func _hit(p: Vector2) -> Dictionary:
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
	return {}


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if leaving != "" or not (event is InputEventMouseButton and event.pressed):
		return
	var h := _hit(event.position)
	if h.is_empty():
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if h["type"] == "altar":
			st["squad"][h["id"]] = ""
			selected = h["id"]
			_save()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	match h["type"]:
		"altar":
			selected = h["id"]
		"card":
			_place(h["id"])
		"button":
			_press(h["id"])


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if leaving != "" or not (event is InputEventKey and event.pressed and not event.echo):
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
		_say("Non hai ancora questa unità: aprila con una pergamena nel portale.")
		return
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
				_say("Metti almeno un'unità sugli altari.")
				return
			_save()
			leaving = GAME_SCENE
		"back":
			_save()
			leaving = MENU_SCENE
		"portal":
			_save()
			leaving = EVOCATION_SCENE


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
	draw_texture_rect(TEX_SKY, Rect2(Vector2(0, -60), TEX_SKY.get_size() * 3.0), false)
	draw_texture_rect(TEX_GROUND, Rect2(Vector2(0, 270), TEX_GROUND.get_size() * 3.0), false)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.05, 0.05, 0.55))

	Pietra.banner(self, Rect2(vp.x / 2.0 - 220, 18, 440, 74))
	Pietra.text_c(self, font, vp.x / 2.0, 34, "PREPARA LA LEGIONE", 24, C0, false)

	# collezione
	var panel := Rect2(24, 112, 616, 520)
	Pietra.stone(self, panel, C2)
	Pietra.text(self, font, panel.position + Vector2(26, 14), "COLLEZIONE  %d/%d" % [st["owned"].size(), Data.ALLY_ORDER.size()], 16, C6)
	for k in Data.ALLY_ORDER:
		_draw_card(k, card_rects[k])

	# altari della squadra
	Pietra.text(self, font, Vector2(672, 116), "SQUADRA DELLA RUN", 16, C6)
	Pietra.text(self, font, Vector2(900, 116), "clicca un altare, poi un'unità", 16, C4, false)
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
	_draw_info(Rect2(664, 400, 592, 232), info_kind)

	# pulsanti in basso
	var hb: String = hover.get("id", "") if hover.get("type", "") == "button" else ""
	Pietra.stone(self, back_rect, C3, hb == "back")
	Pietra.text_c(self, font, back_rect.get_center().x, back_rect.position.y + 15, "< BACK", 16, C6)
	Pietra.stone(self, portal_rect, C3, hb == "portal")
	var sc_label := "PERGAMENE: %d  · PORTALE" % st["scrolls"]
	Pietra.text_c(self, font, portal_rect.get_center().x, portal_rect.position.y + 15, sc_label, 16, C6 if st["scrolls"] > 0 else C5)
	var ready := not _squad().is_empty()
	Pietra.stone(self, start_rect, C4 if ready else C2, hb == "start" and ready)
	Pietra.text_c(self, font, start_rect.get_center().x, start_rect.position.y + 8, "INIZIA LA RUN", 24, C6 if ready else C4)
	Pietra.text_c(self, font, start_rect.get_center().x, start_rect.position.y + 36, "Invio", 16, C1, false)

	if message_t > 0.0:
		var a := clampf(message_t, 0.0, 1.0)
		var w := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 32
		var r := Rect2(vp.x / 2.0 - w / 2.0, 596, w, 36)
		draw_rect(r, Color(C0, 0.9 * a))
		draw_rect(r.grow(-3), Color(C2, 0.9 * a))
		Pietra.text_c(self, font, vp.x / 2.0, 606, message, 16, Color(C6, a))
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(C0, fade))


func _draw_rarity_pips(center_x: float, y: float, rarity: String, col: Color) -> void:
	var n: int = RARITY_PIPS.get(rarity, 0)
	var x0 := center_x - (n * 9 - 3) / 2.0
	for i in n:
		draw_rect(Rect2(x0 + i * 9, y, 6, 6), C0)
		draw_rect(Rect2(x0 + i * 9 + 1, y + 1, 4, 4), col)


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
		var label := k.to_upper()
		var fs := 16 if font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= rr.size.x - 10 else 12
		Pietra.text_c(self, font, rr.get_center().x, rr.position.y + 64 + (16 - fs) / 2, label, fs, C6)
		_draw_rarity_pips(rr.get_center().x, rr.position.y + 88, d["rarity"], C6)
		var rank: int = st["owned"][k]
		if rank > 1:
			Pietra.text(self, font, rr.position + Vector2(8, 6), "R%d" % rank, 12, C6)
		if in_squad >= 0:  # numero dell'altare su cui sta
			var b := Rect2(rr.end.x - 26, rr.position.y + 6, 20, 20)
			draw_rect(b, C0)
			draw_rect(b.grow(-2), C6)
			Pietra.text_c(self, font, b.get_center().x, b.position.y + 2, "%d" % (in_squad + 1), 16, C0, false)
	else:
		# sagoma scura: unità ancora da trovare
		draw_texture_rect_region(Data.ally_texture(k), icon, Data.ally_region(k), Color(0, 0, 0, 0.85))
		Pietra.text_c(self, font, rr.get_center().x, rr.position.y + 64, "???", 16, C3, false)
		_draw_rarity_pips(rr.get_center().x, rr.position.y + 88, d["rarity"], C3)


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
		var lbl := k.to_upper()
		var fs := 16 if font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= r.size.x else 12
		Pietra.text_c(self, font, r.get_center().x, r.position.y + 204, lbl, fs, C6)
	else:
		Pietra.text_c(self, font, r.get_center().x, r.position.y + 96, "vuoto", 16, C4, false)
	if sel:  # frecce che indicano l'altare selezionato
		var k2 := roundf(absf(sin(t * 5.0)) * 3.0)
		Pietra.text_c(self, font, r.get_center().x, r.position.y + 10 + k2, "v", 16, C6)


func _draw_info(r: Rect2, k: String) -> void:
	Pietra.stone(self, r, C2)
	if k == "":
		Pietra.text_c(self, font, r.get_center().x, r.get_center().y - 8, "Scegli un'unità dalla collezione", 16, C4, false)
		return
	var d: Dictionary = Data.UNITS[k]
	var owned: bool = st["owned"].has(k)
	var spr := Rect2(r.position + Vector2(20, 24), Vector2(96, 96))
	draw_rect(Rect2(spr.position + Vector2(-6, -6), spr.size + Vector2(12, 12)), C1)
	draw_texture_rect_region(Data.ally_texture(k), spr, Data.ally_region(k), Color.WHITE if owned else Color(0, 0, 0, 0.85))
	var x := r.position.x + 140
	var y := r.position.y + 18
	if not owned:
		Pietra.text(self, font, Vector2(x, y), "UNITÀ SCONOSCIUTA", 24, C5)
		Pietra.text(self, font, Vector2(x, y + 38), "%s · %s" % [Data.RARITY_NAMES[d["rarity"]], Data.ROLE_NAMES[d["role"]]], 16, C4)
		Pietra.text(self, font, Vector2(x, y + 70), "Trovala aprendo le pergamene nel portale.", 16, C4, false)
		return
	var rank: int = st["owned"][k]
	Pietra.text(self, font, Vector2(x, y), String(d["ally_name"]).to_upper(), 24, C6)
	var sub := "%s · %s" % [Data.RARITY_NAMES[d["rarity"]], Data.ROLE_NAMES[d["role"]]]
	if rank > 1:
		sub += " · rango %d (+%d%%)" % [rank, int(round((Collezione.rank_mult(rank) - 1.0) * 100.0))]
	Pietra.text(self, font, Vector2(x, y + 34), sub, 16, C5)
	var rm := Collezione.rank_mult(rank)
	var ss := stats_for(k)
	var line := "x%d per squadra · Vita %d" % [ss["count"], int(ss["hp"] * rm)]
	if ss["dmg"] > 0.0:
		line += " · Attacco %d" % int(ss["dmg"] * rm)
	if not d["melee"]:
		line += " · Gittata %d" % int(ss["range"])
	Pietra.text(self, font, Vector2(x, y + 62), line, 16, C6)
	Pietra.text_block_left(self, font, Vector2(x, y + 96), r.end.x - x - 20, d["desc"], 16, C5)
