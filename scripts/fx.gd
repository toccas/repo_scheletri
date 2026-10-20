extends Node2D
## Effetto visivo temporaneo disegnato a pixel:
##   "ring"  = onda circolare sul terreno   "bolt"  = fulmine dall'alto
##   "slash" = fendente del corpo a corpo  "spark" = scintille dell'impatto
## Il nodo è scalato di game.px: raggio e coordinate sono in pixel dell'arte.

var kind := "ring"
var radius := 10.0
var color := Color.WHITE
var life := 0.4
var t := 0.0
var bolt_points := PackedVector2Array()
var dir := 1.0  # verso dell'effetto (1 = verso destra)
var sparks: Array = []  # [direzione, velocità] di ogni scintilla


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
			for p in bolt_points:
				draw_rect(Rect2(p, Vector2(1, 2)), col)
			draw_pixel_circle(self, Vector2.ZERO, radius * (0.5 + 0.5 * k), col)
