extends CanvasLayer
## PANNELLO DEV: sblocca quello che vuoi mentre provi il gioco.
## Si apre e si chiude con Ctrl + Shift + D (solo nelle build di prova, vedi dev_tool.gd).
## Mentre è aperto il gioco è in pausa.
##
## Schede:
##   UNITÀ     quali unità hai nella collezione e a che rango
##   RICERCHE  livello di ogni ricerca
##   RISORSE   pergamene, monete d'osso, punti, VIP, fondi infiniti, tutorial
##   LIVELLI   sblocca/completa i livelli e gioca subito quello che vuoi
##   PARTITA   (solo in battaglia) vinci l'ondata, salta a un'ondata, livelli, torre invincibile
## Le modifiche si salvano subito; "Ricarica scena" le fa vedere nella scena aperta.

const Data := preload("res://scripts/game_data.gd")
const Collezione := preload("res://scripts/collezione.gd")
const Research := preload("res://scripts/research_data.gd")
const Portafoglio := preload("res://scripts/portafoglio.gd")
const Dialoghi := preload("res://scripts/dialoghi.gd")
const Lingua := preload("res://scripts/lingua.gd")
const Livelli := preload("res://scripts/livelli.gd")
const SAVE_PATH := "user://progressi.cfg"

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")

signal chiuso

var avevo_messo_pausa := false
var info: Label
var reset_armato := false
var tabs: TabContainer


func _ready() -> void:
	layer = 127
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not get_tree().paused:
		get_tree().paused = true
		avevo_messo_pausa = true
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var panel := PanelContainer.new()
	panel.theme = _tema()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(980, 600)
	panel.position = Vector2(-490, -300)
	bg.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = "MODALITÀ DEV  ·  Ctrl+Shift+D per chiudere"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_btn("Ricarica scena", _ricarica))
	head.add_child(_btn("Chiudi", chiudi))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	tabs.add_child(_tab_unita())
	tabs.add_child(_tab_ricerche())
	tabs.add_child(_tab_risorse())
	tabs.add_child(_tab_livelli())
	if _partita() != null:
		tabs.add_child(_tab_partita())
		tabs.current_tab = tabs.get_tab_count() - 1
	elif get_tree().current_scene and get_tree().current_scene.has_method("_gioca"):
		tabs.current_tab = 3  # dalla scelta del livello apre LIVELLI
	info = Label.new()
	info.add_theme_color_override("font_color", C5)
	box.add_child(info)
	_msg("Le modifiche si salvano subito. Premi \"Ricarica scena\" per vederle nella scena aperta.")


func chiudi() -> void:
	if avevo_messo_pausa:
		get_tree().paused = false
	chiuso.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		chiudi()


func _msg(s: String) -> void:
	if info:
		info.text = s


func _ricarica() -> void:
	chiudi()
	get_tree().reload_current_scene()


## La scena della battaglia, se è quella aperta.
func _partita() -> Node:
	var sc := get_tree().current_scene
	return sc if sc != null and sc.has_method("damage_tower") else null


# --- Unità -----------------------------------------------------------------------

func _tab_unita() -> Control:
	var page := VBoxContainer.new()
	page.name = "UNITÀ"
	var row := HBoxContainer.new()
	page.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	var st := Collezione.load_state()
	var spins := {}
	for k in Data.ALLY_ORDER:
		var h := HBoxContainer.new()
		var cb := CheckBox.new()
		cb.text = Data.nome_breve(k)
		cb.custom_minimum_size.x = 150
		var base: bool = k in Data.STARTING_UNITS
		cb.button_pressed = st["owned"].has(k)
		cb.disabled = base  # le unità di base ci sono sempre
		var sp := SpinBox.new()
		sp.min_value = 1
		sp.max_value = Data.MAX_RANK
		sp.value = st["owned"].get(k, 1)
		sp.prefix = "R"
		sp.tooltip_text = "Rango (ogni rango: +10% vita e danno)"
		spins[k] = [cb, sp]
		cb.toggled.connect(func(on: bool) -> void: _set_unita(k, on, int(sp.value)))
		sp.value_changed.connect(func(v: float) -> void:
			if cb.button_pressed:
				_set_unita(k, true, int(v)))
		h.add_child(cb)
		h.add_child(sp)
		grid.add_child(h)
	row.add_child(_btn("Tutte le unità", func() -> void:
		for k in spins:
			spins[k][0].button_pressed = true
		_msg("Collezione completa.")))
	row.add_child(_btn("Tutte al rango max", func() -> void:
		for k in spins:
			spins[k][0].button_pressed = true
			spins[k][1].value = Data.MAX_RANK
		_msg("Tutte le unità al rango %d." % Data.MAX_RANK)))
	row.add_child(_btn("Solo quelle di base", func() -> void:
		for k in spins:
			if not k in Data.STARTING_UNITS:
				spins[k][0].button_pressed = false
		_msg("Collezione riportata alle unità di base.")))
	page.add_child(grid)
	return page


func _set_unita(k: String, on: bool, rank: int) -> void:
	var st := Collezione.load_state()
	if on:
		st["owned"][k] = clampi(rank, 1, Data.MAX_RANK)
	elif not k in Data.STARTING_UNITS:
		st["owned"].erase(k)
		st["squad"].erase(k)
	Collezione.save_state(st)


# --- Ricerche ----------------------------------------------------------------------

func _tab_ricerche() -> Control:
	var page := VBoxContainer.new()
	page.name = "RICERCHE"
	var row := HBoxContainer.new()
	page.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	var st := Research.load_state()
	var spins := {}
	for id in Research.NODES:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = tr(Research.NODES[id]["name"])
		l.custom_minimum_size.x = 300
		var sp := SpinBox.new()
		sp.min_value = 0
		sp.max_value = Research.max_level(id)
		sp.value = Research.level(st, id)
		sp.suffix = "/ %d" % Research.max_level(id)
		sp.value_changed.connect(func(v: float) -> void:
			var s := Research.load_state()
			s["levels"][id] = int(v)
			Research.save_state(s))
		spins[id] = sp
		h.add_child(l)
		h.add_child(sp)
		grid.add_child(h)
	row.add_child(_btn("Tutte al massimo", func() -> void:
		for id in spins:
			spins[id].value = Research.max_level(id)
		_msg("Tutte le ricerche al massimo (magie comprese).")))
	row.add_child(_btn("Azzera (senza rimborso)", func() -> void:
		for id in spins:
			spins[id].value = 0
		_msg("Ricerche azzerate.")))
	page.add_child(grid)
	return page


# --- Risorse -------------------------------------------------------------------------

func _tab_risorse() -> Control:
	var page := VBoxContainer.new()
	page.name = "RISORSE"
	page.add_theme_constant_override("separation", 10)
	var col := Collezione.load_state()
	var res := Research.load_state()
	var wal := Portafoglio.load_state()
	page.add_child(_numero("Pergamene", col["scrolls"], 0, 9999, func(v: int) -> void:
		var s := Collezione.load_state()
		s["scrolls"] = v
		Collezione.save_state(s), [10, 100]))
	page.add_child(_numero("Monete d'osso", wal["monete"], 0, 9999999, func(v: int) -> void:
		var s := Portafoglio.load_state()
		s["monete"] = v
		Portafoglio.save_state(s), [1000, 10000]))
	page.add_child(_numero("Punti ricerca", res["points"], 0, 999999, func(v: int) -> void:
		var s := Research.load_state()
		s["points"] = v
		Research.save_state(s), [50, 500]))
	var vip := CheckBox.new()
	vip.text = "Pacchetto VIP (velocità x3)"
	vip.button_pressed = wal["vip"]
	vip.toggled.connect(func(on: bool) -> void:
		var s := Portafoglio.load_state()
		s["vip"] = on
		if not on:
			s["acquistati"].erase("vip")
		Portafoglio.save_state(s))
	page.add_child(vip)
	var inf := CheckBox.new()
	inf.text = "Fondi infiniti nel negozio (anche Ctrl+Shift+M)"
	inf.button_pressed = wal["dev_infiniti"]
	inf.toggled.connect(func(on: bool) -> void:
		Portafoglio.set_dev_infinite(on)
		var dt := get_tree().root.get_node_or_null("DevTool")
		if dt:
			dt.active = on)
	page.add_child(inf)
	var row := HBoxContainer.new()
	page.add_child(row)
	row.add_child(_btn("Rivedi lingua e dialoghi", func() -> void:
		Dialoghi.azzera_tutti()
		Lingua.dimentica_scelta()
		_msg("Primo avvio azzerato: torna al menu per rivedere scelta della lingua e dialoghi.")))
	var reset := _btn("CANCELLA TUTTI I PROGRESSI", Callable())
	reset.pressed.connect(func() -> void:
		if not reset_armato:
			reset_armato = true
			reset.text = "SICURO? CLICCA ANCORA"
			return
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		reset.text = "CANCELLA TUTTI I PROGRESSI"
		reset_armato = false
		_msg("Salvataggio cancellato: ricarica la scena (o torna al menu) per ripartire da zero."))
	row.add_child(reset)
	return page


## Riga "nome [numero] [+a] [+b]".
func _numero(nome: String, val: int, lo: int, hi: int, on_change: Callable, piu: Array) -> Control:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = nome
	l.custom_minimum_size.x = 220
	h.add_child(l)
	var sp := SpinBox.new()
	sp.min_value = lo
	sp.max_value = hi
	sp.value = val
	sp.custom_minimum_size.x = 180
	sp.value_changed.connect(func(v: float) -> void: on_change.call(int(v)))
	h.add_child(sp)
	for p in piu:
		h.add_child(_btn("+%d" % p, func() -> void: sp.value += p))
	return h


# --- Partita (solo in battaglia) ----------------------------------------------------------

func _tab_partita() -> Control:
	var m := _partita()
	var page := VBoxContainer.new()
	page.name = "PARTITA"
	page.add_theme_constant_override("separation", 10)
	var r1 := HBoxContainer.new()
	page.add_child(r1)
	r1.add_child(_btn("Vinci l'ondata (uccidi tutti)", func() -> void:
		m.spawn_queue.clear()
		_uccidi_tutti(m)
		_msg("Nemici eliminati.")))
	var wave_sp := SpinBox.new()
	wave_sp.min_value = 1
	wave_sp.max_value = 999
	wave_sp.value = maxi(1, m.wave + 1)
	wave_sp.prefix = "ondata"
	wave_sp.custom_minimum_size.x = 170
	r1.add_child(wave_sp)
	r1.add_child(_btn("Salta a questa ondata", func() -> void:
		var n := int(wave_sp.value)
		m.spawn_queue.clear()
		_uccidi_tutti(m)
		m.wave = n - 1
		m.wave_running = false
		m.next_wave_timer = 0.2
		if m.state == m.State.DEPLOY:
			m._on_start_pressed()
		_msg("La prossima ondata sarà la %d (chiudi il pannello per farla partire)." % n)))
	var inf_cb := CheckBox.new()
	inf_cb.text = "Modalità infinita"
	inf_cb.focus_mode = Control.FOCUS_NONE
	inf_cb.button_pressed = m.infinita
	inf_cb.toggled.connect(func(on: bool) -> void:
		m.infinita = on
		_msg("Modalità infinita %s per questa partita." % ("attiva" if on else "spenta")))
	r1.add_child(inf_cb)
	var r2 := HBoxContainer.new()
	page.add_child(r2)
	r2.add_child(_btn("+1 livello del necromante", func() -> void:
		m.pending_levelups += 1
		m.necro_level += 1
		m.necro_xp_next = Data.xp_to_next(m.necro_level)
		m.call_deferred("_open_level_up")
		_msg("Level up in arrivo: chiudi il pannello e scegli il dono.")))
	r2.add_child(_btn("+5 squadre schierabili", func() -> void:
		m.max_deploy += 5
		_msg("Ora puoi schierare %d squadre." % m.max_deploy)))
	r2.add_child(_btn("Sblocca le 3 magie", func() -> void:
		m.unlocked_abilities = Data.ABILITY_ORDER.duplicate()
		for k in m.ability_cd:
			m.ability_cd[k] = 0.0
		_msg("Palla di fuoco, area curativa e saetta sbloccate (per questa partita).")))
	var r3 := HBoxContainer.new()
	page.add_child(r3)
	r3.add_child(_btn("Ripara la torre", func() -> void:
		m.tower_hp = m.tower_max_hp
		_msg("Torre riparata.")))
	var inv := CheckBox.new()
	inv.text = "Torre invincibile"
	inv.button_pressed = m.dev_invincibile
	inv.toggled.connect(func(on: bool) -> void: m.dev_invincibile = on)
	r3.add_child(inv)
	var r4 := HBoxContainer.new()
	page.add_child(r4)
	var x5 := CheckBox.new()
	x5.text = "Velocità x5 nel pulsante (x1 > x2 > x3 > x5)"
	x5.button_pressed = m.dev_x5
	x5.toggled.connect(func(on: bool) -> void:
		m.dev_x5 = on
		var cfg := ConfigFile.new()
		cfg.load(SAVE_PATH)
		cfg.set_value("dev", "velocita_x5", on)
		cfg.save(SAVE_PATH)
		if not on and Engine.time_scale > 3.0:
			Engine.time_scale = 1.0)
	r4.add_child(x5)
	for sp in [1, 2, 3, 5]:
		r4.add_child(_btn("x%d" % sp, func() -> void:
			if sp == 5:
				m.dev_x5 = true
				x5.button_pressed = true
			Engine.time_scale = float(sp)
			_msg("Velocità x%d: si vede appena chiudi il pannello." % sp)))
	var nocd := CheckBox.new()
	nocd.text = "Magie senza ricarica"
	nocd.button_pressed = m.dev_senza_ricarica
	nocd.toggled.connect(func(on: bool) -> void: m.dev_senza_ricarica = on)
	r3.add_child(nocd)
	return page


func _uccidi_tutti(m: Node) -> void:
	for u in m.enemies_root.get_children():
		if not u.dead:
			u.take_damage(u.hp * 100.0 + 99999.0)


# --- Livelli --------------------------------------------------------------------------

func _tab_livelli() -> Control:
	var page := VBoxContainer.new()
	page.name = "LIVELLI"
	page.add_theme_constant_override("separation", 10)
	var lista := Livelli.elenco()
	var checks: Array[CheckBox] = []
	var row := HBoxContainer.new()
	page.add_child(row)
	row.add_child(_btn("Sblocca tutti", func() -> void:
		for c in checks:
			c.button_pressed = true
		_msg("Tutti i livelli completati: ora sono tutti giocabili.")))
	row.add_child(_btn("Blocca tutti", func() -> void:
		for c in checks:
			c.button_pressed = false
		_msg("Livelli di nuovo bloccati (resta giocabile solo il primo).")))
	row.add_child(_btn("Azzera classifiche", func() -> void:
		Livelli.azzera_classifica()
		for f in page.get_meta("aggiorna", []):
			(f as Callable).call()
		_msg("Classifiche della modalità infinita azzerate.")))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	page.add_child(grid)
	for i in lista.size():
		var info: InfoLivello = lista[i]
		var l := Label.new()
		l.text = "%d. %s" % [i + 1, tr(info.nome)]
		l.custom_minimum_size.x = 270
		grid.add_child(l)
		var stato := Label.new()
		stato.custom_minimum_size.x = 250
		stato.add_theme_color_override("font_color", C5)
		var aggiorna := func() -> void:
			stato.text = ("sbloccato" if Livelli.sbloccato(lista, i) else "bloccato") + "  ·  record %d  ·  inf %d" % [Livelli.record(info.id), Livelli.record_infinito(info.id)]
		aggiorna.call()
		var cb := CheckBox.new()
		cb.text = "completato"
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = Livelli.finito(info.id)
		cb.toggled.connect(func(on: bool) -> void:
			Livelli.segna_finito(info.id, on)
			for f in page.get_meta("aggiorna", []):
				(f as Callable).call())
		checks.append(cb)
		grid.add_child(cb)
		grid.add_child(stato)
		var gioca := HBoxContainer.new()
		for inf: bool in [false, true]:
			gioca.add_child(_btn("Gioca infinita" if inf else "Gioca", func() -> void:
				if info.scena == "" or not ResourceLoader.exists(info.scena):
					_msg("Scena del livello non trovata: " + info.scena)
					return
				Livelli.scegli(info, inf)
				chiudi()
				get_tree().change_scene_to_file(info.scena)))
		grid.add_child(gioca)
		var fs: Array = page.get_meta("aggiorna", [])
		fs.append(aggiorna)
		page.set_meta("aggiorna", fs)
	var nota := Label.new()
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_color_override("font_color", C4)
	nota.text = "\"completato\" sblocca il livello dopo e la sua modalità infinita. \"Gioca\" / \"Gioca infinita\" partono subito con la squadra salvata (senza preparazione). I livelli si modificano in livelli/elenco_livelli.tres e scenes/livelli/."
	page.add_child(nota)
	return page


# --- Aspetto ---------------------------------------------------------------------------

func _btn(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if fn.is_valid():
		b.pressed.connect(fn)
	return b


func _tema() -> Theme:
	var th := Theme.new()
	if ResourceLoader.exists("res://tema.tres"):
		var base := load("res://tema.tres") as Theme
		if base and base.default_font:
			th.default_font = base.default_font
	th.default_font_size = 16
	var box := func(bg: Color, border: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = border
		s.set_border_width_all(2)
		s.set_content_margin_all(8)
		return s
	th.set_stylebox("panel", "PanelContainer", box.call(C0, C6))
	th.set_stylebox("normal", "Button", box.call(C1, C4))
	th.set_stylebox("hover", "Button", box.call(C2, C5))
	th.set_stylebox("pressed", "Button", box.call(C2, C6))
	th.set_color("font_color", "Label", C6)
	return th
