extends CanvasLayer
## Pannello "Bug e consigli" aperto dal menu principale.
##
## Due modi di invio, scelti dalle impostazioni del nodo Menu nell'Inspector:
##  1) INVIO DIRETTO: se "Url Invio Feedback" è compilato (per esempio un modulo
##     Formspree: https://formspree.io/f/xxxxxxx) il gioco manda il messaggio da
##     solo e ti arriva per email. Su Android serve il permesso Internet.
##  2) APP EMAIL: altrimenti si apre l'app email del giocatore con destinatario,
##     oggetto e testo già compilati; il giocatore deve solo premere Invia.
## Al messaggio vengono aggiunte in automatico versione, sistema e progressi.

const Research := preload("res://scripts/research_data.gd")

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")
const MAX_CHARS := 2000

signal closed

var email_to := ""
var send_url := ""
var game_version := ""
var theme_override: Theme

var overlay: ColorRect
var bug_button: Button
var idea_button: Button
var text_edit: TextEdit
var contact_edit: LineEdit
var status_label: Label
var send_button: Button
var mail_button: Button
var http: HTTPRequest
var _close_timer := 0.0


func _ready() -> void:
	layer = 50
	overlay = ColorRect.new()
	overlay.color = Color(C0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # i clic non arrivano al menu sotto
	# stile in scala di grigi del gioco; il tema scelto nell'Inspector (per esempio
	# il font) si aggiunge sopra
	var th := _make_theme()
	if theme_override:
		th.merge_with(theme_override)
	overlay.theme = th
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(C0, C6, 22))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "BUG E CONSIGLI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Hai trovato un problema o hai un'idea? Scrivimi!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", C5)
	box.add_child(sub)

	# tipo di messaggio
	var kinds := HBoxContainer.new()
	kinds.alignment = BoxContainer.ALIGNMENT_CENTER
	kinds.add_theme_constant_override("separation", 12)
	var group := ButtonGroup.new()
	bug_button = _toggle("Bug", group)
	idea_button = _toggle("Consiglio", group)
	bug_button.button_pressed = true
	kinds.add_child(bug_button)
	kinds.add_child(idea_button)
	box.add_child(kinds)

	text_edit = TextEdit.new()
	text_edit.placeholder_text = "Cosa è successo? Cosa stavi facendo? (oppure: la tua idea)"
	text_edit.custom_minimum_size = Vector2(560, 170)
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.text_changed.connect(_on_text_changed)
	box.add_child(text_edit)

	contact_edit = LineEdit.new()
	contact_edit.placeholder_text = "La tua email (facoltativa, se vuoi una risposta)"
	contact_edit.max_length = 120
	box.add_child(contact_edit)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(560, 0)
	status_label.add_theme_color_override("font_color", C5)
	box.add_child(status_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var cancel := _button("Chiudi")
	cancel.pressed.connect(close)
	mail_button = _button("Apri email")
	mail_button.pressed.connect(_open_mail)
	mail_button.visible = false
	send_button = _button("Invia")
	send_button.pressed.connect(_send)
	buttons.add_child(cancel)
	buttons.add_child(mail_button)
	buttons.add_child(send_button)
	box.add_child(buttons)

	http = HTTPRequest.new()
	http.timeout = 15.0
	http.request_completed.connect(_on_request_completed)
	add_child(http)

	if send_url == "":
		status_label.text = "Premendo Invia si apre la tua app email con il messaggio pronto."
	text_edit.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if _close_timer > 0.0:
		_close_timer -= delta
		if _close_timer <= 0.0:
			close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


# --- Invio -----------------------------------------------------------------

func _kind() -> String:
	return "Bug" if bug_button.button_pressed else "Consiglio"


func _subject() -> String:
	return "[Gioco Scheletri] %s" % _kind()


func _system_info() -> String:
	var st := Research.load_state()
	var v := Engine.get_version_info()
	return "Versione gioco: %s\nSistema: %s %s (%s)\nGodot: %s\nRecord: ondata %d · Punti: %d" % [
		game_version, OS.get_name(), OS.get_version(), OS.get_model_name(),
		v["string"], st["best"], st["points"]]


func _full_body() -> String:
	var body := text_edit.text.strip_edges()
	var contact := contact_edit.text.strip_edges()
	if contact != "":
		body += "\n\nContatto: " + contact
	return body + "\n\n---\n" + _system_info()


func _on_text_changed() -> void:
	if text_edit.text.length() > MAX_CHARS:
		text_edit.text = text_edit.text.substr(0, MAX_CHARS)
		text_edit.set_caret_column(text_edit.get_line(text_edit.get_line_count() - 1).length())
		text_edit.set_caret_line(text_edit.get_line_count() - 1)


func _send() -> void:
	if text_edit.text.strip_edges().length() < 5:
		status_label.text = "Scrivi almeno qualche parola prima di inviare."
		return
	if send_url == "":
		_open_mail()
		return
	var data := {
		"_subject": _subject(),
		"tipo": _kind(),
		"messaggio": text_edit.text.strip_edges(),
		"email": contact_edit.text.strip_edges(),
		"info": _system_info(),
	}
	var headers := ["Content-Type: application/json", "Accept: application/json"]
	var err := http.request(send_url, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	if err != OK:
		_failed("non riesco a contattare il server (errore %d)" % err)
		return
	send_button.disabled = true
	status_label.text = "Invio in corso..."


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	send_button.disabled = false
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		status_label.text = "Grazie! Il tuo messaggio è stato inviato."
		send_button.disabled = true
		_close_timer = 2.0
	elif result != HTTPRequest.RESULT_SUCCESS:
		_failed("connessione non riuscita: controlla Internet")
	else:
		_failed("il server ha risposto con l'errore %d" % code)


func _failed(reason: String) -> void:
	status_label.text = "Invio non riuscito: %s. Puoi mandarlo per email con il pulsante qui sotto." % reason
	mail_button.visible = email_to != ""


func _open_mail() -> void:
	if email_to == "" or email_to.contains("esempio"):
		status_label.text = "Indirizzo email per i feedback non ancora configurato."
		push_warning("Imposta 'Email Feedback' nell'Inspector del nodo Menu.")
		return
	var url := "mailto:%s?subject=%s&body=%s" % [email_to, _subject().uri_encode(), _full_body().uri_encode()]
	var err := OS.shell_open(url)
	if err == OK:
		status_label.text = "Si è aperta la tua app email: premi Invia lì per mandarmi il messaggio."
	else:
		status_label.text = "Non trovo un'app email. Scrivimi a: %s" % email_to


# --- Stile -------------------------------------------------------------------

func _box(bg: Color, border: Color, margin: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_content_margin_all(margin)
	return sb


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
	th.set_color("font_disabled_color", "Button", C3)
	th.set_color("font_color", "Label", C6)
	for t in ["TextEdit", "LineEdit"]:
		th.set_stylebox("normal", t, _box(C1, C3, 8))
		th.set_stylebox("focus", t, _box(C1, C5, 8))
		th.set_color("font_color", t, C6)
		th.set_color("font_placeholder_color", t, C4)
		th.set_color("caret_color", t, C6)
	return th


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 42)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _toggle(text: String, group: ButtonGroup) -> Button:
	var b := _button(text)
	b.toggle_mode = true
	b.button_group = group
	return b
