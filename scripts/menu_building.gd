@tool
extends Sprite2D
## Edificio cliccabile del menu (alloggio, altare delle ricerche, portale).
##
## È un normale Sprite2D: spostalo nell'editor (Transform) per cambiarne la
## posizione. L'origine è il centro della base, così l'ordinamento in profondità
## con gli scheletri del cortile (Y Sort) funziona da solo.
## Al passaggio del mouse compare un contorno bianco attorno alla sagoma.
##
## Le animazioni (finestre, libro, vortice...) usano punti dell'immagine: se
## ridisegni un PNG mantieni le stesse proporzioni o aggiorna le coordinate qui sotto.
##
## TARGA CON IL NOME: con "Lato Etichetta" = Manuale compare un nodo figlio
## "Etichetta" (Marker2D): trascinalo nella vista 2D e la targa lo segue.
## Il segnaposto è il centro della targa.

const ATLAS := preload("res://assets/sprites.png")
const PixelFont := preload("res://scripts/pixel_font.gd")

enum Azione { PARTITA, RICERCHE, EVOCAZIONE, NEGOZIO }

## Testo sotto l'edificio.
@export var etichetta := "AVVIA RUN"
## Cosa succede al clic.
@export var azione: Azione = Azione.PARTITA
enum Lato { AUTOMATICO, SOTTO, SOPRA, MANUALE }

const LABEL_NODE := "Etichetta"

## Dove mettere la targa con il nome. AUTOMATICO: sotto l'edificio se c'è spazio
## prima del bordo dello schermo, altrimenti sopra. MANUALE: dove metti il nodo
## figlio "Etichetta" (viene creato da solo nel punto in cui si trova ora la targa).
@export var lato_etichetta: Lato = Lato.AUTOMATICO:
	set(v):
		var before := _label_rect().get_center() if is_inside_tree() else Vector2.ZERO
		lato_etichetta = v
		if v == Lato.MANUALE:
			_ensure_label_marker(before)
		if _label:
			_label.queue_redraw()
## Spostamento extra della targa, in pixel dell'arte.
@export var spostamento_etichetta := Vector2.ZERO:
	set(v):
		spostamento_etichetta = v
		if _label:
			_label.queue_redraw()

const C0 := Color("141414")
const C2 := Color("343434")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")

const OUTLINE_SHADER := """shader_type canvas_item;
uniform bool outline = false;
uniform vec4 outline_color : source_color = vec4(1.0);
uniform float brighten = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (outline && c.a < 0.5) {
		vec2 p = TEXTURE_PIXEL_SIZE;
		float n = texture(TEXTURE, UV + vec2(p.x, 0.0)).a + texture(TEXTURE, UV - vec2(p.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, p.y)).a + texture(TEXTURE, UV - vec2(0.0, p.y)).a;
		if (n > 0.5) {
			c = outline_color;
		}
	} else {
		c.rgb *= brighten;
	}
	COLOR = c;
}"""

static var _shader: Shader

var hovered := false
var t := 0.0
var _img: Image
var _behind: Node2D  # disegnato dietro l'edificio (vortice del portale)
var _front: Node2D  # disegnato davanti (luci, libro, particelle)
var _book: Sprite2D
var _label: Node2D  # targa con il nome, disegnata sopra a tutto (scheletri e nebbia)
var _sparks: Array = []  # [posizione, velocità, vita]


func _ready() -> void:
	centered = false
	if texture:
		offset = Vector2(-roundf(texture.get_width() / 2.0), -texture.get_height())
	_label = Node2D.new()
	_label.z_index = 20
	_label.draw.connect(_draw_label)
	add_child(_label)
	if Engine.is_editor_hint():
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = OUTLINE_SHADER
	material = ShaderMaterial.new()
	material.shader = _shader
	_img = texture.get_image() if texture else null
	_behind = Node2D.new()
	_behind.show_behind_parent = true
	_behind.draw.connect(_draw_behind)
	add_child(_behind)
	_front = Node2D.new()
	_front.draw.connect(_draw_front)
	add_child(_front)
	if azione == Azione.RICERCHE:
		_book = Sprite2D.new()
		_book.texture = load("res://assets/menu/libro.png")
		_book.centered = true
		add_child(_book)


func set_highlight(on: bool) -> void:
	if hovered == on:
		return
	hovered = on
	if material:
		material.set_shader_parameter("outline", on)
		material.set_shader_parameter("brighten", 1.12 if on else 1.0)
	_label.queue_redraw()


## Il punto (coordinate globali) tocca l'edificio o la sua etichetta?
func hit(global_point: Vector2) -> bool:
	var local := to_local(global_point)
	if _label_rect().grow(3).has_point(local):
		return true
	var p := (local - offset).floor()
	if azione == Azione.EVOCAZIONE and _in_portal(p - Vector2(37, 32)):
		return true  # il vortice dentro l'arco è trasparente nel PNG ma cliccabile
	if _img == null or p.x < 0 or p.y < 0 or p.x >= _img.get_width() or p.y >= _img.get_height():
		return false
	return _img.get_pixelv(p).a > 0.5


func _in_portal(d: Vector2) -> bool:
	if d.y < 0.0:
		return Vector2(d.x, d.y * 1.05).length() < 15.5
	return d.y < 23.0 and absf(d.x) < 15.0


## Ingombro della base sul terreno (coordinate del genitore): gli scheletri lo evitano.
func footprint() -> Rect2:
	var w := texture.get_width() * 0.86 if texture else 32.0
	return Rect2(position.x - w / 2.0, position.y - 18.0, w, 22.0)


## Rettangolo del testo (senza la targa), in coordinate locali.
func _label_rect() -> Rect2:
	var w := PixelFont.text_width(etichetta, 1.0)
	var h := PixelFont.text_height(1.0)
	if lato_etichetta == Lato.MANUALE:
		var m := get_node_or_null(LABEL_NODE) as Node2D
		if m:
			return Rect2((m.position - Vector2(w, h) / 2.0).round(), Vector2(w, h))
	var below := Vector2(-roundf(w / 2.0), 6)
	var above := Vector2(-roundf(w / 2.0), offset.y - 15 - h)
	var pos := below
	match lato_etichetta:
		Lato.SOPRA:
			pos = above
		Lato.AUTOMATICO:
			# il bordo basso dello schermo, nelle coordinate dell'edificio
			var screen_h := float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
			if is_inside_tree() and below.y + h + 5 > to_local(Vector2(0, screen_h)).y:
				pos = above
	return Rect2((pos + spostamento_etichetta).round(), Vector2(w, h))


## Crea (solo nell'editor) il segnaposto della targa, salvato nella scena.
func _ensure_label_marker(at: Vector2) -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or get_node_or_null(LABEL_NODE):
		return
	var root := get_tree().edited_scene_root
	if root == null:
		return
	var m := Marker2D.new()
	m.name = LABEL_NODE
	m.gizmo_extents = 4.0
	m.position = at.round()
	add_child(m)
	m.owner = root


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if lato_etichetta == Lato.MANUALE and _label:
			_label.queue_redraw()  # la targa segue il segnaposto mentre lo trascini
		return
	t += delta
	_update_effects(delta)
	_behind.queue_redraw()
	_front.queue_redraw()
	if hovered:
		_label.queue_redraw()


# --- Targa con il nome -----------------------------------------------------------

func _draw_label() -> void:
	var l := _label
	var r := _label_rect()
	var plate := r.grow_individual(4, 3, 3, 2)
	# ombra, bordo e fondo della targa
	l.draw_rect(Rect2(plate.position + Vector2(1, 1), plate.size), Color(0, 0, 0, 0.5))
	l.draw_rect(plate.grow(1), C6 if hovered else C0)
	l.draw_rect(plate, Color("1c1c1c"))
	l.draw_rect(Rect2(plate.position, Vector2(plate.size.x, 1)), C2)
	PixelFont.draw_text(l, etichetta, r.position + Vector2(1, 1), 1.0, C0)
	PixelFont.draw_text(l, etichetta, r.position, 1.0, C6 if hovered else C5)
	if hovered:
		var k := roundf(absf(sin(t * 5.0)))  # le frecce si avvicinano e si allontanano
		PixelFont.draw_text(l, ">", Vector2(plate.position.x - 8 - k, r.position.y), 1.0, C6)
		PixelFont.draw_text(l, "<", Vector2(plate.end.x + 3 + k, r.position.y), 1.0, C6)


# --- Animazioni proprie di ogni edificio ----------------------------------------
# Tutte in coordinate dell'immagine (0,0 = angolo in alto a sinistra del PNG).

func _tex(p: Vector2) -> Vector2:
	return offset + p


func _update_effects(delta: float) -> void:
	# scintille che salgono (altare) o vengono risucchiate (portale)
	var rate := 0.0
	match azione:
		Azione.RICERCHE:
			rate = 6.0
		Azione.EVOCAZIONE:
			rate = 9.0
	if randf() < rate * delta * (2.0 if hovered else 1.0):
		if azione == Azione.RICERCHE:
			_sparks.append([_tex(Vector2(randf_range(22, 44), randf_range(10, 20))), Vector2(randf_range(-2, 2), randf_range(-9, -5)), randf_range(0.8, 1.5)])
		else:
			var a := randf() * TAU
			var c := _tex(Vector2(37, 40))
			_sparks.append([c + Vector2(cos(a), sin(a) * 0.8) * 26.0, Vector2.ZERO, 1.2])
	for s in _sparks:
		s[2] -= delta
		if azione == Azione.EVOCAZIONE:
			var c := _tex(Vector2(37, 40))
			s[0] = s[0].move_toward(c, delta * 22.0)
		else:
			s[0] += s[1] * delta
	_sparks = _sparks.filter(func(s): return s[2] > 0.0)
	if _book:
		_book.position = _tex(Vector2(33, 9)) + Vector2(0, roundf(sin(t * 2.0) * 1.5))


func _draw_behind() -> void:
	if azione != Azione.EVOCAZIONE:
		return
	# vortice dentro l'arco: anelli che ruotano verso il centro
	var c := _tex(Vector2(37, 32))  # centro dell'arco nel PNG
	var speed := 4.0 if hovered else 2.5
	for y in range(-16, 23):
		for x in range(-15, 16):
			if not _in_portal(Vector2(x, y)):
				continue
			var r := Vector2(x, y * 1.15).length()
			var a := atan2(y, x)
			var v := sin(a * 3.0 + r * 0.55 - t * speed) * 0.5 + 0.5
			v = v * (1.0 - r / 24.0) + (0.35 if r < 3.0 else 0.0)
			var col: Color
			if v > 0.72:
				col = Color("ececec")
			elif v > 0.5:
				col = Color("acacac")
			elif v > 0.3:
				col = Color("4a4a4a")
			else:
				col = Color("242424")
			_behind.draw_rect(Rect2(c + Vector2(x, y), Vector2.ONE), col)


func _draw_front() -> void:
	var f := _front
	match azione:
		Azione.PARTITA:
			# finestre che tremolano come candele
			for wp in [Vector2(17, 46), Vector2(41, 46), Vector2(17, 74), Vector2(41, 74)]:
				var k := 0.15 + 0.2 * absf(sin(t * 3.1 + wp.x * 0.7 + wp.y))
				f.draw_rect(Rect2(_tex(wp + Vector2(0, 1)), Vector2(5, 8)), Color(1, 1, 1, k))
				f.draw_rect(Rect2(_tex(wp + Vector2(-2, -1)), Vector2(9, 12)), Color(1, 1, 1, k * 0.25))
			# il necromante sui merli, con il bastone che pulsa
			var n := _tex(Vector2(31, 30))
			f.draw_texture_rect_region(ATLAS, Rect2(n + Vector2(-8, -16), Vector2(16, 16)), Rect2(64, 32, 16, 16))
			var glow := absf(sin(t * 2.2))
			var orb := n + Vector2(6, -14)
			f.draw_rect(Rect2(orb - Vector2.ONE, Vector2(3, 3)), Color(1, 1, 1, 0.3 + 0.5 * glow))
			if glow > 0.8:
				f.draw_rect(Rect2(orb - Vector2(3, 0), Vector2(7, 1)), Color(1, 1, 1, 0.6))
				f.draw_rect(Rect2(orb - Vector2(0, 3), Vector2(1, 7)), Color(1, 1, 1, 0.6))
		Azione.RICERCHE:
			# fiamme delle candele
			for cp in [Vector2(12, 30), Vector2(54, 30)]:
				var hgt := 2.0 + roundf(absf(sin(t * 9.0 + cp.x)) * 1.5)
				f.draw_rect(Rect2(_tex(cp - Vector2(0, hgt)), Vector2(1, hgt)), Color("ececec"))
				f.draw_rect(Rect2(_tex(cp - Vector2(1, 1)), Vector2(3, 1)), Color(1, 1, 1, 0.5))
			# rune della pedana che si accendono a turno
			for i in 18:
				var a := i / 18.0 * TAU
				var p := _tex(Vector2(33, 50)) + Vector2(cos(a) * 21.0, sin(a) * 5.0)
				var k := clampf(sin(t * 2.0 - i * 0.6) * 1.4, 0.0, 1.0)
				if k > 0.05:
					f.draw_rect(Rect2(p.round(), Vector2.ONE), Color(1, 1, 1, k))
			# alone sotto il libro
			var bp := _tex(Vector2(33, 16))
			for k in 3:
				f.draw_rect(Rect2(bp + Vector2(-8 + k * 2, -k), Vector2(16 - k * 4, 1)), Color(1, 1, 1, 0.08 + 0.06 * absf(sin(t * 2.0))))
		Azione.NEGOZIO:
			# lanterna che tremola e moneta dell'insegna che luccica
			var lk := 0.25 + 0.3 * absf(sin(t * 7.0) * sin(t * 2.3))
			f.draw_rect(Rect2(_tex(Vector2(7, 20)), Vector2(1, 4)), Color(1, 1, 1, 0.4 + lk))
			f.draw_rect(Rect2(_tex(Vector2(4, 18)), Vector2(7, 8)), Color(1, 1, 1, lk * 0.25))
			var g := fmod(t, 3.0)
			if g < 0.35:  # scintilla che attraversa la moneta
				var p := _tex(Vector2(36, 23)) + Vector2(roundf(g / 0.35 * 4.0) - 2.0, -roundf(g / 0.35 * 4.0) + 2.0)
				f.draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, 0.9))
				f.draw_rect(Rect2(p - Vector2(1, 0), Vector2(3, 1)), Color(1, 1, 1, 0.35))
				f.draw_rect(Rect2(p - Vector2(0, 1), Vector2(1, 3)), Color(1, 1, 1, 0.35))
			# il mercante ogni tanto alza lo sguardo: occhi che brillano
			if fmod(t + 1.3, 4.0) < 0.25:
				f.draw_rect(Rect2(_tex(Vector2(24, 22)), Vector2(1, 1)), Color(1, 1, 1, 0.9))
				f.draw_rect(Rect2(_tex(Vector2(26, 22)), Vector2(1, 1)), Color(1, 1, 1, 0.9))
		Azione.EVOCAZIONE:
			# runa della chiave di volta
			var k := 0.4 + 0.6 * absf(sin(t * 1.7))
			f.draw_rect(Rect2(_tex(Vector2(36, 8)), Vector2(3, 5)), Color(1, 1, 1, k))
	for s in _sparks:
		var a: float = clampf(s[2], 0.0, 1.0)
		f.draw_rect(Rect2((s[0] as Vector2).round(), Vector2.ONE), Color(1, 1, 1, a))
