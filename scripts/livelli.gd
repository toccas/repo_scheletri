extends RefCounted
## Progressi dei livelli (in user://progressi.cfg, sezione [livelli]):
##   scelto        id del livello scelto nella schermata dei livelli
##   scena         la sua scena (quella che parte dopo la preparazione)
##   finito_<id>   true quando hai superato tutte le ondate di quel livello
##   record_<id>   ondata migliore raggiunta in quel livello

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


static func scegli(info: InfoLivello) -> void:
	var cfg := _cfg()
	cfg.set_value("livelli", "scelto", info.id)
	cfg.set_value("livelli", "scena", info.scena)
	cfg.save(SAVE_PATH)


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
