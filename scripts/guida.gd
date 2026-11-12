extends RefCounted
## GUIDA DELLE SPECIALIZZAZIONI: la prima volta che trovi tre unità uguali (rango 3)
## il gioco ti accompagna passo per passo, mostrando dove toccare:
##   1. Evocazione: il necromante spiega (dialoghi/tre_uguali.tres) e una freccia
##      indica PREPARA LA SQUADRA.
##   2. Preparazione: la freccia indica la stella sulla carta dell'unità.
##   3. Scelta dei rami: la freccia indica i due rami del rango 3.
##   4. Ramo scelto: la freccia indica CHIUDI. Fatto: la guida non compare più.
## Durante ogni passo risponde solo il punto indicato.
## Lo stato sta in user://progressi.cfg: [dialoghi] guida_specializzazioni = true quando
## è finita, [guida] rango3 = "<unità>" mentre è in corso.

const Pietra := preload("res://scripts/ui_pietra.gd")
const SAVE_PATH := "user://progressi.cfg"
const CHIAVE := "guida_specializzazioni"

const C0 := Color("141414")
const C2 := Color("343434")
const C6 := Color("ececec")
const B := 3.0  # un pixel dell'arte

## Freccia a pixel che punta in basso (7x7).
const FRECCIA := ["..XXX..", "..XXX..", "..XXX..", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]


static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return cfg


## La guida è già stata completata?
static func finita() -> bool:
	return bool(_cfg().get_value("dialoghi", CHIAVE, false))


## L'unità per cui è in corso la guida ("" = nessuna).
static func in_corso() -> String:
	if finita():
		return ""
	return String(_cfg().get_value("guida", "rango3", ""))


static func inizia(kind: String) -> void:
	if finita():
		return
	var cfg := _cfg()
	cfg.set_value("guida", "rango3", kind)
	cfg.save(SAVE_PATH)


static func completa() -> void:
	var cfg := _cfg()
	cfg.set_value("dialoghi", CHIAVE, true)
	if cfg.has_section("guida"):
		cfg.erase_section("guida")
	cfg.save(SAVE_PATH)


## Oscura lo schermo tranne `bersaglio`, con una cornice che pulsa, una freccia che
## rimbalza verso il bersaglio e il testo con l'indicazione. Coordinate dello schermo.
static func disegna(ci: CanvasItem, font: Font, vp: Vector2, bersaglio: Rect2, testo: String, t: float) -> void:
	var r := bersaglio.grow(6.0)
	var buio := Color(0, 0, 0, 0.62)
	ci.draw_rect(Rect2(0, 0, vp.x, maxf(0.0, r.position.y)), buio)
	ci.draw_rect(Rect2(0, r.end.y, vp.x, maxf(0.0, vp.y - r.end.y)), buio)
	ci.draw_rect(Rect2(0, r.position.y, maxf(0.0, r.position.x), r.size.y), buio)
	ci.draw_rect(Rect2(r.end.x, r.position.y, maxf(0.0, vp.x - r.end.x), r.size.y), buio)
	# cornice bianca che pulsa
	var p := 0.5 + 0.5 * sin(t * 6.0)
	var c := Color(C6, 0.55 + 0.45 * p)
	var g := r.grow(roundf(p * 3.0))
	ci.draw_rect(Rect2(g.position, Vector2(g.size.x, B)), c)
	ci.draw_rect(Rect2(g.position + Vector2(0, g.size.y - B), Vector2(g.size.x, B)), c)
	ci.draw_rect(Rect2(g.position, Vector2(B, g.size.y)), c)
	ci.draw_rect(Rect2(g.position + Vector2(g.size.x - B, 0), Vector2(B, g.size.y)), c)
	# freccia sopra il bersaglio (sotto, girata, se in alto non c'è posto)
	var sopra := r.position.y > 150.0
	var salto := roundf(absf(sin(t * 5.0)) * 8.0)
	var px := 4.0
	var fx := r.get_center().x - 3.5 * px
	var fy := (r.position.y - 7.0 * px - 8.0 - salto) if sopra else (r.end.y + 8.0 + salto)
	for y in FRECCIA.size():
		var riga: String = FRECCIA[y if sopra else FRECCIA.size() - 1 - y]
		for x in riga.length():
			if riga[x] == "X":
				ci.draw_rect(Rect2(fx + x * px - 2.0, fy + y * px - 2.0, px + 4.0, px + 4.0), C0)
	for y in FRECCIA.size():
		var riga: String = FRECCIA[y if sopra else FRECCIA.size() - 1 - y]
		for x in riga.length():
			if riga[x] == "X":
				ci.draw_rect(Rect2(fx + x * px, fy + y * px, px, px), C6)
	# riquadro con l'indicazione, accanto alla freccia
	var fs := 16
	var w := font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 36.0
	w = minf(w, vp.x - 32.0)
	var h := 40.0
	var bx := clampf(r.get_center().x - w / 2.0, 16.0, vp.x - 16.0 - w)
	var by := (fy - h - 10.0) if sopra else (fy + 7.0 * px + 10.0)
	var box := Rect2(bx, by, w, h)
	ci.draw_rect(box.grow(3.0), C6)
	ci.draw_rect(box, C0)
	ci.draw_rect(box.grow(-3.0), C2)
	Pietra.text_c(ci, font, box.get_center().x, box.position.y + 11.0, testo, fs, C6)
