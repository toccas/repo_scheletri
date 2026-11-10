extends Node
## Riproduce gli effetti sonori. Da qualsiasi script:
##     const Suoni := preload("res://scripts/suoni.gd")
##     Suoni.play("spada")
## I suoni si configurano nell'Inspector: apri assets/suoni/libreria_suoni.tres.
##
## Il nodo "Suoni" si crea da solo nella radice del gioco la prima volta che
## serve e resta attivo cambiando scena. Tutti i Button di Godot fanno "click"
## in automatico quando li premi.
## Per non coprire tutto quando combattono decine di unità, ogni suono ha un
## intervallo minimo e un numero massimo di copie insieme (vedi VoceSuono).
##
## Volumi: tre bus, regolati dagli slider del pannello Impostazioni.
##   "Master"  volume generale
##   "Musica"  ogni AudioStreamPlayer / AudioStreamPlayer2D che metti in una scena
##             (sul bus "Master") viene spostato qui da solo
##   "Effetti" gli effetti sonori suonati da questo nodo
##     Suoni.volume("Musica")  -> 0.0 .. 1.0
##     Suoni.imposta_volume("Musica", 0.5)
## I volumi si salvano in user://audio.cfg e restano anche chiudendo il gioco.
## Se vuoi che un player resti sul Master, mettigli un bus diverso da "Master".

const LIB_PATH := "res://assets/suoni/libreria_suoni.tres"
const SELF_PATH := "res://scripts/suoni.gd"
const VOICES := 24  # suoni contemporanei in tutto
const BUS_MUSICA := "Musica"
const BUS_EFFETTI := "Effetti"
const CFG_AUDIO := "user://audio.cfg"

static var _inst: Node = null
static var _volumi: Dictionary = {}  # bus -> 0..1 (letti da audio.cfg)

var lib: LibreriaSuoni
var players: Array[AudioStreamPlayer] = []
var playing_id: Array[String] = []
var started_at: Array[float] = []
var last_play: Dictionary = {}


## Suona l'effetto `id` (il nome della voce nella libreria).
## `pitch` > 1 = più acuto, `vol_db` si somma al volume della voce.
static func play(id: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if Engine.is_editor_hint():
		return
	var n := _instance()
	if n != null and n.is_inside_tree():
		n._play(id, pitch, vol_db)


## Crea il nodo se non c'è ancora (chiamalo nel _ready di una scena per
## avere già i suoni dal primo clic).
static func install() -> void:
	if not Engine.is_editor_hint():
		_instance()


static func _instance() -> Node:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_inst = tree.root.get_node_or_null("Suoni")
	if _inst == null:
		_inst = load(SELF_PATH).new()
		_inst.name = "Suoni"
		tree.root.add_child.call_deferred(_inst)
	return _inst


## Volume del bus ("Master", "Musica" o "Effetti") da 0.0 a 1.0.
static func volume(bus: String) -> float:
	_prepara_bus()
	return float(_volumi.get(bus, 1.0))


## Cambia il volume del bus (0.0 = muto, 1.0 = pieno). `salva` = scrivi su audio.cfg.
static func imposta_volume(bus: String, v: float, salva: bool = true) -> void:
	_prepara_bus()
	v = clampf(v, 0.0, 1.0)
	_volumi[bus] = v
	_applica(bus)
	if salva:
		var cfg := ConfigFile.new()
		cfg.load(CFG_AUDIO)
		cfg.set_value("audio", "volume_" + bus, v)
		cfg.save(CFG_AUDIO)


## Crea i bus "Musica" ed "Effetti" (mandano al Master) e applica i volumi salvati.
static func _prepara_bus() -> void:
	if not _volumi.is_empty() and AudioServer.get_bus_index(BUS_EFFETTI) >= 0:
		return
	for b: String in [BUS_MUSICA, BUS_EFFETTI]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	var cfg := ConfigFile.new()
	cfg.load(CFG_AUDIO)
	# vecchio pulsante "musica spenta"
	var musica := 0.0 if bool(cfg.get_value("audio", "musica_muta", false)) else 1.0
	_volumi = {
		"Master": float(cfg.get_value("audio", "volume_Master", 1.0)),
		BUS_MUSICA: float(cfg.get_value("audio", "volume_" + BUS_MUSICA, musica)),
		BUS_EFFETTI: float(cfg.get_value("audio", "volume_" + BUS_EFFETTI, 1.0)),
	}
	for b: String in _volumi:
		_applica(b)


static func _applica(bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var v := float(_volumi.get(bus, 1.0))
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prepara_bus()
	if ResourceLoader.exists(LIB_PATH):
		lib = load(LIB_PATH) as LibreriaSuoni
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_EFFETTI
		add_child(p)
		players.append(p)
		playing_id.append("")
		started_at.append(0.0)
	# click automatico su tutti i Button (quelli che ci sono già e quelli nuovi)
	get_tree().node_added.connect(_on_node_added)
	_scan(get_tree().root)


func _scan(n: Node) -> void:
	_on_node_added(n)
	for c in n.get_children():
		_scan(c)


func _on_node_added(n: Node) -> void:
	# la musica delle scene va sul bus "Musica" (i player degli effetti sono figli di questo nodo)
	if (n is AudioStreamPlayer or n is AudioStreamPlayer2D or n is AudioStreamPlayer3D) and n.get_parent() != self:
		if String(n.get("bus")) == "Master":
			n.set("bus", BUS_MUSICA)
	if n is BaseButton and not n.has_meta("suono_click"):
		n.set_meta("suono_click", true)
		(n as BaseButton).pressed.connect(func() -> void: _play("click", 1.0, 0.0))


func _play(id: String, pitch: float, vol_db: float) -> void:
	if lib == null or lib.muto:
		return
	var v := lib.get(id) as VoceSuono
	if v == null or v.suono == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_play.get(id, -10.0)) < v.intervallo_minimo:
		return
	var same := 0
	var free := -1
	var oldest := 0
	for i in players.size():
		if players[i].playing:
			if playing_id[i] == id:
				same += 1
			if started_at[i] < started_at[oldest]:
				oldest = i
		elif free < 0:
			free = i
	if same >= v.voci_massime:
		return
	var k := free if free >= 0 else oldest
	last_play[id] = now
	var p := players[k]
	p.stream = v.suono
	p.volume_db = lib.volume_generale + v.volume_db + vol_db
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-v.variazione_tono, v.variazione_tono)))
	playing_id[k] = id
	started_at[k] = now
	p.play()
