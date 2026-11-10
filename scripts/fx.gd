extends Node2D
## Effetto visivo temporaneo disegnato a pixel:
##   "ring"  = onda circolare sul terreno   "bolt"  = fulmine dall'alto
##   "slash" = fendente del corpo a corpo  "spark" = scintille dell'impatto
##   "fire"  = esplosione di fiamme         "heal"  = cerchio curativo con le crocette
## Magie della Strega:
##   "nube"        = sbuffi di gas che si gonfiano e bolle che scoppiano
##   "maledizione" = cerchio magico con pentacolo e rune che girano, teschio che sale
##   "sciame"      = mosche che ronzano in cerchio e poi si sparpagliano
## Magie del Lich:
##   "bufera"      = bracci di neve che vorticano verso il centro
##   "ghiaccio"    = spuntoni di ghiaccio che crescono dal terreno e si frantumano
##   "cometa"      = cometa che cade dal cielo con la scia, onda d'urto e schegge
## `color` è il colore principale dell'effetto (bianco = nessun colore).
## Il nodo è scalato di game.px: raggio e coordinate sono in pixel dell'arte.

var kind := "ring"
var radius := 10.0
var color := Color.WHITE
var life := 0.4
var t := 0.0
var bolt_points := PackedVector2Array()
var to := Vector2.ZERO  # "zap": punto d'arrivo del fulmine a catena (pixel dell'arte)
var dir := 1.0  # verso dell'effetto (1 = verso destra)
var sparks: Array = []  # [direzione, velocità] di ogni scintilla
var bits: Array = []  # fiamme / crocette: {p, v, d} posizione, velocità, ritardo
const COMETA_CADUTA := 0.38  # parte della vita dell'effetto "cometa" in cui cade (secondi)
const COMETA_DA := Vector2(-46, -118)  # da dove arriva la cometa (pixel dell'arte)


## Pixel di una circonferenza di raggio r (algoritmo del punto medio).
static func circle_points(r: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if r <= 0:
		pts.append(Vector2.ZERO)
		return pts
	var x := r
	var y := 0
	var err := 1 - r
	while x >= y:
		for p in [Vector2(x, y), Vector2(y, x), Vector2(-y, x), Vector2(-x, y),
				Vector2(-x, -y), Vector2(-y, -x), Vector2(y, -x), Vector2(x, -y)]:
			pts.append(p)
		y += 1
		if err < 0:
			err += 2 * y + 1
		else:
			x -= 1
			err += 2 * (y - x) + 1
	return pts


## Disegna una circonferenza a pixel su un qualsiasi CanvasItem.
static func draw_pixel_circle(ci: CanvasItem, center: Vector2, r: float, col: Color) -> void:
	for p in circle_points(int(round(r))):
		ci.draw_rect(Rect2(center + p, Vector2.ONE), col)


func _ready() -> void:
	if kind == "spark":
		for i in 7:
			var a := randf_range(-1.2, 1.2) + (0.0 if dir > 0.0 else PI)
			sparks.append([Vector2.from_angle(a), randf_range(18.0, 34.0)])
	if kind == "fire":
		for i in int(radius * 1.6):
			var a := randf() * TAU
			var r := sqrt(randf()) * radius
			bits.append({"p": Vector2(cos(a) * r, sin(a) * r * 0.45), "v": Vector2(randf_range(-6, 6), -randf_range(10, 34)), "d": randf() * 0.25})
	if kind == "heal":
		for i in int(maxf(5.0, radius * 0.4)):
			var a := randf() * TAU
			var r := sqrt(randf()) * radius * 0.9
			bits.append({"p": Vector2(cos(a) * r, sin(a) * r * 0.45), "v": Vector2(0, -randf_range(10, 20)), "d": randf() * 0.5})
	if kind == "nube":
		for i in int(radius * 0.5) + 5:
			var a := randf() * TAU
			var r := sqrt(randf()) * radius * 0.8
			bits.append({"p": Vector2(cos(a) * r, sin(a) * r * 0.45), "v": Vector2(randf_range(-3, 3), -randf_range(3, 9)),
				"d": randf() * 0.3, "r": randf_range(2.0, 4.5), "bolla": i % 3 == 0})
	if kind == "sciame":
		for i in 16:
			bits.append({"a": randf() * TAU, "w": randf_range(6.0, 10.0) * (1.0 if i % 2 == 0 else -1.0),
				"r": randf_range(3.0, radius * 0.55), "h": randf_range(5.0, 13.0), "d": randf() * 0.15,
				"fuga": Vector2.from_angle(randf() * TAU) * randf_range(25.0, 45.0)})
	if kind == "ghiaccio":
		var n := int(radius * 0.45) + 6
		for i in n:
			var a := randf() * TAU
			var r := sqrt(randf()) * radius * 0.9
			var p := Vector2(cos(a) * r, sin(a) * r * 0.45).round()
			bits.append({"p": p, "h": randf_range(5.0, 10.0), "w": randf_range(3.0, 5.0), "d": r / maxf(radius, 1.0) * 0.18})
		bits.append({"p": Vector2.ZERO, "h": maxf(12.0, radius * 0.7), "w": 7.0, "d": 0.0})  # cristallo centrale
		bits.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["p"].y < y["p"].y)
		for i in 14:  # schegge per quando si frantuma
			sparks.append([Vector2.from_angle(randf() * TAU), randf_range(20.0, 40.0)])
	if kind == "cometa":
		for i in 16:
			var a := randf_range(PI, TAU) if i % 2 == 0 else randf() * TAU
			sparks.append([Vector2.from_angle(a), randf_range(25.0, 55.0)])
	if kind == "zap":  # fulmine spezzettato tra due unità
		var n := maxi(2, int(to.length() / 5.0))
		for i in n + 1:
			var p := to * float(i) / n
			if i > 0 and i < n:
				p += Vector2(randf_range(-2, 2), randf_range(-2, 2))
			bolt_points.append(p.round())
	if kind == "bolt":
		var x := 0
		for y in range(-120, 1, 2):
			if y % 8 == 0:
				x = clampi(x + randi_range(-2, 2), -4, 4)
			bolt_points.append(Vector2(x if y < -4 else 0, y))


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(t / life, 0.0, 1.0)
	var col := Color(color, 1.0 - k * 0.7)
	match kind:
		"zap":
			for i in bolt_points.size() - 1:
				draw_line(bolt_points[i], bolt_points[i + 1], Color(1, 1, 1, col.a), 1.0)
				draw_rect(Rect2(bolt_points[i] + Vector2(0, 1), Vector2.ONE), col)
		"ring":
			var r := radius * (0.35 + 0.65 * k)
			draw_pixel_circle(self, Vector2.ZERO, r, col)
			if r > 3.0:
				draw_pixel_circle(self, Vector2.ZERO, r - 1.0, Color(col, col.a * 0.5))
		"slash":
			# arco bianco che si apre davanti al bersaglio, dall'alto verso il basso
			var sweep := minf(1.0, k * 2.2)
			var a0 := -1.3
			var a1 := lerpf(a0, 1.1, sweep)
			var steps := 20
			for i in steps + 1:
				var a := lerpf(a0, a1, float(i) / steps)
				var tail := float(i) / steps  # la punta dell'arco è più spessa e luminosa
				var p := Vector2(cos(a) * 10.0 * dir - 4.0 * dir, sin(a) * 10.0).round()
				var alpha := (0.4 + 0.6 * tail) * (1.0 - k * k)
				# bordo scuro dietro l'arco, così si stacca anche sopra gli scheletri bianchi
				draw_rect(Rect2(p + Vector2(dir, 1), Vector2(2, 2)), Color(0.08, 0.08, 0.08, alpha * 0.8))
				draw_rect(Rect2(p, Vector2(2 if tail > 0.5 else 1, 2 if tail > 0.5 else 1)), Color(1, 1, 1, alpha))
		"spark":
			for sp in sparks:
				var p: Vector2 = sp[0] * sp[1] * t + Vector2(0, 40.0 * t * t)  # con un po' di gravità
				var size := 2.0 if k < 0.4 else 1.0
				draw_rect(Rect2(p.round(), Vector2(size, size)), col)
			if k < 0.3:
				draw_rect(Rect2(-1, -1, 3, 3), Color(1, 1, 1, 1.0 - k * 3.0))
		"bolt":
			# fulmine colorato con l'anima bianca, che sfarfalla
			var on := k < 0.5 or int(t * 30.0) % 2 == 0
			if on:
				for p in bolt_points:
					draw_rect(Rect2(p - Vector2(1, 0), Vector2(3, 2)), Color(color, col.a * 0.8))
				for p in bolt_points:
					draw_rect(Rect2(p, Vector2(1, 2)), Color(1, 1, 1, col.a))
			draw_pixel_circle(self, Vector2.ZERO, radius * (0.5 + 0.5 * k), col)
			draw_pixel_circle(self, Vector2.ZERO, radius * (0.3 + 0.4 * k), Color(1, 1, 1, col.a * 0.6))
			if k < 0.25:
				draw_rect(Rect2(-radius * 0.6, -1, radius * 1.2, 2), Color(1, 1, 1, 1.0 - k * 4.0))
		"fire":
			# onda d'urto arancio, nucleo giallo-bianco, fiamme che salgono e diventano rosse
			var r := radius * (0.35 + 0.65 * minf(1.0, k * 1.6))
			draw_pixel_circle(self, Vector2.ZERO, r, Color(color, 1.0 - k))
			draw_pixel_circle(self, Vector2.ZERO, r - 1.0, Color(color.darkened(0.35), (1.0 - k) * 0.6))
			if k < 0.4:  # lampo dell'esplosione: ellisse a pixel, gialla al centro e rossa ai bordi
				var cr := radius * (0.3 + k)
				var fa := 1.0 - k * 2.5
				for yy in range(-int(cr * 0.45), int(cr * 0.45) + 1):
					var half := cr * sqrt(maxf(0.0, 1.0 - pow(yy / (cr * 0.45), 2.0)))
					draw_rect(Rect2(-roundf(half), yy, roundf(half) * 2.0, 1), Color(color.darkened(0.25), 0.55 * fa))
					draw_rect(Rect2(-roundf(half * 0.55), yy, roundf(half * 0.55) * 2.0, 1), Color(1.0, 0.85, 0.35, 0.7 * fa))
			for b in bits:
				var bt: float = t - b["d"]
				if bt < 0.0:
					continue
				var bk := clampf(bt / (life * 0.8), 0.0, 1.0)
				if bk >= 1.0:
					continue
				var p: Vector2 = b["p"] + b["v"] * bt
				var fc := Color(1.0, 0.85, 0.35).lerp(color, minf(1.0, bk * 3.0)).lerp(Color(0.78, 0.16, 0.1), clampf(bk * 2.0 - 0.6, 0.0, 1.0))
				var sz := 2.0 if bk < 0.6 else 1.0
				draw_rect(Rect2(p.round(), Vector2(sz, sz + 1.0)), Color(fc, 1.0 - bk * bk))
		"nube":
			_draw_nube(k)
		"maledizione":
			_draw_maledizione(k)
		"sciame":
			_draw_sciame(k)
		"bufera":
			_draw_bufera(k)
		"ghiaccio":
			_draw_ghiaccio(k)
		"cometa":
			_draw_cometa(k)
		"heal":
			# cerchio verde che si allarga, alone tenue e crocette che salgono
			var r := radius * (0.5 + 0.5 * minf(1.0, k * 2.5))
			draw_pixel_circle(self, Vector2.ZERO, r, col)
			if r > 3.0:
				draw_pixel_circle(self, Vector2.ZERO, r - 1.0, Color(col, col.a * 0.4))
			for yy in range(-int(r * 0.45), int(r * 0.45) + 1, 2):
				var half := r * sqrt(maxf(0.0, 1.0 - pow(yy / (r * 0.45), 2.0)))
				draw_rect(Rect2(-half, yy, half * 2.0, 1), Color(color, 0.12 * (1.0 - k)))
			for b in bits:
				var bt: float = t - b["d"]
				if bt < 0.0:
					continue
				var bk := clampf(bt / (life - b["d"]), 0.0, 1.0)
				var p: Vector2 = (b["p"] + b["v"] * bt).round()
				var cc := Color(color.lightened(0.35), 1.0 - bk)
				draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), cc)
				draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), cc)



# --- Magie di Strega e Lich ----------------------------------------------------------

## Disco pieno a pixel (schiacciato in altezza di `sy`).
func _disco(c: Vector2, r: float, col: Color, sy: float = 1.0) -> void:
	var ry := maxf(1.0, r * sy)
	for yy in range(-int(ry), int(ry) + 1):
		var half := roundf(r * sqrt(maxf(0.0, 1.0 - pow(yy / ry, 2.0))))
		if half > 0.0:
			draw_rect(Rect2(c.x - half, c.y + yy, half * 2.0, 1), col)


## Ellisse sul terreno (cerchio schiacciato come le ombre): `n` punti.
func _ellisse(r: float, col: Color, n: int = 48, rot: float = 0.0, tratteggio: bool = false) -> void:
	for i in n:
		if tratteggio and i % 4 >= 2:
			continue
		var a := rot + TAU * i / n
		draw_rect(Rect2(Vector2(cos(a) * r, sin(a) * r * 0.45).round(), Vector2.ONE), col)


func _draw_nube(k: float) -> void:
	if k < 0.35:  # sbuffo iniziale
		_ellisse(radius * (0.4 + 1.6 * k), Color(color, 0.8 - k * 2.0), 56)
	for b in bits:
		var bt: float = t - float(b["d"])
		if bt < 0.0:
			continue
		var bk := clampf(bt / (life - float(b["d"])), 0.0, 1.0)
		var p: Vector2 = (b["p"] + b["v"] * bt).round()
		var r0: float = b["r"]
		if b["bolla"]:  # bolla che sale e scoppia
			if bk < 0.75:
				var rb := 1.0 + roundf(bk * 3.0)
				draw_pixel_circle(self, p + Vector2(0, -bk * 10.0).round(), rb, Color(color.lightened(0.4), 0.9))
			elif bk < 0.85:
				for d4 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
					draw_rect(Rect2(p + Vector2(0, -8) + d4, Vector2.ONE), Color(1, 1, 1, 0.8))
			continue
		var r := r0 * (1.0 + bk * 1.6)
		_disco(p, r, Color(color.darkened(0.25), (1.0 - bk) * 0.45), 0.8)
		_disco(p + Vector2(-1, -1), r * 0.55, Color(color.lightened(0.2), (1.0 - bk) * 0.4), 0.8)


func _draw_maledizione(k: float) -> void:
	var a := 1.0 - k * k
	var r := radius * (1.15 - 0.3 * k)
	var rot := t * 1.6
	var viola := Color(color, a)
	_ellisse(r, viola, 72)
	_ellisse(r * 0.82, Color(color.darkened(0.4), a * 0.9), 56, -rot * 1.5, true)
	# pentacolo: linee tra le punte a salti di 2
	var punte: Array[Vector2] = []
	for i in 5:
		var an := rot + TAU * i / 5.0 - PI / 2.0
		punte.append(Vector2(cos(an) * r * 0.8, sin(an) * r * 0.8 * 0.45).round())
	for i in 5:
		draw_line(punte[i], punte[(i + 2) % 5], Color(color.lightened(0.2), a * 0.8), 1.0)
	# rune che girano sul cerchio
	for i in 8:
		var an := rot + TAU * i / 8.0
		var p := Vector2(cos(an) * r, sin(an) * r * 0.45).round()
		draw_rect(Rect2(p + Vector2(-1, -3), Vector2(3, 1)), Color(color.lightened(0.5), a))
		draw_rect(Rect2(p + Vector2(0, -3), Vector2(1, 4)), Color(color.lightened(0.5), a))
	# teschio che sale dal centro
	var sk := Vector2(-2, -4 - roundf(k * 16.0))
	var ka := clampf(1.0 - absf(k - 0.45) * 2.2, 0.0, 1.0)
	if ka > 0.0:
		var bianco := Color(1, 1, 1, ka)
		draw_rect(Rect2(sk, Vector2(5, 4)), bianco)
		draw_rect(Rect2(sk + Vector2(1, 4), Vector2(3, 1)), bianco)
		draw_rect(Rect2(sk + Vector2(1, 1), Vector2(1, 1)), Color(color.darkened(0.5), ka))
		draw_rect(Rect2(sk + Vector2(3, 1), Vector2(1, 1)), Color(color.darkened(0.5), ka))


func _draw_sciame(k: float) -> void:
	var giallo := color
	for b in bits:
		var bt: float = t - float(b["d"])
		if bt < 0.0:
			continue
		var an: float = float(b["a"]) + float(b["w"]) * bt
		var rr: float = float(b["r"]) * minf(1.0, bt * 4.0)
		var p := Vector2(cos(an) * rr, sin(an) * rr * 0.45 - float(b["h"]))
		p += Vector2(randf_range(-1, 1), randf_range(-1, 1))  # volo a scatti
		if k > 0.7:  # si sparpagliano
			p += (b["fuga"] as Vector2) * (k - 0.7)
		var fa := 1.0 if k < 0.8 else (1.0 - k) * 5.0
		p = p.round()
		draw_rect(Rect2(p + Vector2(0, float(b["h"]) * 0.6).round(), Vector2(2, 1)), Color(0, 0, 0, 0.25 * fa))  # ombra
		draw_rect(Rect2(p, Vector2(2, 1)), Color(giallo.darkened(0.5), fa))
		draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 1)), Color(giallo, fa))
		var su := int(t * 40.0 + float(b["a"]) * 10.0) % 2 == 0  # ali che sbattono
		draw_rect(Rect2(p + Vector2(0, -1 if su else 0) + Vector2(0, -1), Vector2(1, 1)), Color(1, 1, 1, 0.8 * fa))


func _draw_bufera(k: float) -> void:
	var a := 1.0 - k
	_ellisse(radius * (0.3 + 0.9 * minf(1.0, k * 2.5)), Color(color, a * 0.6), 64)
	for braccio in 3:
		for j in 12:
			var f := float(j) / 12.0
			var an := braccio * TAU / 3.0 + f * 2.2 + t * 6.0
			var rr := radius * (1.0 - f * 0.85) * (1.1 - k * 0.4)
			var p := Vector2(cos(an) * rr, sin(an) * rr * 0.45 - 4.0 - f * 6.0).round()
			var col := Color(1, 1, 1, a * (0.35 + 0.65 * f)) if j % 3 != 0 else Color(color.lightened(0.3), a)
			draw_rect(Rect2(p, Vector2(2, 1)), col)
			draw_rect(Rect2(p + Vector2(-2, 0).rotated(an).round(), Vector2.ONE), Color(col, col.a * 0.5))


func _draw_ghiaccio(k: float) -> void:
	var rotto := k > 0.8
	if not rotto:
		_ellisse(radius, Color(color, 0.6), 64)  # brina sul terreno
		_disco(Vector2.ZERO, radius, Color(color, 0.12), 0.45)
	for b in bits:
		var bt: float = t - float(b["d"])
		if bt < 0.0 or rotto:
			continue
		var cresci := minf(1.0, bt / 0.22)
		var h := roundf(float(b["h"]) * cresci)
		var w: float = b["w"]
		var base: Vector2 = b["p"]
		for row in int(h):  # punta a gradini: larga in basso, stretta in cima
			var larg := maxf(1.0, roundf(w * (1.0 - float(row) / maxf(h, 1.0))))
			var y := base.y - row
			draw_rect(Rect2(base.x - roundf(larg / 2.0) - 1, y, larg + 2, 1), Color(0.08, 0.16, 0.22, 0.85))  # contorno
			draw_rect(Rect2(base.x - roundf(larg / 2.0), y, larg, 1), Color(color.lightened(0.15), 0.95))
			draw_rect(Rect2(base.x - roundf(larg / 2.0), y, 1, 1), Color(1, 1, 1, 0.95))  # riflesso a sinistra
	if rotto:  # si frantuma in schegge
		var sk := (k - 0.8) / 0.2
		for sp in sparks:
			var p: Vector2 = sp[0] * sp[1] * sk * 0.35 + Vector2(0, -6.0 + 30.0 * sk * sk * 0.3)
			draw_rect(Rect2(p.round(), Vector2(2, 1)), Color(color.lightened(0.4), 1.0 - sk))


func _draw_cometa(k: float) -> void:
	var tc := t / COMETA_CADUTA
	if tc < 1.0:  # caduta: testa bianca e azzurra, scia che si allunga
		var testa := COMETA_DA * (1.0 - tc)
		for i in 14:
			var q := COMETA_DA * (1.0 - maxf(0.0, tc - i * 0.025))
			var ca := (1.0 - i / 14.0) * 0.8
			var sz := 3.0 if i < 4 else (2.0 if i < 9 else 1.0)
			draw_rect(Rect2(q.round() - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color(color, ca))
		draw_rect(Rect2(testa.round() - Vector2(3, 3), Vector2(6, 6)), Color(color.lightened(0.3), 0.9))
		draw_rect(Rect2(testa.round() - Vector2(2, 2), Vector2(4, 4)), Color(1, 1, 1))
		_ellisse(radius * (0.4 + 0.6 * tc), Color(color, 0.3 * tc), 48)  # ombra che si stringe
		return
	var ik := clampf((t - COMETA_CADUTA) / (life - COMETA_CADUTA), 0.0, 1.0)
	_disco(Vector2.ZERO, radius * 0.9, Color(color, 0.3 * (1.0 - ik)), 0.45)  # brina sul terreno
	if ik < 0.3:  # lampo bianco con il bordo azzurro
		_disco(Vector2.ZERO, radius * (0.7 + ik * 2.5), Color(color.lightened(0.3), 0.7 - ik * 2.3), 0.45)
		_disco(Vector2.ZERO, radius * (0.45 + ik * 2.0), Color(1, 1, 1, 0.95 - ik * 3.0), 0.45)
	for d in [0.0, 1.0]:  # onde d'urto doppie
		_ellisse(radius * (0.5 + 1.6 * ik) - d, Color(color, 1.0 - ik), 96)
		_ellisse(radius * (0.25 + 1.1 * ik) - d, Color(1, 1, 1, (1.0 - ik) * 0.8), 72)
	for sp in sparks:  # schegge di ghiaccio con un po' di gravità
		var p: Vector2 = sp[0] * sp[1] * ik * 0.6 + Vector2(0, 60.0 * ik * ik * 0.35 - 6.0)
		var sz := 3.0 if ik < 0.4 else 2.0
		draw_rect(Rect2(p.round() - Vector2.ONE, Vector2(sz + 1.0, sz + 1.0)), Color(0.08, 0.16, 0.22, (1.0 - ik) * 0.8))
		draw_rect(Rect2(p.round(), Vector2(sz, sz)), Color(color.lightened(0.3), 1.0 - ik))
		draw_rect(Rect2(p.round(), Vector2.ONE), Color(1, 1, 1, 1.0 - ik))
