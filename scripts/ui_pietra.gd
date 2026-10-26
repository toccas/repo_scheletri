extends RefCounted
## Disegno dell'interfaccia "di pietra", nello stesso stile del campo e del menu:
## pannelli smussati (luce in alto a sinistra), lapidi con gli angoli a gradini,
## stendardi di stoffa. Tutto in pixel dello schermo, da chiamare dentro _draw
## (o dal segnale `draw`) di un Control.

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")
const B := 3.0  # spessore dei bordi (1 pixel dell'arte a scala 3)


## Pannello di pietra smussato. `hot` aggiunge il contorno bianco (mouse sopra / selezionato).
static func stone(ci: CanvasItem, r: Rect2, base: Color = C3, hot: bool = false) -> void:
	if hot:
		ci.draw_rect(r.grow(B), C6)
	ci.draw_rect(r, C0)
	var inner := r.grow(-B)
	ci.draw_rect(inner, base)
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, B)), base.lightened(0.28))
	ci.draw_rect(Rect2(inner.position, Vector2(B, inner.size.y)), base.lightened(0.28))
	ci.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - B), Vector2(inner.size.x, B)), base.darkened(0.4))
	ci.draw_rect(Rect2(inner.position + Vector2(inner.size.x - B, B), Vector2(B, inner.size.y - B)), base.darkened(0.4))


## Sagoma a gradini (angoli in alto smussati come in pixel art).
static func stepped(ci: CanvasItem, r: Rect2, col: Color, s: float = B) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(0, 4 * s), Vector2(r.size.x, r.size.y - 4 * s)), col)
	ci.draw_rect(Rect2(r.position + Vector2(s, 2 * s), Vector2(r.size.x - 2 * s, 2 * s)), col)
	ci.draw_rect(Rect2(r.position + Vector2(2 * s, s), Vector2(r.size.x - 4 * s, s)), col)
	ci.draw_rect(Rect2(r.position + Vector2(4 * s, 0), Vector2(r.size.x - 8 * s, s)), col)


## Lapide: contorno, pietra, luce a sinistra e ombra in basso.
static func tomb(ci: CanvasItem, r: Rect2, base: Color = C4, hot: bool = false, s: float = B) -> void:
	stepped(ci, r, C6 if hot else C0, s)
	var inner := r.grow(-s)
	stepped(ci, inner, base, s)
	ci.draw_rect(Rect2(inner.position + Vector2(0, 4 * s), Vector2(s, inner.size.y - 5 * s)), base.lightened(0.3))
	ci.draw_rect(Rect2(inner.position + Vector2(4 * s, 0), Vector2(inner.size.x - 8 * s, s)), base.lightened(0.3))
	ci.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - s), Vector2(inner.size.x, s)), base.darkened(0.4))
	ci.draw_rect(Rect2(inner.position + Vector2(inner.size.x - s, 4 * s), Vector2(s, inner.size.y - 4 * s)), base.darkened(0.4))


## Stendardo di stoffa appeso a un'asta, con la coda a V.
static func banner(ci: CanvasItem, r: Rect2, cloth: Color = C5) -> void:
	ci.draw_rect(Rect2(r.position - Vector2(8 + B, 6 + B), Vector2(r.size.x + 16 + 2 * B, 6 + 2 * B)), C0)
	ci.draw_rect(Rect2(r.position - Vector2(8, 6), Vector2(r.size.x + 16, 6)), C4)
	var notch := minf(24.0, r.size.x * 0.3)
	var body := Rect2(r.position, Vector2(r.size.x, r.size.y - notch))
	ci.draw_rect(body.grow_individual(B, 0, B, 0), C0)
	ci.draw_rect(body, cloth)
	ci.draw_rect(Rect2(body.position, Vector2(B, body.size.y)), cloth.lightened(0.2))
	ci.draw_rect(Rect2(body.end.x - B, body.position.y, B, body.size.y), cloth.darkened(0.25))
	# coda a V, a gradini di 3 pixel
	var steps := int(notch / B)
	for i in steps:
		var y := body.end.y + i * B
		var cut := (i + 1) * (r.size.x / 2.0) / steps
		var w := r.size.x / 2.0 - cut
		if w <= 0.0:
			break
		ci.draw_rect(Rect2(r.position.x - B, y, w + B, B), C0)
		ci.draw_rect(Rect2(r.position.x, y, w - B, B), cloth)
		ci.draw_rect(Rect2(r.end.x - w, y, w + B, B), C0)
		ci.draw_rect(Rect2(r.end.x - w + B, y, w - B, B), cloth.darkened(0.1))


## Testo con ombra a pixel. `pos` è l'angolo in alto a sinistra.
static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color, shadow: bool = true) -> void:
	var base := pos + Vector2(0, font.get_ascent(size))
	if shadow:
		ci.draw_string(font, base + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, C0)
	ci.draw_string(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Testo centrato su `center_x`.
static func text_c(ci: CanvasItem, font: Font, center_x: float, y: float, s: String, size: int, col: Color, shadow: bool = true) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(ci, font, Vector2(roundf(center_x - w / 2.0), y), s, size, col, shadow)


## Testo su più righe, centrato in una larghezza.
static func text_block(ci: CanvasItem, font: Font, pos: Vector2, width: float, s: String, size: int, col: Color) -> void:
	var base := pos + Vector2(0, font.get_ascent(size))
	ci.draw_multiline_string(font, base + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, C0)
	ci.draw_multiline_string(font, base, s, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, col)


## Testo su più righe allineato a sinistra.
static func text_block_left(ci: CanvasItem, font: Font, pos: Vector2, width: float, s: String, size: int, col: Color) -> void:
	var base := pos + Vector2(0, font.get_ascent(size))
	ci.draw_multiline_string(font, base + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, C0)
	ci.draw_multiline_string(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, col)
