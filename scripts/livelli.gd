extends RefCounted
## Progressi dei livelli (in user://progressi.cfg, sezione [livelli]):
##   scelto        id del livello scelto nella schermata dei livelli
##   scena         la sua scena (quella che parte dopo la preparazione)
##   finito_<id>   true quando hai superato tutte le ondate di quel livello
##   record_<id>   ondata migliore raggiunta in quel livello
##   infinita      true se l'ultima scelta è la modalità infinita
## e nella sezione [classifica]: per ogni livello le 10 corse infinite migliori.

const SAVE_PATH := "user://progressi.cfg"
const ELENCO_PATH := "res://livelli/elenco_livelli.tres"
const SCENA_BASE := "res://scenes/main.tscn"


static func elenco() -> Array[InfoLivello]:
	var e := load(ELENCO_PATH) as ElencoLivelli
	return e.livelli if e != null else ([] as Array[InfoLivello])


static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return cfg


## La scena del livello da giocare (il cimitero se non hai mai scelto).
static func scena_scelta() -> String:
	var s: String = _cfg().get_value("livelli", "scena", SCENA_BASE)
	return s if ResourceLoader.exists(s) else SCENA_BASE


static func scegli(info: InfoLivello, infinita: bool = false) -> void:
	var cfg := _cfg()
	cfg.set_value("livelli", "scelto", info.id)
	cfg.set_value("livelli", "scena", info.scena)
	cfg.set_value("livelli", "infinita", infinita)
	cfg.save(SAVE_PATH)


## Cambia solo la modalità (es. "Continua in modalità infinita" dopo la vittoria).
static func scegli_modalita(infinita: bool, id: String = "", scena: String = "") -> void:
	var cfg := _cfg()
	cfg.set_value("livelli", "infinita", infinita)
	if id != "":
		cfg.set_value("livelli", "scelto", id)
	if scena != "":
		cfg.set_value("livelli", "scena", scena)
	cfg.save(SAVE_PATH)


## L'ultima scelta è la modalità infinita? (si gioca solo nei livelli finiti)
static func modalita_infinita() -> bool:
	return bool(_cfg().get_value("livelli", "infinita", false))


static func scelto() -> String:
	return String(_cfg().get_value("livelli", "scelto", ""))


static func finito(id: String) -> bool:
	return bool(_cfg().get_value("livelli", "finito_" + id, false))


static func segna_finito(id: String, on: bool = true) -> void:
	var cfg := _cfg()
	cfg.set_value("livelli", "finito_" + id, on)
	cfg.save(SAVE_PATH)


static func record(id: String) -> int:
	return int(_cfg().get_value("livelli", "record_" + id, 0))


static func salva_record(id: String, ondata: int) -> void:
	var cfg := _cfg()
	if ondata > int(cfg.get_value("livelli", "record_" + id, 0)):
		cfg.set_value("livelli", "record_" + id, ondata)
		cfg.save(SAVE_PATH)


## Il livello i dell'elenco è giocabile? Il primo sempre, gli altri se hai finito quello prima.
static func sbloccato(lista: Array, i: int) -> bool:
	if i <= 0:
		return true
	return finito((lista[i - 1] as InfoLivello).id)


# --- Classifica della modalità infinita ---------------------------------------------

const MAX_CLASSIFICA := 10


## Le corse migliori di un livello, dalla prima: [{ondata, uccisioni, livello, data, squadra}].
static func classifica(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v in _cfg().get_value("classifica", id, []):
		if v is Dictionary:
			out.append(v)
	return out


## Ondata migliore raggiunta in modalità infinita (0 se mai giocata).
static func record_infinito(id: String) -> int:
	var c := classifica(id)
	return int(c[0].get("ondata", 0)) if not c.is_empty() else 0


## Inserisce una corsa: restituisce la posizione (0 = prima) o -1 se non entra.
static func aggiungi_classifica(id: String, voce: Dictionary) -> int:
	var c := classifica(id)
	var pos := c.size()
	for i in c.size():
		if _meglio(voce, c[i]):
			pos = i
			break
	if pos >= MAX_CLASSIFICA:
		return -1
	c.insert(pos, voce)
	if c.size() > MAX_CLASSIFICA:
		c.resize(MAX_CLASSIFICA)
	var cfg := _cfg()
	cfg.set_value("classifica", id, c)
	cfg.save(SAVE_PATH)
	return pos


static func azzera_classifica(id: String = "") -> void:
	var cfg := _cfg()
	if id == "":
		if cfg.has_section("classifica"):
			cfg.erase_section("classifica")
	elif cfg.has_section_key("classifica", id):
		cfg.erase_section_key("classifica", id)
	cfg.save(SAVE_PATH)


## Più ondate vince; a parità, più nemici uccisi.
static func _meglio(a: Dictionary, b: Dictionary) -> bool:
	var wa := int(a.get("ondata", 0))
	var wb := int(b.get("ondata", 0))
	if wa != wb:
		return wa > wb
	return int(a.get("uccisioni", 0)) > int(b.get("uccisioni", 0))


## Simbolo dell'infinito a pixel (il font non ce l'ha): 9x5 pixel da `px`.
const INF := [".XX...XX.", "X..X.X..X", "X...X...X", "X..X.X..X", ".XX...XX."]


static func disegna_infinito(ci: CanvasItem, pos: Vector2, px: float, col: Color, ombra: bool = true) -> void:
	for y in INF.size():
		var riga: String = INF[y]
		for x in riga.length():
			if riga[x] == "X":
				if ombra:
					ci.draw_rect(Rect2(pos + Vector2(x + 0.5, y + 0.5) * px, Vector2(px, px)), Color(0, 0, 0, 0.6))
				ci.draw_rect(Rect2(pos + Vector2(x, y) * px, Vector2(px, px)), col)
