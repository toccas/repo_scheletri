extends RefCounted
## I necromanti giocabili: quali hai comprato e quale usi.
## Salvati in user://progressi.cfg, sezione [necromanti]:
##   posseduti   id dei necromanti che hai (il Signore delle Ossa c'è sempre)
##   attivo      id del necromante scelto per le partite
##
## Da qualsiasi script:
##     const Necromanti := preload("res://scripts/necromanti.gd")
##     Necromanti.attivo()        -> Necromante (la risorsa .tres)
##     Necromanti.elenco()        -> tutti, nell'ordine di ELENCO
##
## Per aggiungerne uno: crea un nuovo .tres in necromanti/ (duplica uno di quelli
## che ci sono), aggiungi il percorso a ELENCO e i suoi nodi in research_data.gd.

const SAVE_PATH := "user://progressi.cfg"
const ELENCO := [
	"res://necromanti/ossa.tres",
	"res://necromanti/strega.tres",
	"res://necromanti/lich.tres",
]
const PRIMO := "ossa"

static var _cache: Array[Necromante] = []


static func elenco() -> Array[Necromante]:
	if _cache.is_empty():
		for p: String in ELENCO:
			var n := load(p) as Necromante
			if n != null:
				_cache.append(n)
	return _cache


static func per_id(id: String) -> Necromante:
	for n in elenco():
		if n.id == id:
			return n
	return elenco()[0] if not elenco().is_empty() else null


static func posseduti() -> Array:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var out: Array = Array(cfg.get_value("necromanti", "posseduti", []))
	for n in elenco():
		if n.prezzo <= 0 and not n.id in out:
			out.append(n.id)
	if not PRIMO in out:
		out.append(PRIMO)
	return out


static func possiede(id: String) -> bool:
	return id in posseduti()


## Il necromante scelto (se non lo possiedi più torna il Signore delle Ossa).
static func attivo() -> Necromante:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var id := String(cfg.get_value("necromanti", "attivo", PRIMO))
	if not possiede(id):
		id = PRIMO
	return per_id(id)


static func attivo_id() -> String:
	var n := attivo()
	return n.id if n != null else PRIMO


static func scegli(id: String) -> void:
	if not possiede(id):
		return
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("necromanti", "attivo", id)
	cfg.save(SAVE_PATH)


## Aggiunge il necromante a quelli posseduti (acquisto nel negozio o pannello dev).
static func sblocca(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var own: Array = Array(cfg.get_value("necromanti", "posseduti", []))
	if not id in own:
		own.append(id)
	cfg.set_value("necromanti", "posseduti", own)
	cfg.save(SAVE_PATH)


## Toglie il necromante da quelli posseduti (solo pannello dev).
static func togli(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var own: Array = Array(cfg.get_value("necromanti", "posseduti", []))
	own.erase(id)
	cfg.set_value("necromanti", "posseduti", own)
	cfg.save(SAVE_PATH)


## Il prossimo necromante posseduto dopo `id` (per i pulsanti che li fanno scorrere).
static func successivo(id: String, passo: int = 1, solo_posseduti: bool = true) -> String:
	var ids: Array = []
	for n in elenco():
		if not solo_posseduti or possiede(n.id):
			ids.append(n.id)
	if ids.is_empty():
		return PRIMO
	var i := ids.find(id)
	return ids[posmod(i + passo, ids.size())]
