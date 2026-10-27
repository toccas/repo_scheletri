extends Node2D
## Effetto visivo temporaneo disegnato a pixel:
##   "ring"  = onda circolare sul terreno   "bolt"  = fulmine dall'alto
##   "slash" = fendente del corpo a corpo  "spark" = scintille dell'impatto
##   "fire"  = esplosione di fiamme         "heal"  = cerchio curativo con le crocette
## `color` è il colore principale dell'effetto (bianco = nessun colore).
## Il nodo è scalato di game.px: raggio e coordinate sono in pixel dell'arte.

var kind := "ring"
var radius := 10.0
var color := Color.WHITE
var life := 0.4
var t := 0.0
var bolt_points := PackedVector2Array()
var dir := 1.0  # verso dell'effetto (1 = verso destra)
var sparks: Array = []  # [direzione, velocità] di ogni scintilla
var bits: Array = []  # fiamme / crocette: {p, v, d} posizione, velocità, ritardo


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
