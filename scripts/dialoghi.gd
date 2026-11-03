extends CanvasLayer
## Finestra dei dialoghi: il necromante in pixel art che parla con un fumetto.
##
## Uso da qualsiasi scena (per esempio nel _ready):
##     Dialoghi.avvia(self, preload("res://dialoghi/negozio.tres"))
## Il dialogo compare solo la prima volta (vedi Dialogo.solo_la_prima_volta);
## quello che il giocatore ha già visto si salva in user://progressi.cfg, sezione [dialoghi].
##
## Comandi: clic / Spazio / Invio = avanti (se il testo sta ancora scrivendo, lo
## completa), Esc o "SALTA" = chiude tutto il dialogo.
## Dev tool: Ctrl+Shift+T fa rivedere tutti i dialoghi (solo nelle build di prova).

signal finito

const SELF_PATH := "res://scripts/dialoghi.gd"
const SAVE_PATH := "user://progressi.cfg"
const TEMA_PATH := "res://tema.tres"  # il tuo tema (per il font Minecraft)
const Pietra := preload("res://scripts/ui_pietra.gd")
const Suoni := preload("res://scripts/suoni.gd")
const Lingua := preload("res://scripts/lingua.gd")
const RITRATTO := preload("res://assets/dialoghi/necromante.png")
const FRAME := 48  # lato di un fotogramma del ritratto
const ZOOM := 4.0

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")
const VIOLA := Color("9c5ccc")

var dialogo: Dialogo
var indice := 0
var mostrati := 0.0  # lettere già scritte della battuta attuale
var righe: Array[String] = []  # battuta attuale già divisa in righe
var dim_testo := 24
var t := 0.0
var entrata := 0.0  # 0 -> 1 quando compare
var uscendo := false
var blink_t := 2.5
var voce_t := 0.0
var font: Font
var root: Control
var skip_rect := Rect2()


# --- API ---------------------------------------------------------------------

## Mostra il dialogo `d` sopra la scena `scena`. Restituisce la finestra (o null se
## il dialogo è già stato visto e `forza` è falso). Collegati a `finito` se ti serve.
static func avvia(scena: Node, d: Dialogo, forza: bool = false) -> Node:
	if d == null or d.battute.is_empty() or Engine.is_editor_hint():
		return null
	if "--autotest" in OS.get_cmdline_user_args():
		return null
	if d.solo_la_prima_volta and not forza and visto(d.chiave()):
		return null
	var w: Node = load(SELF_PATH).new()
	w.dialogo = d
	scena.add_child.call_deferred(w)
	return w


static func visto(id: String) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return bool(cfg.get_value("dialoghi", id, false))


static func segna_visto(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # conserva il resto del salvataggio
	cfg.set_value("dialoghi", id, true)
	cfg.save(SAVE_PATH)


## Dimentica tutti i dialoghi visti (tornano a comparire).
static func azzera_tutti() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	if cfg.has_section("dialoghi"):
		cfg.erase_section("dialoghi")
	cfg.save(SAVE_PATH)


# --- Finestra ------------------------------------------------------------------

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	Lingua.setup()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # la scena sotto non riceve i clic
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.draw.connect(_draw_window)
	root.gui_input.connect(_on_gui_input)
	add_child(root)
	var th: Theme = load(TEMA_PATH) as Theme if ResourceLoader.exists(TEMA_PATH) else null
	font = th.default_font if th != null and th.default_font != null else ThemeDB.fallback_font
	_prepara_battuta()


func _battuta() -> BattutaDialogo:
	# mentre la finestra sfuma dopo l'ultima battuta resta visibile l'ultima
	return dialogo.battute[clampi(indice, 0, dialogo.battute.size() - 1)]


func _testo() -> String:
	var b := _battuta()
	return tr(b.testo) if b else ""


func _bubble_rect() -> Rect2:
	var vp := root.size
	return Rect2(292, vp.y - 214, vp.x - 292 - 24, 190)


## Divide la battuta in righe una volta sola, così le parole non saltano
## da una riga all'altra mentre il testo si scrive.
func _prepara_battuta() -> void:
	mostrati = 0.0
	var w := _bubble_rect().size.x - 64.0
	for size in [24, 16]:
		dim_testo = size
		righe = _wrap(_testo(), w, size)
		if righe.size() <= 5:
			break


func _wrap(text: String, width: float, size: int) -> Array[String]:
	var out: Array[String] = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			var test := word if line == "" else line + " " + word
			if line != "" and font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				out.append(line)
				line = word
			else:
				line = test
		out.append(line)
	return out


func _totale() -> int:
	var n := 0
	for r in righe:
		n += r.length()
	return n


func _process(delta: float) -> void:
	t += delta
	if uscendo:
		entrata = maxf(0.0, entrata - delta * 5.0)
		if entrata <= 0.0:
			finito.emit()
			queue_free()
			return
	else:
		entrata = minf(1.0, entrata + delta * 4.0)
	var prima := int(mostrati)
	if entrata >= 1.0 and mostrati < _totale():
		mostrati = minf(_totale(), mostrati + delta * dialogo.velocita_testo)
		# voce: un piccolo suono ogni poche lettere (non sugli spazi)
		voce_t -= delta
		if int(mostrati) > prima and voce_t <= 0.0:
			var ch := _lettera(int(mostrati) - 1)
			if ch != " " and ch != "":
				Suoni.play("voce", 0.9 + 0.08 * float(_battuta().espressione == BattutaDialogo.Espressione.FELICE) - 0.12 * float(_battuta().espressione == BattutaDialogo.Espressione.ARRABBIATO))
				voce_t = 0.07
	blink_t -= delta
	if blink_t < -0.12:
		blink_t = randf_range(2.0, 4.5)
	root.queue_redraw()


func _lettera(i: int) -> String:
	for r in righe:
		if i < r.length():
			return r[i]
		i -= r.length()
	return ""


func _input(event: InputEvent) -> void:
	if uscendo:
		return
	if event is InputEventKey:
		if event.ctrl_pressed:
			return  # lascia passare le combinazioni del dev tool (Ctrl+Shift+...)
		get_viewport().set_input_as_handled()  # i tasti non arrivano al gioco sotto
		if not event.pressed or event.echo:
			return
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_avanti()
		elif event.keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
			_chiudi()


func _on_gui_input(event: InputEvent) -> void:
	if uscendo or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if skip_rect.grow(4).has_point(event.position):
		_chiudi()
	else:
		_avanti()


func _avanti() -> void:
	if entrata < 1.0:
		return
	if mostrati < _totale():
		mostrati = _totale()  # completa subito la battuta
		return
	Suoni.play("click")
	if indice + 1 >= dialogo.battute.size():
		_chiudi()  # ultima battuta: si chiude restando su questa
	else:
		indice += 1
		_prepara_battuta()


func _chiudi() -> void:
	if uscendo:
		return
	uscendo = true
	if dialogo.solo_la_prima_volta:
		segna_visto(dialogo.chiave())


# --- Disegno -----------------------------------------------------------------

func _draw_window() -> void:
	var vp := root.size
	var k := entrata * entrata * (3.0 - 2.0 * entrata)
	root.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.5 * k))
	var slide := Vector2(0, roundf((1.0 - k) * 60.0))
	root.draw_set_transform(slide)

	# ritratto su una lapide di pietra
	var pr := Rect2(24, vp.y - 260, 248, 236)
	Pietra.stone(root, pr, C2)
	var face := Rect2(pr.position + Vector2(28, 30), Vector2(FRAME, FRAME) * ZOOM)
	root.draw_rect(face.grow(4), C0)
	root.draw_rect(face, Color("1d1a22"))
	# bagliore viola dietro al necromante
	var glow := 0.18 + 0.08 * sin(t * 2.2)
	root.draw_rect(Rect2(face.position + Vector2(24, 24), face.size - Vector2(48, 48)), Color(VIOLA, glow * 0.5))
	var bob := roundf(sin(t * 1.6)) * ZOOM if mostrati >= _totale() else 0.0
	var b := _battuta()
	var row := int(b.espressione) if b else 0
	var col := 0
	if blink_t < 0.0:
		col = 2
	elif mostrati < _totale() and _lettera(int(mostrati)) != " ":
		col = 1 if int(t * 11.0) % 2 == 0 else 0  # bocca che si muove mentre parla
	root.draw_texture_rect_region(RITRATTO, Rect2(face.position + Vector2(0, bob), face.size),
		Rect2(col * FRAME, row * FRAME, FRAME, FRAME))
	# targa con il nome
	var name_txt := tr(dialogo.nome)
	var nw := font.get_string_size(name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28
	var nr := Rect2(roundf(pr.position.x + (pr.size.x - nw) / 2.0), pr.position.y - 16, nw, 30)
	root.draw_rect(nr.grow(3), C0)
	root.draw_rect(nr, C5)
	root.draw_rect(Rect2(nr.position, Vector2(nr.size.x, 3)), C6)
	root.draw_rect(Rect2(nr.position + Vector2(0, nr.size.y - 3), Vector2(nr.size.x, 3)), C4)
	Pietra.text_c(root, font, nr.get_center().x, nr.position.y + 7, name_txt, 16, C0, false)

	# fumetto
	var br := _bubble_rect()
	root.draw_rect(Rect2(br.position + Vector2(6, 6), br.size), Color(0, 0, 0, 0.45))
	Pietra.stepped(root, br.grow(4), C0, 6.0)
	Pietra.stepped(root, br, Color("e6e3dc"), 6.0)
	root.draw_rect(Rect2(br.position.x + 6, br.end.y - 10, br.size.x - 12, 4), Color("c4c0b6"))
	# punta del fumetto verso il necromante
	var tip_y := pr.position.y + 120 + slide.y * 0.0
	for i in 6:
		var h := 28.0 - i * 4.0
		root.draw_rect(Rect2(br.position.x - 4 - i * 4, tip_y - h / 2.0, 4, h), C0)
		if h > 8.0:
			root.draw_rect(Rect2(br.position.x - i * 4, tip_y - h / 2.0 + 4, 4, h - 8), Color("e6e3dc"))
	# testo che si scrive
	var left := int(mostrati)
	var lh := dim_testo + 10
	var y0 := br.position.y + 28
	for i in righe.size():
		if left <= 0:
			break
		var part: String = righe[i].left(left)
		left -= righe[i].length()
		root.draw_string(font, Vector2(br.position.x + 32, y0 + i * lh + font.get_ascent(dim_testo)), part,
			HORIZONTAL_ALIGNMENT_LEFT, -1, dim_testo, C0)
	# contatore e freccia "avanti"
	var counter := "%d/%d" % [indice + 1, dialogo.battute.size()]
	root.draw_string(font, Vector2(br.position.x + 32, br.end.y - 18), counter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C4)
	if mostrati >= _totale() and int(t * 2.5) % 2 == 0:
		var a := Vector2(br.end.x - 40, br.end.y - 34)
		for i in 4:
			root.draw_rect(Rect2(a + Vector2(i * 2, i * 2), Vector2(16 - i * 4, 2)), C0)
	# pulsante SALTA
	var st := tr("SALTA  >>")
	var sw := font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24
	skip_rect = Rect2(br.end.x - sw - 12, br.position.y - 40, sw, 32)
	var hot := skip_rect.grow(4).has_point(root.get_local_mouse_position() - slide)
	Pietra.stone(root, skip_rect, C3, hot)
	Pietra.text_c(root, font, skip_rect.get_center().x, skip_rect.position.y + 8, st, 16, C6 if hot else C5)
	root.draw_set_transform(Vector2.ZERO)
