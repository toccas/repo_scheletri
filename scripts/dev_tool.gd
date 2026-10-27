extends CanvasLayer
## DEV TOOL: fondi infiniti nel negozio.
##
##   Ctrl + Shift + M   attiva / disattiva i fondi infiniti
##
## Funziona solo nell'editor e nelle build esportate con "Export With Debug":
## nelle build finali questo nodo non viene nemmeno creato (vedi portafoglio.gd).
## Quando è attivo, in alto a sinistra compare la scritta "DEV · FONDI INFINITI".
## Lo stato resta salvato finché non lo disattivi.

const Portafoglio := preload("res://scripts/portafoglio.gd")
const COMBO_KEY := KEY_M  # insieme a Ctrl e Shift

var active := false
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


func _input(event: InputEvent) -> void:
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
