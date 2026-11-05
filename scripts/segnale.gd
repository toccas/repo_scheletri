extends Node2D
## Preavviso a terra delle mosse dei campioni: un cerchio (o una striscia lungo la
## corsia) che si riempie; quando è pieno parte `fatto` (il colpo vero).
## Disegnato in pixel dell'arte (il nodo è scalato di game.px).

const Fx := preload("res://scripts/fx.gd")

var game
var forma := "cerchio"  # "cerchio" o "linea"
var raggio := 12.0  # cerchio: raggio; linea: metà altezza
var lunghezza := 60.0  # linea: lunghezza verso sinistra
var ritardo := 1.0
var colore := Color.WHITE
var fatto: Callable
var t := 0.0
var lampo := 0.0  # dopo il colpo: un attimo di luce


func _process(delta: float) -> void:
	if game == null or not game.is_running():
		return
	if lampo > 0.0:
		lampo -= delta
		queue_redraw()
		if lampo <= 0.0:
			queue_free()
		return
	t += delta
	if t >= ritardo:
		if fatto.is_valid():
			fatto.call()
		lampo = 0.18
	queue_redraw()


func _draw() -> void:
	var k := clampf(t / maxf(0.01, ritardo), 0.0, 1.0)
	var blink := 0.55 + 0.45 * absf(sin(t * (6.0 + 10.0 * k)))
	if forma == "linea":
		var r := Rect2(-lunghezza, -raggio, lunghezza, raggio * 2.0)
		if lampo > 0.0:
			draw_rect(r, Color(1, 1, 1, 0.85))
			draw_rect(r.grow_individual(0, -raggio * 0.5, 0, -raggio * 0.5), Color(colore, 0.9))
			return
		draw_rect(r, Color(colore, 0.12 + 0.18 * k))
		draw_rect(Rect2(r.end.x - r.size.x * k, r.position.y, r.size.x * k, r.size.y), Color(colore, 0.2 * blink))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(colore, blink))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(colore, blink))
		return
	if lampo > 0.0:
		draw_circle(Vector2.ZERO, raggio, Color(1, 1, 1, 0.6))
		return
	draw_circle(Vector2.ZERO, raggio * k, Color(colore, 0.22))
	Fx.draw_pixel_circle(self, Vector2.ZERO, raggio, Color(colore, blink))
	Fx.draw_pixel_circle(self, Vector2.ZERO, maxf(1.0, raggio * k), Color(colore, 0.5))
