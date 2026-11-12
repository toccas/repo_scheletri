extends CanvasLayer
## Pannello IMPOSTAZIONI aperto dall'ingranaggio del menu principale.
##
##  - tre slider per il volume: generale (bus Master), musica (bus Musica) ed
##    effetti (bus Effetti). Si salvano in user://audio.cfg (vedi suoni.gd).
##  - una casella per i codici: il codice sviluppatore (nell'Inspector del nodo
##    Menu, "Codice Sviluppatore") sblocca il dev tool anche sul telefono e nelle
##    build finali: in alto a destra compare il tasto DEV (vedi dev_tool.gd).
##    Lo sblocco resta salvato in user://impostazioni.cfg; "Disattiva" lo toglie.
##    Il codice della Torre infernale (Inspector del nodo Menu, "Codice Torre Infernale")
##    aggiunge la Torre infernale alla collezione: non esce dalle pergamene.
##  - si apre dall'ingranaggio del menu e dal pulsante IMPOSTAZIONI della pausa in partita.
##
## Sul telefono, quando si apre la tastiera il pannello sale da solo per non
## restare coperto.

const Suoni := preload("res://scripts/suoni.gd")
const Portafoglio := preload("res://scripts/portafoglio.gd")
const Collezione := preload("res://scripts/collezione.gd")
const MENU_SCENE := "res://scenes/menu.tscn"

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")

signal closed

## Codice che sblocca il dev tool (maiuscole/minuscole non contano).
var codice_dev := "LEONARDO"
## Codice che sblocca la Torre infernale.
var codice_infernale := "INFERNO"
var theme_override: Theme

var overlay: ColorRect
var center: CenterContainer
var code_edit: LineEdit
var status_label: Label
var dev_row: HBoxContainer
var _shift := 0.0


func _ready() -> void:
	layer = 50
	overlay = ColorRect.new()
	overlay.color = Color(C0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # i tocchi non arrivano al menu sotto
	var th := _make_theme()
	if theme_override:
		th.merge_with(theme_override)
	overlay.theme = th
	add_child(overlay)
	# tocco fuori dalla tastiera: la chiude
	overlay.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and code_edit.has_focus():
			code_edit.release_focus())

	center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(C0, C6, 24))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("IMPOSTAZIONI")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	# --- volumi ---
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	_slider(grid, tr("Volume generale"), "Master")
	_slider(grid, tr("Musica"), Suoni.BUS_MUSICA)
	_slider(grid, tr("Effetti"), Suoni.BUS_EFFETTI)

	box.add_child(HSeparator.new())

	# --- codice ---
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 12)
	var cl := Label.new()
	cl.text = tr("Codice")
	cl.custom_minimum_size = Vector2(190, 0)
	code_row.add_child(cl)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = tr("Scrivi un codice")
	code_edit.max_length = 24
	code_edit.custom_minimum_size = Vector2(260, 48)
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	code_edit.text_submitted.connect(func(_t: String) -> void: _prova_codice())
	code_row.add_child(code_edit)
	var ok := _button(tr("OK"), Vector2(90, 48))
	ok.pressed.connect(_prova_codice)
	code_row.add_child(ok)
	box.add_child(code_row)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(560, 0)
	status_label.add_theme_color_override("font_color", C5)
	box.add_child(status_label)

	dev_row = HBoxContainer.new()
	dev_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dev_row.add_theme_constant_override("separation", 12)
	var dl := Label.new()
	dl.text = tr("Strumenti sviluppatore attivi")
	dl.add_theme_color_override("font_color", C5)
	dev_row.add_child(dl)
	var off := _button(tr("Disattiva"), Vector2(150, 44))
	off.pressed.connect(func() -> void:
		Portafoglio.sblocca_dev(false, get_tree())
		status_label.text = tr("Strumenti sviluppatore disattivati.")
		_aggiorna_dev())
	dev_row.add_child(off)
	box.add_child(dev_row)
	_aggiorna_dev()

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var chiudi := _button(tr("Chiudi"), Vector2(200, 52))
	chiudi.pressed.connect(close)
	buttons.add_child(chiudi)
	box.add_child(buttons)


func _process(delta: float) -> void:
	# con la tastiera del telefono aperta il pannello sale finché la casella del
	# codice è visibile sopra la tastiera
	var target := 0.0
	var kb := DisplayServer.virtual_keyboard_get_height()
	if kb > 0 and code_edit.has_focus():
		var vp := overlay.get_viewport_rect().size
		var win := Vector2(DisplayServer.window_get_size())
		var kb_vp := float(kb) * vp.y / maxf(1.0, win.y)
		var bottom := code_edit.get_global_rect().end.y - _shift + 16.0
		target = maxf(0.0, bottom - (vp.y - kb_vp))
	_shift = lerpf(_shift, target, minf(1.0, delta * 12.0))
	center.position.y = -roundf(_shift)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


## I codici scritti nell'Inspector del nodo Menu (per il pannello aperto dalla pausa in
## partita, che non ha il menu a portata di mano). {"dev": ..., "infernale": ...}
static func codici_dal_menu() -> Dictionary:
	var out := {}
	var ps := load(MENU_SCENE) as PackedScene
	if ps == null:
		return out
	var s := ps.get_state()
	for i in s.get_node_property_count(0):
		var nome := s.get_node_property_name(0, i)
		if nome == "codice_sviluppatore":
			out["dev"] = String(s.get_node_property_value(0, i))
		elif nome == "codice_torre_infernale":
			out["infernale"] = String(s.get_node_property_value(0, i))
		elif nome == "email_feedback":  # per mandare il report dev
			out["email"] = String(s.get_node_property_value(0, i))
		elif nome == "url_invio_feedback":
			out["url"] = String(s.get_node_property_value(0, i))
		elif nome == "versione_gioco":
			out["versione"] = String(s.get_node_property_value(0, i))
	return out


func _prova_codice() -> void:
	var t := code_edit.text.strip_edges().trim_suffix(".").to_upper()
	if t == "":
		return
	if codice_infernale.strip_edges() != "" and t == codice_infernale.strip_edges().to_upper():
		if Collezione.sblocca_codice("infernale"):
			status_label.text = tr("Hai sbloccato la TORRE INFERNALE! Mettila nella squadra in preparazione.")
			Suoni.play("livello")
		else:
			status_label.text = tr("La Torre infernale è già nella tua collezione.")
	elif codice_dev.strip_edges() != "" and t == codice_dev.strip_edges().to_upper():
		if Portafoglio.dev_sbloccato():
			status_label.text = tr("Strumenti sviluppatore già attivi: tasto DEV in alto a destra.")
		else:
			Portafoglio.sblocca_dev(true, get_tree())
			status_label.text = tr("Strumenti sviluppatore attivati: tasto DEV in alto a destra.")
			Suoni.play("conferma")
	else:
		status_label.text = tr("Codice non valido.")
		Suoni.play("errore")
	code_edit.text = ""
	code_edit.release_focus()
	_aggiorna_dev()


func _aggiorna_dev() -> void:
	dev_row.visible = Portafoglio.dev_sbloccato()


## Riga dello slider: nome, slider 0-100, valore in %.
func _slider(grid: GridContainer, nome: String, bus: String) -> void:
	var l := Label.new()
	l.text = nome
	l.custom_minimum_size = Vector2(190, 0)
	grid.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = roundf(Suoni.volume(bus) * 100.0)
	s.custom_minimum_size = Vector2(300, 44)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	grid.add_child(s)
	var v := Label.new()
	v.custom_minimum_size = Vector2(70, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.text = "%d%%" % int(s.value)
	grid.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = "%d%%" % int(x)
		Suoni.imposta_volume(bus, x / 100.0, false))
	# un tocco sul binario sposta il cursore senza value_changed: si aggiorna al rilascio
	s.drag_ended.connect(func(_changed: bool) -> void:
		v.text = "%d%%" % int(s.value)
		Suoni.imposta_volume(bus, s.value / 100.0, true)
		if bus != Suoni.BUS_MUSICA:
			Suoni.play("click"))  # anteprima del volume degli effetti


# --- Stile (scala di grigi, come "Bug e consigli") ---------------------------------

func _box(bg: Color, border: Color, margin: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_content_margin_all(margin)
	return sb


func _grabber(col: Color) -> ImageTexture:
	var img := Image.create(22, 34, false, Image.FORMAT_RGBA8)
	img.fill(C0)
	img.fill_rect(Rect2i(2, 2, 18, 30), col)
	img.fill_rect(Rect2i(4, 4, 14, 2), C6)
	return ImageTexture.create_from_image(img)


func _make_theme() -> Theme:
	var th := Theme.new()
	th.set_stylebox("normal", "Button", _box(C1, C4))
	th.set_stylebox("hover", "Button", _box(C2, C5))
	th.set_stylebox("pressed", "Button", _box(C3, C6))
	th.set_stylebox("hover_pressed", "Button", _box(C3, C6))
	th.set_stylebox("disabled", "Button", _box(C0, C2))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", C5)
	th.set_color("font_hover_color", "Button", C6)
	th.set_color("font_pressed_color", "Button", C6)
	th.set_color("font_hover_pressed_color", "Button", C6)
	th.set_color("font_color", "Label", C6)
	th.set_stylebox("normal", "LineEdit", _box(C1, C3, 10))
	th.set_stylebox("focus", "LineEdit", _box(C1, C5, 10))
	th.set_color("font_color", "LineEdit", C6)
	th.set_color("font_placeholder_color", "LineEdit", C4)
	th.set_color("caret_color", "LineEdit", C6)
	# slider con binario spesso e cursore grande, comodi da trascinare col dito
	var track := StyleBoxFlat.new()
	track.bg_color = C1
	track.border_color = C3
	track.set_border_width_all(2)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	th.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = C4
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	th.set_stylebox("grabber_area", "HSlider", fill)
	var fill_hot := fill.duplicate() as StyleBoxFlat
	fill_hot.bg_color = C5
	th.set_stylebox("grabber_area_highlight", "HSlider", fill_hot)
	th.set_icon("grabber", "HSlider", _grabber(C5))
	th.set_icon("grabber_highlight", "HSlider", _grabber(C6))
	th.set_stylebox("separator", "HSeparator", _line())
	return th


func _line() -> StyleBoxLine:
	var l := StyleBoxLine.new()
	l.color = C3
	l.thickness = 2
	return l


func _button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	return b
