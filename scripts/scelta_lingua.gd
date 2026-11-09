extends CanvasLayer
## Scelta della lingua al primo avvio (prima dei dialoghi del tutorial).
## Compare solo se nel salvataggio non c'è ancora una lingua (vedi lingua.gd).
## Tasti: frecce sinistra/destra per scegliere, Invio / Spazio per confermare.

signal scelta(code: String)

const Pietra := preload("res://scripts/ui_pietra.gd")
const Suoni := preload("res://scripts/suoni.gd")
const Lingua := preload("res://scripts/lingua.gd")
const TEMA_PATH := "res://tema.tres"

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")

## Il titolo è scritto in tutte e tre le lingue: il giocatore non ha ancora scelto.
const TITOLI := ["SCEGLI LA LINGUA", "CHOOSE YOUR LANGUAGE", "ELIGE TU IDIOMA"]

var root: Control
var font: Font
var sel := 0
var hover := -1
var t := 0.0
var fade := 0.0
var chiudendo := false
var rects: Array[Rect2] = []


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	var th: Theme = load(TEMA_PATH) as Theme if ResourceLoader.exists(TEMA_PATH) else null
	font = th.default_font if th != null and th.default_font != null else ThemeDB.fallback_font
	sel = maxi(0, Lingua.LINGUE.find(Lingua.current()))  # parte dalla lingua del sistema
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.draw.connect(_draw_ui)
	root.gui_input.connect(_on_gui_input)
	add_child(root)


func _process(delta: float) -> void:
	t += delta
	fade = maxf(0.0, fade - delta * 4.0) if chiudendo else minf(1.0, fade + delta * 4.0)
	if chiudendo and fade <= 0.0:
		queue_free()
		return
	var h := _indice_a(root.get_local_mouse_position())
	if h != hover:
		hover = h
		if h >= 0:
			sel = h
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover >= 0 else Control.CURSOR_ARROW
	root.modulate.a = fade
	root.queue_redraw()


func _input(event: InputEvent) -> void:
	if chiudendo or not (event is InputEventKey):
		return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			sel = posmod(sel - 1, Lingua.LINGUE.size())
			Suoni.play("click", 0.9)
		KEY_RIGHT, KEY_D:
			sel = posmod(sel + 1, Lingua.LINGUE.size())
			Suoni.play("click", 0.9)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_conferma(sel)


func _indice_a(m: Vector2) -> int:
	for i in rects.size():
		if rects[i].has_point(m):
			return i
	return -1


func _on_gui_input(event: InputEvent) -> void:
	if chiudendo or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var i := _indice_a(event.position)  # sul telefono il tocco arriva senza movimento prima
	if i >= 0:
		_conferma(i)


func _conferma(i: int) -> void:
	chiudendo = true
	Suoni.play("conferma")
	var code: String = Lingua.LINGUE[i]
	Lingua.set_lang(code)
	scelta.emit(code)


func _draw_ui() -> void:
	var vp := root.size
	root.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.05, 0.06, 0.88))
	# titolo nelle tre lingue, quello selezionato in evidenza
	var y := vp.y / 2.0 - 190
	for i in TITOLI.size():
		var on := i == sel
		Pietra.text_c(root, font, vp.x / 2.0, y + i * 40, TITOLI[i], 32 if on else 24, C6 if on else C4, on)
	# tre pietre con bandiera e nome
	var bw := 260.0
	var bh := 150.0
	var gap := 36.0
	var x0 := (vp.x - (bw * 3 + gap * 2)) / 2.0
	rects.clear()
	for i in Lingua.LINGUE.size():
		var code: String = Lingua.LINGUE[i]
		var on := i == sel
		var lift := -6.0 if on else 0.0
		var r := Rect2(x0 + i * (bw + gap), vp.y / 2.0 - 30 + lift, bw, bh)
		rects.append(r)
		Pietra.stone(root, r, C4 if on else C2, on)
		_draw_flag(code, Rect2(r.get_center().x - 48, r.position.y + 22, 96, 64))
		Pietra.text_c(root, font, r.get_center().x, r.position.y + 102, Lingua.NOMI[code], 24, C6 if on else C5)
	var hint := "<  >   ·   INVIO / ENTER / INTRO"
	Pietra.text_c(root, font, vp.x / 2.0, vp.y / 2.0 + 160, hint, 16, C4, false)


## Bandiere a blocchi di pixel (16 px per blocco), con bordo scuro.
func _draw_flag(code: String, r: Rect2) -> void:
	root.draw_rect(r.grow(4), C0)
	match code:
		"it":
			var w := r.size.x / 3.0
			root.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), Color("009246"))
			root.draw_rect(Rect2(r.position + Vector2(w, 0), Vector2(w, r.size.y)), Color("f1f2f1"))
			root.draw_rect(Rect2(r.position + Vector2(w * 2, 0), Vector2(w, r.size.y)), Color("ce2b37"))
		"en":
			root.draw_rect(r, Color("012169"))
			# diagonali bianche e rosse a gradini di pixel
			for k in 6:
				var p := r.position + Vector2(k * 16, k * 10.67)
				root.draw_rect(Rect2(p.x, p.y, 16, 11), Color("ffffff"))
				root.draw_rect(Rect2(r.end.x - 16 - k * 16, p.y, 16, 11), Color("ffffff"))
				root.draw_rect(Rect2(p.x + 4, p.y + 3, 8, 5), Color("c8102e"))
				root.draw_rect(Rect2(r.end.x - 12 - k * 16, p.y + 3, 8, 5), Color("c8102e"))
			root.draw_rect(Rect2(r.get_center().x - 16, r.position.y, 32, r.size.y), Color("ffffff"))
			root.draw_rect(Rect2(r.position.x, r.get_center().y - 12, r.size.x, 24), Color("ffffff"))
			root.draw_rect(Rect2(r.get_center().x - 8, r.position.y, 16, r.size.y), Color("c8102e"))
			root.draw_rect(Rect2(r.position.x, r.get_center().y - 6, r.size.x, 12), Color("c8102e"))
		"es":
			root.draw_rect(r, Color("aa151b"))
			root.draw_rect(Rect2(r.position.x, r.position.y + 16, r.size.x, 32), Color("f1bf00"))
			root.draw_rect(Rect2(r.position.x + 20, r.position.y + 24, 12, 16), Color("aa151b"))
