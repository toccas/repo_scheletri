extends CanvasLayer
## DEV TOOL: fondi infiniti nel negozio.
##
##   Ctrl + Shift + D   apre / chiude il PANNELLO DEV: sblocca unità, ricerche,
##                      pergamene, monete, VIP; in battaglia salta ondate, livelli...
##   Ctrl + Shift + M   attiva / disattiva i fondi infiniti
##   Ctrl + Shift + T   rifà il primo avvio: scelta della lingua e tutti i dialoghi
##                      del tutorial (dalla prossima scena che apri)
##
## Sul telefono (o senza tastiera): scrivi il codice sviluppatore nelle
## IMPOSTAZIONI del menu (l'ingranaggio) e in alto a destra compare il tasto DEV,
## che apre / chiude il pannello dev in qualsiasi schermata.
##
## Funziona nell'editor, nelle build esportate con "Export With Debug" e, dopo il
## codice, anche nelle build finali (vedi portafoglio.gd).
## Quando è attivo, in alto a sinistra compare la scritta "DEV · FONDI INFINITI".
## Lo stato resta salvato finché non lo disattivi.

const Portafoglio := preload("res://scripts/portafoglio.gd")
const COMBO_KEY := KEY_M  # insieme a Ctrl e Shift
const COMBO_TUTORIAL := KEY_T
const COMBO_PANNELLO := KEY_D
const PannelloDev := preload("res://scripts/pannello_dev.gd")
const Dialoghi := preload("res://scripts/dialoghi.gd")

## Tasto DEV: grandezza e distanza dall'angolo in alto a destra (pixel dello schermo).
## 96 dall'alto lo tiene sotto i pulsanti velocità/pausa e la scelta della lingua.
const PULSANTE_LATO := Vector2(84, 44)
const PULSANTE_MARGINE := Vector2(16, 96)

var active := false
var pulsante: Button
var toast := ""
var toast_t := 0.0
var canvas: Control


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = Portafoglio.infinite(Portafoglio.load_state())
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_overlay)
	add_child(canvas)
	pulsante = Button.new()
	pulsante.text = "DEV"
	pulsante.focus_mode = Control.FOCUS_NONE
	pulsante.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pulsante.offset_left = -PULSANTE_MARGINE.x - PULSANTE_LATO.x
	pulsante.offset_right = -PULSANTE_MARGINE.x
	pulsante.offset_top = PULSANTE_MARGINE.y
	pulsante.offset_bottom = PULSANTE_MARGINE.y + PULSANTE_LATO.y
	for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("141414", 0.85) if st == "normal" else Color("4a4a4a")
		sb.border_color = Color("ececec") if st != "normal" else Color("acacac")
		sb.set_border_width_all(2)
		pulsante.add_theme_stylebox_override(st, sb)
	pulsante.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	pulsante.add_theme_color_override("font_color", Color("ececec"))
	pulsante.add_theme_color_override("font_hover_color", Color("ffffff"))
	pulsante.add_theme_color_override("font_pressed_color", Color("ffffff"))
	pulsante.add_theme_font_size_override("font_size", 20)
	pulsante.pressed.connect(apri_chiudi_pannello)
	add_child(pulsante)


var pannello: Node = null


## Apre il pannello dev, o lo chiude se è già aperto (Ctrl+Shift+D o tasto DEV).
func apri_chiudi_pannello() -> void:
	if pannello != null and is_instance_valid(pannello):
		pannello.chiudi()
		return
	pannello = PannelloDev.new()
	pannello.chiuso.connect(func() -> void:
		active = Portafoglio.infinite(Portafoglio.load_state())
		var sc := get_tree().current_scene
		if sc and sc.has_method("on_dev_tool_changed"):
			sc.on_dev_tool_changed())
	get_tree().root.add_child(pannello)


func chiudi_pannello() -> void:
	if pannello != null and is_instance_valid(pannello):
		pannello.chiudi()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.ctrl_pressed and event.shift_pressed and event.keycode == COMBO_PANNELLO:
		get_viewport().set_input_as_handled()
		apri_chiudi_pannello()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.ctrl_pressed and event.shift_pressed and event.keycode == COMBO_TUTORIAL:
		Dialoghi.azzera_tutti()
		preload("res://scripts/lingua.gd").dimentica_scelta()
		toast = "DEV TOOL: primo avvio azzerato (lingua e dialoghi): riapri il menu"
		toast_t = 2.5
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.ctrl_pressed and event.shift_pressed and event.keycode == COMBO_KEY:
		active = not active
		Portafoglio.set_dev_infinite(active)
		toast = "DEV TOOL: fondi infiniti %s" % ("ATTIVI" if active else "disattivati")
		toast_t = 2.5
		get_viewport().set_input_as_handled()
		# la scena aperta (es. il negozio) aggiorna subito il saldo
		var sc := get_tree().current_scene
		if sc and sc.has_method("on_dev_tool_changed"):
			sc.on_dev_tool_changed()


func _process(delta: float) -> void:
	toast_t = maxf(0.0, toast_t - delta)
	pulsante.visible = Portafoglio.dev_sbloccato()
	canvas.queue_redraw()


func _draw_overlay() -> void:
	var font := ThemeDB.fallback_font
	var w := canvas.size.x
	if active:
		var label := "DEV · FONDI INFINITI"
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var r := Rect2(6, 6, tw + 20, 22)  # in alto a sinistra, sopra a tutto
		canvas.draw_rect(r, Color(0.08, 0.08, 0.08, 0.85))
		canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(0.93, 0.93, 0.93))
		canvas.draw_string(font, Vector2(r.position.x + 10, r.position.y + 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.93, 0.93, 0.93))
	if toast_t > 0.0:
		var a := clampf(toast_t, 0.0, 1.0)
		var tw := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var r := Rect2(w / 2.0 - tw / 2.0 - 16, canvas.size.y - 120, tw + 32, 36)
		canvas.draw_rect(r, Color(0.08, 0.08, 0.08, 0.9 * a))
		canvas.draw_rect(r.grow(-3), Color(0.2, 0.2, 0.2, 0.9 * a))
		canvas.draw_string(font, Vector2(r.position.x + 16, r.position.y + 25), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.93, 0.93, 0.93, a))
